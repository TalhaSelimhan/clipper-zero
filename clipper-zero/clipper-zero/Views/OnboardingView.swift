import SwiftUI

struct OnboardingPage: Identifiable {
    let id: Int
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

struct OnboardingView: View {
    @State private var currentPage = 0
    var onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            icon: "clipboard.fill",
            iconColor: .accentColor,
            title: "Welcome to Clipper Zero",
            description: "A powerful clipboard manager that lives in your menu bar. Everything you copy is saved, searchable, and always at your fingertips."
        ),
        OnboardingPage(
            id: 1,
            icon: "magnifyingglass",
            iconColor: .blue,
            title: "Instant Search",
            description: "Press **⌘⇧V** anywhere to open the search panel. Find any clip by content — text, images, files, links, or colors."
        ),
        OnboardingPage(
            id: 2,
            icon: "pin.fill",
            iconColor: .orange,
            title: "Pin & Save Snippets",
            description: "Pin important clips to keep them forever. Save frequently used text as snippets for instant access."
        ),
        OnboardingPage(
            id: 3,
            icon: "hand.raised.fill",
            iconColor: .green,
            title: "Your Privacy, Your Control",
            description: "Exclude sensitive apps like 1Password from clipboard capture. Access everything from the menu bar — no dock icon, no clutter."
        ),
        OnboardingPage(
            id: 4,
            icon: "checkmark.circle.fill",
            iconColor: .green,
            title: "You're All Set",
            description: "Clipper Zero is running in your menu bar. Start copying — your clipboard history begins now."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            pageContent
                .frame(width: 520, height: 340)

            Divider()

            navigationBar
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: 520, height: 440)
        .background(.ultraThinMaterial)
    }

    // MARK: - Page Content

    private var pageContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: pages[currentPage].icon)
                .font(.system(size: 56))
                .foregroundStyle(pages[currentPage].iconColor)
                .id("icon-\(currentPage)")

            Text(pages[currentPage].title)
                .font(.title)
                .fontWeight(.bold)
                .id("title-\(currentPage)")

            Text(LocalizedStringKey(pages[currentPage].description))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .id("desc-\(currentPage)")

            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    // MARK: - Page Indicators

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.accentColor : Color.primary.opacity(0.2))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.0 : 0.85)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            Button("Back") {
                withAnimation { currentPage -= 1 }
            }
            .opacity(currentPage > 0 ? 1 : 0)
            .disabled(currentPage == 0)
            .keyboardShortcut(.cancelAction)

            Spacer()

            pageIndicators

            Spacer()

            if currentPage == pages.count - 1 {
                Button("Get Started") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Next") {
                    withAnimation { currentPage += 1 }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        onComplete()
    }
}
