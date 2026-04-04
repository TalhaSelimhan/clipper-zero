import AppKit
import Foundation

@MainActor
final class PasteService {
    static let shared = PasteService()
    static var isPasting = false

    private init() {}

    // MARK: - Public API

    func paste(clip: ClipItem) async {
        if clip.isSecure {
            guard await AuthenticationService.authenticate(reason: "Paste secure content") else { return }
            guard let encrypted = clip.encryptedContent,
                  let decrypted = try? EncryptionService.decrypt(encrypted) else { return }
            setPasteGuard()
            writeDecrypted(data: decrypted, contentType: clip.contentType, plainText: clip.plainText)
            hideAndPaste()
        } else {
            writeToPasteboard(clip: clip)
            hideAndPaste()
        }
    }

    func copyOnly(clip: ClipItem) async {
        if clip.isSecure {
            guard await AuthenticationService.authenticate(reason: "Copy secure content") else { return }
            guard let encrypted = clip.encryptedContent,
                  let decrypted = try? EncryptionService.decrypt(encrypted) else { return }
            setPasteGuard()
            writeDecrypted(data: decrypted, contentType: clip.contentType, plainText: clip.plainText)
        } else {
            writeToPasteboard(clip: clip)
        }
    }

    func paste(snippet: SnippetItem) {
        writeToPasteboard(text: snippet.value)
        hideAndPaste()
    }

    func copyOnly(snippet: SnippetItem) {
        writeToPasteboard(text: snippet.value)
    }

    func paste(secureSnippet: SecureSnippetItem) async {
        guard await AuthenticationService.authenticate(reason: "Paste secure snippet") else { return }
        guard let decrypted = try? EncryptionService.decrypt(secureSnippet.encryptedValue),
              let text = String(data: decrypted, encoding: .utf8) else { return }
        setPasteGuard()
        writeToPasteboard(text: text)
        hideAndPaste()
    }

    func copyOnly(secureSnippet: SecureSnippetItem) async {
        guard await AuthenticationService.authenticate(reason: "Copy secure snippet") else { return }
        guard let decrypted = try? EncryptionService.decrypt(secureSnippet.encryptedValue),
              let text = String(data: decrypted, encoding: .utf8) else { return }
        setPasteGuard()
        writeToPasteboard(text: text)
    }

    func paste(_ result: SearchResult) async {
        switch result {
        case .clip(let clip): await paste(clip: clip)
        case .snippet(let snippet): paste(snippet: snippet)
        case .secureSnippet(let snippet): await paste(secureSnippet: snippet)
        }
    }

    func copyOnly(_ result: SearchResult) async {
        switch result {
        case .clip(let clip): await copyOnly(clip: clip)
        case .snippet(let snippet): copyOnly(snippet: snippet)
        case .secureSnippet(let snippet): await copyOnly(secureSnippet: snippet)
        }
    }

    // MARK: - Paste Guard

    private func setPasteGuard() {
        PasteService.isPasting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            PasteService.isPasting = false
        }
    }

    // MARK: - Private

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
        // Secure clips must use the writeDecrypted path
        guard !clip.isSecure else { return }

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

    private func writeDecrypted(data: Data, contentType: ClipContentType, plainText: String?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch contentType {
        case .text:
            if let text = String(data: data, encoding: .utf8) {
                pasteboard.setString(text, forType: .string)
            }
        case .richText:
            pasteboard.setData(data, forType: .rtf)
            if let attrStr = NSAttributedString(rtf: data, documentAttributes: nil) {
                pasteboard.setString(attrStr.string, forType: .string)
            }
        case .image:
            pasteboard.setData(data, forType: .tiff)
        case .file:
            let bookmarks: [Data]
            if let decoded = try? JSONDecoder().decode([Data].self, from: data) {
                bookmarks = decoded
            } else {
                bookmarks = [data]
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
            if let text = String(data: data, encoding: .utf8) {
                pasteboard.setString(text, forType: .string)
            }
        case .link:
            if let urlString = String(data: data, encoding: .utf8) {
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
