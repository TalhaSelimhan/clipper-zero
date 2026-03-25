import AppKit
import SwiftData
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    var modelContainer: ModelContainer!

    private(set) var clipboardMonitor: ClipboardMonitor!
    private(set) var panelController: PanelController!
    private(set) var hotkeyManager: GlobalHotkeyManager!

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
