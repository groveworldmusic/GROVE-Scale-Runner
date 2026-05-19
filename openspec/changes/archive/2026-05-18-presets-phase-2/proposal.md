# Proposal: Presets Phase 2 — Multi-Select + Batch Operations

## Intent

Single-preset selection limits the browser to one-at-a-time actions. Users managing many presets need: select a range and delete, load multiple presets merged, or export selections. This is the highest-ROI enhancement to the preset browser — no layout changes, pure interaction + store upgrade.

## Scope

### In Scope
- Set-based multi-selection (Shift/Ctrl+click) mirroring `island.lua` proven pattern
- Batch Delete with confirmation dialog
- Merge-mode Load (append notes from multiple presets)
- Batch Export to REAPER MIDI items
- Enhanced context menu with batch actions
- Index fixup on delete (same pattern as `island_store.RemoveNoteAtIndex`)

### Out of Scope
- Tags, metadata, notes, badges, thumbnails — deferred to future phase
- Preview audio (Ctrl+Space ghost notes)
- Auto-save per slot / dirty flags
- Export/Import `.grovpack` format
- Usage stats, versioning, dark/light sync
- Toolbar buttons — context-menu-only for zero layout change

## Capabilities

### New Capabilities
- `preset-multiselect`: Set-based selection model for preset list, mirroring `island.lua` `{selected_indices, ToggleNoteSelected, ClearSelection, IsNoteSelected, GetSelectionCount, GetPrimarySelectedIndex}`

### Modified Capabilities
- `preset-browser`: Selection model changes from single `selected_preset_idx` to set-based `selected_indices`. Click handlers in `preset-list.lua` gain Shift/Ctrl modifier logic. Context menu (`HandleContextMenu` in `preset-list.lua:173`) extended with batch actions. `io.lua` gets `BatchDelete`, `ExportPresetsToMIDI`, merge-mode `LoadPreset`.

## Approach

Follow `island.lua` multi-select pattern exactly:
- `preset-store.lua`: replace `selected_preset_idx` with `selected_indices = {}`, `selection_anchor = nil`. Add `TogglePresetSelected(idx)`, `ClearSelection()`, `IsSelected(idx)`, `GetSelectionCount()`, `GetPrimarySelectedIndex()`, `GetSelectionAnchor()`, `SetSelectionAnchor(v)`.
- `preset-list.lua`: `DrawPresetList` renders multi-selected rows. `HandlePresetClick` gains modifier logic: plain-click → single select, Ctrl+click → toggle, Shift+click → range select from anchor. Right-click on multi-selection shows batch menu ("Load Merged (N)", "Delete (N)", "Export (N)").
- `io.lua`: `BatchDelete(paths)` loops `os.remove`. `LoadPresetMerge(paths)` concatenates notes from all files, pushes single undo snapshot. `ExportPresetsToMIDI(paths)` iterates notes + calls `reaper.MIDI_InsertNote`.
- Index fixup: after delete, rebuild `selected_indices` decrementing keys > removed index (same as `island.lua:210-220`).
- `main.lua` (preset-browser): dispatch updated to handle multi-select results. Backward compat shim so `GetSelectedPresetIdx()` returns primary or nil.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/state/preset-store.lua` | Modified | Replace `selected_preset_idx` with `selected_indices {}` + set-based API |
| `src/ui/preset-browser/preset-list.lua` | Modified | Multi-select rendering, Shift/Ctrl click, batch context menu |
| `src/ui/preset-browser/main.lua` | Modified | Dispatch multi-select results, batch action routing |
| `src/ui/preset-browser/io.lua` | Modified | `BatchDelete()`, `LoadPresetMerge()`, `ExportPresetsToMIDI()` |
| `src/ui/preset-browser.lua` | Modified | Barrel re-export of new functions |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Index drift after batch delete | Medium | Apply fixup pattern from `island_store.RemoveNoteAtIndex`: iterate `selected_indices`, decrement keys > removed idx. Test with adjacent + non-adjacent deletes. |
| Merge-mode Load creates duplicated notes | Low | Single undo snapshot before merge. User can undo to revert. No silent overwrite. |
| Shift-click range undefined without anchor | Low | `selection_anchor` tracks last Ctrl+click or plain-click. First Shift+click with nil anchor behaves as plain-click. |
| Search + multi-select interaction | Low | Multi-select operates on filtered list indices. When search changes (query edit), clear selection to avoid stale indices. |

## Rollback Plan

Revert the single PR that lands this change. `selected_indices` replaces `selected_preset_idx` — a straight revert restores old model. In-place git revert: `git revert <pr-head>` — all 5 files return to single-select. No migration needed (ExtState field `selected_preset_idx` was ephemeral, not persisted). `preset-store.lua` Init won't break on old state.

## Dependencies

- Phase 1 fully merged (Init fix, barrel refactor, Live Search, Undo on Load, Random Preset, Cross-Session Sync)
- Proven `island.lua` multi-select pattern as reference implementation
- `reaper.MIDI_InsertNote` / `MIDI_InsertNoteCnt` for export (already in `core.midi` export path)

## Success Criteria

- [ ] Ctrl+click toggles individual preset selection without losing others
- [ ] Shift+click selects range between anchor and clicked index
- [ ] Multi-selected rows render visually distinct (selected highlight on all)
- [ ] Right-click on multi-selection shows batch menu items (Load Merged, Delete N, Export N)
- [ ] Batch Delete shows confirmation dialog with count, removes files, fixes up indices
- [ ] Merge-mode Load appends notes from multiple presets, pushes single undo snapshot
- [ ] Export creates REAPER MIDI items from all selected presets' notes
- [ ] Search query change clears multi-selection to prevent stale indices
- [ ] Backward compat: `GetSelectedPresetIdx()` returns primary selected index or nil
- [ ] Index fixup after delete works for adjacent (`{2,3,4}`) and non-adjacent (`{2,5,7}`) selection sets
