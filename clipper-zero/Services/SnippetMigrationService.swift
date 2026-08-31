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

        let oldSchema = Schema([SnippetItem.self])
        let oldConfig = ModelConfiguration(
            "ClipperZero",
            schema: oldSchema,
            cloudKitDatabase: .none
        )

        // On a fresh install there is no legacy store to read. Opening a container
        // here would CREATE "ClipperZero.store" with a snippet-only model, and the
        // main container — which owns that same file with the full local schema —
        // would then fail to open it and trap in ModelContainerFactory. Nothing to
        // migrate, so record completion and leave the file for the main container.
        guard FileManager.default.fileExists(atPath: oldConfig.url.path(percentEncoded: false)) else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return nil
        }

        do {
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
