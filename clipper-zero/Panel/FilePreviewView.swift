import SwiftUI
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct FilePreviewView: View {
    let clip: ClipItem

    @State private var fileEntries: [FileEntry] = []
    @State private var loadFailed = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                loadingState
            } else if fileEntries.count == 1 {
                singleFileView(fileEntries[0])
            } else if fileEntries.count > 1 {
                multiFileView
            } else {
                errorState
            }
        }
        .task {
            await loadPreview()
        }
        .onDisappear {
            fileEntries = []
        }
    }

    // MARK: - Single File

    private func singleFileView(_ entry: FileEntry) -> some View {
        HStack(alignment: .top, spacing: 16) {
            thumbnailImage(entry, maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.metadata.fileName)
                    .font(.body)
                    .fontWeight(.semibold)

                if let typeAndSize = entry.metadata.typeAndSizeLabel {
                    Text(typeAndSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.metadata.parentPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
    }

    // MARK: - Multiple Files

    private var multiFileView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(fileEntries.prefix(6)) { entry in
                HStack(spacing: 10) {
                    thumbnailImage(entry, maxHeight: 36)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.metadata.fileName)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if let typeAndSize = entry.metadata.typeAndSizeLabel {
                            Text(typeAndSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
            if fileEntries.count > 6 {
                Text("+\(fileEntries.count - 6) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 46)
            }
        }
    }

    // MARK: - Shared

    private func thumbnailImage(_ entry: FileEntry, maxHeight: CGFloat) -> some View {
        Group {
            if let thumbnail = entry.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let icon = entry.metadata.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(maxHeight: maxHeight)
    }

    // MARK: - Loading & Error

    private var loadingState: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.tertiary)
                .frame(width: 120, height: 90)
                .overlay {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            if let name = clip.plainText {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.body)
                        .fontWeight(.semibold)
                    Text("Loading preview...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var errorState: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
                .frame(width: 64, height: 64)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(clip.plainText ?? "Unknown file")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("File no longer available")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
            }
            Spacer()
        }
    }

    // MARK: - Loading Logic

    private func loadPreview() async {
        let bookmarks: [Data]
        if let decoded = try? JSONDecoder().decode([Data].self, from: clip.content) {
            bookmarks = decoded
        } else {
            bookmarks = [clip.content] // Legacy single bookmark
        }

        var entries: [FileEntry] = []

        for bookmark in bookmarks {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }

            guard url.startAccessingSecurityScopedResource() else { continue }

            let metadata = FileMetadata(url: url)
            entries.append(FileEntry(metadata: metadata, thumbnail: nil, url: url))

            url.stopAccessingSecurityScopedResource()
        }

        if entries.isEmpty {
            isLoading = false
            loadFailed = true
            return
        }

        fileEntries = entries
        isLoading = false

        // Generate thumbnails in parallel (limit to first 6 for performance)
        let thumbnailSize = CGSize(width: 256, height: 256)
        await withTaskGroup(of: (Int, NSImage?).self) { group in
            for (index, entry) in entries.prefix(6).enumerated() {
                group.addTask {
                    guard entry.url.startAccessingSecurityScopedResource() else {
                        return (index, nil)
                    }
                    defer { entry.url.stopAccessingSecurityScopedResource() }
                    let image = await ThumbnailService.generateThumbnail(for: entry.url, size: thumbnailSize)
                    return (index, image)
                }
            }
            for await (index, image) in group {
                guard !Task.isCancelled, index < fileEntries.count else { continue }
                if let image {
                    fileEntries[index].thumbnail = image
                }
            }
        }
    }
}

// MARK: - Supporting Types

private struct FileEntry: Identifiable {
    let id = UUID()
    let metadata: FileMetadata
    var thumbnail: NSImage?
    let url: URL
}

private struct FileMetadata {
    let fileName: String
    let parentPath: String
    let fileSize: String?
    let fileType: String?
    let icon: NSImage?

    var typeAndSizeLabel: String? {
        let label = [fileType, fileSize].compactMap { $0 }.joined(separator: " \u{00B7} ")
        return label.isEmpty ? nil : label
    }

    init(url: URL) {
        self.fileName = url.lastPathComponent
        self.parentPath = url.deletingLastPathComponent().path(percentEncoded: false)
        self.icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])

        if let bytes = values?.fileSize {
            self.fileSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        } else {
            self.fileSize = nil
        }

        self.fileType = values?.contentType?.localizedDescription
    }
}
