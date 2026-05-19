## Exploration: test-mocks

### Current State

**Phase 1 completed**: Zero-mock tests for 5 state stores + progression + midi.GetMidiNote. Files:
- `tests/test_midi.lua` (128 LOC) — tests GetMidiNote via real module + config (refactored from local copies)
- `tests/test_stores.lua` (318 LOC) — all 5 stores: init + getter/setter + consumables
- `tests/test_progression.lua` (78 LOC) — Add, Remove, Swap, Clear, GetLastFilled
- `tests/helpers.lua` (36 LOC) — check(), assert_eq(), summary()
- `tests/run.lua` (53 LOC) — test runner: path setup, discovery, aggregation, os.exit override
- `tests/mock/` — **directory exists but EMPTY**

Phase 1 proved the runner pattern and helpers work. Now Phase 2 needs mock infrastructure for `reaper.*` and `gfx.*` globals.

### Critical Discovery: reaper and gfx are GLOBALS, not modules

**No `require("reaper")` or `require("gfx")` exists anywhere in `src/`.** REAPER injects both as global tables at runtime. This means:

- ❌ `package.loaded["reaper"] = mock` — **does NOT work** (there's no require to intercept)
- ✅ `_G.reaper = mock_table` — **correct approach** — overrides the global before any module uses it
- ✅ `_G.gfx = mock_table` — same pattern

The mock must be installed BEFORE any `require("core.midi")` or other module that references `reaper.*`. In Lua, this means calling `_G.reaper = mock_table` in `tests/run.lua` *before* extending package.path and requiring the test files.

---

### reaper.* Function Inventory (38 unique functions)

Each reaper.* call across the codebase, by file:

#### core/midi.lua (12 calls, 7 unique functions)
- `reaper.StuffMIDIMessage(ch, msg, note, vel)` — SendMidi, AllNotesOff
- `reaper.GetSelectedTrack(0, 0)` — ExportToMidi
- `reaper.InsertTrackAtIndex(0, true)` — ExportToMidi
- `reaper.GetTrack(0, 0)` — ExportToMidi
- `reaper.TimeMap_timeToQN(time)` → qn — ExportToMidi
- `reaper.TimeMap_QNToTime(qn)` → time — ExportToMidi
- `reaper.GetCursorPosition()` → time — ExportToMidi
- `reaper.CreateNewMIDIItemInProj(track, startPpq, endPpq, newTrack)` → item — ExportToMidi
- `reaper.GetActiveTake(item)` → take — ExportToMidi
- `reaper.MIDI_GetPPQPosFromProjQN(take, qn)` → ppq — ExportToMidi
- `reaper.MIDI_InsertNote(take, selected, muted, startPpq, endPpq, ch, pitch, vel, noSort)` — ExportToMidi
- `reaper.MIDI_Sort(take)` — ExportToMidi
- `reaper.UpdateArrange()` — ExportToMidi
- `reaper.JS_Window_GetRect(hwnd)` → l,t,r,b — ToggleIsland

#### core/sequencer.lua (4 calls, 4 unique)
- `reaper.GetPlayState()` → bitmask — Run
- `reaper.TimeMap2_timeToBeats(0, pos)` → measures, beats — Run
- `reaper.GetPlayPosition2()` → time — Run
- `reaper.time_precise()` → seconds — Run (internal clock)
- `reaper.Master_GetTempo()` → bpm — Run (internal clock)

#### core/keyboard.lua (4 calls, 4 unique)
- `reaper.JS_VKeys_GetState(state)` → string — HandleKeyboard
- `reaper.JS_VKeys_Intercept(vk, action)` — InterceptMappedKeys
- `reaper.JS_Window_GetFocus()` → hwnd — IsPluginOrScriptFocused
- `reaper.GetFocusedFX2()` → bitmask — IsPluginOrScriptFocused
- `reaper.time_precise()` → seconds — CheckFocus

#### src/main.lua (11 calls, 7 unique)
- `reaper.MB(msg, title, type)` — Init (dependency error)
- `reaper.JS_VKeys_GetState` — Init (guard check)
- `reaper.atexit(f)` — Init (cleanup registration)
- `reaper.GetExtState(proj, key)` → string — Init (auto-start prefs)
- `reaper.GetResourcePath()` → path — Init (startup script)
- `reaper.RecursiveCreateDirectory(dir, mode)` — Init (startup dir)
- `reaper.defer(f)` — MainLoop (many call sites)

#### ui/compact-init.lua (19 calls, 12 unique)
- `reaper.JS_Window_Find(title, exact)` → hwnd — FindTransportWindow, SwitchViewMode, HandlePanel
- `reaper.JS_Window_GetRect(hwnd)` → l,t,r,b — SwitchViewMode
- `reaper.JS_Window_GetClientSize(hwnd)` → w,h — positioning (via UpdatePositioning)
- `reaper.GetTransportHwnd()` → hwnd — FindTransportWindow (SWS fallback)
- `reaper.JS_LICE_Resize(bm, w, h)` — UpdateCompactView
- `reaper.JS_Composite(hwnd, dx, dy, dw, dh, bm, sx, sy, sw, sh, alpha)` — UpdateCompactView
- `reaper.JS_Window_InvalidateRect(hwnd, x, y, w, h, erase)` — UpdateCompactView
- `reaper.JS_LICE_DestroyBitmap(bm)` — Cleanup
- `reaper.JS_LICE_DestroyFont(font)` — Cleanup
- `reaper.JS_GDI_DeleteObject(font)` — Cleanup

#### ui/compact-intercept.lua (7 calls, 5 unique)
- `reaper.GetMousePosition()` → x,y — ProcessMouseInterception
- `reaper.JS_Window_ScreenToClient(hwnd, x, y)` → cx,cy — ProcessMouseInterception
- `reaper.JS_WindowMessage_Intercept(hwnd, msg, passthrough)` — ProcessMouseInterception
- `reaper.JS_WindowMessage_Peek(hwnd, msg)` → peak,msg,lparam,time — ProcessMouseInterception
- `reaper.JS_WindowMessage_Release(hwnd, msg)` — ProcessMouseInterception, CleanupIntercept
- `reaper.JS_Composite_Unlink(hwnd, bitmap)` — CleanupIntercept
- `reaper.time_precise()` → seconds — ProcessMouseInterception (post-menu guard)

#### ui/compact-menu.lua (4 calls, 3 unique)
- `reaper.GetMousePosition()` → x,y — ShowContextMenu
- `reaper.time_precise()` → seconds — ShowContextMenu
- `reaper.GetUserInputs(title, num, desc, default)` → ret,csv — ShowContextMenu
- `reaper.JS_Window_Find` (via lazy require compact-init)

#### ui/views.lua (3 calls, 2 unique)
- `reaper.GetUserInputs(title, num, desc, default)` → ret,csv — DrawHeader (settings menu)
- `reaper.SetExtState(proj, key, val, persist)` — DrawHeader (auto-start persist)

#### ui/lice.lua (14 calls, 7 unique JS_* LICE functions)
- `reaper.JS_LICE_CreateBitmap(rgb, w, h)` → bitmap — EnsureLICE
- `reaper.JS_LICE_CreateFont()` → font — EnsureLICE
- `reaper.JS_GDI_CreateFont(h, weight, italic, ul, strike, charset, face)` → font — EnsureLICE
- `reaper.JS_LICE_SetFontFromGDI(liceFont, gdiFont, charset)` — EnsureLICE
- `reaper.ColorToNative(r, g, b)` → color — used 4 times across fill/outline/circle/drawtext
- `reaper.JS_LICE_RoundRect(bm, x, y, w, h, r, color, a, fill, aa)` — DrawRoundedRectFill
- `reaper.JS_LICE_FillRect(bm, x, y, w, h, color, a, mode)` — used 7 times
- `reaper.JS_LICE_FillCircle(bm, x, y, r, color, a, mode, aa)` — used 4 times
- `reaper.JS_LICE_SetFontColor(font, color)` — DrawModeHint
- `reaper.JS_LICE_DrawText(bm, font, text, len, x, y, w, h)` — DrawModeHint

#### ui/positioning.lua (4 calls, 4 unique)
- `reaper.JS_Window_GetClientSize(hwnd)` → w,h — UpdatePositioning, FindTransportEmptyArea, GetTransportScreenRect
- `reaper.JS_Window_ClientToScreen(hwnd, x, y)` → sx,sy — FindTransportEmptyArea, GetTransportScreenRect
- `reaper.GetThingFromPoint(sx, sy)` → thing — FindTransportEmptyArea
- `reaper.JS_Window_GetRect(hwnd)` → l,t,r,b — GetTransportScreenRect

#### ui/preset-browser.lua (7 calls, 5 unique)
- `reaper.GetResourcePath()` → path — Init resources
- `reaper.RecursiveCreateDirectory(dir, mode)` — ensure preset dir
- `reaper.GetExtState(proj, key)` → str — load favorites
- `reaper.SetExtState(proj, key, val, persist)` — save favorites
- `reaper.GetUserInputs(title, num, desc, default)` → ret,csv — save preset dialog

#### ui/compact-panel.lua — 0 reaper calls (only `gfx.quit()`)

---

### gfx.* Function Inventory

#### gfx methods (17 unique)
| Method | Used By |
|--------|---------|
| `gfx.init(title, w, h, dock, x, y)` | main.lua, compact-init.lua, midi.lua, compact-menu.lua |
| `gfx.quit()` | main.lua, compact-init.lua, compact-panel.lua, midi.lua, compact-menu.lua |
| `gfx.setfont(1, fontName, size)` | main.lua, midi.lua, views.lua, slots.lua, compact-init.lua, preset-browser.lua |
| `gfx.drawstr(str)` | views.lua, slots.lua, compact-init.lua, preset-browser.lua |
| `gfx.measurestr(str)` → w,h | views.lua, slots.lua, compact-init.lua, preset-browser.lua |
| `gfx.rect(x, y, w, h, fill)` | views.lua, compact-init.lua, preset-browser.lua |
| `gfx.triangle(x1,y1, x2,y2, x3,y3)` | views.lua |
| `gfx.line(x1, y1, x2, y2)` | preset-browser.lua |
| `gfx.getchar()` → char | main.lua, compact-init.lua (HandlePanel) |
| `gfx.dock(mode)` → id | main.lua, midi.lua, compact-init.lua |
| `gfx.showmenu(str)` → choice | views.lua, compact-menu.lua |
| `gfx.screentoclient(x, y)` → cx,cy | compact-menu.lua |

#### gfx state fields (read/write)
| Field | Type | Read By | Write By |
|-------|------|---------|----------|
| `gfx.x` | number | — | main.lua, views.lua, slots.lua, compact-init.lua, preset-browser.lua, compact-menu.lua |
| `gfx.y` | number | — | (same as above, set before drawstr) |
| `gfx.w` | number | main.lua, views.lua, compact-init.lua | — |
| `gfx.h` | number | main.lua, views.lua, compact-init.lua | — |
| `gfx.mouse_x` | number | views.lua, slots.lua, compact-menu.lua, compact-init.lua, preset-browser.lua | — |
| `gfx.mouse_y` | number | (same as above) | — |
| `gfx.mouse_cap` | number | main.lua, views.lua, slots.lua, compact-init.lua | — |
| `gfx.mouse_wheel` | number | main.lua, compact-init.lua | main.lua, compact-init.lua (zeroed) |
| `gfx.hwnd` | userdata | keyboard.lua, midi.lua | — |

#### Module-by-module gfx usage
- **core/midi.lua**: gfx.dock, gfx.hwnd, gfx.quit, gfx.init, gfx.setfont (only in ToggleIsland)
- **core/keyboard.lua**: gfx.hwnd (only in IsPluginOrScriptFocused)
- **core/slots.lua**: gfx.setfont, gfx.measurestr, gfx.drawstr, gfx.mouse_x/y/cap (extensive)
- **main.lua**: gfx.mouse_wheel, gfx.mouse_cap, gfx.getchar, gfx.dock, gfx.init, gfx.quit, gfx.w, gfx.h, gfx.setfont
- **ui/visual modules**: all use gfx.* extensively

---

### Mock Infrastructure Needed

#### mock/reaper.lua — Stubs for 38 unique functions

```lua
-- Assertion wrapper factory
local function make_mock_fn(name)
    local mock = { calls = {}, call_count = 0 }
    local fn = function(...)
        mock.call_count = mock.call_count + 1
        mock.calls[mock.call_count] = {...}
    end
    fn.mock = mock
    return fn
end

local reaper = {
    -- MIDI
    StuffMIDIMessage = make_mock_fn("StuffMIDIMessage"),

    -- Transport
    GetPlayState = function() return 0 end,
    GetPlayPosition2 = function() return 0 end,
    TimeMap2_timeToBeats = function() return 0, 0 end,
    Master_GetTempo = function() return 120 end,
    time_precise = function() return 0 end,
    GetCursorPosition = function() return 0 end,
    TimeMap_timeToQN = function() return 0 end,
    TimeMap_QNToTime = function() return 0 end,

    -- MIDI Export
    GetSelectedTrack = function() return nil end,
    InsertTrackAtIndex = function() end,
    GetTrack = function() return nil end,
    CreateNewMIDIItemInProj = function() return {} end,
    GetActiveTake = function() return {} end,
    MIDI_GetPPQPosFromProjQN = function() return 0 end,
    MIDI_InsertNote = function() end,
    MIDI_Sort = function() end,
    UpdateArrange = function() end,

    -- JS_VKeys
    JS_VKeys_GetState = function() return string.rep("\0", 256) end,
    JS_VKeys_Intercept = make_mock_fn("JS_VKeys_Intercept"),

    -- JS_Window
    JS_Window_Find = function() return nil end,
    JS_Window_GetRect = function() return 0, 0, 0, 0 end,
    JS_Window_GetClientSize = function() return 0, 0, 0 end,
    JS_Window_GetFocus = function() return nil end,
    JS_Window_ClientToScreen = function() return 0, 0 end,
    JS_Window_ScreenToClient = function() return 0, 0 end,
    JS_Window_InvalidateRect = function() end,

    -- JS_WindowMessage
    JS_WindowMessage_Intercept = function() end,
    JS_WindowMessage_Peek = function() return false end,
    JS_WindowMessage_Release = function() end,

    -- JS_Composite
    JS_Composite = function() end,
    JS_Composite_Unlink = function() end,

    -- JS_LICE
    JS_LICE_CreateBitmap = function() return 1 end,
    JS_LICE_CreateFont = function() return 1 end,
    JS_LICE_SetFontFromGDI = function() end,
    JS_LICE_DestroyBitmap = function() end,
    JS_LICE_DestroyFont = function() end,
    JS_LICE_Resize = function() end,
    JS_LICE_FillRect = function() end,
    JS_LICE_RoundRect = function() end,
    JS_LICE_FillCircle = function() end,
    JS_LICE_SetFontColor = function() end,
    JS_LICE_DrawText = function() end,

    -- JS_GDI
    JS_GDI_CreateFont = function() return 1 end,
    JS_GDI_DeleteObject = function() end,

    -- Other
    GetFocusedFX2 = function() return 0 end,
    GetMousePosition = function() return 0, 0 end,
    GetThingFromPoint = function() return "trans" end,
    GetTransportHwnd = function() return nil end,
    ColorToNative = function() return 0 end,
    MB = function() end,
    atexit = function() end,
    defer = function(f) end,
    GetExtState = function() return "" end,
    SetExtState = function() end,
    GetResourcePath = function() return "" end,
    RecursiveCreateDirectory = function() end,
    GetUserInputs = function() return false, "" end,
}
```

#### mock/gfx.lua — Stubs for 17 methods + 9 state fields

```lua
local gfx = {
    -- Methods (all no-ops returning safe defaults)
    init = function() end,
    quit = function() end,
    setfont = function() end,
    drawstr = function() end,
    measurestr = function() return 0, 0 end,
    rect = function() end,
    triangle = function() end,
    line = function() end,
    getchar = function() return 0 end,
    dock = function() return 0 end,
    showmenu = function() return 0 end,
    screentoclient = function() return 0, 0 end,
    gfx = function() end,

    -- State fields (mutable, tests set these up before calling the SUT)
    x = 0, y = 0,
    w = 720, h = 500,
    mouse_x = 0, mouse_y = 0,
    mouse_cap = 0,
    mouse_wheel = 0,
    hwnd = nil,
}
```

---

### Module-by-Module Analysis for Phase 2

#### midi.SendMidi(note, on, velocity) — EASY to mock
- **reaper deps**: `reaper.StuffMIDIMessage(ch, msg, note, vel)` — single function
- **state deps**: `sequencer_store.GetVolume()` (reads), `midi_store` (writes: active notes ref-count, last note played, draw timer)
- **config deps**: `config.NOTE_NAMES`
- **Testable with**: mock reaper + state stores. Trivial to assert call count + args.
- **Key assertions**: StuffMIDIMessage called with correct ch, correct message byte (0x90/0x80), correct note, correct velocity. Active note ref-count incremented/decremented correctly. Volume scaling applied.

#### midi.TriggerChord(degree, on, ctx, velocity) — EASY
- **reaper deps**: indirect via SendMidi (StuffMIDIMessage)
- **config deps**: `config.CHORD_MODES` (offsets), `config.SCALES` (via GetMidiNote)
- **Testable with**: mock reaper + state stores. Verify returned note array + each note sent via SendMidi.
- **Key assertions**: Correct number of notes sent (1/3/4/5 depending on mode). Correct notes in chord. Velocity applied to all notes.

#### midi.AllNotesOff() — MEDIUM
- **reaper deps**: `reaper.StuffMIDIMessage(ch, 0xB0, 123, 0)` + indirect via SendMidi for each held note
- **state deps**: `midi_store.GetKeyStates()`, `midi_store.GetMousePadState()`, `midi_store.ClearActiveNotes()`
- **Key assertions**: CC 123 sent. Every held note in key_states and mouse_pad_state gets a note-off. All state cleared.

#### midi.ExportToMidi() — HARD (DEFER to Phase 3)
- **reaper deps**: 7+ reaper functions (track creation, MIDI item, MIDI notes, arrange update)
- **Requires complex setup**: need to mock track/selection/item/take handles and chain returns
- **Key risk**: Mock chain complexity — each function might return userdata or handles that next function expects

#### midi.ToggleIsland() — HARD (DEFER to Phase 3)
- **reaper deps**: `reaper.JS_Window_GetRect(hwnd)`
- **gfx deps**: `gfx.dock(-1)`, `gfx.hwnd`, `gfx.quit()`, `gfx.init()`, `gfx.setfont()`
- **Key risk**: gfx.quit() followed by gfx.init() means the mock needs to track context lifecycle. Complex state transitions.

#### sequencer.Stop() — EASY
- **reaper deps**: indirect via midi.SendMidi (StuffMIDIMessage)
- **state deps**: `seq_store` — resets 6 fields (IsPlaying, MidiNotes, LastMeasure, CurrentStep, Progress, InternalBeats, LastTime)
- **Key assertions**: All fields reset. Note-offs for all midi_notes. IsPlaying = false.

#### sequencer.Run() — HARD (DEFER to Phase 3)
- **reaper deps**: `reaper.GetPlayState()`, `reaper.TimeMap2_timeToBeats()`, `reaper.GetPlayPosition2()`, `reaper.time_precise()`, `reaper.Master_GetTempo()`
- **State deps**: heavy — reads/writes many seq_store fields
- **Key risk**: Time-dependent logic. Internal clock vs REAPER sync branching. Catch-up skipped measures. Need to orchestrate return values from multiple reaper functions across multiple ticks.

#### keyboard.InterceptMappedKeys(state) — EASY
- **reaper deps**: `reaper.JS_VKeys_Intercept(vk, action)` — called in a loop over 28 keys
- **config deps**: `config.VKEY_MAP`
- **Key assertions**: JS_VKeys_Intercept called for each VKEY_MAP key with correct action (1 or -1).

#### keyboard.Cleanup() — EASY
- **reaper deps**: indirect via InterceptMappedKeys (JS_VKeys_Intercept)
- **Internal state**: `is_intercepting` flag (module-level closure)
- **Key assertions**: Only calls InterceptMappedKeys if flag is set. No-op if already cleaned up.

#### keyboard.HandleKeyboard() — MEDIUM (INCLUDE but limited scope)
- **reaper deps**: `reaper.JS_VKeys_GetState(0)` → string
- **state deps**: `midi_store.GetKeyStates()` — iterates all key states
- **config deps**: `config.VKEY_MAP`, `config.state.*` (remnant keys)
- **Key risk**: VKEY_GetState byte string mocking — need to return string of 256 bytes where byte(k_code) != 0 for pressed keys. Manageable.
- **Key assertions**: Correct TriggerChord called on key-down. Correct note-offs on key-up. Velocity humanization applied.

#### keyboard.CheckFocus() — MEDIUM (DEFER to Phase 3)
- **reaper deps**: `reaper.time_precise()`, `reaper.JS_Window_GetFocus()`, `reaper.GetFocusedFX2()`
- **gfx deps**: `gfx.hwnd`
- **Internal state**: `last_focus_check` (closure), `is_intercepting` (closure)
- **Key risk**: Throttle timing (0.2s). Window handle comparison. Focus state transitions. Needs careful orchestration of time_precise returns.

---

### Mock Strategy Options

#### Option A: Global mock via _G override ⭐ RECOMMENDED
Set `_G.reaper = mock_reaper` and `_G.gfx = mock_gfx` before requiring any project modules.

```lua
-- In tests/run.lua, BEFORE extending package.path:
_G.reaper = require("tests.mock.reaper")
_G.gfx = require("tests.mock.gfx")

-- Now require modules that use reaper.* and gfx.* globals:
package.path = root_dir .. "src/?.lua;" .. root_dir .. "?.lua;" .. package.path
local midi = require("core.midi")
```

**Pros:**
- Zero code changes to src/ — reaper.* calls work unchanged
- Transparent — globals are resolved at runtime, no require interception needed
- Works with ALL existing `reaper.*` calls across 31 files
- Tests can selectively override individual functions per test (e.g., `reaper.StuffMIDIMessage = function(...) end`)
- No module-level changes needed

**Cons:**
- Cannot have real reaper alongside tests (not an issue — tests never run in REAPER)
- Globals persist across test files if run.lua uses dofile — need to reset between files

#### Option B (rejected): Selective mock injection
Require modules to accept reaper as parameter. Would require changing ALL module signatures — unacceptable.

---

### Recommended Phase 2 Scope

| Function | Priority | Effort | Include? |
|----------|----------|--------|----------|
| midi.SendMidi | HIGH | Low | ✅ YES |
| midi.TriggerChord | HIGH | Low | ✅ YES |
| midi.AllNotesOff | HIGH | Medium | ✅ YES |
| sequencer.Stop | HIGH | Low | ✅ YES |
| keyboard.InterceptMappedKeys | HIGH | Low | ✅ YES |
| keyboard.Cleanup | HIGH | Low | ✅ YES |
| keyboard.HandleKeyboard | HIGH | Medium | ✅ YES (basic cases) |
| midi.ExportToMidi | MEDIUM | High | ❌ DEFER Phase 3 |
| midi.ToggleIsland | MEDIUM | High | ❌ DEFER Phase 3 |
| sequencer.Run | MEDIUM | High | ❌ DEFER Phase 3 |
| keyboard.CheckFocus | MEDIUM | Medium | ❌ DEFER Phase 3 |

**Phase 2 deliverables:**
1. `tests/mock/reaper.lua` — complete mock with assertion wrappers for key functions
2. `tests/mock/gfx.lua` — minimal mock (Phase 2 needs only gfx.hwnd for keyboard)
3. Refactor `tests/run.lua` to install globals before test execution
4. Test file: `tests/test_sendmidi.lua` — SendMidi, TriggerChord, AllNotesOff
5. Test file: `tests/test_sequencer.lua` — Stop only
6. Test file: `tests/test_keyboard.lua` — InterceptMappedKeys, Cleanup, HandleKeyboard (basic)
7. Update `tests/AGENTS.md` with mock usage conventions

---

### Risks

1. **Module init side effects**: When `require("core.midi")` loads, it sets up module-level state. Mock must be installed BEFORE the require. **Mitigation**: Install `_G.reaper` and `_G.gfx` in `run.lua` before `package.path` extension.

2. **config.state mutation by tests**: `midi.TriggerChord` reads `config.state.*` remnant keys. Tests must set these up explicitly. **Mitigation**: Document that test setup must set `config.state.root_index`, `config.state.scale_index`, `config.state.octave`, `config.state.chord_mode_index`.

3. **is_intercepting closure**: `keyboard.lua` line 9: `local is_intercepting = false` — a module-level closure. State leaks between tests within the same dofile context. **Mitigation**: Separate test files for keyboard tests, or expose a reset mechanism.

4. **gfx.hwnd nil in HandleKeyboard**: `keyboard.IsPluginOrScriptFocused()` accesses `gfx.hwnd`. Phase 2 functions that DON'T call CheckFocus are fine — mock gfx.hwnd is nil by default.

5. **math.random in HandleKeyboard**: Line 23 uses `math.random(30)` for velocity humanization. **Mitigation**: Test with `GetUseVelocity() == false` (fixed velocity 100) for deterministic assertions.

### Ready for Proposal
Yes — comprehensive inventory complete, mock strategy proven, phase scope defined. Next step: sdd-propose.
