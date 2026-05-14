# Proposal: test-mocks-phase3

## Intent

Complete test coverage for 4 remaining runtime functions that were deferred from Phases 1+2. All 4 have proven mock strategies from exploration — no mock infra changes needed.

## Scope

### In Scope
- `keyboard.CheckFocus()` — 5 scenarios (throttle, focus gain, focus loss, no-op, throttle boundary)
- `midi.ToggleIsland()` — 4 scenarios (docked early-return, expand, collapse, hwnd rect capture)
- `midi.ExportToMidi()` — 4 scenarios (empty progression, single slot, multiple slots, no-track branch)
- `sequencer.Run()` — 4 core paths (not playing, REAPER sync + empty progression, REAPER sync + measure advance, internal clock first tick)

### Out of Scope
- `sequencer.Run()` edge cases: catch-up loop, auto-pagination, internal clock precision boundaries — deferred
- `midi.AllRandomVelocity()` (if function exists)
- Mock infra changes — existing stubs + test-level overrides are sufficient

## Capabilities

### New Capabilities
- `check-focus-tests`: Focus detection with 0.2s throttle, gfx.hwnd vs plugin focus, intercept lifecycle
- `toggle-island-tests`: GFX window lifecycle toggle, dock guard, hwnd rect capture
- `export-midi-tests`: MIDI file export chain — progression scan, track selection, note insertion
- `sequencer-run-tests`: Transport-synced sequencer tick — play state, measure advance, progression boundaries

### Modified Capabilities
None — no existing specs change.

## Approach

1. **CheckFocus (LOW)**: Reuse existing keyboard module isolation (`package.loaded` clear). Override `reaper.time_precise` to control throttle. Override `gfx.hwnd`, `JS_Window_GetFocus`, `GetFocusedFX2` for focus states. Direct assertions on `InterceptMappedKeys` calls and `is_intercepting` guard.
2. **ToggleIsland (MEDIUM)**: Override `gfx.init`/`gfx.quit` with tracking flags to verify call count + args. Init `compact_store` with `last_gfx_state` table. Test both `gfx.hwnd` nil and truthy paths.
3. **ExportToMidi (MEDIUM)**: Override 8+ reaper stubs with truthy return values (1 for handles, functions for numeric conversions). Populate `sequencer_store` progression with 1-3 slots. Two-phase: empty progression (early return) then populated progression (verify MIDI_InsertNote chain).
4. **sequencer.Run (MEDIUM)**: Override `GetPlayState` (0/1), `GetPlayPosition2` + `TimeMap2_timeToBeats` for REAPER sync. Sequential `time_precise` closure for internal clock. Fixed `Master_GetTempo` (120 BPM). Clear/populate progression for empty vs active paths.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `tests/run.lua` | Modified | Add 4 test files to `test_names` |
| `tests/test_checkfocus.lua` | New | ~50 LOC, 5 scenarios |
| `tests/test_toggleisland.lua` | New | ~70 LOC, 4 scenarios |
| `tests/test_exportmidi.lua` | New | ~80 LOC, 4 scenarios |
| `tests/test_sequencer_run.lua` | New | ~100 LOC, 4 scenarios |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| sequencer.Run time dependency | Low | Override controls inputs; internal clock needs sequential `time_precise` closure |
| ExportToMidi stub chain failure | Medium | Two-phase test: empty progression first (no stub chain), populated second |
| ToggleIsland gfx mock tracking | Low | Override pattern with local flags — proven approach, no gfx.lua changes |

## Rollback Plan

Revert the 4 test files and the `run.lua` diff in a single commit. Zero production code changed — no rollback risk.

## Dependencies

- Mock infra from Phases 1+2 (reaper.lua w/ 50+ stubs, gfx.lua w/ 17 methods + 9 fields) — already stable
- `package.loaded["core.keyboard"] = nil` pattern for CheckFocus module isolation

## Success Criteria

- [ ] All 4 test files pass when run via `tests/run.lua`
- [ ] CheckFocus: throttle, focus gain, focus loss, and no-op paths verified
- [ ] ToggleIsland: both expand and collapse `gfx.init` args verified
- [ ] ExportToMidi: empty progression early return + single/multi-slot insertion verified
- [ ] sequencer.Run: all 4 core paths pass without mocking infra changes
- [ ] Total: ~300 new test scenarios across 4 files
