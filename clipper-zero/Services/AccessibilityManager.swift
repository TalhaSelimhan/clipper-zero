import AppKit
import ApplicationServices

enum AccessibilityManager {
    private static var permissionTimer: Timer?
    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
    }

    static func promptForAccessibility() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )

        if !trusted {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Clipper Zero needs Accessibility permission to:\n\n• Register the global hotkey (⌘⇧V)\n• Paste clips into other apps\n\nPlease grant access in System Settings → Privacy & Security → Accessibility."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                openAccessibilitySettings()
            }
        }
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Polls for accessibility permission and calls the handler when granted
    static func waitForPermission(completion: @escaping () -> Void) {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if isAccessibilityGranted() {
                timer.invalidate()
                permissionTimer = nil
                completion()
            }
        }
    }
}
