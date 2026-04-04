import SwiftData
import Foundation

@MainActor
final class SecureItemCleanupService {
    private let modelContainer: ModelContainer
    private var timer: Timer?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func start() {
        cleanup()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cleanup()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func cleanup() {
        let context = modelContainer.mainContext
        let now = Date.now

        // Expired secure clips
        let clipPredicate = #Predicate<ClipItem> { item in
            item.isSecure && item.expiresAt != nil && item.expiresAt! < now
        }
        if let expiredClips = try? context.fetch(FetchDescriptor(predicate: clipPredicate)) {
            for clip in expiredClips {
                context.delete(clip)
            }
        }

        // Expired secure snippets
        let snippetPredicate = #Predicate<SecureSnippetItem> { item in
            item.expiresAt != nil && item.expiresAt! < now
        }
        if let expiredSnippets = try? context.fetch(FetchDescriptor(predicate: snippetPredicate)) {
            for snippet in expiredSnippets {
                context.delete(snippet)
            }
        }

        try? context.save()
    }
}
