import SwiftUI

struct OnboardingBackgroundView: View {
    let pages: [OnboardingPage]
    let currentPage: Int
    let dragOffset: CGFloat
    let frameWidth: CGFloat

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(pages) { page in
                    ZStack {
                        // Background image or fallback gradient
                        if let nsImage = NSImage(named: page.imageName) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectFill(width: frameWidth, height: geometry.size.height)
                        } else {
                            // Fallback: radial gradient when image not available
                            RadialGradient(
                                colors: [
                                    page.accentColor.opacity(0.3),
                                    page.gradientBottom,
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 300
                            )
                        }

                        // Gradient overlay for text readability
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: page.gradientBottom.opacity(0.5), location: 0.4),
                                .init(color: page.gradientBottom.opacity(0.95), location: 0.7),
                                .init(color: page.gradientBottom, location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .frame(width: frameWidth, height: geometry.size.height)
                }
            }
            // Parallax: image moves at 0.4x the drag rate
            .offset(x: -CGFloat(currentPage) * frameWidth + dragOffset * 0.4)
        }
    }
}

// MARK: - Image Aspect Fill Helper

private extension Image {
    func aspectFill(width: CGFloat, height: CGFloat) -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipped()
    }
}
