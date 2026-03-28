import SwiftUI

struct CheckForUpdatesView: View {
    var viewModel: CheckForUpdatesViewModel

    var body: some View {
        Button("Check for Updates…") {
            viewModel.checkForUpdates()
        }
        .disabled(!viewModel.canCheckForUpdates)
    }
}
