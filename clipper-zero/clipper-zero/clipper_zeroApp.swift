import SwiftUI
import SwiftData

@main
struct ClipperZeroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([ClipItem.self, ClipCollection.self, ExcludedApp.self])
            let config = ModelConfiguration("ClipperZero", schema: schema)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        appDelegate.modelContainer = modelContainer
    }

    var body: some Scene {
        MenuBarExtra("Clipper Zero", systemImage: "clipboard") {
            MenuBarView()
                .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }
}
