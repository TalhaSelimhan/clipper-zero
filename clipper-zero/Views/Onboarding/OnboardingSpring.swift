import SwiftUI

// MARK: - Spring Constants

enum OnboardingSpring {
    static let page: Animation = .spring(response: 0.45, dampingFraction: 0.82)
    static let entrance: Animation = .spring(response: 0.5, dampingFraction: 0.75)
    static let button: Animation = .spring(response: 0.25, dampingFraction: 0.7)
    static let windowEntrance: Animation = .spring(response: 0.6, dampingFraction: 0.8)
}
