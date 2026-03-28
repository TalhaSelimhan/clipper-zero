import SwiftUI

struct OnboardingNavigationBar: View {
    let currentPage: Int
    let totalPages: Int
    let pages: [OnboardingPage]
    let onBack: () -> Void
    let onNext: () -> Void
    let onComplete: () -> Void

    private var isLastPage: Bool {
        currentPage == totalPages - 1
    }

    var body: some View {
        HStack {
            // Back button
            Button("Back", action: onBack)
                .buttonStyle(HoverUnderlineButtonStyle())
                .opacity(currentPage > 0 ? 1 : 0)
                .disabled(currentPage == 0)
                .keyboardShortcut(.cancelAction)

            Spacer()

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? pages[currentPage].accentColor : Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                        .scaleEffect(index == currentPage ? 1.0 : 0.85)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }

            Spacer()

            if isLastPage {
                Button("Get Started", action: onComplete)
                    .buttonStyle(HoverScaleButtonStyle(accentColor: pages[currentPage].accentColor))
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Next", action: onNext)
                    .buttonStyle(HoverScaleButtonStyle(accentColor: pages[currentPage].accentColor))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
