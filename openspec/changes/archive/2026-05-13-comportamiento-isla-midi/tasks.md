# Tasks: Comportamiento Isla MIDI — Bug Fixes

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 150–250 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: State layer — `src/state/island.lua`

- [x] 1.1 Declare `local MAX_UNDO = 50` before `PushUndo()` definition
- [x] 1.2 Add `undo_stack={}`, `redo_stack={}`, `undo_depth=0`, `redo_depth=0` to `island_state` init table
- [x] 1.3 Add `local _uuid_to_idx = {}` after `local m = {}`, remove any orphan global ref
- [x] 1.4 Add `folder_scroll = 0` to `island_state`; add `GetFolderScroll()` / `SetFolderScroll(v)` getter/setter

## Phase 2: Preset browser — `src/ui/preset-browser.lua`

- [x] 2.1 In `LoadPreset()` loop: assign `n.uuid = island_store.AllocNoteUUID()` per note before building the table
- [x] 2.2 After `SetNotes(valid_notes)` in `LoadPreset()`, call `island_store.ClearUndoStacks()`
- [x] 2.3 In `DrawPresetBrowser()` folder list call: pass `island_store.GetFolderScroll()` as scroll offset; store result via `island_store.SetFolderScroll()`

## Phase 3: Interaction — `views.lua` + `piano-roll/`

- [x] 3.1 In `views.lua` `HandleMouseClick` call: add `(gfx.mouse_cap & 32) ~= 0` as 8th arg (`shift_held`)
- [x] 3.2 In `grid.lua` `ComputeVisibleRanges`: add `m.PITCH_ROW_H` to cache key comparison and assignment
- [x] 3.3 In `interaction.lua` `HandlePencilClick`: when `snap_res <= 0`, set `snapped_beat = beat` (no fallback)
- [x] 3.4 In `note.lua` `GetNotesInRect`: clamp `pitch_high = math.min(MAX_PITCH, ...)`

## Phase 4: Visual — `view.lua` + `views.lua` + `midi.lua`

- [x] 4.1 In `view.lua` vertical scrollbar: change `sb_y = y + ratio * h` to `sb_y = y + ratio * (h - sb_h)`
- [x] 4.2 In `views.lua` horizontal scrollbar: compute `track_w = sb_w - bar_w`; change ratio to use `track_w` instead of `sb_w`
- [x] 4.3 In `midi.lua`: replace hardcoded `793`/`497` with `local EXPANDED_H` / `local COLLAPSED_H` constants

## Phase 5: Cleanup

- [x] 5.1 In `velocity.lua`: remove unreferenced `local base_initial_vel` line
