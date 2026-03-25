import SwiftUI
import SwiftData

struct ClipboardPanel: View {
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var expandedPreview = false
    @FocusState private var isSearchFocused: Bool

    @Query(sort: \ClipItem.createdAt, order: .reverse)
    private var allClips: [ClipItem]

    private var filteredClips: [ClipItem] {
        if searchText.isEmpty { return allClips }
        return allClips.filter { clip in
            clip.plainText?.localizedStandardContains(searchText) ?? false
        }
    }

    var body: some View {
        let clips = filteredClips
        VStack(spacing: 0) {
            searchBar
            Divider()
            clipList(clips)
            Divider()
            footerBar(clips)
        }
        .frame(width: 680, height: 480)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            pasteSelected()
            return .handled
        }
        .onKeyPress(.tab) {
            expandedPreview.toggle()
            return .handled
        }
        .onKeyPress(keys: [.init("f")], phases: .down) { press in
            if press.modifiers.contains(.command) {
                togglePin()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [.init("c")], phases: .down) { press in
            if press.modifiers.contains(.command) {
                copySelected()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [.delete], phases: .down) { press in
            if press.modifiers.contains(.command) {
                deleteSelected()
                return .handled
            }
            return .ignored
        }
        .onChange(of: searchText) {
            selectedIndex = 0
            expandedPreview = false
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.title3)

            TextField("Search clips...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Clip List

    private func clipList(_ clips: [ClipItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        ClipRow(
                            clip: clip,
                            isSelected: index == selectedIndex,
                            isExpanded: index == selectedIndex && expandedPreview
                        )
                        .id(index)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction {
                            selectedIndex = index
                            pasteSelected()
                        }
                        .onTapGesture(count: 2) {
                            selectedIndex = index
                            pasteSelected()
                        }
                        .onTapGesture {
                            selectedIndex = index
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: selectedIndex) { _, newValue in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Footer

    private func footerBar(_ clips: [ClipItem]) -> some View {
        HStack(spacing: 16) {
            shortcutHint("↑↓", "Navigate")
            shortcutHint("↵", "Paste")
            shortcutHint("⌘F", "Pin")
            shortcutHint("⇥", "Preview")
            shortcutHint("⌘C", "Copy")
            Spacer()
            Text("\(clips.count) clips")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.1))
                .clipShape(.rect(cornerRadius: 4))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func moveSelection(by delta: Int) {
        let clips = filteredClips
        guard !clips.isEmpty else { return }
        selectedIndex = max(0, min(clips.count - 1, selectedIndex + delta))
    }

    private func pasteSelected() {
        guard let clip = selectedClip else { return }
        PasteService.shared.paste(clip: clip)
    }

    private func copySelected() {
        guard let clip = selectedClip else { return }
        PasteService.shared.copyOnly(clip: clip)
    }

    private func togglePin() {
        guard let clip = selectedClip else { return }
        clip.isPinned.toggle()
        try? modelContext.save()
    }

    private func deleteSelected() {
        guard let clip = selectedClip else { return }
        modelContext.delete(clip)
        try? modelContext.save()
        if selectedIndex >= filteredClips.count {
            selectedIndex = max(0, filteredClips.count - 1)
        }
    }

    private var selectedClip: ClipItem? {
        let clips = filteredClips
        guard selectedIndex >= 0, selectedIndex < clips.count else { return nil }
        return clips[selectedIndex]
    }
}
