import SwiftUI

// MARK: - About

struct AboutTab: View {
    var updaterViewModel: CheckForUpdatesViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Clipper Zero")
                .font(.title)
                .bold()

            Text("A modern macOS clipboard manager")
                .foregroundStyle(.secondary)

            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            CheckForUpdatesView(viewModel: updaterViewModel)

            Spacer()
        }
        .padding(.top, 32)
        .frame(maxWidth: .infinity)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
