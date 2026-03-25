import SwiftData
import Foundation

@Model
final class ExcludedApp {
    var id: UUID
    @Attribute(.unique) var bundleIdentifier: String
    var appName: String

    init(bundleIdentifier: String, appName: String) {
        self.id = UUID()
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
    }
}
