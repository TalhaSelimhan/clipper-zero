import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var windowAppeared = false

    private let pages = OnboardingPage.all
    static let frameWidth: CGFloat = 960
    static let frameHeight: CGFloat = 640
    private let cardHeight: CGFloat = 160

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed background image
            OnboardingBackgroundView(
                pages: pages,
                currentPage: currentPage
            )
            .animation(OnboardingSpring.page, value: currentPage)

            // Blur overlay card at the bottom
            blurCard
                .frame(height: cardHeight)
                .padding(20)
        }
        .frame(width: Self.frameWidth, height: Self.frameHeight)
        .clipped()
        .opacity(windowAppeared ? 1 : 0)
        .scaleEffect(windowAppeared ? 1 : 0.96)
        .onAppear {
            withAnimation(OnboardingSpring.windowEntrance) {
                windowAppeared = true
            }
        }
    }

    // MARK: - Blur Card

    private var blurCard: some View {
        VStack(spacing: 0) {
            // Page content
            pageContentStack
                .frame(maxHeight: .infinity)

            // Navigation buttons
            OnboardingNavigationBar(
                currentPage: currentPage,
                totalPages: pages.count,
                pages: pages,
                onBack: goBack,
                onNext: goNext,
                onComplete: onComplete
            )
            .animation(OnboardingSpring.page, value: currentPage)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var pageContentStack: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(pages) { page in
                    OnboardingPageView(
                        page: page,
                        isActive: page.id == currentPage
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .offset(x: -CGFloat(currentPage) * geometry.size.width)
            .animation(OnboardingSpring.page, value: currentPage)
        }
    }

    // MARK: - Navigation

    private func goBack() {
        withAnimation(OnboardingSpring.page) {
            if currentPage > 0 { currentPage -= 1 }
        }
    }

    private func goNext() {
        withAnimation(OnboardingSpring.page) {
            if currentPage < pages.count - 1 { currentPage += 1 }
        }
    }
}
