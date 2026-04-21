import AppKit
import SwiftData
import Foundation
import UniformTypeIdentifiers
import os

@MainActor
final class ClipboardMonitor {
    private let modelContainer: ModelContainer
    private var timer: Timer?
    private var lastChangeCount: Int = 0

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkPasteboard()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }

        if PasteService.shouldIgnorePasteboardChange(currentChangeCount) {
            lastChangeCount = currentChangeCount
            return
        }

        if PasteService.isPasting {
            lastChangeCount = currentChangeCount
            return
        }

        lastChangeCount = currentChangeCount

        // Check if the frontmost app is excluded
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontApp.bundleIdentifier {
            if isAppExcluded(bundleId: bundleId) { return }
        }

        self.captureClip(from: pasteboard)
    }

    private func isAppExcluded(bundleId: String) -> Bool {
        let context = modelContainer.mainContext
        let predicate = #Predicate<ExcludedApp> { $0.bundleIdentifier == bundleId }
        let descriptor = FetchDescriptor<ExcludedApp>(predicate: predicate)
        let results = (try? context.fetch(descriptor)) ?? []
        return !results.isEmpty
    }

    private static let logger = Logger(subsystem: "com.talhaselimhan.Clipper-Zero", category: "ClipboardMonitor")

    private func captureClip(from pasteboard: NSPasteboard) {
        let context = modelContainer.mainContext

        let (contentType, content, plainText) = extractContent(from: pasteboard)
        guard let content else { return }

        // Extract file name for sensitivity detection on file clips
        let fileName: String? = {
            guard contentType == .file else { return nil }
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL], let first = urls.first {
                return first.lastPathComponent
            }
            return nil
        }()

        // Detect sensitive content before dedup (sensitive files should be checked early)
        let autoDetect = UserDefaults.standard.object(forKey: "autoDetectSensitive") as? Bool ?? true
        let detection = autoDetect
            ? SensitiveContentDetector.detect(plainText: plainText, contentType: contentType, fileName: fileName)
            : nil

        // Dedup check — skip entirely for sensitive items to avoid dropping distinct secrets
        if detection == nil,
           contentType != .file,
           let plainText,
           let existing = findExistingClip(plainText: plainText, contentType: contentType, in: context) {
            existing.createdAt = .now
            try? context.save()
            return
        }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let clip: ClipItem

        if let detection {
            // Sensitive content detected — encrypt and store securely
            let ttl = TimeInterval(UserDefaults.standard.integer(forKey: "secureItemTTL").nonZeroOr(86400))
            do {
                let encrypted = try EncryptionService.encrypt(content)
                clip = ClipItem(
                    content: Data(),
                    contentType: contentType,
                    plainText: detection.maskedPreview,
                    sourceAppBundle: frontApp?.bundleIdentifier,
                    sourceAppName: frontApp?.localizedName,
                    isSecure: true,
                    encryptedContent: encrypted,
                    expiresAt: Date.now.addingTimeInterval(ttl),
                    secureLabel: detection.label
                )
            } catch {
                Self.logger.warning("Encryption failed, skipping secure clip capture: \(error.localizedDescription)")
                return
            }
        } else {
            clip = ClipItem(
                content: content,
                contentType: contentType,
                plainText: plainText,
                sourceAppBundle: frontApp?.bundleIdentifier,
                sourceAppName: frontApp?.localizedName
            )
        }

        if contentType == .image && !clip.isSecure {
            clip.previewData = generateThumbnail(from: content)
        }

        context.insert(clip)
        try? context.save()

        enforceRetentionPolicy(in: context)

        if UserDefaults.standard.bool(forKey: "playSoundOnCopy") {
            NSSound(named: "Pop")?.play()
        }
    }

    private func findExistingClip(plainText: String, contentType: ClipContentType, in context: ModelContext) -> ClipItem? {
        let predicate = #Predicate<ClipItem> { $0.plainText == plainText && $0.contentType == contentType }
        var descriptor = FetchDescriptor<ClipItem>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func extractContent(from pasteboard: NSPasteboard) -> (ClipContentType, Data?, String?) {
        // Check for color
        if let color = NSColor(from: pasteboard) {
            let colorDesc = color.description
            return (.color, colorDesc.data(using: .utf8), colorDesc)
        }

        // Check for file URLs (before images — Finder puts both file URL and TIFF on the pasteboard)
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !fileURLs.isEmpty {
            let bookmarks = fileURLs.compactMap { url in
                try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }
            guard !bookmarks.isEmpty else { return (.text, nil, nil) }
            let encoded = (try? JSONEncoder().encode(bookmarks)) ?? Data()
            let plainText = fileURLs.count == 1
                ? fileURLs[0].lastPathComponent
                : "\(fileURLs.count) files"
            return (.file, encoded, plainText)
        }

        // Check for image (in-app copies like screenshots, not file copies)
        if let imageType = pasteboard.availableType(from: [.tiff, .png]) {
            if let imageData = pasteboard.data(forType: imageType) {
                return (.image, imageData, nil)
            }
        }

        // Check for URL (link)
        if let urlString = pasteboard.string(forType: .URL) ?? pasteboard.string(forType: .string),
           let url = URL(string: urlString), url.scheme != nil,
           urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            let data = urlString.data(using: .utf8)
            return (.link, data, urlString)
        }

        // Check for rich text
        if let rtfData = pasteboard.data(forType: .rtf) {
            let plainText = pasteboard.string(forType: .string)
            return (.richText, rtfData, plainText)
        }

        // Plain text
        if let text = pasteboard.string(forType: .string) {
            return (.text, text.data(using: .utf8), text)
        }

        return (.text, nil, nil)
    }

    private func generateThumbnail(from imageData: Data) -> Data? {
        guard let image = NSImage(data: imageData) else { return nil }
        let maxDimension: CGFloat = 64
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let thumbnail = NSImage(size: newSize, flipped: false) { rect in
            image.draw(in: rect)
            return true
        }
        return thumbnail.tiffRepresentation
    }

    private func enforceRetentionPolicy(in context: ModelContext) {
        let effectiveLimit = normalizedHistoryLimit()

        let countDescriptor = FetchDescriptor<ClipItem>()
        guard let totalCount = try? context.fetchCount(countDescriptor),
              totalCount > effectiveLimit else { return }

        let excess = totalCount - effectiveLimit

        // Keep the SQL predicate limited to scalar fields. Filtering on the
        // to-many relationship in memory avoids SwiftData/Core Data SQL
        // generation crashes for `collections?.isEmpty`.
        let predicate = #Predicate<ClipItem> { item in
            !item.isPinned && !item.isSecure
        }
        let descriptor = FetchDescriptor<ClipItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        
        guard let candidates = try? context.fetch(descriptor) else { return }
        let oldItems = candidates
            .lazy
            .filter { $0.collections?.isEmpty ?? true }
            .prefix(excess)

        for item in oldItems {
            context.delete(item)
        }
        try? context.save()
    }

    private func normalizedHistoryLimit() -> Int {
        let limit = UserDefaults.standard.integer(forKey: "historyLimit")
        if limit == 0 { return 1000 }
        if limit < 100 {
            UserDefaults.standard.set(100, forKey: "historyLimit")
            Self.logger.notice("Normalized invalid historyLimit=\(limit) to 100")
            return 100
        }
        return limit
    }
}

extension Int {
    func nonZeroOr(_ fallback: Int) -> Int {
        self != 0 ? self : fallback
    }
}
