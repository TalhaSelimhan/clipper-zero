import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    @State private var elementsVisible = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon badge
            Image(systemName: page.iconName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(page.accentColor)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 11)
                        .fill(page.accentColor.opacity(0.15))
                )
                .staggeredEntrance(isVisible: elementsVisible, delay: 0.0, offsetY: 0, scale: 0.6)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(page.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .staggeredEntrance(isVisible: elementsVisible, delay: 0.08)

                Text(page.subtitle)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .staggeredEntrance(isVisible: elementsVisible, delay: 0.16)

                if let shortcut = page.shortcut {
                    shortcutBadge(shortcut)
                        .staggeredEntrance(isVisible: elementsVisible, delay: 0.24, offsetY: 12)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 32)
        .onChange(of: isActive) { _, active in
            if active {
                elementsVisible = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    elementsVisible = true
                }
            } else {
                elementsVisible = false
            }
        }
        .onAppear {
            if isActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    elementsVisible = true
                }
            }
        }
    }

    // MARK: - Shortcut Badge

    private func shortcutBadge(_ shortcut: String) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(shortcut), id: \.self) { char in
                Text(String(char))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(minWidth: 24, minHeight: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                    )
            }
        }
    }
}
