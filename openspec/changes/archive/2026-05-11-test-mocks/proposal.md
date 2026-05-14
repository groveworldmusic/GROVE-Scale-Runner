# Proposal: test-mocks

## Intent

Phase 1 proved the test runner + helpers work (179 tests, zero mocks). Now Phase 2 adds mock infrastructure for `reaper.*` and `gfx.*` globals so we can test runtime functions (MIDI, sequencer, keyboard) that depend on REAPER's injected globals.

Both are `_G` globals, NOT require'd modules — so the mock strategy is `_G.reaper = mock_table` before any `require("core.*")` call.

## Scope

### In Scope
- `tests/mock/reaper.lua` — 38 stubs with `make_mock_fn(name)` assertion wrappers
- `tests/mock/gfx.lua` — minimal stubs for 17 methods + 9 state fields
- `tests/run.lua` — install `_G.reaper` and `_G.gfx` BEFORE module loading
- `tests/test_sendmidi.lua` — midi.SendMidi, midi.TriggerChord, midi.AllNotesOff
- `tests/test_sequencer_stop.lua` — sequencer.Stop
- `tests/test_keyboard.lua` — InterceptMappedKeys, Cleanup, HandleKeyboard (basic)
- `tests/AGENTS.md` — mock conventions and initialization requirements

### Out of Scope (Phase 3)
- midi.ExportToMidi — 7+ reaper functions with handle chaining
- midi.ToggleIsland — gfx.quit/gfx.init cycle, complex state transitions
- sequencer.Run — 5 reaper functions, time-dependent branching
- keyboard.CheckFocus — focus timing, window handle comparison

## Capabilities

### New Capabilities
- `reaper-mock`: mock for reaper.* globals with `make_mock_fn(name)` assertion wrappers — call counting + arg recording on each stub
- `gfx-mock`: minimal mock for gfx.* globals — 17 method stubs + 9 mutable state fields (x, y, w, h, mouse_x, mouse_y, mouse_cap, mouse_wheel, hwnd)
- `midi-runtime-tests`: SendMidi, TriggerChord, AllNotesOff — verify StuffMIDIMessage call count + args, active note ref-count, volume scaling
- `sequencer-stop-tests`: sequencer.Stop — verify seq_store field resets, note-offs, IsPlaying=false
- `keyboard-interaction-tests`: InterceptMappedKeys, Cleanup, HandleKeyboard — verify JS_VKeys_Intercept calls, is_intercepting flag management, VKEY byte-string parsing

### Modified Capabilities
- `test-runner`: install `_G.reaper` and `_G.gfx` before module path setup — any require of src/ modules must have globals in place

## Approach

1. **`tests/mock/reaper.lua`** — 38-line table with `make_mock_fn` factory for assertion-wrapped stubs. Key functions (StuffMIDIMessage, JS_VKeys_Intercept) get call counting + arg recording. Others return safe defaults.
2. **`tests/mock/gfx.lua`** — 17 method no-ops + 9 state fields with default values. Mutable so tests can set `gfx.hwnd`, `gfx.mouse_x`, etc.
3. **`tests/run.lua`** — install globals **before** `package.path` extension: `_G.reaper = require("tests.mock.reaper")` then extend path, then require test files.
4. **Test files** — each loads real modules after globals are installed, sets up config.state remnant keys explicitly, runs assertions against mock call records.
5. **`tests/AGENTS.md`** — document mock init order, `config.state` setup, closure reset guidance.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `tests/mock/reaper.lua` | New | 38 stubs with assertion wrappers |
| `tests/mock/gfx.lua` | New | 17 method stubs + 9 state fields |
| `tests/run.lua` | Modified | Install `_G.reaper`/`_G.gfx` before module loading |
| `tests/test_sendmidi.lua` | New | SendMidi, TriggerChord, AllNotesOff |
| `tests/test_sequencer_stop.lua` | New | sequencer.Stop |
| `tests/test_keyboard.lua` | New | InterceptMappedKeys, Cleanup, HandleKeyboard |
| `tests/AGENTS.md` | Modified | Mock conventions, init order, config.state setup |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Module init side effects — require("core.midi") runs code at load time | High | Install globals BEFORE package.path extension in run.lua |
| config.state remnant keys not set — TriggerChord reads root_index/scale_index/chord_mode_index | Med | Document explicit setup in each test; tests set before calling SUT |
| keyboard.is_intercepting closure leaks state between tests | Med | Separate test files per keyboard function; or expose reset via index |
| math.random in HandleKeyboard makes assertions non-deterministic | Low | Test with velocity humanization OFF (GetUseVelocity()=false → fixed 100) |

## Rollback Plan

Revert `tests/run.lua` to its Phase 1 state (no global install). Delete `tests/mock/` directory. Remove new test files. Revert `tests/AGENTS.md` changes.

## Dependencies

- Phase 1 test infrastructure (runner, helpers) — complete
- No external packages — pure Lua stdlib

## Success Criteria

- [ ] `_G.reaper` installed before any `require("core.*")` works without crash
- [ ] `make_mock_fn` records call count and args for asserted functions
- [ ] `midi.SendMidi(60, true, 100)` → mock records `StuffMIDIMessage(1, 0x90, 60, 100)`
- [ ] `midi.TriggerChord(1, true, ctx)` → 3-5 notes sent via SendMidi depending on chord_mode
- [ ] `midi.AllNotesOff()` → CC 123 sent + each held note gets note-off
- [ ] `sequencer.Stop()` → all seq_store fields reset, IsPlaying=false
- [ ] `keyboard.InterceptMappedKeys(true)` → JS_VKeys_Intercept called for each VKEY_MAP entry
- [ ] `keyboard.HandleKeyboard()` with VKEY byte string → TriggerChord called for pressed keys
- [ ] All Phase 2 tests pass: `tests/run.lua` exits 0
