# Tasks: test-mocks-phase3

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~280-340 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Delivery strategy | exception-ok |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Medium

## Phase 1: Focus tests

- [ ] 1.1 Create `tests/test_keyboard_focus.lua` — throttle gate (skip at 0.1s delta, pass at 0.25s)
- [ ] 1.2 Add focus gain scenario: override `gfx.hwnd` match, assert `InterceptMappedKeys(true)`
- [ ] 1.3 Add focus loss scenario: override `gfx.hwnd` mismatch, assert `InterceptMappedKeys(false)` + `AllNotesOff()`
- [ ] 1.4 Add stable-state no-ops: already intercepting+focused, already not intercepting+unfocused

## Phase 2: ToggleIsland tests

- [ ] 2.1 Create `tests/test_toggle_island.lua` — docked early return: set `GetDockedMode=true`, assert no gfx calls
- [ ] 2.2 Add expand scenario: collapsed→expanded with height 793, track gfx.quit→gfx.init→gfx.setfont order
- [ ] 2.3 Add collapse scenario: expanded→collapsed with height 497, verify same call order
- [ ] 2.4 Track gfx lifecycle via local override closures (init/quit/setfont), assert call count and args

## Phase 3: ExportToMidi tests

- [ ] 3.1 Create `tests/test_export_midi.lua` — empty progression: `GetLastFilled=0`, assert no MIDI_InsertNote
- [ ] 3.2 Single slot scenario: populate 1 slot with 3 chord notes, stub 12 reaper APIs, assert 3 MIDI_InsertNote calls
- [ ] 3.3 Multi-slot scenario: 2 slots × 3 notes each, assert 6 MIDI_InsertNote calls with correct pitch/velocity/start
- [ ] 3.4 No-track branch: `GetSelectedTrack=nil`, assert `InsertTrackAtIndex` called
- [ ] 3.5 Finalization: assert `MIDI_Sort` + `UpdateArrange` called once after all inserts

## Phase 4: Sequencer.Run tests

- [ ] 4.1 Create `tests/test_sequencer_run.lua` — not-playing: `IsPlaying=false`, assert Progress=0, no MIDI calls
- [ ] 4.2 Measure advance: `IsPlaying=true`, advance measure, assert CurrentStep++ and TriggerChord called
- [ ] 4.3 Same measure noop: same measure value, assert no step advance and no TriggerChord
- [ ] 4.4 Empty progression: playing + no slots, assert `Stop()` called

## Phase 5: Runner update + verify

- [ ] 5.1 Modify `tests/run.lua` — add 4 new test files to `test_names` array
- [ ] 5.2 Run all tests and confirm pass
