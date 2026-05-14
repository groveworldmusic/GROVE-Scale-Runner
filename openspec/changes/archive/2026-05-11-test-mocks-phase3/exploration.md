# Exploration: test-mocks-phase3

## Current State

Phases 1 and 2 delivered 285 tests covering stores, progression, SendMidi, TriggerChord, AllNotesOff,
sequencer.Stop, keyboard.InterceptMappedKeys, keyboard.Cleanup, and keyboard.HandleKeyboard.

Four "HARD" functions remain untested — each with distinct mocking challenges:

1. `midi.ExportToMidi()` — creates MIDI items in REAPER via chain of API calls
2. `midi.ToggleIsland()` — GFX window lifecycle (gfx.quit/gfx.init)
3. `sequencer.Run()` — transport sync + internal clock with time-dependent logic
4. `keyboard.CheckFocus()` — focus detection with 0.2s throttle

Mock infra (50+ reaper stubs + 17 gfx no-ops) is proven and working. All stubs return nil by default;
tests override specific stubs when they need non-nil return values.

---

## Function Analysis

---

### Function: keyboard.CheckFocus()

**reaper deps**: `reaper.time_precise()`
**gfx deps**: `gfx.hwnd` (read, via IsPluginOrScriptFocused)
**State deps**: none directly (reads `gfx.hwnd`, calls `reaper.GetFocusedFX2()`)
**Config deps**: none
**Control flow**:
1. `time_precise()` → `now`
2. `now - last_focus_check > 0.2` throttle gate (module-level `last_focus_check` starts at 0)
3. `IsPluginOrScriptFocused()` = `gfx.hwnd` match OR `GetFocusedFX2()` bitmask (bits 1/2 set, bit 4 clear)
4. Focus gain (!intercepting + should_intercept) → `InterceptMappedKeys(true)`, `is_intercepting = true`
5. Focus loss (intercepting + !should_intercept) → `InterceptMappedKeys(false)`, `is_intercepting = false`, `midi.AllNotesOff()`
6. No change (should_intercept matches current state) → no-op

**Mock strategy** — LOW effort:
- **Throttle control**: Existing `reaper.time_precise` returns 0 by default. Override to return e.g. 10 for first call (bypasses 0.2s since `10 - 0 > 0.2`). For sequential calls testing throttle boundary, use a function that increments on each call.
- **Focus conditions**:
  - "gfx.hwnd focused": set `gfx.hwnd = 12345`, override `reaper.JS_Window_GetFocus` → `return 12345`
  - "plugin focused": `gfx.hwnd = nil`, override `reaper.JS_Window_GetFocus` → `return 456`, override `reaper.GetFocusedFX2` → `return 1` (bit 1 set, bit 4 clear)
  - "focus lost": `gfx.hwnd = nil`, `reaper.JS_Window_GetFocus` → `return nil`, `reaper.GetFocusedFX2` → `return 0`
- **Module isolation**: Must clear `package.loaded["core.keyboard"]` before each test file (already established pattern in HandleKeyboard tests).

**Test assertions**:
- First call with gfx-focused: intercept activated (28 VKeys_Intercept calls)
- Subsequent call within 0.2s: NO additional intercept calls (throttle works)
- Subsequent call after 0.2s: re-evaluates focus
- Focus loss: intercept released + AllNotesOff called
- No change (already intercepting + still focused): no-op
- Already intercepting + focus still lost: only ONE cleanup (is_intercepting guard)

**Effort**: LOW (~40 LOC test file, reuses existing patterns)

---

### Function: midi.ToggleIsland()

**reaper deps**: `reaper.JS_Window_GetRect(hwnd)` — conditional on `gfx.hwnd` being truthy
**gfx deps**: `gfx.dock(-1)`, `gfx.hwnd` (read), `gfx.quit()`, `gfx.init(title, 720, h, dock, x, y)`, `gfx.setfont(1, "Calibri", 16)`
**State deps**: `ui_store.GetDockedMode()`, `compact_store.GetLastGfxState()` (returns table ref, mutated in-place)
**Config deps**: `config.script_title = "Scale Runner"`
**Module fields**: `midi.midi_island_expanded` (toggle), `midi.midi_island_toggled` (set true)
**Control flow**:
1. Early return if `ui_store.GetDockedMode()` is true
2. Toggle `midi.midi_island_expanded`
3. Set `midi.midi_island_toggled = true`
4. Capture `gfx.dock(-1)` → dock mode
5. Read `compact_store.GetLastGfxState()` → `gs` table
6. If `gfx.hwnd` is truthy: `JS_Window_GetRect(hwnd)` → update `gs.x, gs.y`
7. Calculate `new_h = midi_island_expanded ? 793 : 497`
8. `gfx.quit()` + `gfx.init(config.script_title, 720, new_h, dock, gs.x, gs.y)`
9. `gfx.setfont(1, "Calibri", 16)`

