# Design: test-mocks

## Technical Approach

Global mock injection via `_G.reaper`/`_G.gfx` before module loading, plus `make_mock_fn(name)` factory for assertion-tracked stubs. Phase 2 tests cover 3 runtime modules across 7 test files (est. ~250 new assertions).

## Architecture Decisions

### Decision 1: Mock Installation Strategy

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `_G.reaper = mock` in run.lua | No code changes to src/; transparent to all modules | ✅ **Adopted** |
| `package.loaded["reaper"] = mock` | Doesn't work — reaper is a global, not a module | ❌ Rejected |
| DI into every module | Requires changing ALL module signatures | ❌ Rejected |

`_G.reaper = mock` **before** `package.path` extension ensures any `require("core.midi")` finds the mock. The order in `run.lua` is: (1) require mocks, (2) assign globals, (3) extend path, (4) require modules.

### Decision 2: Mock Function Pattern

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `make_mock_fn(name)` factory | Consistent tracking; `fn.mock` property stores call history | ✅ **Adopted** |
| Hand-written stubs per function | Error-prone, inconsistent call recording | ❌ Rejected |

Non-obvious pattern — the factory returns a closure with a `mock` property attached:

```lua
local function make_mock_fn(name)
    local track = { call_count = 0, calls = {} }
    local fn = function(...)
        track.call_count = track.call_count + 1
        track.calls[track.call_count] = {...}
    end
    fn.mock = track
    return fn
end
```

Plus `reset_all_calls()` that zeroes every mock fn's counters — called between test files in run.lua.

### Decision 3: Test File Isolation

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Separate files per keyboard function | Fresh dofile = fresh module closure | ✅ **Adopted** |
| Single keyboard test file | `is_intercepting` closure leaks state between test blocks | ❌ Rejected |

Keyboard module has `local is_intercepting = false` (line 9). Each `dofile()` in run.lua creates a new Lua chunk — so separate files give us clean closure state per test group.

### Decision 4: config.state Setup

`TriggerChord` reads `config.state.*` remnant keys directly. Tests must set these explicitly before calling the SUT:

```lua
config.state.root_index = 1       -- C
config.state.scale_index = 1      -- Major
config.state.octave = 4
config.state.chord_mode_index = 2 -- Tri
```

### Decision 5: Deterministic Tests

`midi_store.SetUseVelocity(false)` → fixed velocity 100 (no math.random). A separate future test can cover velocity humanization by seeding math.random.

## Data Flow

```
run.lua ──→ _G.reaper = mock_reaper()
         ──→ _G.gfx = mock_gfx()
         ──→ package.path += src/?.lua
         ──→ dofile(test_*.lua)
                  │
                  ▼
            test_*.lua ──→ require("core.midi")
                         ──→ midi.SendMidi(60, true)
                         ──→ assert(reaper.StuffMIDIMessage.mock.calls[1])
                                  │
                                  ▼
                         mock/reaper.lua ──→ make_mock_fn("StuffMIDIMessage")
                                            track.call_count++
                                            track.calls[n] = {...}
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `tests/mock/reaper.lua` | Create | 38 stubs via `make_mock_fn`; `reset_all_calls()` export |
| `tests/mock/gfx.lua` | Create | 17 no-op methods + 9 mutable state fields |
| `tests/test_sendmidi.lua` | Create | SendMidi, TriggerChord, AllNotesOff (~80 LOC) |
| `tests/test_sequencer_stop.lua` | Create | sequencer.Stop state reset + note-offs (~30 LOC) |
| `tests/test_keyboard_intercept.lua` | Create | InterceptMappedKeys true/false with 28 calls each (~25 LOC) |
| `tests/test_keyboard_cleanup.lua` | Create | Cleanup when intercepting vs not, idempotent (~20 LOC) |
| `tests/test_keyboard_handle.lua` | Create | Key-down/up dispatch, unmapped keys, multi-key, deterministic vel (~50 LOC) |
| `tests/run.lua` | Modify | Install globals at top; reset mocks between files; discover new test files |
| `tests/AGENTS.md` | Modify | Document mock init order, config.state setup, closure reset guidance |

## Interfaces / Contracts

**mock/reaper.lua exports**:
- Standard reaper.* functions (38), most via `make_mock_fn` for tracking
- Key assertion-tracked fns: `StuffMIDIMessage`, `JS_VKeys_Intercept`
- Simple-return stubs for: `GetPlayState() → 0`, `time_precise() → 0`, `JS_VKeys_GetState() → "\0"*256`
- `reaper.reset_all_calls()` — clears all mock counters
- `reaper.get_mock_call(name, n)` — returns nth call args for a named mock fn

**mock/gfx.lua exports**:
- 17 methods: all accept `(...)` and return nil (or `0` for `getchar`, `dock`, etc.)
- 9 fields: `x=0, y=0, w=720, h=500, mouse_x=0, mouse_y=0, mouse_cap=0, mouse_wheel=0, hwnd=nil`

**Test pattern**:
```lua
local config = require("config")
local midi = require("core.midi")
local helpers = require("tests.helpers")
local check = helpers.check

-- Setup
config.state.chord_mode_index = 2
midi_store.SetUseVelocity(false)
reaper.reset_all_calls()

-- Exercise
midi.TriggerChord(1, true)

-- Assert
local c1 = reaper.StuffMIDIMessage.mock.calls[1]
check(c1[2] == 0x90, "note-on on first chord note")
check(reaper.StuffMIDIMessage.mock.call_count == 3, "triad sends 3 notes")
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Mock infra | Stubs return safe defaults; tracking records calls correctly | Unit test (the mocks themselves) |
| midi runtime | SendMidi, TriggerChord, AllNotesOff via StuffMIDIMessage calls and state assertions | Integration with mocks |
| sequencer.Stop | State field resets + note-offs per MidiNotes entry | Integration with mocks |
| keyboard intercept | JS_VKeys_Intercept call count = 28 per invocation | Integration with mocks |
| keyboard cleanup | is_intercepting closure guard, idempotent | Integration with mocks |
| keyboard handle | VKEY byte → TriggerChord dispatch, note-off on release | Integration with mocks |

All tests deterministic: no math.random, no time dependence, fresh mock state per file via `reset_all_calls()`.

## Migration / Rollout

No migration. New files only; `run.lua` gains mock installation + discovers new test files via a table. Existing Phase 1 tests (test_midi.lua, test_stores.lua, test_progression.lua) are unaffected — they don't use reaper/gfx globals.

## Open Questions

None.
