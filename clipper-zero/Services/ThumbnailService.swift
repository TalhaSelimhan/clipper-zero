import AppKit
import QuickLookThumbnailing

enum ThumbnailService {
    static func generateThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let scale = await MainActor.run {
            NSScreen.main?.backingScaleFactor ?? 2.0
        }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return representation.nsImage
        } catch {
            return nil
        }
    }
}
