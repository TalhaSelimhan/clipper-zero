import SwiftUI
import SwiftData
@main
struct ClipperZeroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var updaterViewModel = CheckForUpdatesViewModel()

    let modelContainer: ModelContainer

    private var sharedModelContext: ModelContext {
        modelContainer.mainContext
    }

    init() {
        modelContainer = ModelContainerFactory.create()
        appDelegate.modelContainer = modelContainer
    }

    var body: some Scene {
        MenuBarExtra("Clipper Zero", systemImage: "clipboard") {
            MenuBarView()
                .modelContainer(modelContainer)
                .modelContext(sharedModelContext)
        }
        .menuBarExtraStyle(.window)
        .modelContext(sharedModelContext)

        Settings {
            SettingsView(updaterViewModel: updaterViewModel)
        }
        .modelContainer(modelContainer)
        .modelContext(sharedModelContext)
    }
}
