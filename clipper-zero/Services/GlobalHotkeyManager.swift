import AppKit
import Carbon.HIToolbox

final class GlobalHotkeyManager {
    // nonisolated(unsafe): these are only mutated from the main thread,
    // but must be accessed from the C event-tap callback which cannot be actor-isolated.
    nonisolated(unsafe) private var eventTap: CFMachPort?
    nonisolated(unsafe) private var runLoopSource: CFRunLoopSource?
    private var registeredRunLoop: CFRunLoop?
    private var retainedSelfPtr: UnsafeMutableRawPointer?
    private let onToggle: @Sendable () -> Void

    init(onToggle: @escaping @Sendable () -> Void) {
        self.onToggle = onToggle
    }

    func register() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }

        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        retainedSelfPtr = selfPtr

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            print("Failed to create event tap. Accessibility permission may not be granted.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        registeredRunLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(registeredRunLoop, runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(registeredRunLoop, source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        registeredRunLoop = nil
        if let selfPtr = retainedSelfPtr {
            Unmanaged<GlobalHotkeyManager>.fromOpaque(selfPtr).release()
            retainedSelfPtr = nil
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Cmd+Shift+V: keyCode 9 = V
        let hasCmd = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)
        let isV = keyCode == 9

        if hasCmd && hasShift && isV {
            Task { @MainActor [weak self] in
                self?.onToggle()
            }
            return nil // Consume the event
        }

        return Unmanaged.passRetained(event)
    }

    deinit {
        unregister()
    }
}
