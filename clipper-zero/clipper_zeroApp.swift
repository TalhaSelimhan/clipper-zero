import SwiftUI
import SwiftData
@main
struct ClipperZeroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var updaterViewModel = CheckForUpdatesViewModel()

    let modelContainer: ModelContainer

    init() {
        modelContainer = ModelContainerFactory.create()
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