**⚠️ Potential nil bug**: `compact_store.GetLastGfxState()` can return `nil` if `last_gfx_state` was never set (default in compact_state is `nil`). If `hwnd` is truthy, line 135 `gs.x, gs.y = l, t` would error. If `hwnd` is nil, line 140 passes `gs.x, gs.y` where gs could be nil. The `config.state` default (line 81) has `{dock=0, x=100, y=100, w=720, h=500}`, so after proper Init this table exists.

**Mock strategy** — LOW-MEDIUM effort:
- `gfx.quit()` and `gfx.init()` are already no-ops in mock — safe to call, no real side effects
- `gfx.dock(-1)` returns 0 by default — fine for testing
- `gfx.hwnd` is nil by default — test both paths (nil and set to truthy value)
- `compact_store.GetLastGfxState()`: need to Init compact_store with a proper `last_gfx_state` table
- Need to make `gfx.init` **trackable** so we can assert on the arguments passed
- Need to make `gfx.quit` trackable similarly
- **Current mock limitation**: `gfx.init`, `gfx.quit`, `gfx.dock`, `gfx.setfont` are untracked no-ops. Phase 3 MUST make them trackable (or test them via override + assertion).

**Test assertions**:
- Early return: set docked_mode = true → no gfx.quit/gfx.init calls, no state toggle
- First toggle: `midi_island_expanded` goes false→true, `new_h = 793`
- Second toggle: `midi_island_expanded` goes true→false, `new_h = 497`
- `gfx.init` called with correct args: `("Scale Runner", 720, expected_h, dock_val, gs.x, gs.y)`
- `gfx.quit` called
- `gfx.setfont(1, "Calibri", 16)` called
- `gfx.dock(-1)` called once
- `midi_island_toggled` set to true during toggle
- If `gfx.hwnd` is set: `JS_Window_GetRect` called and `gs.x, gs.y` match rect values

**Effort**: MEDIUM — needs gfx mock upgrade (track gfx.init/gfx.quit args), plus compact_store setup

---

### Function: midi.ExportToMidi()

**reaper deps** (in call order):
1. `reaper.GetSelectedTrack(0, 0)` → MediaTrack or nil
2. `reaper.InsertTrackAtIndex(0, true)` — only if no track selected
3. `reaper.GetTrack(0, 0)` — only if inserted new track
4. `reaper.GetCursorPosition()` → seconds (nested inside TimeMap_timeToQN call)
5. `reaper.TimeMap_timeToQN(start_seconds)` → start in quarter notes
6. `reaper.TimeMap_QNToTime(qn)` × 2 → seconds for item bounds
7. `reaper.CreateNewMIDIItemInProj(track, t1, t2, false)` → MediaItem
8. `reaper.GetActiveTake(item)` → MediaTake
9. `reaper.MIDI_GetPPQPosFromProjQN(take, qn)` × 2 per slot → PPQ positions
10. `reaper.MIDI_InsertNote(take, false, false, p0, p1, 0, note, vel, true)` × N per chord offset
11. `reaper.MIDI_Sort(take)` — once after all insertions
12. `reaper.UpdateArrange()` — once after all insertions

**gfx deps**: None
**State deps**: `sequencer_store.GetProgressionEntry(i)` for slots 1..16
**Config deps**: `config.CHORD_MODES` (chord offsets), `config.SCALES` (via GetMidiNote)
**Control flow**:
1. Get selected track → if nil: insert track at index 0, get reference
2. Get cursor position → convert to quarter notes → `start_qn`
3. Scan 16→1 for last filled slot → `count` (0..16)
4. Early return if `count == 0`
5. `end_qn = start_qn + (count * 4)` → 4 quarter notes per slot
6. Create MIDI item from start_qn→end_qn (converted back to seconds)
7. Get active take from item
8. For each slot 1..count: insert chord notes via MIDI_InsertNote
9. MIDI_Sort + UpdateArrange

