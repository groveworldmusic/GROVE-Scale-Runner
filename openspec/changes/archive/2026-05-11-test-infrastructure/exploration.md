## Exploration: test-infrastructure

### Current State

The project has a single test file (`tests/test_midi.lua`, 223 LOC) that **copies** the logic of `midi.GetMidiNote` and `midi.GetChordNotes` instead of requiring the real modules. Lines 26-69 define local duplicates of `config.NOTE_NAMES`, `config.SCALES`, `config.CHORD_MODES` and a standalone `GetMidiNote` function. A change to the real function will NOT be caught by this test — it tests an independent copy.

The `tests/mock/` directory exists but is **empty**. No test runner, no helpers, no mock infrastructure exists.

### Lua Environment

| Item | Value |
|------|-------|
| **Lua binary** | `C:\Users\Andrik\AppData\Local\Temp\lua54.exe` (not in PATH) |
| **Version** | Lua 5.4.6 (confirmed: `lua54.exe -v`) |
| **Other binaries** | `lua54_launcher.exe` (25KB), `lua_full.exe` (invalid Win32 — Linux binary), `lua54.dll` (160KB) |
| **Invocation** | `& "C:\Users\Andrik\AppData\Local\Temp\lua54.exe" tests/run.lua` — requires full path |
| **LuaRocks** | Not installed. No `luacov`, `busted`, or any test framework available. |
| **Compatibility** | Plain Lua 5.4.6 — no `reaper.*` or `gfx.*` globals. The project code is Lua 5.1-compatible (no `goto`, no `::`, tables only, `math.floor` used over `//`). |

### Module Loading Mechanism

The project sets up `package.path` in `main.lua` (lines 39-45):

```lua
local info = debug.getinfo(1, 'S')
local script_path = info.source:match([[^@?(.*[\/])[^\/]-$]])
package.path = package.path .. ";" .. script_path .. "?.lua"
```

This prepends the `src/` directory to `package.path`, so `require("config")` finds `src/config.lua`, `require("state.midi")` finds `src/state/midi.lua`, etc.

**For test loading**, the equivalent would be:
```lua
local script_path = "D:/05 - Develop/Proyectos/02 - En Desarrollo/GROVE FL MIDI/src/"
package.path = package.path .. ";" .. script_path .. "?.lua"
```

But since tests live in `tests/`, a relative path from `tests/run.lua` is better:

```lua
local info = debug.getinfo(1, 'S')
local tests_dir = info.source:match([[^@?(.*[\/])[^\/]-$]])
local src_dir = tests_dir .. "..\\src\\"
package.path = package.path .. ";" .. src_dir .. "?.lua"
```

This avoids hardcoded absolute paths and works from any machine.

### State Stores API

#### 1. `state/compact.lua` — 40 LOC
| Init | Method |
|------|--------|
| `Init(defaults)` | Copies from `defaults.compact` (sub-table), `defaults.compact_overlay_active`, `defaults.last_gfx_state` |
| Getters (6) | `GetTransportHwnd()`, `GetLiceBitmap()`, `GetLiceFont()`, `GetGdiFont()`, `GetOverlayActive()`, `GetLastGfxState()` |
| Setters (6) | `SetTransportHwnd(v)`, `SetLiceBitmap(v)`, `SetLiceFont(v)`, `SetGdiFont(v)`, `SetOverlayActive(v)`, `SetLastGfxState(v)` |
| **reaper deps** | **None** at any level |

#### 2. `state/drag.lua` — 55 LOC
| Init | Method |
|------|--------|
| `Init(defaults)` | Copies from `defaults.drag` (sub-table), 9 keys |
| Getters (9) | `GetIsDragging()`, `GetSourceDegree()`, `GetSourceSlotIdx()`, `GetPendingDegree()`, `GetPendingSlotIdx()`, `GetStartX()`, `GetStartY()`, `GetX()`, `GetY()` |
| Setters (9) | Same 9 with `Set` prefix |
| Special | `Reset()` — clears is_dragging, source_degree=-1, source_slot_idx=-1, pending_degree=nil, pending_slot_idx=nil |
| **reaper deps** | **None** at any level |

