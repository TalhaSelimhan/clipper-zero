# File Preview for Copied Files

## Context

Clipper Zero captures files copied from Finder as security-scoped bookmarks (`.file` content type), but the clipboard panel only shows the filename as plain text. Users have no way to see what's *inside* a copied file without opening it. This design adds on-demand content thumbnails using macOS's native QuickLook framework, supporting all file types the system can render — PDFs, images, documents, videos, and more.

## Requirements

- **Scope:** File URLs copied from Finder only (`.file` content type)
- **File types:** All QuickLook-supported types via `QLThumbnailGenerator`
- **Generation:** On-demand when the user expands a file clip (Tab key)
- **Caching:** None — regenerate from the original file each time
- **Display:** Expanded view only — row stays compact with filename text
- **No model changes:** `previewData` field remains unused for file clips

## Architecture

### Data Flow

```
User presses Tab on a file clip
  → ClipRow renders FilePreviewView
    → FilePreviewView resolves security-scoped bookmark → URL
      → ThumbnailService.generateThumbnail(for:size:)
        → QLThumbnailGenerator.shared.generateBestRepresentation(for:)
          → Returns CGImage → NSImage
            → Display thumbnail + file metadata
```

### New Components

**`ThumbnailService`** (`Services/ThumbnailService.swift`)
- Wraps `QLThumbnailGenerator` from the `QuickLookThumbnailing` framework
- Single async method: `generateThumbnail(for url: URL, size: CGSize) async -> NSImage?`
- Pure thumbnail generator — takes a file URL (caller manages security scope), returns image or nil

**`FilePreviewView`** (`Panel/FilePreviewView.swift`)
- SwiftUI view that takes a `ClipItem` of type `.file`
- Owns the full lifecycle: resolves bookmark → starts security-scoped access → reads metadata + requests thumbnail → stops access
- Calls `ThumbnailService` in a `.task {}` modifier
- Manages three states: loading, success (thumbnail + metadata), error (file unavailable)
- Reads file metadata via `URL.resourceValues(forKeys:)`: file size, content type, path

### Modified Components

**`ClipRow`** (`Panel/ClipRow.swift`)
- In `expandedPreview`, add a `case .file:` branch that renders `FilePreviewView`
- Currently falls through to the `default:` case showing plain text

## Expanded View Layout

### Success State

```
┌──────────────────────────────────────────────────┐
│ [FILE]  report-2026.pdf          Finder   2m ago │
├──────────────────────────────────────────────────┤
│  ┌──────────┐                                    │
│  │          │  report-2026.pdf                   │
│  │ QuickLook│  PDF Document · 2.4 MB             │
│  │ Thumbnail│  /Users/talha/Documents/Reports/   │
│  │          │                                    │
│  └──────────┘                                    │
└──────────────────────────────────────────────────┘
```

- Thumbnail: left-aligned, max 200px height, aspect-fit, rounded corners, subtle shadow
- Metadata: filename (bold), file type + size, file path (monospaced, dimmed)

### Loading State

```
┌──────────────────────────────────────────────────┐
│ [FILE]  presentation.key         Finder   5m ago │
├──────────────────────────────────────────────────┤
│  ┌ ─ ─ ─ ─ ┐                                    │
│  │ Loading  │  presentation.key                  │
│  │   ...    │  Keynote Presentation              │
│  └ ─ ─ ─ ─ ┘                                    │
└──────────────────────────────────────────────────┘
```

- Dashed border placeholder with `ProgressView`
- Metadata shown immediately (resolved from bookmark URL before thumbnail is ready)

### Error State — File Not Found

```
┌──────────────────────────────────────────────────┐
│ [FILE]  deleted-file.zip         Finder   1h ago │
├──────────────────────────────────────────────────┤
│  ┌──────┐                                        │
│  │  📄  │  deleted-file.zip (dimmed)             │
│  └──────┘  File no longer available (red)        │
│            /Users/talha/Downloads/ (dimmed)       │
└──────────────────────────────────────────────────┘
```

- Generic document icon (or `NSWorkspace.icon(forFile:)` if path is resolvable)
- "File no longer available" in red secondary text
- Path shown from the last known bookmark data

## Technical Details

### QLThumbnailGenerator

- **Framework:** `QuickLookThumbnailing` (import required)
- **Request size:** `CGSize(width: 256, height: 256)` — sufficient for 200px max display height
- **Representation type:** `.thumbnail` (content-based rendering, not file icon)
- **Scale:** `NSScreen.main?.backingScaleFactor ?? 2.0` for Retina support
- **Minimum macOS:** 10.15 (project targets 14.0+)

### Security-Scoped Bookmark Resolution

```swift
// Resolve bookmark → URL
var isStale = false
guard let url = try? URL(
    resolvingBookmarkData: clip.content,
    options: .withSecurityScope,
    bookmarkDataIsStale: &isStale
) else { /* show error state */ }

// Access the file
guard url.startAccessingSecurityScopedResource() else { /* show error state */ }
defer { url.stopAccessingSecurityScopedResource() }

// Now safe to pass url to QLThumbnailGenerator and read metadata
```

### File Metadata

Read via `URL.resourceValues(forKeys:)`:
- `.fileSizeKey` → format with `ByteCountFormatter`
- `.contentTypeKey` → `UTType.localizedDescription` for "PDF Document", "JPEG Image", etc.
- `.pathKey` → parent directory path for display

### Error Fallback Chain

1. Bookmark resolution fails → show "File no longer available" with generic icon
2. Bookmark resolves but QuickLook returns nil → fall back to `NSWorkspace.shared.icon(forFile: url.path)` (system file icon, always works)
3. Both fail → show generic document icon (`NSImage(systemSymbolName: "doc")`)

## Files to Modify/Create

| File | Action |
|------|--------|
| `Services/ThumbnailService.swift` | **Create** — QuickLook thumbnail wrapper |
| `Panel/FilePreviewView.swift` | **Create** — SwiftUI expanded preview view |
| `Panel/ClipRow.swift` | **Modify** — add `case .file:` in `expandedPreview` |

## Verification

1. Build the project with XcodeBuildMCP
2. Copy various file types from Finder (PDF, image, .swift file, .docx, video, .zip)
3. Open clipboard panel → verify FILE badge + filename in row
4. Press Tab to expand → verify:
   - Loading state appears briefly
   - Thumbnail renders with correct content
   - File metadata (name, type, size, path) displays correctly
5. Delete a file that was previously copied → expand the clip → verify error state
6. Copy a very large file (1GB+) → verify thumbnail generates without blocking the UI
