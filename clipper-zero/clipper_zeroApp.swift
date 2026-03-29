import SwiftUI
import SwiftData
@main
struct ClipperZeroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var updaterViewModel = CheckForUpdatesViewModel()

    let modelContainer: ModelContainer

    init() {
        // Phase 1: Extract old snippets before creating the main container
        // to avoid two ModelContainers competing on the same SQLite file.
        let oldSnippets = SnippetMigrationService.extractOldSnippetsIfNeeded()

        do {
            let schema = Schema([ClipItem.self, ClipCollection.self, ExcludedApp.self, SnippetItem.self])

            let localConfig = ModelConfiguration(
                "ClipperZero",
                schema: Schema([ClipItem.self, ClipCollection.self, ExcludedApp.self]),
                cloudKitDatabase: .none
            )

            let cloudConfig = ModelConfiguration(
                "ClipperZeroSnippets",
                schema: Schema([SnippetItem.self]),
                cloudKitDatabase: .automatic
            )

            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: ClipperZeroMigrationPlan.self,
                configurations: [localConfig, cloudConfig]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Phase 2: Insert extracted snippets into the cloud store.
        SnippetMigrationService.completeMigration(oldSnippets, into: modelContainer)
        appDelegate.modelContainer = modelContainer
    }

    var body: some Scene {
        MenuBarExtra("Clipper Zero", systemImage: "clipboard") {
            MenuBarView()
                .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(updaterViewModel: updaterViewModel)
        }
        .modelContainer(modelContainer)
    }
}