#### 3. `state/sequencer.lua` — 78 LOC
| Init | Method |
|------|--------|
| `Init(defaults)` | Copies `defaults.progression` (REF), `defaults.sequencer` sub-table merged key-by-key, `defaults.current_page`, `defaults.page_override_timer`, `defaults.slot_flash` sub-keys |
| Progression | `GetProgression()` (REF), `SetProgression(t)`, `GetProgressionLen()`, `GetProgressionEntry(i)`, `SetProgressionEntry(i, v)`, `ClearProgression()` (slots 1..16 → nil) |
| Playback (8 pairs) | `IsPlaying`, `CurrentStep`, `LastMeasure`, `MidiNotes`, `Progress`, `InternalBeats`, `LastTime`, `Volume` |
| Page (2 pairs) | `CurrentPage`, `PageOverrideTimer` |
| Flash (2 pairs) | `SlotFlashIdx`, `SlotFlashTimer` |
| **reaper deps** | **None** at any level |

#### 4. `state/midi.lua` — 60 LOC
| Init | Method |
|------|--------|
| `Init(defaults)` | Direct: `use_velocity`, `last_note_played`, `active_note_draw_timer`. REF: `key_states`. Merge: `active_notes` (entry by entry), `mouse_pad_state` (sub-keys merged) |
| Simple pairs (3) | `UseVelocity(bool)`, `LastNotePlayed(string)`, `ActiveNoteDrawTimer(num)` |
| Key states | `GetKeyStates()` (REF), `GetKeyState(i)`, `SetKeyState(i, v)` |
| Active notes | `GetActiveNotes()` (REF), `GetActiveNote(i)`, `SetActiveNote(i, v=nil/num)`, `ClearActiveNotes()` |
| Ref return | `GetMousePadState()` (REF — `{pad_hover, pad_selected, pad_timer, active_degree, midi_notes}`) |
| **reaper deps** | **None** at any level |

#### 5. `state/ui.lua` — 114 LOC
| Init | Method |
|------|--------|
| `Init(defaults)` | ~15 root keys direct from `config.state.*`. `pad_flash` merged recursively (including nested `prev_active` table) |
| View | `Get/SetViewMode(num)` — 1=FULL, 2=COMPACT |
| Mouse (event bus) | `Get/SetMouseClick(bool)`, `ConsumeMouseClick() → bool (clears)`, `Get/SetMouseWheelDelta(num)`, `ConsumeMouseWheelDelta() → num (zeros)` |
| Preferences (4 pairs) | `ShowTooltips(bool)`, `ColorMode("grade"/"flat")`, `UseScroll(bool)`, `SliderDragging(bool)` |
| State | `LastMouseCap(num)`, `UseScroll(bool)` |
| Pad flash | `Get/SetPadFlashDegree(num)`, `Get/SetPadFlashTimer(num)`, `GetPadFlashPrevActive()` (REF), `ClearPadFlash()` (degree=-1, timer=0) |
| Dock (2 pairs) | `DockedMode(bool)`, `DockId(num)` |
| Auto-start (2 pairs) | `AutoStartCompact(bool)`, `AutoStartReaper(bool)` |
| Guard (1 pair) | `DidCleanup(bool)` |
| **reaper deps** | **None** at any level |

**All 5 stores have ZERO reaper dependencies.** None of them reference `reaper.*` or `gfx.*` at require time or in their getters/setters.

### progression.lua API

File: `src/core/progression.lua` (38 LOC). Depends only on `state.sequencer` (pure).

