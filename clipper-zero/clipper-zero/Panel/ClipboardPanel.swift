import SwiftUI
import SwiftData

enum PanelSegment: String, CaseIterable {
    case clips = "Clips"
    case snippets = "Snippets"
}

struct ClipboardPanel: View {
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var expandedPreview = false
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
        return activeSegment == .clips ? filteredClips.count : filteredSnippets.count
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            segmentPicker
            Divider()
            contentList
            Divider()
            footerBar
        }
        .frame(width: 680, height: 480)
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
            if isSearchFocused { return .ignored }
            activeSegment = .clips
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if isSearchFocused { return .ignored }
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
                DispatchQueue.main.async {
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
        }
        .onChange(of: activeSegment) {
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

            TextField("Search...", text: $searchText)
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
            clipList(filteredClips)
        } else {
            snippetList(filteredSnippets)
        }
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

    // MARK: - Snippet List

    private func snippetList(_ snippets: [SnippetItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if isAddingSnippet {
                        inlineAddForm
                    }

                    ForEach(Array(snippets.enumerated()), id: \.element.id) { index, snippet in
                        SnippetRow(
                            snippet: snippet,
                            isSelected: index == selectedIndex
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

    // MARK: - Unified Search List

    private var unifiedSearchList: some View {
        let results = searchResults
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
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

    // MARK: - Inline Add Form

    private var inlineAddForm: some View {
        VStack(spacing: 6) {
            TextField("Name", text: $newSnippetName)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isSnippetNameFocused)

            TextField("Value", text: $newSnippetValue)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 16) {
            shortcutHint("↑↓", "Navigate")
            shortcutHint("←→", "Switch")
            shortcutHint("↵", "Paste")
            if activeSegment == .snippets && searchText.isEmpty {
                shortcutHint("⌘N", "New")
            } else {
                shortcutHint("⌘F", "Pin")
            }
            shortcutHint("⇥", "Preview")
            shortcutHint("⌘C", "Copy")
            Spacer()
            Text(footerCountText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var footerCountText: String {
        if !searchText.isEmpty {
            return "\(searchResults.count) results"
        }
        if activeSegment == .clips {
            return "\(filteredClips.count) clips"
        }
        return "\(filteredSnippets.count) snippets"
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
        guard currentItemCount > 0 else { return }
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
        switch item {
        case .clip(let clip):
            PasteService.shared.paste(clip: clip)
        case .snippet(let snippet):
            PasteService.shared.paste(snippet: snippet)
        }
    }

    private func copySelected() {
        guard let item = selectedItem else { return }
        switch item {
        case .clip(let clip):
            PasteService.shared.copyOnly(clip: clip)
        case .snippet(let snippet):
            PasteService.shared.copyOnly(snippet: snippet)
        }
    }

    private func togglePin() {
        guard let item = selectedItem, case .clip(let clip) = item else { return }
        clip.isPinned.toggle()
        try? modelContext.save()
    }

    private func deleteSelected() {
        guard let item = selectedItem else { return }
        switch item {
        case .clip(let clip):
            modelContext.delete(clip)
        case .snippet(let snippet):
            modelContext.delete(snippet)
        }
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

        let maxOrder = allSnippets.map(\.sortOrder).max() ?? -1
        let snippet = SnippetItem(name: trimmedName, value: trimmedValue, sortOrder: maxOrder + 1)
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