**Mock strategy** — MEDIUM effort:
- **Critical chain**: Need mock stubs to return truthy values that flow through the function without nil errors.
  - `GetSelectedTrack` → return `nil` to test "no track" branch, or `1` (truthy) to test "has track" branch
  - InsertTrackAtIndex → void, no return needed
  - `GetTrack(0,0)` → return `1` (truthy MediaTrack stand-in)
  - `GetCursorPosition()` → return `10.0` (or whatever)
  - `TimeMap_timeToQN(seconds)` → return `seconds * 2` (or whatever, just needs to return a number)
  - `TimeMap_QNToTime(qn)` → return `qn / 2` (reverse of above, or just return `qn`)
  - `CreateNewMIDIItemInProj(track, t1, t2, false)` → return `1` (truthy MediaItem)
  - `GetActiveTake(item)` → return `1` (truthy MediaTake)
  - `MIDI_GetPPQPosFromProjQN(take, qn)` → return two numbers, e.g. `qn * 1000` and `(qn+4) * 1000`
  - `MIDI_InsertNote(take, ...)` → void
  - `MIDI_Sort(take)` → void
  - `UpdateArrange()` → void

- **Test setup**: Need to populate progression in sequencer_store with 2-3 slots containing varied chord modes, roots, scales, octaves to verify correct note outputs.

- **What Lua actually needs**: `nil` is falsy. `1`, `{},`, `"a"` are all truthy. We DON'T need actual REAPER userdata (MediaTrack, MediaItem, MediaTake). Any truthy value is sufficient. The function only checks truthiness on GetSelectedTrack return, passes handles through to subsequent calls without inspecting them.

- **Currently**: All these stubs are plain `make_mock_fn` — they return `nil`. For the "no track" branch this is fine (GetSelectedTrack returns nil → triggers InsertTrackAtIndex). But `GetTrack(0,0)` also returns nil, which would crash on `CreateNewMIDIItemInProj(nil, ...)`. So the "no track" branch ALSO needs override.

**Test assertions**:
- Empty progression: early return, no MIDI calls
- Single slot: 1 chord × N offsets = N MIDI_InsertNote calls
- Multiple slots: correct count of MIDI_InsertNote calls
- Correct MIDI_InsertNote args: take, selected, muted, ppq0, ppq1, 0, note, vel, true
- Correct channel/velocity: channel=0 (since midi_channel defaults to 1, channel = 1-1 = 0), vel=100
- MIDI_Sort called once at end
- UpdateArrange called once at end
- CreateNewMIDIItemInProj called with correct time range
- No track selected: InsertTrackAtIndex called, then GetTrack

**Effort**: MEDIUM — requires overriding ~8+ stub return values, but no complex state machines

---

### Function: sequencer.Run()

**reaper deps**:
- `reaper.GetPlayState()` → bitmask (1 = playing, 5 = playing+recording, etc.)
- `reaper.TimeMap2_timeToBeats(0, pos)` → `(ok, measures, beats, tpos)` — synced path
- `reaper.GetPlayPosition2()` → seconds — synced path
- `reaper.time_precise()` → seconds — internal clock path
- `reaper.Master_GetTempo()` → BPM — internal clock path

**gfx deps**: None
**State deps** (sequencer_store): IsPlaying, LastMeasure, CurrentStep, Progress, InternalBeats, LastTime, MidiNotes, CurrentPage, Progression
**Core deps**: `midi.TriggerChord(slot.degree, true, slot)`, `midi.SendMidi(n, false)`, `progression.GetLastFilled()`

**Control flow**:
1. **Early return**: if not playing → SetProgress(0) → return
2. **GetPlayState() & 1 check**: REAPER sync vs internal clock
3. **REAPER sync branch**:
   - `TimeMap2_timeToBeats(0, GetPlayPosition2())` → `_, measures`
   - Reset internal clock state: `SetLastTime(nil)`
4. **Internal clock branch**:
   - `time_precise()` → `now`
   - First tick: `SetLastTime(now)`, `SetInternalBeats(0)`
   - Subsequent ticks: `delta = now - last_time`, `SetLastTime(now)`
   - `Master_GetTempo()` → BPM → beats_per_sec
   - `internal_beats += delta * beats_per_sec`
   - `measures = internal_beats / 4`