| Function | Signature | Notes |
|----------|-----------|-------|
| `Add(idx, slot)` | `progression.Add(number, table)` | Sets entry, triggers flash (idx + timer=10) |
| `Remove(idx)` | `progression.Remove(number)` | Sets entry to nil |
| `Swap(a, b)` | `progression.Swap(number, number)` | Via temp variable |
| `Clear()` | `progression.Clear()` | Calls `ClearProgression()` on store |
| `GetLastFilled()` | `progression.GetLastFilled() → number (0-16)` | Scans 16→1, O(n) |

**reaper deps**: **None**. Tests just need `package.path` pointing to `src/` + require `state.sequencer`.

### midi.lua Pure Functions

File: `src/core/midi.lua` (144 LOC). Depends on `config`, `state.compact`, `state.sequencer`, `state.midi`, `state.ui` — all pure at require time.

#### `midi.GetMidiNote(root_idx, scale_idx, degree_idx, octave_val) → number (0-127)`

Real implementation (line 14-23):
```lua
function midi.GetMidiNote(root_idx, scale_idx, degree_idx, octave_val)
    local root = root_idx - 1
    local scale = config.SCALES[scale_idx]
    local n_scale = #scale.intervals
    local deg0 = degree_idx - 1
    local oct_off = math.floor(deg0 / n_scale)
    local interval = scale.intervals[(deg0 % n_scale) + 1]
    local result = (octave_val + 1) * 12 + root + (oct_off * 12) + interval
    return math.max(0, math.min(127, result))
end
```

The test's local copy (test_midi.lua lines 60-69) is **functionally identical** — same algorithm, same clamping. But it reads from a local `SCALES` table, not `config.SCALES`. This is the core problem.

#### `midi.GetChordNotes` — **Does NOT exist as a standalone function**

The test defines a local `GetChordNotes` (lines 77-85), but the real module computes chord notes inline inside `TriggerChord` (lines 49-59):

```lua
function midi.TriggerChord(degree, on, ctx, velocity)
    local c = ctx or config.state
    local notes = {}
    local offsets = config.CHORD_MODES[c.chord_mode_index].offsets
    for _, off in ipairs(offsets) do
        local n = midi.GetMidiNote(c.root_index, c.scale_index, degree + off, c.octave)
        midi.SendMidi(n, on, velocity)
        table.insert(notes, n)
    end
    return notes
end
```

So the test's `GetChordNotes` function has **no real counterpart**. To test chord note computation, you'd either:
- Test `midi.GetMidiNote` independently (covered)
- Test `midi.TriggerChord` with `midi.SendMidi` mocked out (requires reaper mock)

#### Other functions that need runtime mocks

| Function | reaper.* | gfx.* | State stores |
|----------|----------|-------|-------------|
| `midi.GetMidiNote` | ❌ | ❌ | ❌ (pure) |
| `midi.TriggerChord` | ❌ (just calls SendMidi) | ❌ | config.state ctx |
| `midi.SendMidi` | ✅ `reaper.StuffMIDIMessage` | ❌ | midi_store (set) |
| `midi.AllNotesOff` | ✅ `reaper.StuffMIDIMessage` | ❌ | midi_store (clear) |
| `midi.ExportToMidi` | ✅ Heavy (`reaper.GetSelectedTrack`, `reaper.InsertTrackAtIndex`, `reaper.GetTrack`, `reaper.TimeMap_timeToQN`, `reaper.TimeMap_QNToTime`, `reaper.CreateNewMIDIItemInProj`, `reaper.GetActiveTake`, `reaper.MIDI_GetPPQPosFromProjQN`, `reaper.MIDI_InsertNote`, `reaper.MIDI_Sort`, `reaper.UpdateArrange`, `reaper.GetCursorPosition`) | ❌ | sequencer_store (read) |
| `midi.ToggleIsland` | ✅ `reaper.JS_Window_GetRect` | ✅ `gfx.dock`, `gfx.quit`, `gfx.init`, `gfx.hwnd`, `gfx.setfont` | ui_store, compact_store |

