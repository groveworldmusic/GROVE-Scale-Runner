# Tasks: test-mocks

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~450-550 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | exception-ok |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Medium

## Phase 1: Foundation — Mock Modules

- [x] 1.1 Create `tests/mock/reaper.lua` with `make_mock_fn(name)` factory; 50+ stubs (StuffMIDIMessage, JS_VKeys_Intercept, GetPlayState, etc.); export `reset_all_calls()` + `get_mock(name)` + `get_mock_call(name, n)`
- [x] 1.2 Create `tests/mock/gfx.lua` with 17 no-op methods (getchar→0, dock→0, etc.) + 9 mutable state fields (x, y, w, h, mouse_x, mouse_y, mouse_cap, mouse_wheel, hwnd)

## Phase 2: Runner Update

- [x] 2.1 Modify `tests/run.lua` — require and assign `_G.reaper`/`_G.gfx` AFTER `package.path` setup (path required to load mock modules); call `reaper.reset_all_calls()` between test files; add 5 new test files to discovery list
- [x] 2.2 Modify `tests/AGENTS.md` — document mock init order, config.state setup requirements, closure reset guidance for keyboard tests, get_mock() API

## Phase 3: MIDI Runtime Tests

- [x] 3.1 Create `tests/test_sendmidi.lua` — SendMidi note-on/off via StuffMIDIMessage args; ref-counted active notes (duplicate triggers); volume passthrough; TriggerChord Tri/7ma/9na/Off modes; AllNotesOff (CC123 + held notes + state reset)

## Phase 4: Sequencer Tests

- [x] 4.1 Create `tests/test_sequencer_stop.lua` — sequencer.Stop sets IsPlaying=false, sends note-off for each MidiNotes entry, resets state fields

## Phase 5: Keyboard Tests

- [x] 5.1 Create `tests/test_keyboard_intercept.lua` — InterceptMappedKeys(true/false); verify JS_VKeys_Intercept called exactly 28 times per invocation
- [x] 5.2 Create `tests/test_keyboard_cleanup.lua` — Cleanup with/without intercept flag active; double-call behavior (code does NOT reset is_intercepting)
- [x] 5.3 Create `tests/test_keyboard_handle.lua` — key-down byte → TriggerChord dispatch; key-up → SendMidi note-off; unmapped keys ignored; deterministic velocity (midi_store.SetUseVelocity(false)); multi-key simultaneous press

## Phase 6: Verify

- [x] 6.1 Run all tests via `lua tests/run.lua` — **285 assertions, ALL PASSED, exit code 0**
