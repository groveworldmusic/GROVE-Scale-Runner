# Proposal: Complete Presets Panel

## Intent

The presets panel is structurally complete (state store, file I/O, preset list, favorites, sandboxed loading) but functionally broken. Folder navigation is dead — the folder list never renders because `DrawFolderList` is called with wrong arguments (missing `dirs` and `scroll_offset`), and the click/wheel handlers are never invoked. This makes the panel a read-only file list with no directory navigation. The goal is to wire up all broken connections so the panel works as designed.

## Scope

### In Scope
1. **Wire folder list rendering** — Pass `dirs` (from `preset_store.GetPresetTree().dirs`) and `scroll_offset` (from `preset_store.GetFolderScroll()`) to `DrawFolderList` in `main.lua`
2. **Wire folder click handler** — Call `HandleFolderClick` in `main.lua` dispatch loop; on `"navigate:path"` update `current_directory` and call `ScanDirectory`
3. **Wire folder wheel handler** — Call `HandleFolderWheel` in `main.lua`; update `folder_scroll` state
4. **Wire folder header "up" button** — Handle `"up"` return from `DrawFolderHeader` to navigate to parent directory
5. **Add error banner** — Render `browser_error` from store as a visible banner below the header when set
6. **Use `io_mod.Init()` in midi-island.lua** — Replace direct `ScanDirectory(root)` call with `preset_browser.Init()` for proper initialization flow
7. **Cross-platform path separator** — Replace hardcoded `\\` with a helper that uses `/` on non-Windows or a configurable separator

### Out of Scope
- **Bookmarks** — Field exists but has zero UI. Deferred: no user demand yet, removing would be a breaking change if future features use it
- **Favorites view filter** — Deferred as a separate feature (filter toggle to show only favorited presets)
- **LFS dependency** — The fallback to `io.popen` + `dir /B` is Windows-only but works. Adding cross-platform fallback without LFS is a separate task
- **Duplicate preset action** — Mentioned in exploration but not implemented; deferred

## Capabilities

### Modified Capabilities
- `preset-browser`: Folder navigation now functional — folder list renders, click/wheel handlers wired, parent navigation works, error banner displays

## Approach

1. **`preset-browser/main.lua`** — The primary fix. Add `dirs` and `scroll_offset` args to `DrawFolderList` call. Add a dispatch section that calls `HandleFolderClick`, `HandleFolderWheel`, and handles `DrawFolderHeader`'s "up" return. Add error banner rendering.
2. **`ui/midi-island.lua`** — Replace `InitPresetBrowser()` body to call `preset_browser.Init()` instead of direct `ScanDirectory`.
3. **`preset-browser/io.lua`** — Add a `PathJoin(a, b)` helper to replace hardcoded `\\` concatenation. Use it in `GetPresetFilePath`, `ScanDirectory`, `RenamePreset`.

Changes are localized to 3 files. No new modules, no store changes, no behavioral changes to save/load.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/preset-browser/main.lua` | Modified | Wire folder rendering args, add click/wheel/header dispatch, add error banner |
| `src/ui/midi-island.lua` | Modified | Replace direct ScanDirectory with preset_browser.Init() |
| `src/ui/preset-browser/io.lua` | Modified | Add PathJoin helper, replace hardcoded `\\` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Folder click consumes mouse event meant for preset list | Medium | Dispatch order: folder first (left column), preset list second (right column) — mutually exclusive by X coordinate |
| `DrawFolderHeader` return value currently ignored | Low | Add return capture and handle "up" before drawing folder list |
| PathJoin changes break existing `.grove` file paths | Low | Only affects new saves; existing files use absolute paths stored in preset entries |
| Error banner overlaps existing UI elements | Low | Render below header, above folder list, with fixed 20px height |

## Rollback Plan

Revert the 3 modified files to their current state. The panel will return to its current broken-but-harmless state (preset list renders, folder list empty). No data loss risk — all preset files on disk are untouched.

## Dependencies

- None. All required modules (`folder.lua`, `preset-store.lua`, `io.lua`) already exist with correct APIs.

## Success Criteria

- [ ] Folder list renders subdirectories in left column of preset panel
- [ ] Clicking a folder navigates into it and updates preset list
- [ ] Clicking ".." (up button) navigates to parent directory
- [ ] Scroll wheel on folder list scrolls folder entries
- [ ] Browser error messages display as visible banner when set
- [ ] `preset_browser.Init()` is called instead of direct `ScanDirectory`
- [ ] Path construction uses cross-platform helper (no hardcoded `\\` in new code)