### Mock Requirements

#### Minimal mocks for `midi.SendMidi` testing

```lua
-- tests/mock/reaper.lua (minimal)
local reaper = {}
reaper.StuffMIDIMessage = function(ch, msg, note, vel)
    -- test can override to capture calls
end
return reaper
```

#### Full reaper mock needed for `midi.ExportToMidi`
Would need stubs for ~12+ functions. Not worth it for initial phase.

#### Full gfx mock needed for `midi.ToggleIsland`
Would need stubs for `gfx.dock`, `gfx.quit`, `gfx.init`, `gfx.hwnd`, `gfx.setfont`. Medium complexity.

### Module Require Chains (testable without mocks)

```
require("config")
  → OK (no deps)

require("state.compact")
  → OK (no deps)

require("state.drag")
  → OK (no deps)

require("state.sequencer")
  → OK (no deps)

require("state.midi")
  → OK (no deps)

require("state.ui")
  → OK (no deps)

require("core.progression")
  → require("state.sequencer") → OK (both pure)

require("core.midi")
  → require("config") → OK
  → require("state.compact") → OK
  → require("state.sequencer") → OK
  → require("state.midi") → OK
  → require("state.ui") → OK
  → require succeeds. Runtime: GetMidiNote works, SendMidi needs reaper mock.
```

### Approaches

#### 1. **Minimal** — helpers + run.lua + refactor test_midi.lua + store/progression tests

| Item | What |
|------|------|
| **Create** | `tests/helpers.lua` — `check()`, `assert_eq()`, `summary()` |
| **Create** | `tests/run.lua` — package.path setter + test discovery + runner |
| **Refactor** | `tests/test_midi.lua` — replace local copies with `require("core.midi")` |
| **Create** | `tests/test_stores.lua` — Init + every getter/setter round-trip for all 5 stores |
| **Create** | `tests/test_progression.lua` — CRUD for progression module |
| **Mock** | None needed (progression + stores + midi.GetMidiNote are all pure) |
| **Files changed** | 1 modified + 4 new |

**Pros**:
- Zero mock infrastructure needed
- Tests the REAL modules (fixes the core contradiction)
- Covers 6 modules immediately (5 stores + progression)
- Quick win: get working tests in <100 LOC of infrastructure

**Cons**:
- Doesn't test `midi.SendMidi`, `midi.TriggerChord`, `midi.AllNotesOff`
- Doesn't test keyboard, sequencer, slots (need mock infrastructure)
- `midi.GetChordNotes` has no real counterpart — test needs adjustment

**Effort**: Low (2-3 hours)

#### 2. **Full** — Minimal approach + mock reaper/gfx + test midi runtime functions

| Item | What |
|------|------|
| **All of Approach 1** | Same base |
| **Create** | `tests/mock/reaper.lua` — minimal stubs for `StuffMIDIMessage` |
| **Create** | `tests/mock/gfx.lua` — minimal stubs for `dock`, `quit`, `init`, `hwnd`, `setfont` |
| **Create** | `tests/test_midi_runtime.lua` — SendMidi, TriggerChord, AllNotesOff with mocked reaper |
| **Require order** | Mock modules must be `required` BEFORE real modules so `_G.reaper` exists |

**Pros**:
- Tests MIDI note on/off logic (ref-counting, velocity scaling, note clamping)
- Tests AllNotesOff edge cases (empty state, partial state)
- Catches bugs in SendMidi (the ref-counted active notes pattern is non-trivial)

**Cons**:
- Mock infrastructure adds complexity
- Mock `reaper` must be loaded into global scope before core modules
- Need to handle require order carefully (mocks before real modules)
- `gfx.*` mock is needed only for `ToggleIsland` — questionable ROI

**Effort**: Medium (4-6 hours)

#### 3. **Store-only** (most minimal subset of Approach 1)

