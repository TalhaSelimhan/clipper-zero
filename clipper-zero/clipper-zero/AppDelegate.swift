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

    private static let onboardingSize = CGSize(width: 520, height: 440)

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
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
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
