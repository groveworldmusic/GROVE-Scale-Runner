# tests/ — Infraestructura de Testing

## File Inventory

| File | Action | LOC | Description |
|------|--------|-----|-------------|
| `tests/run.lua` | Runner | 75 | Derives paths, installs mock globals, extends package.path, discovers/executes test files, prints summary |
| `tests/helpers.lua` | Shared | 32 | `check()`, `assert_eq()`, `summary()` — pass/fail counters across dofile calls |
| `tests/mock/reaper.lua` | Mock | 191 | 50+ `reaper.*` stubs via `make_mock_fn()` factory; `reset_all_calls()` + `get_mock_call()` helpers |
| `tests/mock/gfx.lua` | Mock | 33 | 17 no-op methods + 9 mutable state fields (w=720, h=500, mouse_*=0, hwnd=nil) |
| `tests/test_midi.lua` | Test | 77 | `midi.GetMidiNote` pure function: basic, all scales, wraparound, boundaries, edge cases, exhaustive range |
| `tests/test_stores.lua` | Test | 304 | All 9 state stores: Init, getter/setter round-trips, consumables, edge cases |
| `tests/test_progression.lua` | Test | 67 | `progression.*`: Add, Remove, Swap, Clear, GetLastFilled |
| `tests/test_sendmidi.lua` | Test | 171 | `midi.SendMidi`, `midi.TriggerChord`, `midi.AllNotesOff` via mock reaper |
| `tests/test_sequencer_stop.lua` | Test | 68 | `sequencer.Stop`: state reset + note-offs |
| `tests/test_keyboard_intercept.lua` | Test | 33 | `keyboard.InterceptMappedKeys(true/false)`: 28 calls per invocation |
| `tests/test_keyboard_cleanup.lua` | Test | 34 | `keyboard.Cleanup`: with/without intercept flag, double call behavior |
| `tests/test_keyboard_handle.lua` | Test | 89 | `keyboard.HandleKeyboard`: key-down/up dispatch, multi-key, unmapped keys |
| `tests/test_keyboard_focus.lua` | Test | 97 | `keyboard.CheckFocus`: throttle, focus gain (intercept), focus loss (release + AllNotesOff), stable-state no-op |
| `tests/test_toggle_island.lua` | Test | 77 | `midi.ToggleIsland`: docked early return, expand (720×793), collapse (720×497) |
| `tests/test_export_midi.lua` | Test | 104 | `midi.ExportToMidi`: empty progression, single slot (Tri), multiple slots, no-track branch |
| `tests/test_sequencer_run.lua` | Test | 98 | `sequencer.Run`: not playing, measure advance, same measure (no-op), empty progression → Stop |
| `tests/snap-tests.lua` | Test | 286 | `snap.SnapBeat` pure function: all resolutions, triplets, edge cases, boundaries — 89 check() calls |
| `tests/undo-tests.lua` | Test | 345 | `piano-roll-store` undo/redo: push, pop, clear, max depth 50, mixed operations — 94 check() calls |
| `tests/barrel-backward-compat.lua` | Test (static) | 21 | Barrel backward-compatibility: verifies `components.DrawPianoKeyboard` etc. are accessible — 0 check() calls, NOT in runner |

## Coverage

| Module | Functions | Tested? | Depends on reaper.*? |
|--------|-----------|---------|---------------------|
| `core/midi.lua` | GetMidiNote, SendMidi, TriggerChord, AllNotesOff | ✅ | Yes |
| `core/midi.lua` | ExportToMidi, ToggleIsland, GetMidiChannel, SetMidiChannel | ✅ | Yes (mock reaper+gfx) |
| `core/keyboard.lua` | InterceptMappedKeys, Cleanup, HandleKeyboard, CheckFocus | ✅ | Yes |
| `core/sequencer.lua` | Stop, Run | ✅ | Yes (mock reaper + time_precise) |
| `core/progression.lua` | Add, Remove, Swap, Clear, GetLastFilled | ✅ | No |
| `core/snap.lua` | SnapBeat | ✅ (snap-tests.lua) | No (pure function) |
| `state/*.lua` | All 9 stores: getters, setters, Init, consumables | ✅ | No |
| `state/piano-roll-store.lua` | Undo/redo, note CRUD | ✅ (undo-tests.lua) | No |

