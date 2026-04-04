import SwiftData

enum ModelContainerFactory {
    static func create() -> ModelContainer {
        // Phase 1: Extract old snippets before creating the main container
        // to avoid two ModelContainers competing on the same SQLite file.
        let oldSnippets = SnippetMigrationService.extractOldSnippetsIfNeeded()

        do {
            let schema = Schema([ClipItem.self, ClipCollection.self, ExcludedApp.self, SnippetItem.self, SecureSnippetItem.self])

            let localConfig = ModelConfiguration(
                "ClipperZero",
                schema: Schema([ClipItem.self, ClipCollection.self, ExcludedApp.self, SecureSnippetItem.self]),
                cloudKitDatabase: .none
            )

            let cloudConfig = ModelConfiguration(
                "ClipperZeroSnippets",
                schema: Schema([SnippetItem.self]),
                cloudKitDatabase: .automatic
            )

            let container = try ModelContainer(
                for: schema,
                migrationPlan: ClipperZeroMigrationPlan.self,
                configurations: [localConfig, cloudConfig]
            )

            // Phase 2: Insert extracted snippets into the cloud store.
            SnippetMigrationService.completeMigration(oldSnippets, into: container)
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
