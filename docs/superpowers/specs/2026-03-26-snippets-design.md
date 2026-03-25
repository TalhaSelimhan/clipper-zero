# Snippets Feature — Design Spec

## Overview

Add a "Snippets" feature to Clipper Zero — a separate persistent store of manually-created name/value pairs for quick access to frequently used text (user IDs, emails, code fragments, etc.). Snippets are accessed from the same panel as clips, with a segmented control to switch between views and unified search across both.

## Data Model

New `SnippetItem` SwiftData model in the existing "ClipperZero" `ModelContainer`:

```swift
@Model
final class SnippetItem {
    var id: UUID
    var name: String        // searchable display name, e.g. "Cerebro User ID"
    var value: String       // the text to paste, e.g. "12312321"
    var createdAt: Date
    var sortOrder: Int      // for manual ordering; initially set to creation order
}
```

- Lives alongside `ClipItem` and `ClipCollection` — no relationships to either
- Both `name` and `value` are searchable
- Plain text values only (MVP scope)

## Panel UI & Navigation

### Segmented Control

A native SwiftUI `Picker` with `.segmented` style sits between the search bar and the list:

```
┌─────────────────────────────────┐
│  Search...                      │
│  ┌──────────┬──────────┐        │
│  │  Clips   │ Snippets │        │
│  └──────────┴──────────┘        │
│  ─────────────────────────────  │
│  [list of clips or snippets]    │
│                                 │
│  ─────────────────────────────  │
│  footer                         │
└─────────────────────────────────┘
```

### Keyboard Navigation

- **Left/Right arrows** switch the active segment when the search bar is not focused (arrow keys still move the cursor while typing)
- Switching segments resets selection index to 0
- **Up/Down arrows** navigate within the current list (unchanged)
- **Enter** pastes the selected item (clip or snippet)
- **Cmd+C** copies without pasting
- **Cmd+Delete** deletes the selected item
- **Tab** expands preview (clips only — snippets show name/value inline)
- **Cmd+N** opens inline snippet creation form (Snippets segment only)

### Snippet Row Layout (Two-Line)

- `SNP` type badge on the left (colored pill, consistent with clip badges like `TXT`, `IMG`)
- Line 1: snippet name (primary text)
- Line 2: snippet value, truncated, dimmed/secondary style

### Footer

Updates to show snippet count when on the Snippets segment.

## Search

### Behavior

- **Search empty:** show only items for the active segment (Clips or Snippets)
- **Search non-empty:** show results from both clips and snippets, interleaved in a single list

### Matching

- Same `localizedStandardContains` as clips — case-insensitive, diacritic-insensitive
- Clips: match against `plainText`
- Snippets: match against both `name` and `value`

### Result Ordering (Mixed)

- Snippets first (intentionally saved, higher-intent matches), ordered by `sortOrder`
- Clips second, ordered by `createdAt` descending

### Result Type Wrapper

```swift
enum SearchResult: Identifiable {
    case clip(ClipItem)
    case snippet(SnippetItem)

    var id: UUID { ... }
}
```

## Snippet CRUD

### Quick-Add from Panel

- `Cmd+N` on the Snippets segment opens an inline form at the top of the list
- Two text fields: Name and Value
- `Enter` to save, `Escape` to cancel
- New snippet gets `sortOrder` = max existing + 1

### Settings Management

- New "Snippets" tab in the Settings window
- Table/list of all snippets with Name and Value columns
- "+" to add, "-" to delete selected
- Inline editing — click a cell to edit name or value
- Drag-and-drop reordering (updates `sortOrder`)

### Deletion

- `Cmd+Delete` from the panel (same shortcut as clips)
- No confirmation dialog (consistent with clip deletion)

### Editing

- Only from Settings for MVP — the panel is optimized for quick access, not editing

## Paste & Copy

### Enter (Paste)

1. Write snippet `value` to `NSPasteboard` as plain text
2. Simulate `Cmd+V` via existing `PasteService`
3. Dismiss the panel

### Cmd+C (Copy Only)

1. Copy snippet `value` to clipboard
2. Dismiss the panel

No changes to `PasteService` needed — it already handles plain text writes. Snippets call the same code path with `value` as content.

## Out of Scope (MVP)

- Rich text / image / file snippet values
- Snippet collections or folders
- Import/export of snippets
- Snippet sync across devices
- Editing snippets from the panel