## Mock Infrastructure

### Mock Installation Order (in run.lua)

```
1. Derive paths (debug.getinfo)
2. Extend package.path (root_dir/src/?.lua; root_dir/?.lua)
3. _G.reaper = require("tests.mock.reaper")
4. _G.gfx = require("tests.mock.gfx")
5. require("tests.helpers")
6. Discover test files
7. For each file: reaper.reset_all_calls(); dofile(file)
8. helpers.summary()
```

This order ensures `_G.reaper` and `_G.gfx` exist BEFORE any `require("core.*")` call inside test files.

### make_mock_fn Pattern

Mock call data is stored internally in `_mock_storage` (keyed by function name) rather than attached to function objects, because Lua 5.4 does not support setting arbitrary properties on function values.

```lua
local _mock_storage = {}

local function make_mock_fn(name)
    local track = { call_count = 0, calls = {} }
    _mock_storage[name] = track
    local fn = function(...)
        track.call_count = track.call_count + 1
        track.calls[track.call_count] = {...}
    end
    return fn
end
```

Access mock data via `reaper.get_mock(name)`:

```lua
reaper.get_mock("StuffMIDIMessage").call_count  -- number of calls
reaper.get_mock("StuffMIDIMessage").calls[1]     -- args of first call
```

### Tracked Functions (tests assert on these)

- `reaper.StuffMIDIMessage` — primary assertion target for MIDI calls
- `reaper.JS_VKeys_Intercept` — primary assertion target for keyboard intercept
- `reaper.JS_VKeys_GetState` — returns 256-byte string via `reaper._vkey_string` (tests set specific bytes)
- `reaper.time_precise` — returns 0 by default; tests override to bypass CheckFocus throttle
- `reaper.GetPlayState` — returns 0 by default (stopped)
- `reaper.GetFocusedFX2` — returns 0 by default (no FX focused)

All 50+ other stubs use plain `make_mock_fn` (tracked, return nil).

### JS_VKeys_GetState: Dynamic Byte String

`reaper._vkey_string` is a mutable field (256 null bytes by default). Tests set specific bytes to control which keys HandleKeyboard sees as pressed:

```lua
-- Set key 0x31 ('1') as pressed
local vks = string.rep("\0", 256)
vks = vks:sub(1, 0x30) .. "\x01" .. vks:sub(0x32)
reaper._vkey_string = vks
```

### Helper Functions

- `reaper.reset_all_calls()` — zeroes `call_count` and empties `calls{}` on every tracked function
- `reaper.get_mock(name)` — returns `{call_count, calls}` for a named function
- `reaper.get_mock_call(name, n)` — returns the nth call's args table for a named mock function

## Test Patterns

### Standard Setup for Runtime Tests

```lua
local config = require("config")
local midi = require("core.midi")
local midi_store = require("state.midi")
local sequencer_store = require("state.sequencer")

-- Init stores with populated key_states from config
midi_store.Init({
    use_velocity = false,
    key_states = config.state.key_states,
    active_notes = {},
    mouse_pad_state = { active_degree = -1, midi_notes = {} },
})

-- Config.state remnant keys (for TriggerChord)
config.state.root_index = 1       -- C
config.state.scale_index = 1      -- Major
config.state.octave = 4
config.state.chord_mode_index = 2 -- Tri

-- Deterministic velocity
midi_store.SetUseVelocity(false)

-- Reset mock counters
reaper.reset_all_calls()

-- Exercise SUT
midi.TriggerChord(1, true)

-- Assert
check(reaper.get_mock("StuffMIDIMessage").call_count == 3, "Triad: 3 notes")
local call = reaper.get_mock("StuffMIDIMessage").calls[1]
check(call[2] == 0x90, "Note-on message byte")
```

