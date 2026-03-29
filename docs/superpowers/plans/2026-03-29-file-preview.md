# File Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show on-demand QuickLook content thumbnails when users expand file clips in the clipboard panel.

**Architecture:** `FilePreviewView` resolves the security-scoped bookmark, reads file metadata, and calls `ThumbnailService` (a thin wrapper around `QLThumbnailGenerator`) to produce a content thumbnail. `ClipRow` delegates to `FilePreviewView` for the `.file` case in its expanded preview. No model changes, no caching.

**Tech Stack:** QuickLookThumbnailing framework, SwiftUI, UniformTypeIdentifiers, AppKit (NSWorkspace)

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `clipper-zero/Services/ThumbnailService.swift` | **Create** | Wraps `QLThumbnailGenerator` with a single async method |
| `clipper-zero/Panel/FilePreviewView.swift` | **Create** | SwiftUI view: bookmark resolution, metadata, thumbnail display, loading/error states |
| `clipper-zero/Panel/ClipRow.swift` | **Modify** | Add `case .file:` branch in `expandedPreview` |

---

### Task 1: Create ThumbnailService

**Files:**
- Create: `clipper-zero/Services/ThumbnailService.swift`

- [ ] **Step 1: Create `ThumbnailService.swift`**

```swift
import AppKit
import QuickLookThumbnailing

enum ThumbnailService {
    static func generateThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let scale = await MainActor.run {
            NSScreen.main?.backingScaleFactor ?? 2.0
        }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return representation.nsImage
        } catch {
            return nil
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: XcodeBuildMCP `build_sim` (or use the `/verify` skill)
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add clipper-zero/Services/ThumbnailService.swift
git commit -m "feat: add ThumbnailService wrapping QLThumbnailGenerator"
```

---

### Task 2: Create FilePreviewView

**Files:**
- Create: `clipper-zero/Panel/FilePreviewView.swift`

**Context:** This view resolves the security-scoped bookmark stored in `clip.content`, reads file metadata (name, size, type, path), requests a thumbnail from `ThumbnailService`, and renders one of three states: loading, success, or error. The view is used inside `ClipRow`'s expanded preview area, so it should have no outer padding (the caller provides that).

**Reference — bookmark resolution pattern from `PasteService.swift:73-81`:**
```swift
var isStale = false
if let url = try? URL(
    resolvingBookmarkData: clip.content,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
) { ... }
```

- [ ] **Step 1: Create `FilePreviewView.swift`**

```swift
import SwiftUI
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct FilePreviewView: View {
    let clip: ClipItem

    @State private var thumbnail: NSImage?
    @State private var fileMetadata: FileMetadata?
    @State private var loadFailed = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                loadingState
            } else if let fileMetadata {
                successState(metadata: fileMetadata)
            } else {
                errorState
            }
        }
        .task {
            await loadPreview()
        }
    }

    // MARK: - States

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

    private func successState(metadata: FileMetadata) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let icon = metadata.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(metadata.fileName)
                    .font(.body)
                    .fontWeight(.semibold)

                if let typeAndSize = metadata.typeAndSizeLabel {
                    Text(typeAndSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(metadata.parentPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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

    // MARK: - Loading

    private func loadPreview() async {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: clip.content,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            isLoading = false
            loadFailed = true
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            isLoading = false
            loadFailed = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Read metadata (available immediately)
        let metadata = FileMetadata(url: url)
        self.fileMetadata = metadata
        isLoading = false

        // Generate thumbnail (async)
        let size = CGSize(width: 256, height: 256)
        if let image = await ThumbnailService.generateThumbnail(for: url, size: size) {
            self.thumbnail = image
        }
        // If thumbnail fails, successState falls back to metadata.icon (NSWorkspace icon)
    }
}

// MARK: - FileMetadata

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
```

- [ ] **Step 2: Build to verify it compiles**

Run: XcodeBuildMCP `build_sim` (or use the `/verify` skill)
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add clipper-zero/Panel/FilePreviewView.swift
git commit -m "feat: add FilePreviewView with loading, success, and error states"
```

---

### Task 3: Wire FilePreviewView into ClipRow

**Files:**
- Modify: `clipper-zero/Panel/ClipRow.swift:88-128` (the `expandedPreview` computed property)

**Context:** Currently `expandedPreview` has explicit cases for `.image`, `.link`, and `.color`, with everything else falling through to `default:` (plain text in a monospaced code block). We need to add a `case .file:` branch before the `default:` that renders `FilePreviewView`.

- [ ] **Step 1: Add `case .file:` to `expandedPreview`**

In `clipper-zero/Panel/ClipRow.swift`, inside the `expandedPreview` `Group { switch clip.contentType { ... } }`, add a new case between the `.color` case and the `default` case:

```swift
            case .file:
                FilePreviewView(clip: clip)
```

The full `expandedPreview` should now read:

```swift
    private var expandedPreview: some View {
        Group {
            switch clip.contentType {
            case .image:
                if let nsImage = NSImage(data: clip.content) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            case .link:
                if let urlString = clip.plainText {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(urlString)
                            .font(.body)
                            .foregroundStyle(.blue)
                            .underline()
                    }
                }
            case .color:
                if let colorDesc = clip.plainText {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray)
                            .frame(width: 32, height: 32)
                        Text(colorDesc)
                            .font(.body.monospaced())
                    }
                }
            case .file:
                FilePreviewView(clip: clip)
            default:
                Text(clip.plainText ?? "No content")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run: XcodeBuildMCP `build_sim` (or use the `/verify` skill)
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add clipper-zero/Panel/ClipRow.swift
git commit -m "feat: wire FilePreviewView into ClipRow expanded preview for file clips"
```

---

### Task 4: Manual Verification

- [ ] **Step 1: Build and run on simulator**

Run: XcodeBuildMCP `build_run_sim`

- [ ] **Step 2: Test with various file types**

1. In Finder, copy a PDF file (Cmd+C)
2. Open clipboard panel (global hotkey)
3. Verify the row shows `[FILE]` badge + filename
4. Press Tab to expand — verify thumbnail of PDF first page appears with metadata (name, type, size, path)
5. Repeat with: an image file (.png/.jpg), a text file (.swift or .txt), a .zip archive, a Keynote/Pages doc

- [ ] **Step 3: Test error state**

1. Copy a file from Finder
2. Delete or move that file
3. Open clipboard panel and expand that clip
4. Verify "File no longer available" error state renders (red text, document icon)

- [ ] **Step 4: Test large file**

1. Copy a large file (500MB+) from Finder
2. Expand the clip — verify the UI doesn't freeze (thumbnail may take a moment but the loading state should appear immediately)

- [ ] **Step 5: Final commit**

If any fixes were needed during testing, commit them:
```bash
git add -A
git commit -m "fix: address issues found during file preview manual testing"
```
