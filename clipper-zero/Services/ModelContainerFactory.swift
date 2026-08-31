import Foundation
import SwiftData

enum ModelContainerFactory {
    static func create() -> ModelContainer {
        // Phase 1: Extract old snippets before creating the main container
        // to avoid two ModelContainers competing on the same SQLite file.
        let oldSnippets = SnippetMigrationService.extractOldSnippetsIfNeeded()

        do {
            let container = try makeContainer()
            // Phase 2: Insert extracted snippets into the cloud store.
            SnippetMigrationService.completeMigration(oldSnippets, into: container)
            return container
        } catch {
            NSLog("ClipperZero: ModelContainer load failed: \(error)")
            return recover(from: error, pendingSnippets: oldSnippets)
        }
    }

    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema([ClipItem.self, ClipCollection.self, ExcludedApp.self, SnippetItem.self, SecureSnippetItem.self])

        let localConfig = ModelConfiguration(
            StoreLocation.localName,
            schema: Schema([ClipItem.self, ClipCollection.self, ExcludedApp.self, SecureSnippetItem.self]),
            cloudKitDatabase: .none
        )

        let cloudConfig = ModelConfiguration(
            StoreLocation.cloudName,
            schema: Schema([SnippetItem.self]),
            cloudKitDatabase: .automatic
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: ClipperZeroMigrationPlan.self,
            configurations: [localConfig, cloudConfig]
        )
    }

    /// A store that no version in the migration plan can identify (written by a
    /// newer build, stamped with a partial schema, or simply corrupt) would
    /// otherwise trap on every launch with no way out short of deleting files by
    /// hand. Move the stores aside instead and start clean.
    ///
    /// The local store goes first: clipboard history is a cache. The cloud store
    /// is only touched if that was not enough, and it re-populates from CloudKit.
    /// Neither is deleted — both are renamed with a timestamp.
    private static func recover(from originalError: Error, pendingSnippets: [MigratedSnippet]?) -> ModelContainer {
        for storeURL in [StoreLocation.local, StoreLocation.cloud] {
            guard let quarantined = StoreLocation.quarantine(storeURL) else { continue }
            NSLog("ClipperZero: quarantined \(storeURL.lastPathComponent) to \(quarantined.lastPathComponent)")

            do {
                let container = try makeContainer()
                SnippetMigrationService.completeMigration(pendingSnippets, into: container)
                return container
            } catch {
                NSLog("ClipperZero: ModelContainer still failing after quarantine: \(error)")
            }
        }

        // Nothing left to move aside — the failure is not the stores.
        fatalError("Failed to create ModelContainer: \(originalError)")
    }
}
