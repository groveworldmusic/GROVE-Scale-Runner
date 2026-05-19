# Tasks: Architecture Debt Sweep

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,289 (24 + 961 + 304) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 (P1) → PR 2 (P2) → PR 3 (P3) |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | View offset persistence (P1) | PR 1 | Base = feature/tracker branch. ~24 LOC, trivial |
| 2 | Preset browser barrel (P2) | PR 2 | Base = PR 1 branch. ~961 LOC gross (881 deletions), highest risk |
| 3 | UI tests (P3) | PR 3 | Base = PR 2 branch. ~304 LOC across 5 files |

---

## Phase 1: View Offset Persistence (P1)

- [x] 1.1 Add `last_saved_vx`/`last_saved_vy` sentinel fields + 4 getter/setter pairs (`Get/SetLastSavedX/Y`) to `src/state/ui.lua` — +12 LOC
- [x] 1.2 Add save trigger block in `src/main.lua` after line 367, mirroring `window_w/h` dirty-flag pattern: read current position, compare vs sentinel, call `persist.Save()` on change, update sentinel — +12 LOC

## Phase 2: Preset Browser Barrel Refactor (P2)

- [ ] 2.1 Rewrite `src/ui/preset-browser.lua` from 881 LOC monolith to ~80 LOC barrel: require 4 submodules (`io`, `folder`, `preset-list`, `main`), re-export 22 functions, omit `ToggleFavorite`/`DrawActionButtons` (zero external callers). Run `barrel-backward-compat.lua` after to verify API surface.

## Phase 3: UI Tests (P3)

- [ ] 3.1 Create `tests/test_piano_roll_grid.lua` — ~80 LOC, ~40 check() for `ComputeVisibleRanges` and scroll/zoom clamps in `piano-roll/grid.lua`
- [ ] 3.2 Create `tests/test_note_store.lua` — ~70 LOC, ~35 check() for `ProgressionToNotes`, `GroupNotesByBeat`, `DetectChordMode`, `GetVisibleNotes` in `piano-roll/note.lua`
- [ ] 3.3 Create `tests/test_preset_browser_io.lua` — ~70 LOC, ~35 check() for `IsValidPresetFile`, `GetPresetFilePath`, `HasLFS`, `IsFavorite` in `preset-browser/io.lua`
- [ ] 3.4 Create `tests/test_piano_roll_drag.lua` — ~80 LOC, ~45 check() for `IsNoteRightEdge`, `IsNoteLeftEdge` in `piano-roll/drag.lua`
- [ ] 3.5 Add 4 new filenames to `test_names` array in `tests/run.lua` — +4 LOC
