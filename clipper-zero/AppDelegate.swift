import AppKit
import SwiftData
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate!

    var modelContainer: ModelContainer!

    private(set) var clipboardMonitor: ClipboardMonitor!
    private(set) var panelController: PanelController!
    private(set) var hotkeyManager: GlobalHotkeyManager!

    private var onboardingWindow: NSWindow?
    private var onboardingCompleted = false

    private enum DefaultsKey {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private static let onboardingSize = CGSize(width: OnboardingView.frameWidth, height: OnboardingView.frameHeight)

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setup()
    }

    private func setup() {
        clipboardMonitor = ClipboardMonitor(modelContainer: modelContainer)
        panelController = PanelController(modelContainer: modelContainer)
        hotkeyManager = GlobalHotkeyManager { [weak self] in
            self?.panelController.togglePanel()
        }

        if UserDefaults.standard.bool(forKey: DefaultsKey.hasCompletedOnboarding) {
            checkAccessibilityAndStart()
        } else {
            showOnboarding()
        }
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        // Show in Cmd+Tab during onboarding so users can find the window
        NSApp.setActivationPolicy(.regular)

        let onboardingView = OnboardingView { [weak self] in
            self?.completeOnboarding()
        }

        let hostingView = NSHostingView(rootView: onboardingView)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.onboardingSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        window.hasShadow = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        self.onboardingWindow = window
    }

    private func completeOnboarding() {
        guard !onboardingCompleted else { return }
        onboardingCompleted = true
        UserDefaults.standard.set(true, forKey: DefaultsKey.hasCompletedOnboarding)
        onboardingWindow?.close()
        onboardingWindow = nil

        // Hide from Cmd+Tab again (agent/menu bar app)
        NSApp.setActivationPolicy(.accessory)

        checkAccessibilityAndStart()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === onboardingWindow,
              !onboardingCompleted else { return }
        completeOnboarding()
    }

    // MARK: - Services

    private func checkAccessibilityAndStart() {
        if AccessibilityManager.isAccessibilityGranted() {
            startServices()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                AccessibilityManager.promptForAccessibility()
            }

            AccessibilityManager.waitForPermission { [weak self] in
                self?.startServices()
            }
        }
    }

    private func startServices() {
        clipboardMonitor.start()
        hotkeyManager.register()
    }
}
