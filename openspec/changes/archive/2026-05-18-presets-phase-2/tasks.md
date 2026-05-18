# Tasks: Presets Phase 2 — Multi-Select + Batch Operations

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~275 (additions + modifications) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single-pr |
| Delivery strategy | exception-ok |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

**Prerequisite**: Phase 1 barrel + features (search, undo-on-load, random, cross-sync) deployed. Sub-modules exist at `preset-browser/`, barrel re-exports them.

## Phase 1: Data Model — `preset-store.lua`

- [ ] **1.1 — Replace `selected_preset_idx` with set-based selection**: Change state from `selected_preset_idx = nil` to `selected_indices = {}` + `_last_selected_idx = nil`. Add fields + Init sync.
- [ ] **1.2 — Add set-based selection API**: `GetSelectedIndices()`, `SetSelectedIndices(t)`, `ClearSelection()`, `IsPresetSelected(idx)`, `TogglePresetSelected(idx)`, `GetPrimarySelectedIndex()`, `GetSelectionCount()` — 7 functions, mirror island.lua pattern exactly.
- [ ] **1.3 — Backward compat shims**: `GetSelectedPresetIdx()` delegates to `GetPrimarySelectedIndex()`. `SetSelectedPresetIdx(v)` calls `ClearSelection()` + sets index. All 17 existing callers keep working unchanged.

## Phase 2: Core UI — `preset-list.lua`

- [ ] **2.1 — Set-based is_selected rendering**: Change `local is_selected = (i == selected_idx)` to `local is_selected = preset_store.IsPresetSelected(i)`. All selected items render with ITEM_SELECTED bg.
- [ ] **2.2 — Modifier-aware click dispatch**: Add `reaper.JS_VKeys_GetState(0)` detection for Ctrl (VK_0x11) and Shift (VK_0x10) in `HandlePresetClick`. Plain click → `ClearSelection()` + set clicked. Ctrl+click → `TogglePresetSelected()`. Shift+click → range select from anchor.
- [ ] **2.3 — Batch context menu**: In `HandleContextMenu`, branch on `GetSelectionCount() > 1`. Show "Delete N presets", "Load (Merge)", "Export to MIDI" in addition to single-item options. Right-click on unselected item clears + selects it first.

## Phase 3: Integration — `main.lua`, `io.lua`, barrel

- [ ] **3.1 — Route multi-select results in main.lua**: Update `DrawPresetBrowser` result dispatch for batch actions. Add `ClearSelection()` on search query change.
- [ ] **3.2 — Batch delete in io.lua**: `BatchDeletePresets(indices, files)` — confirm dialog with count, loop `os.remove`, call `RefreshPresets()` + `ClearSelection()`.
- [ ] **3.3 — Merge-mode load in io.lua**: `LoadPresetMerge(file_paths)` — loop `safe_loader.LoadSandboxed`, concat notes with unique UUIDs, `PushUndo()` once, `SetNotes()` combined array.
- [ ] **3.4 — Export to MIDI in io.lua**: `ExportPresetsToMIDI(indices, files, track)` — iterate selected presets, `CreateNewMIDIItemInProj` per preset, `MIDI_InsertNote` per note, `MIDI_Sort` per take.
- [ ] **3.5 — Barrel re-export**: Add `BatchDeletePresets`, `LoadPresetMerge`, `ExportPresetsToMIDI`, `GetSelectedIndices`, `GetSelectionCount`, `GetPrimarySelectedIndex`, `TogglePresetSelected` to barrel.

## Manual Testing Checklist (REAPER)

- [ ] Plain click: single select, old selection cleared
- [ ] Ctrl+click: toggle individual preset in/out of selection set
- [ ] Shift+click: range select from anchor to clicked index
- [ ] Right-click on single selection: shows Load/Rename/Duplicate/Delete/Show in Explorer
- [ ] Right-click on multi-selection: shows Load (Merge), Delete N, Export to MIDI
- [ ] Batch Delete: confirm dialog shows correct count, files removed, selection cleared
- [ ] Load (Merge): notes from all presets combined into editor, undo reverts in one step
- [ ] Export to MIDI: one MIDI item per preset created on selected track
- [ ] Search query change clears multi-selection
- [ ] `GetSelectedPresetIdx()` returns primary index (backward compat with Rename/Load buttons)
- [ ] `ScanDirectory` / `RefreshPresets` clears selection
