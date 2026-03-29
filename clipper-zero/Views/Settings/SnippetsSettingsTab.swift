import SwiftUI
import SwiftData

// MARK: - Snippets

struct SnippetsSettingsTab: View {
    @Query(sort: \SnippetItem.sortOrder) private var snippets: [SnippetItem]
    @Environment(\.modelContext) private var modelContext
    @State private var expandedSnippetID: UUID?
    @State private var scrollTarget: UUID?
    @FocusState private var focusedField: SnippetField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum SnippetField: Hashable {
        case title(UUID)
        case content(UUID)
    }

    private var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 6) {
                Image(systemName: iCloudAvailable ? "checkmark.icloud" : "exclamationmark.icloud")
                    .foregroundStyle(iCloudAvailable ? .green : .orange)
                Text(iCloudAvailable
                     ? "Snippets sync across your devices via iCloud."
                     : "Sign in to iCloud to sync snippets across devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollViewReader { proxy in
                Form {
                    Section {
                        if snippets.isEmpty {
                            ContentUnavailableView("No Snippets",
                                systemImage: "note.text",
                                description: Text("Add snippets for quick access to frequently used text."))
                        } else {
                            ForEach(snippets) { snippet in
                                if expandedSnippetID == snippet.id {
                                    SnippetExpandedEditor(
                                        snippet: snippet,
                                        focusedField: $focusedField,
                                        canMoveUp: snippet.id != snippets.first?.id,
                                        canMoveDown: snippet.id != snippets.last?.id,
                                        onMoveUp: { moveSnippet(snippet, direction: -1) },
                                        onMoveDown: { moveSnippet(snippet, direction: 1) },
                                        onCollapse: {
                                            withAnimation {
                                                expandedSnippetID = nil
                                            }
                                        },
                                        onDelete: { deleteSnippet(snippet) }
                                    )
                                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                                    .id(snippet.id)
                                } else {
                                    Button {
                                        withAnimation {
                                            expandedSnippetID = snippet.id
                                        }
                                    } label: {
                                        SnippetCollapsedRow(snippet: snippet)
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.opacity)
                                    .id(snippet.id)
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .onChange(of: scrollTarget) { _, newValue in
                    guard let id = newValue else { return }
                    scrollTarget = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
            }

            HStack {
                Button {
                    addNewSnippet()
                } label: {
                    Label("Add Snippet", systemImage: "plus")
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func moveSnippet(_ snippet: SnippetItem, direction: Int) {
        guard let idx = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        let neighborIdx = idx + direction
        guard snippets.indices.contains(neighborIdx) else { return }
        let neighbor = snippets[neighborIdx]
        let tmp = snippet.sortOrder
        snippet.sortOrder = neighbor.sortOrder
        neighbor.sortOrder = tmp
        try? modelContext.save()
    }

    private func addNewSnippet() {
        let snippet = SnippetItem(name: "", value: "", sortOrder: snippets.maxSortOrder + 1)
        modelContext.insert(snippet)
        try? modelContext.save()
        expandedSnippetID = snippet.id
        scrollTarget = snippet.id
        Task { @MainActor in
            focusedField = .title(snippet.id)
        }
    }

    private func deleteSnippet(_ snippet: SnippetItem) {
        if expandedSnippetID == snippet.id {
            expandedSnippetID = nil
        }
        modelContext.delete(snippet)
        try? modelContext.save()
    }
}

// MARK: - Collapsed Row

struct SnippetCollapsedRow: View {
    let snippet: SnippetItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(snippet.name.isEmpty ? "Untitled Snippet" : snippet.name)
                    .font(.body)
                    .foregroundStyle(snippet.name.isEmpty ? .secondary : .primary)
                if !snippet.value.isEmpty {
                    Text(snippet.value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Expanded Editor

struct SnippetExpandedEditor: View {
    @Bindable var snippet: SnippetItem
    var focusedField: FocusState<SnippetsSettingsTab.SnippetField?>.Binding
    var canMoveUp: Bool
    var canMoveDown: Bool
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onCollapse: () -> Void
    var onDelete: () -> Void

    private var isContentFocused: Bool {
        if case .content(snippet.id) = focusedField.wrappedValue { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tappable to collapse
            HStack {
                Button(action: onCollapse) {
                    HStack {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)

                        Text(snippet.name.isEmpty ? "New Snippet" : snippet.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)
                .opacity(canMoveUp ? 1 : 0.3)
                .accessibilityLabel("Move up")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
                .opacity(canMoveDown ? 1 : 0.3)
                .accessibilityLabel("Move down")

                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete snippet")
            }
            .padding(.bottom, 10)

            // Title field
            VStack(alignment: .leading, spacing: 4) {
                Text("TITLE")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                TextField("Snippet name", text: $snippet.name)
                    .textFieldStyle(.roundedBorder)
                    .focused(focusedField, equals: .title(snippet.id))
            }
            .padding(.bottom, 10)

            // Content field
            VStack(alignment: .leading, spacing: 4) {
                Text("CONTENT")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                TextEditor(text: $snippet.value)
                    .font(.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .focused(focusedField, equals: .content(snippet.id))
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isContentFocused
                                    ? Color.accentColor
                                    : Color(nsColor: .separatorColor),
                                    lineWidth: isContentFocused ? 2.5 : 1)
                    }
                    .animation(.easeInOut(duration: 0.15), value: isContentFocused)
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
