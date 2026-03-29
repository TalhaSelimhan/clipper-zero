import SwiftUI

// MARK: - Hover Scale Button Style

struct HoverScaleButtonStyle: ButtonStyle {
    let accentColor: Color

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor)
                    .brightness(isHovered ? 0.05 : 0)
            )
            .foregroundStyle(.white)
            .fontWeight(.semibold)
            .scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.03 : 1.0))
            .animation(OnboardingSpring.button, value: configuration.isPressed)
            .animation(OnboardingSpring.button, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
