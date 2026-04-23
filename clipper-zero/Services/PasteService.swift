import AppKit
import Foundation

@MainActor
final class PasteService {
    static let shared = PasteService()
    static var isPasting = false
    private static var ignoredPasteboardChangeCount: Int?

    private init() {}

    // MARK: - Public API

    func paste(clip: ClipItem) async -> Bool {
        if clip.isSecure {
            guard await AuthenticationService.authenticate(reason: "Paste secure content") else { return false }
            guard let encrypted = clip.encryptedContent,
                  let decrypted = try? EncryptionService.decrypt(encrypted) else { return false }
            setPasteGuard()
            writeDecrypted(data: decrypted, contentType: clip.contentType, plainText: clip.plainText)
            hideAndPaste()
            return true
        } else {
            writeToPasteboard(clip: clip)
            hideAndPaste()
            return true
        }
    }

    func copyOnly(clip: ClipItem) async -> Bool {
        if clip.isSecure {
            guard await AuthenticationService.authenticate(reason: "Copy secure content") else { return false }
            guard let encrypted = clip.encryptedContent,
                  let decrypted = try? EncryptionService.decrypt(encrypted) else { return false }
            setPasteGuard()
            writeDecrypted(data: decrypted, contentType: clip.contentType, plainText: clip.plainText)
            return true
        } else {
            writeToPasteboard(clip: clip)
            return true
        }
    }

    func paste(snippet: SnippetItem) -> Bool {
        writeToPasteboard(text: snippet.value)
        hideAndPaste()
        return true
    }

    func copyOnly(snippet: SnippetItem) -> Bool {
        writeToPasteboard(text: snippet.value)
        return true
    }

    func paste(secureSnippet: SecureSnippetItem) async -> Bool {
        guard await AuthenticationService.authenticate(reason: "Paste secure snippet") else { return false }
        guard let decrypted = try? EncryptionService.decrypt(secureSnippet.encryptedValue),
              let text = String(data: decrypted, encoding: .utf8) else { return false }
        setPasteGuard()
        writeToPasteboard(text: text)
        hideAndPaste()
        return true
    }

    func copyOnly(secureSnippet: SecureSnippetItem) async -> Bool {
        guard await AuthenticationService.authenticate(reason: "Copy secure snippet") else { return false }
        guard let decrypted = try? EncryptionService.decrypt(secureSnippet.encryptedValue),
              let text = String(data: decrypted, encoding: .utf8) else { return false }
        setPasteGuard()
        writeToPasteboard(text: text)
        return true
    }

    func paste(_ result: SearchResult) async -> Bool {
        switch result {
        case .clip(let clip): await paste(clip: clip)
        case .snippet(let snippet): paste(snippet: snippet)
        case .secureSnippet(let snippet): await paste(secureSnippet: snippet)
        }
    }

    func copyOnly(_ result: SearchResult) async -> Bool {
        switch result {
        case .clip(let clip): await copyOnly(clip: clip)
        case .snippet(let snippet): copyOnly(snippet: snippet)
        case .secureSnippet(let snippet): await copyOnly(secureSnippet: snippet)
        }
    }

    static func shouldIgnorePasteboardChange(_ changeCount: Int) -> Bool {
        guard ignoredPasteboardChangeCount == changeCount else { return false }
        ignoredPasteboardChangeCount = nil
        return true
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
        // Tiny delay to let WindowServer transfer key status to the previous app
        // before we post the synthetic ⌘V event.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            self.simulateCmdV()
        }
    }

    private func writeToPasteboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        registerPasteboardWrite(pasteboard)
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

        registerPasteboardWrite(pasteboard)
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

        registerPasteboardWrite(pasteboard)
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

    private func registerPasteboardWrite(_ pasteboard: NSPasteboard) {
        PasteService.ignoredPasteboardChangeCount = pasteboard.changeCount
    }
}
