# Tasks: Preset Browser Enhancements — Phase 1

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~970 (additions + deletions) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: Barrel (T1) → PR 2: Features (T2–T6) |
| Delivery strategy | ask-on-risk |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Replace 881-LOC monolith with barrel | PR 1 | Mechanical, verifiable by grep. ~931 diff lines but trivial semantics. |
| 2 | All 5 feature tasks | PR 2 | ~86 net additions. T2–T6 are independent of each other. |

## Phase 1: Foundation (Barrel + Init Fix)

- [x] **1.1 — Barrel replacement**: Replace `src/ui/preset-browser.lua` (881 LOC) with a barrel that requires and re-exports from the 4 sub-modules (`io.lua`, `folder.lua`, `preset-list.lua`, `main.lua`). Grep all `require("ui.preset-browser")` sites to confirm the public API: `Init`, `DrawPresetBrowser`, `SavePreset`, `LoadPreset`, `ScanDirectory`, `RefreshPresets`, `RenamePreset`, `IsFavorite`, `GetPresetFilePath`, `LoadFavorites`, `SaveFavorites`, `DrawFolderHeader`, `DrawFolderList`, `DrawPresetList`. No consumer changes needed. ~50 LOC written, 831 removed.

- [ ] **1.2 — LoadFavorites in Init**: Add `m.LoadFavorites()` at the end of `io.lua` `Init()`. Currently `Init` sets up directories but never loads saved favorites from ExtState. 1 line.

## Phase 2: Feature Implementation

- [ ] **2.1 — Live Search** (`preset-store.lua`, `main.lua`, barrel):
  - Add `search_query` field + getter/setter to `preset-store.lua`.
  - In `main.lua` `DrawPresetBrowser`: render a search bar below the header; capture `gfx.getchar()` for character input (alphanumeric + backspace); filter `files` via `string.find` case-insensitive before passing to `DrawPresetList`; Escape key clears query.
  - Re-export search functions from barrel if needed. ~35 LOC.

- [ ] **2.2 — Undo on Load** (`io.lua`):
  - Before `SetNotes()` in `LoadPreset()`: snapshot current notes with a shallow copy, push undo entry via `note_store.PushUndo({type="preset_load", snapshot=CopyNotes(n), selected=selected_idx})`.
  - Replace `note_store.ClearUndoStacks()` with `note_store.RedoClearStacks()` — preserve undo history so user can revert a preset load. If `note_store.PushUndo` already clears redo, just remove the `ClearUndoStacks` call entirely.
  - Add helper to deep-copy notes array. ~15 LOC.

- [ ] **2.3 — Random Preset** (`main.lua`, barrel):
  - Add RANDOM button in `DrawPresetBrowser` action area (below count label, before divider).
  - On click: `math.random(#files)` → `io_mod.LoadPreset(files[idx].path)`. ~15 LOC.

- [ ] **2.4 — Cross-Session Sync** (`main.lua`):
  - Track `_last_scan_time` via `reaper.time_precise()` module-level variable.
  - At top of `DrawPresetBrowser`: if `_last_scan_time` is nil or `reaper.time_precise() - _last_scan_time >= 3` and browser is visible, call `io_mod.RefreshPresets()` and update timer. ~8 LOC.

## Manual Testing Checklist (REAPER)

- [ ] Barrel: all 3 external callers (midi-island.lua, midi-island/header.lua) work without changes
- [ ] T2: favorites load on init (check ExtState round-trip)
- [ ] T3: typing filters list, Escape clears, case-insensitive match
- [ ] T4: after LoadPreset, Ctrl+Z reverts to previous notes
- [ ] T5: RANDOM button loads a random preset from current directory
- [ ] T6: leaving browser open for 3s re-scans directory (verify via new file appearing)
