import SwiftUI

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