5. **Common**: `cur_m = floor(measures)`, `SetProgress(measures % 1)`
6. **Measure boundary** (`cur_m ~= last_measure`):
   a. Stop previous: note-off all held notes, clear midi_notes
   b. Cache `loop = progression.GetLastFilled()`
   c. **Catch-up**: while `cur_m > last_measure + 1`: iterate skipped slots → TriggerChord + immediate note-off
   d. If `loop == 0`: Stop() + return
   e. `SetCurrentStep((cur_m % loop) + 1)`
   f. `SetLastMeasure(cur_m)`
   g. Auto-paginate: `SetCurrentPage(floor((step-1)/4) + 1)`
   h. Trigger chord for current slot

**Mock strategy** — HIGH effort — this is the most complex function:

**Question 1: Can we test deterministically by controlling GetPlayState, GetPlayPosition2, and time_precise?**

YES, but with caveats:

**REAPER sync path**: Fully deterministic.
- `GetPlayState()` returns a simple number → test provides 1 (playing) or 0 (stopped)
- `GetPlayPosition2()` returns position in seconds → test controls via override
- `TimeMap2_timeToBeats(0, pos)` returns `(ok, measures, beats, tpos)` → test overrides to return specific measure count
- **No time dependency** in the REAPER path — positions don't need to be sequential

**Internal clock path**: Requires SEQUENTIAL time_precise values.
- `time_precise()` is called exactly once per `Run()` call (line 36)
- But `GetLastTime()` stores the value from the PREVIOUS Run() call
- To test a delta > 0, need `time_precise()` to return different values across sequential calls
- **Example**: First Run() → time_precise returns 10.0 → internal_beats starts at 0. Second Run() → time_precise returns 11.5 → delta = 1.5s
- **Solution**: Test overrides `reaper.time_precise` with a closure that increments on each call:

```lua
local t = 1000
reaper.time_precise = function()
    t = t + 10  -- each Run() call sees 10s later
    return t
end
```

- `Master_GetTempo()` returns BPM — test provides a fixed value (e.g. 120)
- This means each "tick" of Run() advances 10 seconds, producing deterministic beats

**Catch-up loop testing**:
- Set `last_measure = 0`, make Run() produce `cur_m = 5` → catch-up loop runs for measures 1,2,3,4
- Each skipped slot triggers TriggerChord + immediate note-off
- Without proper progression entries, loop == 0 branch will Stop() early

**Test scenarios needed**:

1. **Not playing**: Set IsPlaying=false → SetProgress(0) → return
2. **REAPER sync, playing, no progression**: Set IsPlaying=true, progression empty → Stop() called
3. **REAPER sync, playing, single measure**: progression has 1 slot, GetPlayState=1, measures changes from 0→1→2
4. **REAPER sync, measure boundary**: cur_m changes → note-off previous, trigger new
5. **REAPER sync, catch-up**: last_measure=0, cur_m=3 → catch-up trigger measures 1 and 2
6. **Internal clock, first tick**: No last_time → init internal state, no notes triggered
7. **Internal clock, second tick**: delta > 0, measure boundary reached
8. **Auto-pagination**: step moves to page 2 → CurrentPage updates

**Test assertions**:
- IsPlaying stays true during run
- Progress = measures % 1
- CurrentStep = (cur_m % loop) + 1
- LastMeasure updates
- MidiNotes updated when step changes (note-off old, trigger new)
- Catch-up: TriggerChord + immediate note-off for each skipped slot
- Internal state: InternalBeats accumulates, LastTime updates
- Auto-pagination: CurrentPage = floor((step-1)/4) + 1
- Empty progression: Stop() called, IsPlaying = false
- Correct MIDI calls: note-off previous chord notes, note-on current

**Effort**: HIGH (~200+ LOC test file, 8-10 scenarios, complex setup)

---

## Key Questions Answered

### Q1: Can we test sequencer.Run() deterministically?

**Yes, but with different strategies per path**:

| Path | Deterministic? | Strategy |
|------|---------------|----------|
| Not playing | ✅ Trivial | IsPlaying=false → early return |
| REAPER sync | ✅ Fully | Override GetPlayState, GetPlayPosition2, TimeMap2_timeToBeats |
| Internal clock | ✅ Yes | Sequential time_precise closure + fixed tempo |
| Catch-up loop | ✅ Yes | Set last_measure low, control measures to be higher |
| Boundary transitions | ✅ Yes | Control beats/measures to cross integer boundaries |

