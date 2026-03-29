import SwiftUI

struct SettingsView: View {
    var updaterViewModel: CheckForUpdatesViewModel

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ExcludedAppsTab()
                .tabItem {
                    Label("Excluded Apps", systemImage: "nosign")
                }

            SnippetsSettingsTab()
                .tabItem {
                    Label("Snippets", systemImage: "note.text")
                }

            AboutTab(updaterViewModel: updaterViewModel)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 400)
    }
}
