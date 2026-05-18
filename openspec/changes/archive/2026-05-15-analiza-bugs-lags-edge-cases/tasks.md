# Tasks: Codebase Bug, Lag & Edge-Case Fix

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~400 total (5 phases, <120 each) |
| 400-line budget risk | Low |
| Chained PRs recommended | Yes |
| Suggested split | 5 chained PRs (1 per phase) |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Branch | Base |
|------|------|--------|------|
| 1 | HIGH perf + MEDIUM bug | fix/perf-notes-phase1 | feature/buglag-tracker |
| 2 | MEDIUM remaining | fix/perf-notes-phase2 | fix/perf-notes-phase1 |
| 3 | LOW items | fix/perf-notes-phase3 | fix/perf-notes-phase2 |
| 4 | Known issues #6 & #9 | fix/perf-notes-phase4 | fix/perf-notes-phase3 |
| 5 | config.state migration | fix/perf-notes-phase5 | fix/perf-notes-phase4 |
| Final | Merge tracker | feature/buglag-tracker | main |

## Phase 1 — HIGH perf + MEDIUM bug (~80 lines)

- [x] 1.1 `src/core/keyboard.lua` — hoist `JS_VKeys_GetState(0)` call outside the `for k_code, state in pairs()` loop; assign to `local vk_state` before loop
- [x] 1.2 `src/core/slots.lua` — add `slot_click_noteoff_counter` module field; increment on click-play in `HandleSlotInteraction`; decrement in `DrawProgressionSlot` and fire note-off at counter == 1

## Phase 2 — MEDIUM remaining (~60 lines)

- [x] 2.1 `src/ui/pads.lua` — add `active_degrees_cache` module field + `ComputeActiveDegrees()`; replace O(7·28) inner loop with O(1) degree lookup
- [x] 2.2 `src/core/keyboard.lua` — replace literal `0` in `JS_VKeys_GetState(0)` with module-level `key_state_buffer` variable
- [x] 2.3 `src/state/preferences.lua` — add `save_pending` + `TickSaveDebounce()`; debounce `persist.Save` to once per frame

## Phase 3 — LOW items (~100 lines)

- [ ] 3.1 `src/state/midi.lua` — add `active_notes_revision` field; add `GetActiveNotesRevision()` getter; increment in `SetActiveNote()`
- [ ] 3.2 `src/ui/piano.lua` — add `cached_active_mod12` + `cached_active_revision`; rebuild cache only when revision diverges
- [ ] 3.3 `src/ui/dropdown.lua` — hoist `GetFitText()` closure to module level; remove inner function definition
- [ ] 3.4 `src/core/midi.lua` — pre-allocate `chord_note_buffer` for reuse; make `midi_channel` configurable via ExtState
- [ ] 3.5 `src/core/slots.lua` — add `cached_sub_idx` + `cached_sub_revision`; cache subdivision index reads per frame
- [ ] 3.6 `src/ui/layout.lua` — add `IsScaleValid()` guard returning `_S > 0`
- [ ] 3.7 `src/core/api-guard.lua` — remove `reaper.ShowConsoleMsg` from `ClampIndex`; keep clamping behavior

## Phase 4 — Known issues #6 & #9 (~40 lines)

- [ ] 4.1 `src/ui/views.lua` — fix #6: render properly sized/colored left-pointing triangle for undock button; verify in all dock modes
- [ ] 4.2 `src/ui/views.lua` — fix #9: correct octave dropdown `open_up` parameter to `false` (octave island is in top half)

## Phase 5 — config.state migration (~120 lines)

- [ ] 5.1 Source-wide: replace all `config.state.view_offset_x/y`, `use_scroll`, `root_index`, `scale_index`, `octave`, `chord_mode_index` references (~28 occurrences) with corresponding `preferences_store.Get*()` calls
- [ ] 5.2 `src/config.lua` — remove migrated keys from `config.state` block; keep constants (SCALES, CHORD_MODES, VKEY_MAP, NOTE_NAMES)
- [ ] 5.3 Verify: launch REAPER, confirm all preferences load correctly, no `nil` field errors from stale refs