### Keyboard Test Isolation

`keyboard.lua` has a module-level `local is_intercepting = false` closure (line 9). Since `require()` caches modules, each keyboard test file MUST clear the cache before loading:

```lua
package.loaded["core.keyboard"] = nil
local keyboard = require("core.keyboard")
```

This ensures a fresh `is_intercepting = false` per file. Files are executed via `dofile()` in `run.lua`, so the cache clear happens in each file's scope.

### Activating Intercept in Tests

HandleKeyboard and Cleanup tests need `is_intercepting = true`. Use CheckFocus:

```lua
gfx.hwnd = 12345
reaper.JS_Window_GetFocus = function() return 12345 end
reaper.time_precise = function() return 10 end  -- bypass 0.2s throttle
keyboard.CheckFocus()
-- is_intercepting is now true
```

### CheckFocus Test Pattern (gfx focus loss simulation)

```lua
-- Step 1: gain focus (intercept)
gfx.hwnd = 12345
reaper.JS_Window_GetFocus = function() return 12345 end
reaper.time_precise = function() return 10 end
keyboard.CheckFocus()
-- is_intercepting is now true

-- Step 2: simulate focus loss (focused_ret != gfx.hwnd)
reaper.JS_Window_GetFocus = function() return 0 end
reaper.time_precise = function() return 10.3 end  -- bypass throttle
keyboard.CheckFocus()
-- AllNotesOff sent, intercept released
```

Key detail: `time_precise` must advance past the previous call time (0.2s throttle). Use discrete values (e.g. 10 → 10.3) to avoid the throttle guard.

### Sequencer.Run Test Setup (time + state mocks)

```lua
-- Step 1: seed progression
sequencer_store.Init({
    progression = config.state.progression,  -- ref, populated below
})
config.state.progression[1] = { degree = 1, root_index = 1, scale_index = 1, octave = 4, chord_mode_index = 2 }

-- Step 2: start playing
sequencer_store.SetIsPlaying(true)
sequencer_store.SetLastMeasure(-1)  -- first measure advance
sequencer_store.SetInternalBeats(0)

-- Step 3: mock time for REAPER-synced mode
reaper.GetPlayState = function() return 0 end  -- 0 = internal clock
reaper.time_precise = function() return 0 end
reaper.Master_GetTempo = function() return 120 end  -- 120 BPM = 2 beats/sec

-- At t=0: 0 beats → 0 measures → measure 0
-- At t=2 (4 beats elapsed, 1 measure): measure advance → chord trigger
reaper.time_precise = function() return 2.0 end
sequencer.Run()  -- triggers chord for slot 1
```

### AllNotesOff Test Setup

```lua
-- Add held notes to key_states
local ks = midi_store.GetKeyStates()
local first_vk = next(config.VKEY_MAP)
ks[first_vk].is_pressed = true
ks[first_vk].midi_notes = {60, 64}

-- Add held notes to mouse_pad_state
local mps = midi_store.GetMousePadState()
mps.midi_notes = {67}

-- Set active notes ref counts
midi_store.SetActiveNote(60, 1)
midi_store.SetActiveNote(64, 1)
midi_store.SetActiveNote(67, 1)
```

## Cross-References

- **`src/core/AGENTS.md`** — API documentation: midi, keyboard, sequencer, progression, api-guard, snap
- **`src/state/AGENTS.md`** — Stores API: all getters/setters, Init semantics, consumable pattern, piano-roll-store (undo/redo)
- **`AGENTS.md` (root)** — Circular dependency map, pattern glossary, init/teardown contract
- **`openspec/specs/`** — Specs for test domains (check-focus, toggle-island, export-midi, sequencer-run, sendmidi, etc.)
- **`openspec/changes/archive/`** — Archived SDD change artifacts (test-mocks, test-mocks-phase3, test-infrastructure)
