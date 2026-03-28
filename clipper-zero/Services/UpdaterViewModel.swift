import Sparkle
import Combine

@Observable
final class CheckForUpdatesViewModel {
    var canCheckForUpdates = false

    let updaterController: SPUStandardUpdaterController
    private var cancellable: AnyCancellable?

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        cancellable = updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
