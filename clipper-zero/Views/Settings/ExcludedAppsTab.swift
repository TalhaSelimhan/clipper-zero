import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

// MARK: - Excluded Apps

struct ExcludedAppsTab: View {
    @Query private var excludedApps: [ExcludedApp]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(excludedApps) { app in
                    HStack {
                        if let icon = appIcon(for: app.bundleIdentifier) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Text(app.appName)
                        Spacer()
                        Button {
                            deleteExcludedApp(app)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove excluded app")
                    }
                }

                if excludedApps.isEmpty {
                    ContentUnavailableView("No Excluded Apps",
                        systemImage: "nosign",
                        description: Text("Apps added here will not have their clipboard content recorded."))
                }
            }

            HStack {
                Button {
                    showingAppPicker = true
                } label: {
                    Label("Add App", systemImage: "plus")
                }
                .fileImporter(
                    isPresented: $showingAppPicker,
                    allowedContentTypes: [.application],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        addExcludedApp(from: url)
                    }
                }

                Spacer()

                Button("Add 1Password") {
                    insertExcludedApp(bundleIdentifier: "com.1password.1password", name: "1Password")
                }
                .disabled(excludedApps.contains { $0.bundleIdentifier == "com.1password.1password" })

                Button("Add Keychain") {
                    insertExcludedApp(bundleIdentifier: "com.apple.keychainaccess", name: "Keychain Access")
                }
                .disabled(excludedApps.contains { $0.bundleIdentifier == "com.apple.keychainaccess" })
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func addExcludedApp(from url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return }
        let name = bundle.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        insertExcludedApp(bundleIdentifier: bundleId, name: name)
    }

    private func insertExcludedApp(bundleIdentifier: String, name: String) {
        let app = ExcludedApp(bundleIdentifier: bundleIdentifier, appName: name)
        modelContext.insert(app)
        try? modelContext.save()
    }

    private func deleteExcludedApp(_ app: ExcludedApp) {
        modelContext.delete(app)
        try? modelContext.save()
    }

    private func appIcon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
    }
}
