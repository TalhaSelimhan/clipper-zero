import SwiftData
import Foundation

enum SnippetMigrationService {
    private static let migrationKey = "hasCompletedSnippetCloudMigration"

    static func migrateIfNeeded(container: ModelContainer) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

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
                return
            }

            let newContext = ModelContext(container)
            for old in oldSnippets {
                let migrated = SnippetItem(
                    name: old.name,
                    value: old.value,
                    sortOrder: old.sortOrder
                )
                migrated.createdAt = old.createdAt
                newContext.insert(migrated)
            }
            try newContext.save()

            for old in oldSnippets {
                oldContext.delete(old)
            }
            try oldContext.save()

            UserDefaults.standard.set(true, forKey: migrationKey)
        } catch {
            print("Snippet migration failed: \(error)")
        }
    }
}
