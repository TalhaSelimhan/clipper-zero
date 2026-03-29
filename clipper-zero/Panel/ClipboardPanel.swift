import SwiftUI
import SwiftData

// MARK: - Panel Size Constants

enum PanelMetrics {
    static let width: CGFloat = 680
    static let height: CGFloat = 480
}

struct ClipboardPanel: View {
    // MARK: - Nested Types

    enum PanelSegment: String, CaseIterable {
        case clips = "Clips"
        case snippets = "Snippets"
    }

    private struct ScrollList<Content: View>: View {
        let selectedIndex: Int
        @ViewBuilder let content: () -> Content

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        content()
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
    }

    private struct ShortcutHint: View {
        let key: String
        let label: String

        var body: some View {
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
    }

    private struct SearchBar: View {
        @Binding var searchText: String
        var isSearchFocused: FocusState<Bool>.Binding

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.title3)

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused(isSearchFocused)

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
    }

    private struct InlineAddForm: View {
        @Binding var snippetName: String
        @Binding var snippetValue: String
        var isNameFocused: FocusState<Bool>.Binding

        var body: some View {
            VStack(spacing: 6) {
                TextField("Name", text: $snippetName)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused(isNameFocused)

                TextField("Value", text: $snippetValue)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private struct FooterBar: View {
        let activeSegment: PanelSegment
        let searchText: String
        let countText: String

        var body: some View {
            HStack(spacing: 16) {
                ShortcutHint(key: "↑↓", label: "Navigate")
                ShortcutHint(key: "←→", label: "Switch")
                ShortcutHint(key: "↵", label: "Paste")
                if activeSegment == .snippets && searchText.isEmpty {
                    ShortcutHint(key: "⌘N", label: "New")
                } else {
                    ShortcutHint(key: "⌘F", label: "Pin")
                }
                ShortcutHint(key: "⇥", label: "Preview")
                ShortcutHint(key: "⌘C", label: "Copy")
                Spacer()
                Text(countText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Properties

    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var expandedPreview = false
    @State private var displayLimit = 50
    @State private var activeSegment: PanelSegment = .clips
    @State private var isAddingSnippet = false
    @State private var newSnippetName = ""
    @State private var newSnippetValue = ""
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isSnippetNameFocused: Bool

    @Query(sort: \ClipItem.createdAt, order: .reverse)
    private var allClips: [ClipItem]

    @Query(sort: \SnippetItem.sortOrder)
    private var allSnippets: [SnippetItem]

    private var filteredClips: [ClipItem] {
        if searchText.isEmpty { return allClips }
        return allClips.filter { clip in
            clip.plainText?.localizedStandardContains(searchText) ?? false
        }
    }

    private var visibleClips: [ClipItem] {
        Array(filteredClips.prefix(displayLimit))
    }

    private var filteredSnippets: [SnippetItem] {
        if searchText.isEmpty { return allSnippets }
        return allSnippets.filter { snippet in
            snippet.name.localizedStandardContains(searchText) ||
            snippet.value.localizedStandardContains(searchText)
        }
    }

    private var searchResults: [SearchResult] {
        filteredSnippets.map { .snippet($0) } + filteredClips.map { .clip($0) }
    }

    private var currentItemCount: Int {
        if !searchText.isEmpty {
            return searchResults.count
        }
        return activeSegment == .clips ? visibleClips.count : filteredSnippets.count
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(searchText: $searchText, isSearchFocused: $isSearchFocused)
            segmentPicker
            Divider()
            contentList
            Divider()
            FooterBar(activeSegment: activeSegment, searchText: searchText, countText: footerCountText)
        }
        .frame(width: PanelMetrics.width, height: PanelMetrics.height)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onKeyPress(.escape) {
            if isAddingSnippet {
                cancelAddSnippet()
                return .handled
            }
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
        .onKeyPress(.leftArrow) {
            if isSearchFocused && !searchText.isEmpty { return .ignored }
            activeSegment = .clips
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if isSearchFocused && !searchText.isEmpty { return .ignored }
            activeSegment = .snippets
            return .handled
        }
        .onKeyPress(.return) {
            if isAddingSnippet {
                saveNewSnippet()
                return .handled
            }
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
        .onKeyPress(keys: [.init("n")], phases: .down) { press in
            if press.modifiers.contains(.command) && activeSegment == .snippets {
                isAddingSnippet = true
                isSearchFocused = false
                Task { @MainActor in
                    isSnippetNameFocused = true
                }
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
            displayLimit = 50
        }
        .onChange(of: activeSegment) {
            selectedIndex = 0
            expandedPreview = false
            displayLimit = 50
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Segment Picker

    private var segmentPicker: some View {
        Picker("", selection: $activeSegment) {
            ForEach(PanelSegment.allCases, id: \.self) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Content List

    @ViewBuilder
    private var contentList: some View {
        if !searchText.isEmpty {
            unifiedSearchList
        } else if activeSegment == .clips {
            clipList(visibleClips)
        } else {
            snippetList(filteredSnippets)
        }
    }

    // MARK: - Clip List

    private func clipList(_ clips: [ClipItem]) -> some View {
        ScrollList(selectedIndex: selectedIndex) {
            ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                Button {
                    selectedIndex = index
                } label: {
                    ClipRow(
                        clip: clip,
                        isSelected: index == selectedIndex,
                        isExpanded: index == selectedIndex && expandedPreview
                    )
                }
                .id(index)
                .buttonStyle(.plain)
                .accessibilityAction {
                    selectedIndex = index
                    pasteSelected()
                }
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        selectedIndex = index
                        pasteSelected()
                    }
                )
            }

            if clips.count < filteredClips.count {
                Color.clear
                    .frame(height: 1)
                    .task(id: displayLimit) {
                        displayLimit = min(displayLimit + 50, filteredClips.count)
                    }
            }
        }
    }

    // MARK: - Snippet List

    private func snippetList(_ snippets: [SnippetItem]) -> some View {
        ScrollList(selectedIndex: selectedIndex) {
            if isAddingSnippet {
                InlineAddForm(snippetName: $newSnippetName, snippetValue: $newSnippetValue, isNameFocused: $isSnippetNameFocused)
            }

            ForEach(Array(snippets.enumerated()), id: \.element.id) { index, snippet in
                Button {
                    selectedIndex = index
                } label: {
                    SnippetRow(
                        snippet: snippet,
                        isSelected: index == selectedIndex
                    )
                }
                .id(index)
                .buttonStyle(.plain)
                .accessibilityAction {
                    selectedIndex = index
                    pasteSelected()
                }
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        selectedIndex = index
                        pasteSelected()
                    }
                )
            }
        }
    }

    // MARK: - Unified Search List

    private var unifiedSearchList: some View {
        let results = searchResults
        return ScrollList(selectedIndex: selectedIndex) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                Button {
                    selectedIndex = index
                } label: {
                    Group {
                        switch result {
                        case .clip(let clip):
                            ClipRow(
                                clip: clip,
                                isSelected: index == selectedIndex,
                                isExpanded: index == selectedIndex && expandedPreview
                            )
                        case .snippet(let snippet):
                            SnippetRow(
                                snippet: snippet,
                                isSelected: index == selectedIndex
                            )
                        }
                    }
                }
                .id(index)
                .buttonStyle(.plain)
                .accessibilityAction {
                    selectedIndex = index
                    pasteSelected()
                }
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        selectedIndex = index
                        pasteSelected()
                    }
                )
            }
        }
    }

    // MARK: - Footer

    private var footerCountText: String {
        if !searchText.isEmpty {
            return "\(currentItemCount) results"
        }
        if activeSegment == .clips {
            let visible = visibleClips.count
            let total = filteredClips.count
            if visible < total {
                return "\(visible) of \(total) clips"
            }
            return "\(total) clips"
        }
        return "\(currentItemCount) snippets"
    }

    // MARK: - Actions

    private func moveSelection(by delta: Int) {
        guard currentItemCount > 0 else { return }

        if activeSegment == .clips && searchText.isEmpty {
            let target = selectedIndex + delta
            if target >= displayLimit - 5 {
                displayLimit = min(displayLimit + 50, filteredClips.count)
            }
        }

        selectedIndex = max(0, min(currentItemCount - 1, selectedIndex + delta))
    }

    private var selectedItem: SearchResult? {
        guard selectedIndex >= 0, selectedIndex < currentItemCount else { return nil }
        if !searchText.isEmpty {
            return searchResults[selectedIndex]
        }
        if activeSegment == .clips {
            let clips = filteredClips
            guard selectedIndex < clips.count else { return nil }
            return .clip(clips[selectedIndex])
        } else {
            let snippets = filteredSnippets
            guard selectedIndex < snippets.count else { return nil }
            return .snippet(snippets[selectedIndex])
        }
    }

    private func pasteSelected() {
        guard let item = selectedItem else { return }
        PasteService.shared.paste(item)
    }

    private func copySelected() {
        guard let item = selectedItem else { return }
        PasteService.shared.copyOnly(item)
    }

    private func togglePin() {
        guard let item = selectedItem, case .clip(let clip) = item else { return }
        clip.isPinned.toggle()
        try? modelContext.save()
    }

    private func deleteSelected() {
        guard let item = selectedItem else { return }
        item.delete(from: modelContext)
        try? modelContext.save()
        if selectedIndex >= currentItemCount {
            selectedIndex = max(0, currentItemCount - 1)
        }
    }

    // MARK: - Snippet Add Helpers

    private func saveNewSnippet() {
        let trimmedName = newSnippetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = newSnippetValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedValue.isEmpty else { return }

        let snippet = SnippetItem(name: trimmedName, value: trimmedValue, sortOrder: allSnippets.maxSortOrder + 1)
        modelContext.insert(snippet)
        try? modelContext.save()
        cancelAddSnippet()
    }

    private func cancelAddSnippet() {
        isAddingSnippet = false
        newSnippetName = ""
        newSnippetValue = ""
        isSnippetNameFocused = false
        isSearchFocused = true
    }
}
