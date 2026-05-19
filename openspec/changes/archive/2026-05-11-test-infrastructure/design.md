# Design: test-infrastructure

## Technical Approach

Phase 1 zero-mock test infrastructure: shared helpers + unified runner + refactor existing test to use real module + add store and progression tests. No `src/` files touched. All 5 state stores and `progression.lua` are pure — no `reaper.*` or `gfx.*` dependencies.

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|-------------|-----------|
| Path derivation | `debug.getinfo(1,'S')` from run.lua, normalize backslashes | Hardcoded relative path | Works from any cwd; breakage proof |
| Store Init per group | Fresh `{compact={}, drag={}, ...}` per store section | Reuse singleton config.state | No cross-contamination between store tests |
| `os.exit` ownership | run.lua overrides `os.exit` before loading test files | `pcall` each file | Lua exits immediately on `os.exit` — pcall won't catch it |
| Chord tests | Compute per-offset via `midi.GetMidiNote` | Test `TriggerChord` with mock | `GetChordNotes` doesn't exist in real module; per-offset tests verify same math |
| Test file loading | `dofile()` within run.lua | `require()` | Each file runs in its own closure; `require` caches singletons and doesn't re-execute |

## Data Flow

```
lua54.exe tests/run.lua
  │
  ├── debug.getinfo(1,'S') → derive src/ path
  ├── package.path += ";..\\src\\?.lua"
  │
  ├── os.exit = dummy_fn          ← capture exit ownership
  ├── helpers = {} state reset
  │
  ├── dofile("tests/test_midi.lua")
  │     ├── require("config")          ──→ config.SCALES, NOTE_NAMES, CHORD_MODES
  │     ├── require("core.midi")       ──→ midi.GetMidiNote (real module)
  │     └── check/assert from helpers     print PASS/FAIL
  │
  ├── dofile("tests/test_stores.lua")
  │     ├── for each store:
  │     │     local state = {key = {}}  ──→ fresh table per group
  │     │     store.Init(state)
  │     │     assert round-trips
  │     └── ui_store consume lifecycle tests
  │
  ├── dofile("tests/test_progression.lua")
  │     ├── require("core.progression")
  │     ├── require("state.sequencer")
  │     └── CRUD: Add → GetLastFilled → Remove → Swap → Clear
  │
  ├── os.exit = restore original
  └── summary() → os.exit(0|1)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `tests/helpers.lua` | Create | `check()`, `assert_eq()`, `summary()` with pass/fail counters |
| `tests/run.lua` | Create | Path derivation, test discovery (`test_*.lua`), aggregate results |
| `tests/test_midi.lua` | Modify | Remove local copies, `require("config")` + `require("core.midi")`, adapt chord tests |
| `tests/test_stores.lua` | Create | All 5 stores: Init, round-trip, edge cases, consume lifecycle |
| `tests/test_progression.lua` | Create | Progression CRUD: Add/Remove/Swap/Clear/GetLastFilled |

## Interfaces / Contracts

### helpers.lua

```lua
-- State: passed (num), failed (num)
function check(condition, msg)      → nil       -- passes: print PASS, increments; fails: print FAIL, increments
function assert_eq(a, b, msg)       → nil       -- calls check(a==b, msg .. ": expected "..tostring(b)..", got "..tostring(a))
function summary()                  → nil       -- prints totals, os.exit(1) if failed > 0
```

### Store Init pattern for tests

```lua
local state = {
    -- Each store reads from a specific sub-key:
    compact = {},              -- compact_store reads defaults.compact.*
    drag = {},                 -- drag_store reads defaults.drag.*
    progression = {},          -- sequencer reads ref
    sequencer = {},            -- sequencer reads defaults.sequencer.*
    current_page = 1,
    page_override_timer = 0,
    slot_flash = { idx = -1, timer = 0 },
    use_velocity = false,
    last_note_played = "None",
    active_note_draw_timer = 0,
    key_states = {},
    active_notes = {},
    mouse_pad_state = {},
    -- ui_store root keys:
    view_mode = 1,
    mouse_click = false,
    mouse_wheel_delta = 0,
    pad_flash = { degree = -1, timer = 0, prev_active = {} },
    -- ... remaining ui defaults
}
store.Init(state)  -- fills all defaults from state table
```

### Chord test adaptation

```lua
-- No GetChordNotes in real module. Compute per-offset:
local function get_chord_note(root, scale, degree, octave, offset)
    return midi.GetMidiNote(root, scale, degree + offset, octave)
end
-- Test: Tri C Major degree 1 octave 4 → {60, 64, 67}
check(get_chord_note(1, 1, 1, 4, 0) == 60, "Root note C4")
check(get_chord_note(1, 1, 1, 4, 2) == 64, "Third E4")
check(get_chord_note(1, 1, 1, 4, 4) == 67, "Fifth G4")
```

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Unit | `midi.GetMidiNote` (pure) | Existing 223 LOC test refactored to use real `require("core.midi")` |
| Unit | All 5 state stores | Per-store Init + every getter/setter round-trip + Consume lifecycle (ui_store) + edge cases |
| Unit | `progression.*` CRUD | Add → GetLastFilled, Remove, Swap (source≠target and source=target), Clear, empty state |
| Integration | run.lua entry point | Execute via `lua54.exe tests\run.lua`, verify exit code 0 (all pass) and 1 (deliberate failure) |

## Migration / Rollback

No migration required. Delete created files, restore `tests/test_midi.lua` from git.

## Open Questions

None — all decisions resolved in exploration.
