import SwiftUI
import SwiftData
import Foundation
import os

struct MenuBarView: View {
    private static let logger = Logger(subsystem: "com.talhaselimhan.Clipper-Zero", category: "MenuBarView")

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ClipItem.createdAt, order: .reverse)
    private var allClips: [ClipItem]

    @Query(filter: #Predicate<ClipItem> { $0.isPinned },
           sort: \ClipItem.createdAt, order: .reverse)
    private var pinnedClips: [ClipItem]

    @Query(sort: \ClipCollection.createdAt, order: .reverse)
    private var collections: [ClipCollection]

    private var recentClips: [ClipItem] {
        Array(allClips.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            VStack(alignment: .leading, spacing: 4) {
                recentSection
                pinnedSection
                collectionsSection
            }
            .debugLayout("contentStack", logger: Self.logger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)

            Divider()
            footer
        }
        .frame(width: 320)
        .onAppear {
            logSnapshot(reason: "menu bar appeared")
        }
        .onChange(of: recentClips.map(\.id)) { _ in
            logSnapshot(reason: "recent clips changed")
        }
        .onChange(of: pinnedClips.map(\.id)) { _ in
            logSnapshot(reason: "pinned clips changed")
        }
        .onChange(of: collections.map(\.id)) { _ in
            logSnapshot(reason: "collections changed")
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
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
                dismiss()
                AppDelegate.shared.panelController.hidePanel()
                AppDelegate.shared.activateForSettings()
            })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Recent Section

    private var recentSection: some View {
        sectionContent(title: "Recent") {
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
        }
    }

    // MARK: - Pinned Section

    @ViewBuilder
    private var pinnedSection: some View {
        if !pinnedClips.isEmpty {
            sectionContent(title: "Pinned") {
                ForEach(pinnedClips) { clip in
                    MenuBarClipRow(clip: clip)
                }
            }
        }
    }

    // MARK: - Collections Section

    @ViewBuilder
    private var collectionsSection: some View {
        if !collections.isEmpty {
            sectionContent(title: "Collections") {
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

    private func sectionContent<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(title)
            content()
        }
        .debugLayout("section-\(title)", logger: Self.logger)
        .onAppear {
            Self.logger.debug("Section appeared: \(title, privacy: .public)")
        }
    }

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

    private func logSnapshot(reason: String) {
        let recentSummary = recentClips
            .map(Self.describeClip)
            .joined(separator: " | ")
        let pinnedSummary = pinnedClips
            .prefix(10)
            .map(Self.describeClip)
            .joined(separator: " | ")
        let collectionSummary = collections
            .map { "\($0.name)=\($0.items?.count ?? 0)" }
            .joined(separator: ", ")

        Self.logger.notice(
            """
            Snapshot reason=\(reason, privacy: .public) all=\(allClips.count) recent=\(recentClips.count) pinned=\(pinnedClips.count) collections=\(collections.count) recentItems=\(recentSummary, privacy: .public) pinnedItems=\(pinnedSummary, privacy: .public) collectionItems=\(collectionSummary, privacy: .public)
            """
        )
    }

    private static func describeClip(_ clip: ClipItem) -> String {
        let sourceApp = clip.sourceAppName ?? "-"
        let plainTextCount = clip.plainText?.count ?? 0
        let timestamp = ISO8601DateFormatter().string(from: clip.createdAt)
        return "id=\(String(clip.id.uuidString.prefix(8)));type=\(clip.contentType.rawValue);secure=\(clip.isSecure);chars=\(plainTextCount);app=\(sourceApp);created=\(timestamp)"
    }
}

// MARK: - Menu Bar Clip Row

struct MenuBarClipRow: View {
    private static let logger = Logger(subsystem: "com.talhaselimhan.Clipper-Zero", category: "MenuBarClipRow")

    @Environment(\.modelContext) private var modelContext
    let clip: ClipItem

    var body: some View {
        Group {
            if clip.isSecure {
                secureRow
            } else {
                normalRow
            }
        }
        .debugLayout("row-\(String(clip.id.uuidString.prefix(8)))", logger: Self.logger)
        .onAppear {
            Self.logger.debug("\(Self.describeClip(clip), privacy: .public)")
        }
    }

    private var normalRow: some View {
        Button {
            Task { @MainActor in
                guard await PasteService.shared.copyOnly(clip: clip) else { return }
                SelectionTrackingService.markUsed(clip, in: modelContext)
            }
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var secureRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(clip.plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Secure item")
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text("Open panel to copy")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Image(systemName: clip.contentType.iconName)
                .font(.caption)
                .foregroundStyle(clip.contentType.badgeColor)
                .frame(width: 16)

            Text(clip.plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? clip.contentType.badge)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.subheadline)

            Spacer()

            Text(clip.createdAt.relativeDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private static func describeClip(_ clip: ClipItem) -> String {
        let sourceApp = clip.sourceAppName ?? "-"
        let plainTextCount = clip.plainText?.count ?? 0
        return "Row appeared id=\(String(clip.id.uuidString.prefix(8)));type=\(clip.contentType.rawValue);secure=\(clip.isSecure);chars=\(plainTextCount);app=\(sourceApp)"
    }
}

private struct DebugLayoutModifier: ViewModifier {
    let name: String
    let logger: Logger

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        logLayout(proxy: proxy, reason: "appear")
                    }
                    .onChange(of: proxy.size) { _ in
                        logLayout(proxy: proxy, reason: "sizeChanged")
                    }
            }
        )
    }

    private func logLayout(proxy: GeometryProxy, reason: String) {
        let frame = proxy.frame(in: .global)
        logger.debug(
            """
            Layout \(name, privacy: .public) reason=\(reason, privacy: .public) size=\(Int(proxy.size.width))x\(Int(proxy.size.height)) origin=\(Int(frame.minX)),\(Int(frame.minY))
            """
        )
    }
}

private extension View {
    func debugLayout(_ name: String, logger: Logger) -> some View {
        modifier(DebugLayoutModifier(name: name, logger: logger))
    }
}
