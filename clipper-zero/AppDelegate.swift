import AppKit
import ServiceManagement
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
        static let hasAskedLaunchAtLogin = "hasAskedLaunchAtLogin"
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

    // MARK: - Settings Activation

    /// Temporarily switches to `.regular` activation policy so the Settings
    /// window appears in front of other apps, then reverts to `.accessory`
    /// once the window closes or is hidden.
    func activateForSettings() {
        guard !isActivatingForSettings else { return }
        isActivatingForSettings = true

        NSApp.setActivationPolicy(.regular)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        // The Settings scene window is created asynchronously by SwiftUI.
        // Wait briefly, then find it and observe visibility to revert policy.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let settingsWindow = NSApp.windows.first(where: {
                $0.identifier?.rawValue.localizedCaseInsensitiveContains("settings") == true
                || $0.frameAutosaveName.localizedCaseInsensitiveContains("settings")
            }) else {
                self?.revertToAccessory()
                return
            }

            settingsWindow.makeKeyAndOrderFront(nil)
            self?.observeSettingsClose(settingsWindow)
        }
    }

    private var isActivatingForSettings = false
    private var settingsVisibilityObservation: NSKeyValueObservation?

    private func observeSettingsClose(_ window: NSWindow) {
        settingsVisibilityObservation?.invalidate()
        // KVO on isVisible catches both close and orderOut (red X may hide
        // SwiftUI Settings windows instead of closing them).
        settingsVisibilityObservation = window.observe(\.isVisible, options: [.new]) { [weak self] _, change in
            guard change.newValue == false else { return }
            self?.settingsVisibilityObservation?.invalidate()
            DispatchQueue.main.async {
                self?.settingsVisibilityObservation = nil
                self?.revertToAccessory()
            }
        }
    }

    private func revertToAccessory() {
        isActivatingForSettings = false
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Services

    private func checkAccessibilityAndStart() {
        if AccessibilityManager.isAccessibilityGranted() {
            promptLaunchAtLoginIfNeeded()
            startServices()
        } else {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                AccessibilityManager.promptForAccessibility()
            }

            AccessibilityManager.waitForPermission { [weak self] in
                self?.promptLaunchAtLoginIfNeeded()
                self?.startServices()
            }
        }
    }

    private func promptLaunchAtLoginIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.hasAskedLaunchAtLogin) else { return }
        UserDefaults.standard.set(true, forKey: DefaultsKey.hasAskedLaunchAtLogin)

        let alert = NSAlert()
        alert.messageText = "Open at Launch?"
        alert.informativeText = "Would you like Clipper Zero to start automatically when you log in?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")

        if alert.runModal() == .alertFirstButtonReturn {
            try? SMAppService.mainApp.register()
        }
    }

    private func startServices() {
        clipboardMonitor.start()
        hotkeyManager.register()
    }
}
