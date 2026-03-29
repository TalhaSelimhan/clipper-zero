import SwiftUI
import SwiftData

// MARK: - Snippets

struct SnippetsSettingsTab: View {
    @Query(sort: \SnippetItem.sortOrder) private var snippets: [SnippetItem]
    @Environment(\.modelContext) private var modelContext

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

            Form {
                Section {
                    if snippets.isEmpty {
                        ContentUnavailableView("No Snippets",
                            systemImage: "note.text",
                            description: Text("Add snippets for quick access to frequently used text."))
                    } else {
                        ForEach(snippets) { snippet in
                            SnippetSettingsRow(
                                snippet: snippet,
                                canMoveUp: snippet.id != snippets.first?.id,
                                canMoveDown: snippet.id != snippets.last?.id,
                                onMoveUp: { moveSnippet(snippet, direction: -1) },
                                onMoveDown: { moveSnippet(snippet, direction: 1) },
                                onDelete: {
                                    deleteSnippet(snippet)
                                }
                            )
                        }
                    }
                }
            }
            .formStyle(.grouped)

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
        let snippet = SnippetItem(name: "New Snippet", value: "", sortOrder: snippets.maxSortOrder + 1)
        modelContext.insert(snippet)
        try? modelContext.save()
    }

    private func deleteSnippet(_ snippet: SnippetItem) {
        modelContext.delete(snippet)
        try? modelContext.save()
    }
}

struct SnippetSettingsRow: View {
    @Bindable var snippet: SnippetItem
    var canMoveUp: Bool = true
    var canMoveDown: Bool = true
    var onMoveUp: () -> Void = {}
    var onMoveDown: () -> Void = {}
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: $snippet.name)
                    .font(.body)
                    .textFieldStyle(.plain)
                TextField("Value", text: $snippet.value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.plain)
            }
            Spacer()
            VStack(spacing: 2) {
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
            }
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete snippet")
        }
    }
}
