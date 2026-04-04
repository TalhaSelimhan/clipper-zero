import SwiftUI
import SwiftData

// MARK: - Snippets

struct SnippetsSettingsTab: View {
    @Query(sort: \SnippetItem.sortOrder) private var snippets: [SnippetItem]
    @Query(sort: \SecureSnippetItem.sortOrder) private var secureSnippets: [SecureSnippetItem]
    @Environment(\.modelContext) private var modelContext
    @State private var expandedSnippetID: UUID?
    @State private var scrollTarget: UUID?
    @FocusState private var focusedField: SnippetField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum SnippetField: Hashable {
        case title(UUID)
        case content(UUID)
    }

    private enum AnySnippet: Identifiable {
        case regular(SnippetItem)
        case secure(SecureSnippetItem)

        var id: UUID {
            switch self {
            case .regular(let s): return s.id
            case .secure(let s): return s.id
            }
        }

        var sortOrder: Int {
            switch self {
            case .regular(let s): return s.sortOrder
            case .secure(let s): return s.sortOrder
            }
        }

        var name: String {
            switch self {
            case .regular(let s): return s.name
            case .secure(let s): return s.name
            }
        }

        var isSecure: Bool {
            if case .secure = self { return true }
            return false
        }
    }

    private var mergedSnippets: [AnySnippet] {
        var seen = Set<UUID>()
        let all: [(Int, AnySnippet)] = snippets.map { ($0.sortOrder, .regular($0)) }
            + secureSnippets.map { ($0.sortOrder, .secure($0)) }
        return all
            .sorted { $0.0 < $1.0 }
            .compactMap { pair in
                guard seen.insert(pair.1.id).inserted else { return nil }
                return pair.1
            }
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
                        if mergedSnippets.isEmpty {
                            ContentUnavailableView("No Snippets",
                                systemImage: "note.text",
                                description: Text("Add snippets for quick access to frequently used text."))
                        } else {
                            ForEach(mergedSnippets) { anySnippet in
                                if expandedSnippetID == anySnippet.id {
                                    switch anySnippet {
                                    case .regular(let snippet):
                                        SnippetExpandedEditor(
                                            snippet: snippet,
                                            isSecure: false,
                                            focusedField: $focusedField,
                                            canMoveUp: anySnippet.id != mergedSnippets.first?.id,
                                            canMoveDown: anySnippet.id != mergedSnippets.last?.id,
                                            onMoveUp: { moveSnippet(anySnippet, direction: -1) },
                                            onMoveDown: { moveSnippet(anySnippet, direction: 1) },
                                            onCollapse: { withAnimation { expandedSnippetID = nil } },
                                            onDelete: { deleteSnippet(anySnippet) },
                                            onToggleSecure: { toggleSecure(anySnippet) }
                                        )
                                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                                        .id(anySnippet.id)
                                    case .secure(let snippet):
                                        SecureSnippetExpandedEditor(
                                            snippet: snippet,
                                            focusedField: $focusedField,
                                            canMoveUp: anySnippet.id != mergedSnippets.first?.id,
                                            canMoveDown: anySnippet.id != mergedSnippets.last?.id,
                                            onMoveUp: { moveSnippet(anySnippet, direction: -1) },
                                            onMoveDown: { moveSnippet(anySnippet, direction: 1) },
                                            onCollapse: { withAnimation { expandedSnippetID = nil } },
                                            onDelete: { deleteSnippet(anySnippet) },
                                            onToggleSecure: { toggleSecure(anySnippet) }
                                        )
                                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                                        .id(anySnippet.id)
                                    }
                                } else {
                                    Button {
                                        withAnimation {
                                            expandedSnippetID = anySnippet.id
                                        }
                                    } label: {
                                        SnippetCollapsedRow(name: anySnippet.name, value: anySnippet.isSecure ? nil : {
                                            if case .regular(let s) = anySnippet { return s.value }
                                            return nil
                                        }(), isSecure: anySnippet.isSecure)
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.opacity)
                                    .id(anySnippet.id)
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .onChange(of: expandedSnippetID) { _, newValue in
                    guard let id = newValue else { return }
                    Task { @MainActor in
                        focusedField = .title(id)
                    }
                }
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

    private func moveSnippet(_ anySnippet: AnySnippet, direction: Int) {
        let sorted = mergedSnippets
        guard let idx = sorted.firstIndex(where: { $0.id == anySnippet.id }) else { return }
        let neighborIdx = idx + direction
        guard sorted.indices.contains(neighborIdx) else { return }
        let neighbor = sorted[neighborIdx]

        let currentOrder = anySnippet.sortOrder
        let neighborOrder = neighbor.sortOrder

        setOrder(anySnippet, order: neighborOrder)
        setOrder(neighbor, order: currentOrder)
        try? modelContext.save()
    }

    private func setOrder(_ anySnippet: AnySnippet, order: Int) {
        switch anySnippet {
        case .regular(let s): s.sortOrder = order
        case .secure(let s): s.sortOrder = order
        }
    }

    private func addNewSnippet() {
        let maxOrder = max(snippets.maxSortOrder, secureSnippets.maxSortOrder)
        let snippet = SnippetItem(name: "", value: "", sortOrder: maxOrder + 1)
        modelContext.insert(snippet)
        try? modelContext.save()
        expandedSnippetID = snippet.id
        scrollTarget = snippet.id
    }

    private func deleteSnippet(_ anySnippet: AnySnippet) {
        if expandedSnippetID == anySnippet.id {
            expandedSnippetID = nil
        }
        switch anySnippet {
        case .regular(let s): modelContext.delete(s)
        case .secure(let s): modelContext.delete(s)
        }
        try? modelContext.save()
    }

    private func toggleSecure(_ anySnippet: AnySnippet) {
        Task {
            switch anySnippet {
            case .regular(let snippet):
                // Mark as secure: encrypt → create SecureSnippetItem → delete SnippetItem
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
                expandedSnippetID = secure.id

            case .secure(let secureSnippet):
                // Unmark: auth → decrypt → create SnippetItem → delete SecureSnippetItem
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
                expandedSnippetID = regular.id
            }
        }
    }
}

// MARK: - Collapsed Row

struct SnippetCollapsedRow: View {
    let name: String
    let value: String?
    var isSecure: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if isSecure {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(name.isEmpty ? "Untitled Snippet" : name)
                        .font(.body)
                        .foregroundStyle(name.isEmpty ? .secondary : .primary)
                }
                if isSecure {
                    Text("\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let value, !value.isEmpty {
                    Text(value)
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
    var isSecure: Bool
    var focusedField: FocusState<SnippetsSettingsTab.SnippetField?>.Binding
    var canMoveUp: Bool
    var canMoveDown: Bool
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onCollapse: () -> Void
    var onDelete: () -> Void
    var onToggleSecure: () -> Void

    private var isContentFocused: Bool {
        if case .content(snippet.id) = focusedField.wrappedValue { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorHeader(title: snippet.name.isEmpty ? "New Snippet" : snippet.name)
            titleField(text: $snippet.name, id: snippet.id)

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
            .padding(.bottom, 10)

            // Secure toggle
            Toggle("Secure", isOn: .constant(isSecure))
                .onChange(of: false) { _, _ in } // Placeholder — actual toggle via button
                .hidden()
            Button(isSecure ? "Remove Secure" : "Mark as Secure") {
                onToggleSecure()
            }
            .font(.caption)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func editorHeader(title: String) -> some View {
        HStack {
            Button(action: onCollapse) {
                HStack {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: onMoveUp) {
                Image(systemName: "chevron.up").font(.caption)
            }
            .buttonStyle(.plain).disabled(!canMoveUp).opacity(canMoveUp ? 1 : 0.3)
            .accessibilityLabel("Move up")
            Button(action: onMoveDown) {
                Image(systemName: "chevron.down").font(.caption)
            }
            .buttonStyle(.plain).disabled(!canMoveDown).opacity(canMoveDown ? 1 : 0.3)
            .accessibilityLabel("Move down")
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
            }
            .buttonStyle(.plain).accessibilityLabel("Delete snippet")
        }
        .padding(.bottom, 10)
    }

    private func titleField(text: Binding<String>, id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TITLE")
                .font(.caption)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            TextField("Snippet name", text: text)
                .textFieldStyle(.roundedBorder)
                .focused(focusedField, equals: .title(id))
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Secure Snippet Expanded Editor

struct SecureSnippetExpandedEditor: View {
    @Bindable var snippet: SecureSnippetItem
    var focusedField: FocusState<SnippetsSettingsTab.SnippetField?>.Binding
    var canMoveUp: Bool
    var canMoveDown: Bool
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onCollapse: () -> Void
    var onDelete: () -> Void
    var onToggleSecure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onCollapse) {
                    HStack {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                        Text(snippet.name.isEmpty ? "Secure Snippet" : snippet.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up").font(.caption)
                }
                .buttonStyle(.plain).disabled(!canMoveUp).opacity(canMoveUp ? 1 : 0.3)
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down").font(.caption)
                }
                .buttonStyle(.plain).disabled(!canMoveDown).opacity(canMoveDown ? 1 : 0.3)
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
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

            // Content — read-only masked
            VStack(alignment: .leading, spacing: 4) {
                Text("CONTENT")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text("\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}")
                    .font(.body)
                    .frame(minHeight: 40, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }
            }
            .padding(.bottom, 10)

            Button("Remove Secure") {
                onToggleSecure()
            }
            .font(.caption)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
