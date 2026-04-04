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

    @Query(sort: \SecureSnippetItem.sortOrder)
    private var allSecureSnippets: [SecureSnippetItem]

    private var filteredClips: [ClipItem] {
        if searchText.isEmpty { return allClips }
        return allClips.filter { clip in
            (clip.plainText?.localizedStandardContains(searchText) ?? false) ||
            (clip.secureLabel?.localizedStandardContains(searchText) ?? false)
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

    private var filteredSecureSnippets: [SecureSnippetItem] {
        if searchText.isEmpty { return allSecureSnippets }
        return allSecureSnippets.filter { snippet in
            snippet.name.localizedStandardContains(searchText)
        }
    }

    /// Merged snippet results sorted by sortOrder, deduped by id as safety net
    private var mergedSnippetResults: [SearchResult] {
        var seen = Set<String>()
        let regular: [(Int, SearchResult)] = filteredSnippets.map { ($0.sortOrder, .snippet($0)) }
        let secure: [(Int, SearchResult)] = filteredSecureSnippets.map { ($0.sortOrder, .secureSnippet($0)) }
        return (regular + secure)
            .sorted { $0.0 < $1.0 }
            .compactMap { pair in
                let result = pair.1
                guard seen.insert(result.id).inserted else { return nil }
                return result
            }
    }

    private var searchResults: [SearchResult] {
        mergedSnippetResults + filteredClips.map { .clip($0) }
    }

    private var currentItemCount: Int {
        if !searchText.isEmpty {
            return searchResults.count
        }
        return activeSegment == .clips ? visibleClips.count : mergedSnippetResults.count
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
        .onKeyPress(keys: [.init("l")], phases: .down) { press in
            if press.modifiers.contains(.command) {
                toggleSecure()
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
            mergedSnippetList
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
                .contextMenu {
                    if clip.isSecure {
                        Button("Mark as Not Secure") {
                            selectedIndex = index
                            toggleSecureForClip(clip)
                        }
                    } else {
                        Button("Mark as Secure") {
                            selectedIndex = index
                            toggleSecureForClip(clip)
                        }
                    }
                }
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

    // MARK: - Merged Snippet List

    private var mergedSnippetList: some View {
        let results = mergedSnippetResults
        return ScrollList(selectedIndex: selectedIndex) {
            if isAddingSnippet {
                InlineAddForm(snippetName: $newSnippetName, snippetValue: $newSnippetValue, isNameFocused: $isSnippetNameFocused)
            }

            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                Button {
                    selectedIndex = index
                } label: {
                    Group {
                        switch result {
                        case .snippet(let snippet):
                            SnippetRow(snippet: snippet, isSelected: index == selectedIndex)
                        case .secureSnippet(let snippet):
                            SecureSnippetRow(snippet: snippet, isSelected: index == selectedIndex)
                        default:
                            EmptyView()
                        }
                    }
                }
                .id(index)
                .buttonStyle(.plain)
                .contextMenu {
                    switch result {
                    case .snippet:
                        Button("Mark as Secure") {
                            selectedIndex = index
                            toggleSecureForSearchResult(result)
                        }
                    case .secureSnippet:
                        Button("Mark as Not Secure") {
                            selectedIndex = index
                            toggleSecureForSearchResult(result)
                        }
                    default:
                        EmptyView()
                    }
                }
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
                        case .secureSnippet(let snippet):
                            SecureSnippetRow(
                                snippet: snippet,
                                isSelected: index == selectedIndex
                            )
                        }
                    }
                }
                .id(index)
                .buttonStyle(.plain)
                .contextMenu {
                    switch result {
                    case .clip(let clip):
                        if clip.isSecure {
                            Button("Mark as Not Secure") {
                                selectedIndex = index
                                toggleSecureForClip(clip)
                            }
                        } else {
                            Button("Mark as Secure") {
                                selectedIndex = index
                                toggleSecureForClip(clip)
                            }
                        }
                    case .snippet:
                        Button("Mark as Secure") {
                            selectedIndex = index
                            toggleSecureForSearchResult(result)
                        }
                    case .secureSnippet:
                        Button("Mark as Not Secure") {
                            selectedIndex = index
                            toggleSecureForSearchResult(result)
                        }
                    }
                }
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
            let results = mergedSnippetResults
            guard selectedIndex < results.count else { return nil }
            return results[selectedIndex]
        }
    }

    private func pasteSelected() {
        guard let item = selectedItem else { return }
        Task { await PasteService.shared.paste(item) }
    }

    private func copySelected() {
        guard let item = selectedItem else { return }
        Task { await PasteService.shared.copyOnly(item) }
    }

    private func togglePin() {
        guard let item = selectedItem, case .clip(let clip) = item else { return }
        clip.isPinned.toggle()
        try? modelContext.save()
    }

    private func deleteSelected() {
        guard let item = selectedItem else { return }
        expandedPreview = false
        item.delete(from: modelContext)
        try? modelContext.save()
        if selectedIndex >= currentItemCount {
            selectedIndex = max(0, currentItemCount - 1)
        }
    }

    // MARK: - Secure Toggle

    private func toggleSecure() {
        guard let item = selectedItem else { return }
        toggleSecureForSearchResult(item)
    }

    private func toggleSecureForSearchResult(_ result: SearchResult) {
        switch result {
        case .clip(let clip):
            toggleSecureForClip(clip)
        case .snippet(let snippet):
            toggleSecureForSnippet(snippet)
        case .secureSnippet(let secureSnippet):
            toggleSecureForSecureSnippet(secureSnippet)
        }
    }

    private func toggleSecureForClip(_ clip: ClipItem) {
        Task {
            if clip.isSecure {
                // Unmark as secure — requires auth
                guard await AuthenticationService.authenticate(reason: "Remove secure status") else { return }
                guard let encrypted = clip.encryptedContent,
                      let decrypted = try? EncryptionService.decrypt(encrypted) else { return }
                clip.content = decrypted
                clip.plainText = String(data: decrypted, encoding: .utf8) ?? clip.plainText
                clip.encryptedContent = nil
                clip.secureLabel = nil
                clip.isSecure = false
                clip.expiresAt = nil
            } else {
                // Mark as secure
                let originalPlainText = clip.plainText ?? ""
                do {
                    let encrypted = try EncryptionService.encrypt(clip.content)
                    clip.encryptedContent = encrypted
                    clip.plainText = SensitiveContentDetector.mask(originalPlainText)
                    clip.secureLabel = "Manual"
                    clip.content = Data()
                    clip.previewData = nil
                    clip.isSecure = true
                    let ttl = TimeInterval(UserDefaults.standard.integer(forKey: "secureItemTTL").nonZeroOr(86400))
                    clip.expiresAt = clip.isPinned ? nil : Date.now.addingTimeInterval(ttl)
                } catch {
                    return
                }
            }
            try? modelContext.save()
        }
    }

    private func toggleSecureForSnippet(_ snippet: SnippetItem) {
        Task {
            guard let valueData = snippet.value.data(using: .utf8),
                  let encrypted = try? EncryptionService.encrypt(valueData) else { return }
            let secure = SecureSnippetItem(
                id: snippet.id,
                name: snippet.name,
                encryptedValue: encrypted,
                expiresAt: nil,
                sortOrder: snippet.sortOrder,
                createdAt: snippet.createdAt
            )
            modelContext.insert(secure)
            modelContext.delete(snippet)
            try? modelContext.save()
        }
    }

    private func toggleSecureForSecureSnippet(_ secureSnippet: SecureSnippetItem) {
        Task {
            guard await AuthenticationService.authenticate(reason: "Remove secure status") else { return }
            guard let decrypted = try? EncryptionService.decrypt(secureSnippet.encryptedValue),
                  let value = String(data: decrypted, encoding: .utf8) else { return }
            let regular = SnippetItem(
                id: secureSnippet.id,
                name: secureSnippet.name,
                value: value,
                sortOrder: secureSnippet.sortOrder
            )
            modelContext.insert(regular)
            modelContext.delete(secureSnippet)
            try? modelContext.save()
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
