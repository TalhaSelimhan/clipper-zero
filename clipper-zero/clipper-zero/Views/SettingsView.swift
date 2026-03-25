import ServiceManagement
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
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

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 350)
    }
}

// MARK: - General Settings

struct GeneralSettingsTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("historyLimit") private var historyLimit = 1000
    @AppStorage("playSoundOnCopy") private var playSoundOnCopy = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
            }

            Section("Hotkey") {
                HStack {
                    Text("Global hotkey")
                    Spacer()
                    Text("⌘⇧V")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 6))
                }
            }

            Section("History") {
                HStack {
                    Text("History limit")
                    Spacer()
                    Stepper("\(historyLimit)", value: $historyLimit, in: 100 ... 10000, step: 100)
                }
            }

            Section("Sounds") {
                Toggle("Play sound on copy", isOn: $playSoundOnCopy)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}

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
                            modelContext.delete(app)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
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
                    if case let .success(urls) = result, let url = urls.first {
                        addExcludedApp(from: url)
                    }
                }

                Spacer()

                Button("Add 1Password") {
                    addPredefined(bundle: "com.1password.1password", name: "1Password")
                }
                .disabled(excludedApps.contains { $0.bundleIdentifier == "com.1password.1password" })

                Button("Add Keychain") {
                    addPredefined(bundle: "com.apple.keychainaccess", name: "Keychain Access")
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

        let app = ExcludedApp(bundleIdentifier: bundleId, appName: name)
        modelContext.insert(app)
        try? modelContext.save()
    }

    private func addPredefined(bundle: String, name: String) {
        let app = ExcludedApp(bundleIdentifier: bundle, appName: name)
        modelContext.insert(app)
        try? modelContext.save()
    }

    private func appIcon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
    }
}

// MARK: - About

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Clipper Zero")
                .font(.title)
                .fontWeight(.bold)

            Text("A modern macOS clipboard manager")
                .foregroundStyle(.secondary)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.top, 32)
        .frame(maxWidth: .infinity)
    }
}
