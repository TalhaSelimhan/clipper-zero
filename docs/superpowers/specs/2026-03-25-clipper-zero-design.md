# Clipper Zero — Design Spec

A modern macOS clipboard manager with a Raycast-style floating search panel, menu bar quick access, and support for text, images, files, colors, and links.

## App Architecture

**App type:** Menu bar app (no dock icon, no main window). Lives in the macOS menu bar with a global hotkey popup.

**Minimum target:** macOS 14 (Sonoma)

**Tech stack:** SwiftUI + AppKit bridging (NSPanel), SwiftData for persistence, all Apple-native frameworks.

**Distribution:** DMG / GitHub Releases / Homebrew cask (not App Store — sandbox incompatible).

### Key Components

- **ClipperZeroApp** — `@main` entry point. Sets up `MenuBarExtra` scene, registers global hotkey via `CGEvent` tap, initializes SwiftData `ModelContainer`.
- **ClipboardMonitor** — Background service polling `NSPasteboard.general` at ~0.5s intervals. Detects `changeCount` changes, reads pasteboard contents, creates `ClipItem` records. Skips clips from excluded apps (checks frontmost app bundle ID via `NSWorkspace`).
- **PanelController** — AppKit controller owning a borderless, non-activating `NSPanel` (level: `.floating`). Hosts SwiftUI content via `NSHostingView`. Handles show/hide animation, screen-center positioning, and focus management.
- **ClipboardPanel** (SwiftUI) — The Raycast-style search UI inside the panel. Search bar at top (always focused), scrollable results list with type badges, source app, timestamps. Tab-to-preview expansion.
- **MenuBarView** (SwiftUI) — `MenuBarExtra` dropdown. Shows recent clips, pinned clips, collections, and settings access.
- **PasteService** — Writes selected clip data to `NSPasteboard`, dismisses the panel, simulates `Cmd+V` via `CGEvent` to paste into the frontmost app.

### Data Flow

```
NSPasteboard → ClipboardMonitor → SwiftData
                                      ↓
User triggers hotkey → PanelController shows NSPanel
                                      ↓
                           ClipboardPanel (search/browse)
                                      ↓
                    User selects clip → PasteService → NSPasteboard → Cmd+V
```

## Data Model

### ClipItem

| Field | Type | Purpose |
|---|---|---|
| `id` | UUID | Primary key |
| `content` | Data | Raw clipboard data (text as UTF-8, images as PNG/TIFF, files as bookmark data) |
| `contentType` | enum: text, richText, image, file, color, link | What was copied |
| `plainText` | String? | Extracted plain text for search and display |
| `sourceAppBundle` | String? | Bundle ID of source app (e.g. `com.apple.Safari`) |
| `sourceAppName` | String? | Display name of source app |
| `createdAt` | Date | When captured |
| `isPinned` | Bool | Whether it's in favorites |
| `previewData` | Data? | Thumbnail for images, favicon for links |

### Collection

| Field | Type | Purpose |
|---|---|---|
| `id` | UUID | Primary key |
| `name` | String | Display name (e.g. "Code Snippets") |
| `icon` | String | SF Symbol name |
| `createdAt` | Date | For ordering |
| `items` | [ClipItem] | Many-to-many relationship |

### ExcludedApp

| Field | Type | Purpose |
|---|---|---|
| `id` | UUID | Primary key |
| `bundleIdentifier` | String | e.g. `com.1password.1password` |
| `appName` | String | Display name |

### Retention Policy

Default cap: 1000 items (user-configurable). When exceeded, unpinned items not in any collection are deleted oldest-first. Pinned items and collection members are exempt.

## UI Design

### Clipboard Panel (Global Hotkey Popup)

Single-pane Raycast-style floating panel:

- **Search bar** — top of panel, always focused, fuzzy search as you type
- **Results list** — scrollable rows, each showing: type badge (color-coded), content preview (truncated), source app name, relative timestamp
- **Type badges:** Text (purple), Link (blue), Image (green), Color (yellow), File (gray), Rich Text (purple)
- **Preview expansion** — press Tab to expand the selected item inline with full content preview (syntax-highlighted code, image thumbnail, link metadata)
- **Footer** — keyboard shortcut hints: ↑↓ Navigate, ↵ Paste, ⌘F Pin, ⇥ Preview, esc Close

**Visual style:** Adapts to system appearance. Dark mode: dark background (#1a1a2e-ish), subtle white borders. Light mode: white/light gray background, subtle dark borders. Both: rounded corners (12px), vibrancy/blur material backdrop, smooth show/hide animations.

### Menu Bar Dropdown

Simpler quick-access view via `MenuBarExtra`:

- **Header:** "Clipper Zero" + gear icon for settings
- **Recent section:** Last 10 clips as compact rows (type icon + truncated text + time)
- **Pinned section:** Favorited clips, always visible
- **Collections section:** Expandable list of named collections
- **Footer:** "Clear History" + "Open Panel (⌘⇧V)"

Clicking any clip copies it to pasteboard. No search — the panel handles that.

### Settings Window

Standard SwiftUI `Settings` scene. Three tabs:

**General:**
- Launch at login (toggle, via `SMAppService`)
- Global hotkey (hotkey recorder, default `Cmd+Shift+V`)
- History limit (slider/stepper, default 1000)
- Play sound on copy (toggle)

**Excluded Apps:**
- List of excluded apps with icons
- "+" button opens app picker
- Pre-populated suggestions: 1Password, Keychain Access

**About:**
- Version, credits, GitHub link

### Collection Management

Inline, not in settings. Right-click a clip → "Add to Collection" → pick existing or create new. Collections editable from menu bar dropdown (rename, delete, change icon).

## Keyboard & Interactions

### Global Hotkey

`Cmd+Shift+V` (configurable) — toggles the floating panel.

### Panel Keyboard Navigation

| Key | Action |
|---|---|
| `↑` / `↓` | Navigate clip list |
| `↵` Enter | Paste selected clip |
| `⇥` Tab | Toggle preview expansion |
| `⌘F` | Toggle pin/favorite |
| `⌘C` | Copy to pasteboard without pasting |
| `⌘⌫` | Delete selected clip |
| `esc` | Dismiss panel |
| Type anything | Fuzzy search (search bar always focused) |

### Paste-Back Flow

1. User presses `Cmd+Shift+V` — panel appears as non-activating `NSPanel` (frontmost app stays active)
2. User navigates and selects a clip
3. Panel writes clip data to `NSPasteboard`, dismisses itself
4. App simulates `Cmd+V` via `CGEvent` — paste lands in original app

## Permissions & System Integration

### Required Permissions

- **Accessibility** — for `CGEvent` paste simulation. Prompt on first launch with clear explanation.
- **No sandbox** — clipboard managers need unrestricted `NSPasteboard` access and `CGEvent` posting.

### First Launch Flow

1. App starts in menu bar (no dock icon)
2. Welcome popover from menu bar icon explaining the app
3. Accessibility permission request with "why" explanation
4. Clipboard monitoring begins once granted

### System APIs

- `NSPasteboard` — clipboard monitoring and writing
- `CGEvent` — simulating Cmd+V for paste-back
- `NSWorkspace` — detecting frontmost app for source attribution and excluded app checking
- `SMAppService` — launch at login
- `NSPanel` — non-activating floating window
- `SwiftData` — persistence
- `NSEvent.addGlobalMonitorForEvents` / `CGEvent.tapCreate` — global hotkey registration
