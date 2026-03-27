import SwiftUI
import SwiftData
import ServiceManagement
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

            SnippetsSettingsTab()
                .tabItem {
                    Label("Snippets", systemImage: "note.text")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 400)
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
                    Stepper("\(historyLimit)", value: $historyLimit, in: 100...10000, step: 100)
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

    private func appIcon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
    }
}

// MARK: - Snippets

struct SnippetsSettingsTab: View {
    @Query(sort: \SnippetItem.sortOrder) private var snippets: [SnippetItem]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(snippets) { snippet in
                    SnippetSettingsRow(snippet: snippet) {
                        modelContext.delete(snippet)
                        try? modelContext.save()
                    }
                }
                .onMove { indices, newOffset in
                    var ordered = snippets.map { $0 }
                    ordered.move(fromOffsets: indices, toOffset: newOffset)
                    for (index, snippet) in ordered.enumerated() {
                        snippet.sortOrder = index
                    }
                    try? modelContext.save()
                }

                if snippets.isEmpty {
                    ContentUnavailableView("No Snippets",
                        systemImage: "note.text",
                        description: Text("Add snippets for quick access to frequently used text."))
                }
            }

            HStack {
                Button {
                    let snippet = SnippetItem(name: "New Snippet", value: "", sortOrder: snippets.maxSortOrder + 1)
                    modelContext.insert(snippet)
                    try? modelContext.save()
                } label: {
                    Label("Add Snippet", systemImage: "plus")
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

struct SnippetSettingsRow: View {
    @Bindable var snippet: SnippetItem
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: $snippet.name)
                    .font(.body)
                TextField("Value", text: $snippet.value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
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
