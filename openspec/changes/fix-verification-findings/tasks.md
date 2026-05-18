# Tasks: fix-verification-findings

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1200 |
| 400-line budget risk | High |
| Chained PRs recommended | No |
| Suggested split | single PR |
| Delivery strategy | exception-ok |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Fix Unit Tests | PR 1 | base branch; tests included |
| 2 | Refactor Preset Browser | PR 1 | depends on Phase 1; UI layer |
| 3 | De-inflate Island Store | PR 1 | depends on Phase 2; State layer |

## Phase 1: Unit Test Fixes (Foundation)

- [ ] 1.1 Fix `test_note_store.lua`: Update `SyncNotesToProgression` assertions with correct chord mode indices.
- [ ] 1.2 Fix `test_note_store.lua`: Update `FindNearestScaleDegree` tie-break expectation.
- [ ] 1.3 Fix `test_note_store.lua`: Implement correct element counting for sparse tables in `GroupNotesByBeat` (avoid `#` on non-contiguous tables).

## Phase 2: Preset Browser Refactor (UI Layer)

- [ ] 2.1 Create `src/ui/preset-browser/io.lua` (ScanDirectory, SavePreset, LoadPreset, RenamePreset, DeletePreset, etc.).
- [ ] 2.2 Create `src/ui/preset-browser/folder.lua` (DrawFolderHeader, DrawFolderList, HandleFolderClick, HandleFolderWheel).
- [ ] 2.3 Create `src/ui/preset-browser/preset-list.lua` (DrawPresetList, DrawActionButtons, DrawFavoriteStar, HandlePresetClick, HandleActionClick, HandlePresetListWheel, LoadFavorites, SaveFavorites).
- [ ] 2.4 Refactor `src/ui/preset-browser.lua` to be a barrel re-exporter using lazy `require`.

## Phase 3: Island Store De-inflation (State Layer)

- [ ] 3.1 Update `src/state/note-store.lua`: Add selection state (Get/SetSelectedIndices, ClearSelection, GetPrimarySelectedIndex, SetSelectedNoteIndex, GetSelectionCount, ToggleNoteSelected) and `notes_state` (Get/SetNotesState, ResetNotesState, GetNotesDirty, SetNotesDirty).
- [ ] 3.2 Update `src/state/island.lua`: Remove all note and selection proxies (GetNotes, SetNotes, GetNoteCount, GetSelectedIndices, SetSelectedIndices, etc.).
- [ ] 3.3 Retarget consumers to `note_store`:
  - `src/ui/midi-island.lua` (notes, selection)
  - `src/ui/preset-browser.lua` (notes, selection, favorites)
  - `src/ui/preset-browser/preset-list.lua` (notes, selection)
  - `src/ui/preset-browser/io.lua` (notes, selection)
  - `src/main.lua` (notes, selection)
  - `src/ui/velocity.lua` (notes, selection)
  - `src/ui/piano-roll/interaction/handlers.lua` (selection, lasso, drag)
  - `src/ui/piano-roll/clipboard.lua` (selection, clipboard)