**What you CANNOT test**: Real-time behavior (defer loop, actual transport sync from REAPER). But the function's LOGIC is fully deterministic given controlled inputs.

**What you need**:
- `TimeMap2_timeToBeats` override that returns a specific measures value
- `GetPlayPosition2` override (return seconds, feed into TimeMap2)
- Sequential `time_precise` closure for internal clock path
- `Master_GetTempo` override returning fixed BPM

### Q2: For ExportToMidi(), do we need actual REAPER userdata?

**No**. Only truthy values are needed. Lua treats `nil` as falsy and everything else as truthy.

| Function | Return | What test needs |
|----------|--------|-----------------|
| `GetSelectedTrack` | MediaTrack or nil | `nil` → no track branch, `1` → has track |
| `GetTrack(0,0)` | MediaTrack | `1` |
| `CreateNewMIDIItemInProj` | MediaItem | `1` |
| `GetActiveTake(item)` | MediaTake | `1` |
| `GetCursorPosition` | number | `10.0` |
| `TimeMap_timeToQN` | number | `return seconds * 2` |
| `TimeMap_QNToTime` | number | `return qn / 2` |
| `MIDI_GetPPQPosFromProjQN` | number | `return qn * 1000` |
| All others | void | (default nil is fine) |

The function NEVER inspects the userdata — it passes handles through the API chain. Any truthy value satisfies the "is there a track" check, and subsequent functions only pass the value through.

**⚠️ Current issue**: All these stubs are plain `make_mock_fn` returning `nil`. For the "no track" branch, `GetTrack(0,0)` also returns nil → `CreateNewMIDIItemInProj(nil, ...)` would error. Tests MUST override these stubs.

### Q3: For ToggleIsland(), can we mock the gfx lifecycle?

**Yes, and the mocks already exist as no-ops.** The key insight:

- `gfx.quit()` in mock: does nothing (no-op)
- `gfx.init(...)` in mock: does nothing (no-op) 
- `gfx.dock(-1)` in mock: returns 0 (no-op)
- `gfx.setfont(...)` in mock: does nothing (no-op)

Since these are no-ops, calling them in tests is **safe**. The test verifies:

1. **That they were called** (need tracking on gfx.init, gfx.quit, gfx.dock, gfx.setfont)
2. **With correct arguments** (need to capture init params)
3. **In correct order** (quit before init)

**Current limitation**: `gfx.init`, `gfx.quit`, `gfx.dock`, `gfx.setfont` are NOT tracked — they're plain no-ops. Phase 3 must either:
- Add `get_mock("gfx_init")` style tracking to gfx.lua, OR
- Test by overriding: `local temp_gfx_init_called = false` pattern

**Recommendation**: Keep gfx mock simple. Don't add full tracking — instead, use override + flag pattern within the test file:

```lua
local init_called = false
gfx.init = function(title, w, h, dock, x, y)
    init_called = true
    check(title == "Scale Runner", "...")
    check(w == 720, "...")
    check(h == 793, "...")  -- or 497 depending on test
end
```

### Q4: For CheckFocus(), can we control time_precise to trigger throttle boundary?

**Yes, fully**. The pattern is already proven in `test_keyboard_handle.lua` (lines 58-65):

```lua
gfx.hwnd = 12345
reaper.JS_Window_GetFocus = function() return 12345 end
reaper.time_precise = function() return 10 end  -- bypass 0.2s throttle
keyboard.CheckFocus()
```

For testing the throttle BOUNDARY (i.e., calls within 0.2s are skipped):

```lua
-- First call: time = 10 → passes throttle (10 - 0 > 0.2)
reaper.time_precise = function() return 10 end
keyboard.CheckFocus()
check(intercept_called, "First call intercepts")

-- Second call: time = 10.1 → delta = 0.1 ← SKIPPED
reaper.time_precise = function() return 10.1 end
keyboard.CheckFocus()
-- intercept NOT called again, AllNotesOff NOT called

-- Third call: time = 10.3 → delta = 0.3 ← PASSES
reaper.time_precise = function() return 10.3 end
keyboard.CheckFocus()
-- re-evaluates focus
```

**⚠️ Gotcha**: Since `keyboard.lua` has module-level `local last_focus_check = 0` (line 10), each test file MUST clear the module cache: `package.loaded["core.keyboard"] = nil`. This is already the established pattern.

