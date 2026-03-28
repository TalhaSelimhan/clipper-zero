import SwiftData
import Foundation

struct MigratedSnippet {
    let name: String
    let value: String
    let sortOrder: Int
    let createdAt: Date
}

enum SnippetMigrationService {
    private static let migrationKey = "hasCompletedSnippetCloudMigration"

    /// Phase 1: Read old snippets from the local store before the main container is created.
    /// Returns nil if migration already completed or no old snippets exist.
    static func extractOldSnippetsIfNeeded() -> [MigratedSnippet]? {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return nil }

        do {
            let oldSchema = Schema([SnippetItem.self])
            let oldConfig = ModelConfiguration(
                "ClipperZero",
                schema: oldSchema,
                cloudKitDatabase: .none
            )
            let oldContainer = try ModelContainer(for: oldSchema, configurations: [oldConfig])
            let oldContext = ModelContext(oldContainer)
            let oldSnippets = try oldContext.fetch(FetchDescriptor<SnippetItem>())

            guard !oldSnippets.isEmpty else {
                UserDefaults.standard.set(true, forKey: migrationKey)
                return nil
            }

            return oldSnippets.map { snippet in
                MigratedSnippet(
                    name: snippet.name,
                    value: snippet.value,
                    sortOrder: snippet.sortOrder,
                    createdAt: snippet.createdAt
                )
            }
        } catch {
            print("Snippet migration extraction failed: \(error)")
            return nil
        }
    }

    /// Phase 2: Insert extracted snippets into the cloud store with deduplication.
    static func completeMigration(_ snippets: [MigratedSnippet]?, into container: ModelContainer) {
        guard let snippets = snippets, !snippets.isEmpty else { return }

        do {
            let context = ModelContext(container)
            let existingSnippets = try context.fetch(FetchDescriptor<SnippetItem>())
            let existingPairs = Set(existingSnippets.map { "\($0.name)\u{0}\($0.value)" })

            for snippet in snippets {
                let key = "\(snippet.name)\u{0}\(snippet.value)"
                guard !existingPairs.contains(key) else { continue }

                let migrated = SnippetItem(
                    name: snippet.name,
                    value: snippet.value,
                    sortOrder: snippet.sortOrder
                )
                migrated.createdAt = snippet.createdAt
                context.insert(migrated)
            }
            try context.save()

            UserDefaults.standard.set(true, forKey: migrationKey)
        } catch {
            print("Snippet migration insertion failed: \(error)")
        }
    }
}
