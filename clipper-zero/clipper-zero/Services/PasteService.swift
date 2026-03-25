import AppKit
import Foundation

@MainActor
final class PasteService {
    static let shared = PasteService()

    private init() {}

    func paste(clip: ClipItem) {
        writeToPasteboard(clip: clip)
        AppDelegate.shared.panelController.hidePanel()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulateCmdV()
        }
    }

    func copyOnly(clip: ClipItem) {
        writeToPasteboard(clip: clip)
    }

    func paste(snippet: SnippetItem) {
        writeToPasteboard(text: snippet.value)
        AppDelegate.shared.panelController.hidePanel()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulateCmdV()
        }
    }

    func copyOnly(snippet: SnippetItem) {
        writeToPasteboard(text: snippet.value)
    }

    private func writeToPasteboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func writeToPasteboard(clip: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch clip.contentType {
        case .text:
            if let text = String(data: clip.content, encoding: .utf8) {
                pasteboard.setString(text, forType: .string)
            }
        case .richText:
            pasteboard.setData(clip.content, forType: .rtf)
            if let plainText = clip.plainText {
                pasteboard.setString(plainText, forType: .string)
            }
        case .image:
            pasteboard.setData(clip.content, forType: .tiff)
        case .file:
            // Resolve bookmark data back to URL
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: clip.content,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                pasteboard.writeObjects([url as NSURL])
            }
        case .color:
            if let text = String(data: clip.content, encoding: .utf8) {
                pasteboard.setString(text, forType: .string)
            }
        case .link:
            if let urlString = String(data: clip.content, encoding: .utf8) {
                pasteboard.setString(urlString, forType: .string)
                if let url = URL(string: urlString) {
                    pasteboard.setString(url.absoluteString, forType: .URL)
                }
            }
        }
    }

    private func simulateCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = V
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