---

## Risks for Phase 3

### 🔴 HIGH: sequencer.Run() complexity

sequencer.Run() has 10+ scenarios with branching between REAPER sync and internal clock, catch-up loops, and progression-dependent behavior. A comprehensive test file is estimated at ~200 LOC with 8-10 `io.write("\n-- Scenario N\n")` blocks.

**Risk**: Time investment vs coverage ratio. The function is 73 LOC with deep nesting. Some edge cases (e.g., playing stops mid-catch-up) may not be worth testing.

**Recommendation**: Write tests for the 5 most important paths (not playing, REAPER sync silent, REAPER sync measure-advance, internal clock first tick, empty progression Stop) and mark the rest as "deferred to phase 4 if needed."

### 🟡 MEDIUM: ExportToMidi() stub override chain

ExportToMidi has a 12-function dependency chain where return values flow from one call to the next. A single wrong return type (nil vs number vs truthy) causes cascading failures.

**Risk**: Test debugging time. A nil from GetTrack crashes on CreateNewMIDIItemInProj, which is hard to trace without REAPER.

**Mitigation**: Test in two phases:
1. **Dry run**: progression scan early return (test with empty progression, verify no MIDI calls)
2. **Full run**: populate progression, override ALL needed stubs, verify MIDI_InsertNote calls

### 🟢 LOW: ToggleIsland() gfx mock tracking

gfx.init/quit are no-ops. Adding tracking OR relying on override pattern is trivial.

**Risk**: None. The override pattern (`local called = false; gfx.init = function(...) called = true end`) works perfectly for this use case.

### 🟢 LOW: CheckFocus() module isolation

Already a solved problem — `package.loaded["core.keyboard"] = nil` pattern is established and documented in tests/AGENTS.md.

### 🟡 MEDIUM: compact_store.GetLastGfxState() nil in ToggleIsland

If `last_gfx_state` was never set (e.g., Init wasn't called or defaults didn't include it), `gs` is nil and line 135 or 140 errors. Tests need to ensure compact_store is properly initialized.

**Risk for testing**: Need to call `compact_store.Init({last_gfx_state = {x=100, y=100, dock=0, w=720, h=500}})` in test setup, OR verify that main.lua's Init always provides it.

---

## Feasibility Summary

| Function | Effort | LOC estimate | Scenarios | Mock changes needed | Defer? |
|----------|--------|-------------|-----------|---------------------|--------|
| CheckFocus | LOW | ~50 | 4-5 | None (reuse existing) | No |
| ToggleIsland | MEDIUM | ~70 | 3-4 | Track gfx.init/gfx.quit or use overrides | No |
| ExportToMidi | MEDIUM | ~80 | 4 | Override 8+ stubs | No |
| sequencer.Run | HIGH | ~200 | 8-10 | Sequential time_precise, TimeMap2 override | **Maybe partial** |

### Deferral recommendation

- **Do NOT defer**: CheckFocus, ToggleIsland, ExportToMidi (all feasible, clear strategies, reasonable effort)
- **Do in Phase 3**: sequencer.Run — REAPER sync path (playing, not playing, basic measure advance)
- **Defer to Phase 4 if needed**: sequencer.Run — catch-up loop, auto-pagination edge cases, internal clock precision boundary tests

### Mock infra upgrades needed for Phase 3

1. **gfx.lua**: Make `gfx.init`, `gfx.quit`, `gfx.dock`, `gfx.setfont` trackable OR document override pattern
   - **Recommendation**: Don't add tracking to gfx.lua — the override pattern is simpler and avoids modifying a stable mock file
2. **reaper.lua**: No changes needed — all required stubs already exist. Tests override return values via function replacement (already established pattern).
3. **run.lua**: Add new test files to the `test_names` list:
   - `"test_checkfocus.lua"`
   - `"test_toggleisland.lua"`
   - `"test_exportmidi.lua"`
   - `"test_sequencer_run.lua"`

## Ready for Proposal

**Yes**. Analysis is complete with clear strategies for all four functions.

The proposal should cover:
1. Four new test files with the mock strategies above
2. Optional: gfx.lua minimal upgrade (track gfx.init args) for ToggleIsland
3. Test file registration in run.lua's `test_names` list
4. Phase split: sequencer.Run REAPER sync in Phase 3, internal clock edge cases deferred if LOC budget is tight
