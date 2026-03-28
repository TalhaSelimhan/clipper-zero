import SwiftUI
import SwiftData
@main
struct ClipperZeroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var updaterViewModel = CheckForUpdatesViewModel()

    let modelContainer: ModelContainer

    init() {
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

            modelContainer = try ModelContainer(for: schema, configurations: [localConfig, cloudConfig])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        SnippetMigrationService.migrateIfNeeded(container: modelContainer)
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
