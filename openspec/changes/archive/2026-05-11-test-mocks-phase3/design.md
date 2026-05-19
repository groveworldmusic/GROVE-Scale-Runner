# Design: test-mocks-phase3

## Technical Approach

Phase 3 adds 4 test files exercising deferred runtime functions (`keyboard.CheckFocus`, `midi.ToggleIsland`, `midi.ExportToMidi`, `sequencer.Run`) using the proven mock infra (reaper.lua with 50+ stubs, gfx.lua with 17 no-ops). No mock module changes needed — all new behavior is controlled via per-test overrides of global stubs.

## Architecture Decisions

### Decision 1: Per-test stub override over gfx.lua tracking

| Option | Tradeoff |
|--------|----------|
| Add tracking to gfx.lua stubs | Modifies stable mock module, couples tracking to architecture |
| Override + flag per test | Local, self-contained, zero impact on other tests |

**Decision**: Override gfx.init/quit/setfont with local tracking closures per test file. gfx.lua stays untouched. Proven in existing keyboard tests.

### Decision 2: Two-phase ExportToMidi test setup

Test empty progression first (early return at line 104 — no stub chain needed). Then populate progression with 1-3 slots and override all 12 reaper stubs with simple truthy/callback returns. Isolates stub-chain debugging from logic errors.

### Decision 3: Sequential time_precise closure for sequencer.Run

Internal clock path calls `time_precise()` once per tick. A closure incrementing a counter on each call provides deterministic deltas without real time:

```lua
local t = 1000
reaper.time_precise = function() t = t + 10; return t end
```

### Decision 4: CheckFocus throttle via time_precise stepping

Single bypass: return fixed `10`. Throttle boundary test: step through `10.0 → 10.1 → 10.3` to verify 0.2s gate behavior. Module-level `last_focus_check = 0` requires `package.loaded["core.keyboard"] = nil` per file.

## Data Flow

```
keyboard.CheckFocus():
  time_precise → throttle gate → IsPluginOrScriptFocused()
    → gfx.hwnd / JS_Window_GetFocus / GetFocusedFX2
    → InterceptMappedKeys | AllNotesOff

midi.ToggleIsland():
  GetDockedMode → gfx.dock → GetLastGfxState → gfx.hwnd
    → JS_Window_GetRect → gfx.quit → gfx.init → gfx.setfont

midi.ExportToMidi():
  GetSelectedTrack → GetCursorPosition → TimeMap_timeToQN
    → GetProgressionEntry ×16 → CreateNewMIDIItemInProj
    → GetActiveTake → MIDI_GetPPQPosFromProjQN ×2
    → MIDI_InsertNote ×N → MIDI_Sort → UpdateArrange

sequencer.Run():
  GetIsPlaying → GetPlayState → TimeMap2_timeToBeats | time_precise
    → GetLastMeasure → GetLastFilled → TriggerChord → SendMidi
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `tests/test_keyboard_focus.lua` | Create | ~40 LOC, 5 CheckFocus scenarios: throttle skip, throttle pass, focus gain, focus loss, no-op |
| `tests/test_toggle_island.lua` | Create | ~60 LOC, 4 ToggleIsland scenarios: docked early-return, expand (793h), collapse (497h), hwnd rect capture |
| `tests/test_export_midi.lua` | Create | ~80 LOC, 4 ExportToMidi scenarios: empty early return, single slot, multiple slots, no-track branch |
| `tests/test_sequencer_run.lua` | Create | ~100 LOC, 4 Run scenarios: not-playing, REAPER sync + empty progression, REAPER sync + measure advance, internal clock |
| `tests/run.lua` | Modify | Add 4 test file names to `test_names` array |

## Interfaces / Contracts

### Override patterns (no new interfaces — all per-test closures)

**ToggleIsland** — gfx init tracking:
```lua
local gfx_init_calls = {}
local orig_init = _G.gfx.init
_G.gfx.init = function(title, w, h, dock, x, y)
    table.insert(gfx_init_calls, {title=title, w=w, h=h, dock=dock, x=x, y=y})
end
```

**ExportToMidi** — stub orchestration:
```lua
reaper.GetSelectedTrack = function() return 1 end       -- track exists
reaper.GetCursorPosition = function() return 10.0 end
reaper.TimeMap_timeToQN = function() return 10.0 end
reaper.CreateNewMIDIItemInProj = function() return 1 end
reaper.GetActiveTake = function() return 1 end
reaper.MIDI_GetPPQPosFromProjQN = function(_, _, qn) return qn * 480 end
```

**CheckFocus throttle boundary:**
```lua
reaper.time_precise = function() return 10.0 end       -- first call: passes
reaper.time_precise = function() return 10.1 end       -- second: 0.1s delta → skip
reaper.time_precise = function() return 10.3 end       -- third: 0.3s delta → passes
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | CheckFocus throttle gate | Override time_precise with sequential values, assert InterceptMappedKeys call count |
| Unit | CheckFocus focus logic | Override gfx.hwnd, JS_Window_GetFocus, GetFocusedFX2; verify intercept + AllNotesOff |
| Unit | ToggleIsland gfx lifecycle | Override gfx.init/quit with trackers; assert call order + args (width, height, dock) |
| Unit | ToggleIsland dock guard | Set GetDockedMode=true; assert no gfx.init/quit calls |
| Integration | ExportToMidi stub chain | Override 12 reaper stubs, populate progression; assert MIDI_InsertNote calls + args |
| Integration | sequencer.Run paths | Override GetPlayState + time_precise + TimeMap2; clear/populate progression; assert state mutations |
| Integration | Empty progression paths | Assert early return (ExportToMidi line 104) and Stop() call (sequencer.Run line 79) |

## Migration / Rollout

No migration required — tests only, zero production code changes. New tests registered via `tests/run.lua` `test_names` array.

## Open Questions

- None.

