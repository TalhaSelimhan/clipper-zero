import AppKit
import SwiftData
import Foundation
import UniformTypeIdentifiers

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
            self?.checkPasteboard()
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

    @MainActor
    private func captureClip(from pasteboard: NSPasteboard) {
        let context = modelContainer.mainContext

        let (contentType, content, plainText) = extractContent(from: pasteboard)
        guard let content else { return }

        // If a clip with the same text already exists, move it to the top instead of duplicating
        if let plainText, let existing = findExistingClip(plainText: plainText, in: context) {
            existing.createdAt = .now
            try? context.save()
            return
        }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let clip = ClipItem(
            content: content,
            contentType: contentType,
            plainText: plainText,
            sourceAppBundle: frontApp?.bundleIdentifier,
            sourceAppName: frontApp?.localizedName
        )

        if contentType == .image {
            clip.previewData = generateThumbnail(from: content)
        }

        context.insert(clip)
        try? context.save()

        enforceRetentionPolicy(in: context)

        if UserDefaults.standard.bool(forKey: "playSoundOnCopy") {
            NSSound(named: "Pop")?.play()
        }
    }

    private func findExistingClip(plainText: String, in context: ModelContext) -> ClipItem? {
        let predicate = #Predicate<ClipItem> { $0.plainText == plainText }
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

        // Check for image
        if let imageType = pasteboard.availableType(from: [.tiff, .png]) {
            if let imageData = pasteboard.data(forType: imageType) {
                return (.image, imageData, nil)
            }
        }

        // Check for file URLs
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], let firstURL = fileURLs.first {
            let bookmarkData = try? firstURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return (.file, bookmarkData ?? Data(), firstURL.lastPathComponent)
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
        let limit = UserDefaults.standard.integer(forKey: "historyLimit")
        let effectiveLimit = limit > 0 ? limit : 1000

        let countDescriptor = FetchDescriptor<ClipItem>()
        guard let totalCount = try? context.fetchCount(countDescriptor),
              totalCount > effectiveLimit else { return }

        let excess = totalCount - effectiveLimit

        // Fetch oldest unpinned items not in any collection
        let predicate = #Predicate<ClipItem> { item in
            !item.isPinned && (item.collections?.isEmpty ?? true)
        }
        var descriptor = FetchDescriptor<ClipItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = excess

        guard let oldItems = try? context.fetch(descriptor) else { return }
        for item in oldItems {
            context.delete(item)
        }
        try? context.save()
    }
}
