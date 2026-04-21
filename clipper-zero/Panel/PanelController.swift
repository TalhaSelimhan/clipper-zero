import AppKit
import SwiftUI
import SwiftData

final class PanelController {
    private var panel: NSPanel?
    private var clickOutsideMonitor: Any?
    private var appActivationObserver: NSObjectProtocol?
    private let modelContainer: ModelContainer

    private var sharedModelContext: ModelContext {
        modelContainer.mainContext
    }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    deinit {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func togglePanel() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        if panel == nil {
            createPanel()
        }

        guard let panel else { return }

        positionPanel(panel)

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.hidePanel()
            }
        }

        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hidePanel()
        }
    }

    func hidePanel() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }

        guard let panel, panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
        })
    }

    private func createPanel() {
        let contentView = ClipboardPanel(
            onDismiss: { [weak self] in self?.hidePanel() }
        )
        .modelContainer(modelContainer)
        .modelContext(sharedModelContext)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: PanelMetrics.width, height: PanelMetrics.height)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: PanelMetrics.width, height: PanelMetrics.height),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false

        // Allow the panel to become key so the search field can receive input
        panel.becomesKeyOnlyIfNeeded = false

        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY - panelSize.height / 2 + screenFrame.height * 0.1 // slightly above center

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
