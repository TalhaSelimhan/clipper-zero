import SwiftUI

struct OnboardingPage: Identifiable {
    let id: Int
    let imageName: String
    let accentColor: Color
    let gradientBottom: Color
    let iconName: String
    let title: String
    let subtitle: String
    let shortcut: String?

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            imageName: "onboarding-welcome",
            accentColor: Color(red: 0.34, green: 0.56, blue: 1.0),
            gradientBottom: Color(red: 0.05, green: 0.08, blue: 0.18),
            iconName: "clipboard.fill",
            title: "Welcome to Clipper Zero",
            subtitle: "Everything you copy, saved and searchable. Always one shortcut away.",
            shortcut: nil
        ),
        OnboardingPage(
            id: 1,
            imageName: "onboarding-search",
            accentColor: Color(red: 0.25, green: 0.78, blue: 0.88),
            gradientBottom: Color(red: 0.04, green: 0.12, blue: 0.16),
            iconName: "magnifyingglass",
            title: "Instant Search",
            subtitle: "Press the global shortcut anywhere to find any clip by content.",
            shortcut: "⌘⇧V"
        ),
        OnboardingPage(
            id: 2,
            imageName: "onboarding-pins",
            accentColor: Color(red: 1.0, green: 0.62, blue: 0.25),
            gradientBottom: Color(red: 0.18, green: 0.1, blue: 0.04),
            iconName: "pin.fill",
            title: "Pin & Save Snippets",
            subtitle: "Pin important clips forever. Save frequently used text as snippets.",
            shortcut: nil
        ),
        OnboardingPage(
            id: 3,
            imageName: "onboarding-privacy",
            accentColor: Color(red: 0.3, green: 0.85, blue: 0.55),
            gradientBottom: Color(red: 0.04, green: 0.14, blue: 0.08),
            iconName: "hand.raised.fill",
            title: "Your Privacy, Your Control",
            subtitle: "Exclude sensitive apps. No dock icon. No clutter.",
            shortcut: nil
        ),
        OnboardingPage(
            id: 4,
            imageName: "onboarding-ready",
            accentColor: Color(red: 0.65, green: 0.45, blue: 1.0),
            gradientBottom: Color(red: 0.1, green: 0.06, blue: 0.2),
            iconName: "checkmark.circle.fill",
            title: "You're All Set",
            subtitle: "Clipper Zero is in your menu bar. Start copying.",
            shortcut: nil
        ),
    ]
}
