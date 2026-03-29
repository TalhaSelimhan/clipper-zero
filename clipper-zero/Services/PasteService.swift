import AppKit
import Foundation

@MainActor
final class PasteService {
    static let shared = PasteService()

    private init() {}

    func paste(clip: ClipItem) {
        writeToPasteboard(clip: clip)
        hideAndPaste()
    }

    func copyOnly(clip: ClipItem) {
        writeToPasteboard(clip: clip)
    }

    func paste(snippet: SnippetItem) {
        writeToPasteboard(text: snippet.value)
        hideAndPaste()
    }

    func copyOnly(snippet: SnippetItem) {
        writeToPasteboard(text: snippet.value)
    }

    func paste(_ result: SearchResult) {
        switch result {
        case .clip(let clip): paste(clip: clip)
        case .snippet(let snippet): paste(snippet: snippet)
        }
    }

    func copyOnly(_ result: SearchResult) {
        switch result {
        case .clip(let clip): copyOnly(clip: clip)
        case .snippet(let snippet): copyOnly(snippet: snippet)
        }
    }

    private func hideAndPaste() {
        AppDelegate.shared.panelController.hidePanel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulateCmdV()
        }
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
            let bookmarks: [Data]
            if let decoded = try? JSONDecoder().decode([Data].self, from: clip.content) {
                bookmarks = decoded
            } else {
                bookmarks = [clip.content] // Legacy single bookmark
            }
            let urls: [NSURL] = bookmarks.compactMap { bookmark in
                var isStale = false
                return try? URL(
                    resolvingBookmarkData: bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) as NSURL
            }
            if !urls.isEmpty {
                pasteboard.writeObjects(urls)
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
