import SwiftUI
import ServiceManagement

// MARK: - General Settings

struct GeneralSettingsTab: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("historyLimit") private var historyLimit = 1000
    @AppStorage("playSoundOnCopy") private var playSoundOnCopy = false
    @AppStorage("autoDetectSensitive") private var autoDetectSensitive = true
    @AppStorage("secureItemTTL") private var secureItemTTL = 86400

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

            Section("Security") {
                Toggle("Auto-detect sensitive content", isOn: $autoDetectSensitive)

                Picker("Secure item expiration", selection: $secureItemTTL) {
                    Text("1 hour").tag(3600)
                    Text("1 day").tag(86400)
                    Text("1 week").tag(604800)
                    Text("30 days").tag(2592000)
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
