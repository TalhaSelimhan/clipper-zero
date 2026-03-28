import SwiftUI

struct OnboardingProgressBar: View {
    let currentPage: Int
    let totalPages: Int
    let pages: [OnboardingPage]

    private var progress: CGFloat {
        CGFloat(currentPage + 1) / CGFloat(totalPages)
    }

    private var currentAccent: Color {
        pages[currentPage].accentColor
    }

    private var nextAccent: Color {
        let nextIndex = min(currentPage + 1, pages.count - 1)
        return pages[nextIndex].accentColor
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 3)

                // Fill
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [currentAccent, nextAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 3)
                    .animation(OnboardingSpring.progress, value: currentPage)
            }
        }
        .frame(height: 3)
    }
}
