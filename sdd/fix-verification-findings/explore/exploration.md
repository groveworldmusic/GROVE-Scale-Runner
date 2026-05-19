## Exploration: fix-verification-findings

### Current State
The codebase has three specific issues identified during the verification of the `codebase-improvement-bundle` change:
1. **Broken Unit Tests in `tests/test_note_store.lua`**: Tests are failing due to incorrect assertions in `SyncNotesToProgression` (chord mode indices), a conflicting tie-break expectation in `FindNearestScaleDegree`, and incorrect use of the `#` operator on a sparse table in `GroupNotesByBeat`.
2. **`preset-browser.lua` is NOT a barrel**: The module contains a large amount of duplicate logic that should be delegated to its sub-modules (`io.lua`, `folder.lua`, `preset-list.lua`).
3. **`island.lua` proxy de-inflation is incomplete**: The `island_store` still acts as a middleman for many `note_store` and `preset_store` operations, creating redundant code and unnecessary coupling.

### Affected Areas
- `tests/test_note_store.lua` — Needs fixing for correct testing of `note-store`.
- `src/ui/preset-browser.lua` — Needs refactoring into a barrel module.
- `src/ui/preset-browser/io.lua` — Currently contains implementation that should be managed via the barrel.
- `src/ui/preset-browser/folder.lua` — Contains folder navigation rendering.
- `src/ui/preset-browser/preset-list.lua` — Contains preset list rendering.
- `src/state/island.lua` — Needs removal of note/selection proxies.
- **Consumers of `island_store` note/selection proxies**:
  - `src/ui/preset-browser.lua`
  - `src/ui/midi-island.lua`
  - `src/ui/preset-browser/preset-list.lua`
  - `src/ui/preset-browser/io.lua`
  - `src/main.lua`
  - `src/ui/velocity.lua`
  - `src/ui/piano-roll/clipboard.lua`

### Approaches
1. **Fix Unit Tests**
   - Update `tests/test_note_store.lua` to use correct chord mode indices in `SyncNotesToProgression`.
   - Resolve the tie-break conflict for `FindNearestScaleDegree` (choose one expected result).
   - Fix `GroupNotesByBeat` test to correctly count elements in a sparse Lua table (avoid `#`).
   - **Effort**: Low

2. **Refactor Preset Browser into a Barrel**
   - Move all filesystem and preset management logic (`ScanDirectory`, `Init`, `LoadFavorites`, `SaveFavorites`, `ToggleFavorite`, `IsFavorite`, `SavePreset`, `LoadPreset`, `RenamePreset`, `DeletePreset`) to `ui.preset-browser.io`.
   - Move folder navigation rendering (`DrawFolderHeader`, `DrawFolderList`) to `ui.preset-browser.folder`.
   - Move preset list rendering (`DrawPresetList`, `DrawActionButtons`) to `ui.preset-browser.preset-list`.
   - Refactor `src/ui/preset-browser.lua` to be a thin barrel module that re-exports these functions.
   - **Effort**: Medium

3. **De-inflate Island Store**
   - Remove note and selection proxies (`GetNotes`, `SetNotes`, `GetNotesState`, `SetNotesState`, `ResetNotesState`, `ClearSelection`, `GetSelectedIndices`, `SetSelectedIndices`, `IsNoteSelected`, `GetSelectionCount`, `GetPrimarySelectedIndex`, `GetSelectedNoteIndex`, `SetSelectedNoteIndex`, `AddNote`, `RemoveNoteAtIndex`) from `src/state/island.lua`.
   - Retarget all identified consumers to use `note_store` or `preset_store` directly.
   - Ensure any side effects (like `island_store.ClearSelection()` when `SetNotes()` is called) are preserved in the retargeting process.
   - **Effort**: Medium/High

### Recommendation
Execute the fixes in the following order to maintain stability:
1. **Fix Unit Tests**: Ensures we have a reliable baseline for `note-store`.
2. **Refactor Preset Browser**: Cleans up the UI layer.
3. **De-inflate Island Store**: Cleans up the state layer once the UI is stabilized.

### Risks
- **Side Effects**: Removing proxies from `island.lua` might miss subtle side effects (e.g., selection management during note replacement) if not carefully retargeted.
- **Consumer Breakage**: Retargeting many files requires high precision to avoid breaking the UI or state synchronization.

### Ready for Proposal
Yes
