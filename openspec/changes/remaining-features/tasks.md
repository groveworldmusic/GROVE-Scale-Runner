# Tasks: remaining-features

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,388 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | Phase A → Phase B → Phase C → Phase D → Phase E |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Phase A: Progression dispatch hooks (~37 LOC) | PR 1 | base=main; wires undo into existing store |
| 2 | Phase B: Progression-only presets (~167 LOC) | PR 2 | base=main; dual-ext, filter tabs, SaveProgressionPreset |
| 3 | Phase C: Vkey-map configurables (~400 LOC) | PR 3 | base=main; new module, remap overlay, gear button |
| 4 | Phase D: MIDI input recording (~480 LOC) | PR 4 | base=main; new core module, record UI, wiring |
| 5 | Phase E: UI tests (~304 LOC) | PR 5 | base=main; 3 new test files + runner registration |

## Phase 1: Progression Dispatch Hooks (A)

- [x] 1.1 Wrap `progression.Swap()` in undo gate + manual snapshot in `src/core/progression.lua`
- [x] 1.2 Compute `progression_focused` flag in `src/ui/midi-island.lua`, pass to `input.HandleKeyboard()`
- [x] 1.3 Add Ctrl+Z/Y dispatch before piano-roll shortcuts in `src/ui/midi-island/input.lua`
- [x] 1.4 Add `ProgPushUndo()` at top of `SyncNotesToProgression()` in `src/state/note-store.lua`

## Phase 2: Progression-Only Presets (B)

- [x] 2.1 Add dual-ext scanning `.grove`/`.grove-prog`, `SaveProgressionPreset()`, and `type`-based LoadPreset branching in `src/ui/preset-browser/io.lua`
- [x] 2.2 Add Notes/Progression/All filter tabs + "Save Progression" button in `src/ui/preset-browser/main.lua`
- [x] 2.3 Add `type_filter` param and type badge rendering in `src/ui/preset-browser/preset-list.lua`
- [x] 2.4 Re-export `SaveProgressionPreset` in `src/ui/preset-browser.lua`

## Phase 3: Vkey-Map Configurables (C)

- [x] 3.1 Create `src/core/vkey-map.lua` with `GetVkeyMap()`, `SetEntry()`, `ResetToDefaults()`, `Serialize()`, `Deserialize()`, `IsModified()`
- [x] 3.2 Add `vkey_map_raw` + `vkey_map_modified` keys to `src/state/preferences.lua`, `src/state/persist.lua`, `src/config.lua`
- [x] 3.3 Replace `config.VKEY_MAP` with `vkey_map.GetVkeyMap()` in `src/core/keyboard.lua` + `src/ui/pads.lua`
- [x] 3.4 Create `src/ui/midi-island/remap.lua` — 4×7 grid overlay, cell click handler, degree/octave dropdown, conflict detection
- [x] 3.5 Add gear button between TOOLS and PRESETS in `src/ui/midi-island/header.lua`

## Phase 4: MIDI Input Recording (D)

- [ ] 4.1 Create `src/core/midi-input.lua` with `Poll()`, `SetArmed()`, `IsArmed()`, `Cleanup()`, `_open_notes` tracking, 5s auto-close timeout
- [ ] 4.2 Add `UpdateOpenNoteDuration(pitch, duration)` to `src/state/note-store.lua`
- [ ] 4.3 Add record-arm toggle button (red circle, glow when armed) in `src/ui/midi-island/header.lua`
- [ ] 4.4 Wire midi-input in `src/main.lua` — require in Init, `Poll()` after HandleKeyboard in MainLoop, `Cleanup()` in CleanupAll

## Phase 5: UI Tests (E)

- [ ] 5.1 Create `tests/test_piano_roll_grid.lua` — ~40 check() for SnapBeat pure functions, all resolutions, triplets, edges
- [ ] 5.2 Create `tests/test_preset_browser_io.lua` — ~35 check() for I/O with mock filesystem, save/load progression presets
- [ ] 5.3 Create `tests/test_piano_roll_drag.lua` — ~45 check() for edge detection (8px threshold), drag under/over threshold
- [ ] 5.4 Register new test files in `tests/run.lua` `test_names` array
