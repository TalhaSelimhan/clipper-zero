import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ClipItem.createdAt, order: .reverse)
    private var allClips: [ClipItem]

    @Query(filter: #Predicate<ClipItem> { $0.isPinned },
           sort: \ClipItem.createdAt, order: .reverse)
    private var pinnedClips: [ClipItem]

    @Query(sort: \ClipCollection.createdAt, order: .reverse)
    private var collections: [ClipCollection]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    recentSection
                    pinnedSection
                    collectionsSection
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 400)

            Divider()
            footer
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Clipper Zero")
                .font(.headline)
            Spacer()
            SettingsLink {
                Label("Settings", systemImage: "gear")
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                AppDelegate.shared.panelController.hidePanel()
                NSApp.activate(ignoringOtherApps: true)
            })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Recent Section

    private var recentSection: some View {
        Section {
            let recentClips = Array(allClips.prefix(10))
            if recentClips.isEmpty {
                Text("No clips yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            } else {
                ForEach(recentClips) { clip in
                    MenuBarClipRow(clip: clip)
                }
            }
        } header: {
            sectionHeader("Recent")
        }
    }

    // MARK: - Pinned Section

    @ViewBuilder
    private var pinnedSection: some View {
        if !pinnedClips.isEmpty {
            Section {
                ForEach(pinnedClips) { clip in
                    MenuBarClipRow(clip: clip)
                }
            } header: {
                sectionHeader("Pinned")
            }
        }
    }

    // MARK: - Collections Section

    @ViewBuilder
    private var collectionsSection: some View {
        if !collections.isEmpty {
            Section {
                ForEach(collections) { collection in
                    DisclosureGroup {
                        if let items = collection.items, !items.isEmpty {
                            ForEach(items) { clip in
                                MenuBarClipRow(clip: clip)
                            }
                        } else {
                            Text("Empty")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                        }
                    } label: {
                        Label(collection.name, systemImage: collection.icon)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                }
            } header: {
                sectionHeader("Collections")
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Clear History") {
                clearHistory()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .font(.caption)

            Spacer()

            Text("⌘⇧V Open Panel")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.top, 6)
    }

    private func clearHistory() {
        let unpinnedClips = allClips.filter { !$0.isPinned && ($0.collections?.isEmpty ?? true) }
        for clip in unpinnedClips {
            modelContext.delete(clip)
        }
        try? modelContext.save()
    }
}

// MARK: - Menu Bar Clip Row

struct MenuBarClipRow: View {
    let clip: ClipItem

    var body: some View {
        Button {
            PasteService.shared.copyOnly(clip: clip)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: clip.contentType.iconName)
                    .font(.caption)
                    .foregroundStyle(clip.contentType.badgeColor)
                    .frame(width: 16)

                Text(clip.plainText ?? clip.contentType.badge)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.subheadline)

                Spacer()

                Text(clip.createdAt.relativeDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

