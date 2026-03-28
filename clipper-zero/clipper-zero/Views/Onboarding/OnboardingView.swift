import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var windowAppeared = false

    private let pages = OnboardingPage.all
    private let frameWidth: CGFloat = 960
    private let frameHeight: CGFloat = 640
    private let cardHeight: CGFloat = 160
    private let dragThreshold: CGFloat = 80

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed background image
            OnboardingBackgroundView(
                pages: pages,
                currentPage: currentPage,
                dragOffset: dragOffset,
                frameWidth: frameWidth
            )
            .animation(OnboardingSpring.page, value: currentPage)

            // Blur overlay card at the bottom
            blurCard
                .frame(height: cardHeight)
                .padding(20)
        }
        .frame(width: frameWidth, height: frameHeight)
        .clipped()
        .gesture(dragGesture)
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
            .offset(x: -CGFloat(currentPage) * geometry.size.width + dragOffset)
            .animation(OnboardingSpring.page, value: currentPage)
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation.width
                if (currentPage == 0 && translation > 0) ||
                    (currentPage == pages.count - 1 && translation < 0) {
                    dragOffset = translation * 0.3
                } else {
                    dragOffset = translation
                }
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.width - value.translation.width
                let shouldAdvance = value.translation.width < -dragThreshold || velocity < -300
                let shouldRetreat = value.translation.width > dragThreshold || velocity > 300

                withAnimation(OnboardingSpring.page) {
                    if shouldAdvance && currentPage < pages.count - 1 {
                        currentPage += 1
                    } else if shouldRetreat && currentPage > 0 {
                        currentPage -= 1
                    }
                    dragOffset = 0
                }
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
