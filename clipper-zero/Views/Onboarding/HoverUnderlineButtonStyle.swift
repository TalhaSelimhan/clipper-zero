import SwiftUI

// MARK: - Back Button Style

struct HoverUnderlineButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(isHovered ? 0.9 : 0.5))
            .underline(isHovered)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(OnboardingSpring.button, value: isHovered)
            .animation(OnboardingSpring.button, value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
