import SwiftUI

// MARK: - Spring Constants

enum OnboardingSpring {
    static let page: Animation = .spring(response: 0.45, dampingFraction: 0.82)
    static let entrance: Animation = .spring(response: 0.5, dampingFraction: 0.75)
    static let button: Animation = .spring(response: 0.25, dampingFraction: 0.7)
    static let windowEntrance: Animation = .spring(response: 0.6, dampingFraction: 0.8)
}

// MARK: - Staggered Entrance

struct StaggeredEntrance: ViewModifier {
    let isVisible: Bool
    let delay: Double
    let offsetY: CGFloat
    let scale: CGFloat?

    init(isVisible: Bool, delay: Double, offsetY: CGFloat = 16, scale: CGFloat? = nil) {
        self.isVisible = isVisible
        self.delay = delay
        self.offsetY = offsetY
        self.scale = scale
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : offsetY)
            .scaleEffect(isVisible ? 1 : (scale ?? 1))
            .animation(
                OnboardingSpring.entrance.delay(delay),
                value: isVisible
            )
    }
}

extension View {
    func staggeredEntrance(isVisible: Bool, delay: Double, offsetY: CGFloat = 16, scale: CGFloat? = nil) -> some View {
        modifier(StaggeredEntrance(isVisible: isVisible, delay: delay, offsetY: offsetY, scale: scale))
    }
}

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
