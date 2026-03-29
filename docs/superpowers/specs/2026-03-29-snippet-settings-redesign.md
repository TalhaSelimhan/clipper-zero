# Snippet Settings Redesign: Compact List + Expandable Editor

## Problem

The current snippet settings UI in `SnippetsSettingsTab.swift` has two usability issues:

1. **Ambiguous fields** — Two plain `TextField`s stacked vertically with only placeholder text ("Name", "Value") as labels. Users can't tell which field is which at a glance.
2. **Single-line content** — The snippet content field is a single-line `TextField`, making it impractical for multiline snippets (email templates, code blocks, formatted text).

## Solution

Replace the current flat list of always-editable rows with a **compact list + expandable inline editor** (accordion pattern). Each snippet shows as a compact row by default; clicking a row expands it into a labeled editor with multiline support.

## Design

### Collapsed State (Default)

Each snippet renders as a compact row:
- **Name** in body font weight (primary text)
- **Content preview** below in caption/secondary, truncated to one line with ellipsis
- **Disclosure indicator** (chevron.right) on the trailing edge

No edit controls are visible in collapsed state — the list stays clean and scannable.

### Expanded State (Click to Edit)

Clicking a row expands it inline. Only one snippet can be expanded at a time (accordion — expanding one collapses the previously expanded).

The expanded area contains:
- **Header bar**: Snippet name in accent color + reorder buttons (chevron.up/down) + delete button (minus.circle.fill)
- **"Title" label** (small, uppercase, secondary color) above a `TextField` for the snippet name
- **"Content" label** (same style) above a `TextEditor` for the snippet content
  - Minimum height ~80pt, grows with content
  - Scrollable for very long snippets
- Subtle tinted background (e.g. `Color.accentColor.opacity(0.05)`) to distinguish editing area

Changes auto-save via SwiftData `@Bindable` binding (same behavior as current).

### Adding a New Snippet

- Click "+ Add Snippet" button at bottom
- New `SnippetItem` is created with empty name/value
- New snippet is immediately expanded for editing
- Title field receives focus automatically

### Deleting a Snippet

- Delete button visible only in expanded state header
- Same immediate deletion behavior as current (no confirmation dialog)

### Reordering

- Up/down chevron buttons in expanded state header (same swap logic as current)
- Disabled at boundaries (first/last)

## Files to Modify

- **`clipper-zero/Views/Settings/SnippetsSettingsTab.swift`** — Primary file. Rewrite `SnippetSettingsRow` into two components: `SnippetCollapsedRow` and `SnippetExpandedEditor`. Add `@State private var expandedSnippetID: UUID?` to `SnippetsSettingsTab` for accordion state.

## Data Model

No changes to `SnippetItem` model — the existing fields (`name`, `value`, `sortOrder`, `createdAt`) are sufficient.

## Implementation Notes

- Use `TextEditor` (not `TextField`) for the content field. Apply `.frame(minHeight: 80)` and `.scrollContentBackground(.hidden)` for consistent styling.
- Use `withAnimation` on expand/collapse transitions for smooth accordion behavior.
- The `expandedSnippetID` state tracks which snippet is expanded. Setting it to a new snippet's ID on add ensures the new snippet opens for editing.
- Keep the existing `Form` + `.formStyle(.grouped)` container — the accordion rows render inside the form section.

## Verification

1. Build with XcodeBuildMCP and verify no compilation errors
2. Open Settings → Snippets tab
3. Verify collapsed rows show name + content preview
4. Click a row — verify it expands with labeled Title/Content fields
5. Edit title and content — verify changes persist (close and reopen settings)
6. Add a new snippet — verify it appears expanded with focus on title
7. Delete a snippet from expanded state — verify removal
8. Reorder via up/down buttons — verify order persists
9. Verify multiline content renders correctly in TextEditor
10. Verify only one snippet can be expanded at a time