| Item | What |
|------|------|
| **Create** | `tests/helpers.lua` — check function |
| **Create** | `tests/test_stores.lua` — all store tests in one file |
| **Skip** | run.lua, test_midi refactor, progression tests |
| **Run method** | Direct: `lua54.exe tests/test_stores.lua` |

**Pros**: Absolute minimum effort, quickest time-to-value
**Cons**: Doesn't fix the broken test_midi.lua, no progression coverage

**Effort**: Very Low (1 hour)

### Recommendation

**Approach 1 (Minimal)** with the following order:

1. **Create `tests/helpers.lua`** — generic `check()`, `assert_eq()` functions + summary reporter
2. **Create `tests/run.lua`** — package.path setup (relative to tests/), require all `test_*.lua` files, aggregate results
3. **Refactor `tests/test_midi.lua`** — keep existing test CHECK logic, replace local `GetMidiNote` with `require("core.midi").GetMidiNote` and adjust chord tests to test `TriggerChord` with a mock or test `GetMidiNote` directly for each offset
4. **Create `tests/test_stores.lua`** — file-per-store sections:
   - Init with empty defaults
   - Init with custom defaults
   - Getter/setter round-trip for every pair
   - Consume lifecycle for ui_store: `SetMouseClick(true) → ConsumeMouseClick() → true` then `ConsumeMouseClick() → false`
5. **Create `tests/test_progression.lua`** — Add → GetLastFilled, Remove, Swap source≠target, Swap source=target (no-op), Clear, empty GetLastFilled → 0
6. **Test execution**: `& "C:\Users\Andrik\AppData\Local\Temp\lua54.exe" tests\run.lua`

**Do NOT add mock infrastructure in the first phase.** The pure modules already cover 6 of the 10 modules in the project. Mock infrastructure can be added in a second phase after verifying the test runner works end-to-end.

### Risks

1. **`midi.GetChordNotes` discrepancy**: The test defines `GetChordNotes` as a standalone function, but the real module computes chord notes inline in `TriggerChord`. The refactored test needs to either: (a) test `midi.GetMidiNote` for each chord offset independently, or (b) test `midi.TriggerChord` with `SendMidi` mocked. Option (a) is cleaner for phase 1.

2. **`require()` vs `dofile()`**: The `run.lua` package.path setup must match exactly. If `src/` path is wrong, all requires fail silently. Must verify with a smoke test (`require("config")` → check `config.NOTE_NAMES`).

3. **No exit code propagation**: `run.lua` must aggregate per-file results and call `os.exit(1)` if ANY test file fails. The current `test_midi.lua` does this internally — after refactor, `run.lua` owns the exit code.

4. **Lua 5.4 edge cases**: The project code was written with Lua 5.1/JIT assumptions. Lua 5.4 has different `math.random` behavior, but for stores and progression tests this is irrelevant (pure table operations). `midi.GetMidiNote` uses only `math.floor`, `math.min`, `math.max` — identical across all Lua versions.

5. **Windows path backslashes**: `package.path` uses Lua's `?.lua` pattern with forward slashes. The `debug.getinfo` source path may return backslashes on Windows. Must use `:gsub("\\", "/")` in run.lua to normalize paths.

6. **Module identity**: Each call to `require("state.midi")` returns the SAME module table (singleton). Store tests must call `Init(defaults)` to reset between test groups, or use separate test functions that don't leak state.

### Ready for Proposal

**Yes.** This exploration is sufficiently grounded in real code. All file reads are verified against the actual source. The recommendation is clear: Approach 1 (Minimal) with the explicit order of steps.

**Proceed to SDD proposal** with:
- Change: `test-infrastructure`
- Scope: helpers.lua, run.lua, refactor test_midi.lua, test_stores.lua, test_progression.lua
- Mock phase: deferred to future change
- Test runner: standalone Lua 5.4.6 binary at `C:\Users\Andrik\AppData\Local\Temp\lua54.exe`
