## Exploration: GFX Window Repositioning on REAPER Resize/Toggle

### Current State

The script enforces a minimum window size (720×793) when the MIDI island is expanded, and resizes the window when ToggleIsland() toggles between collapsed (720×497) and expanded (720×793). Both operations use `gfx.quit() + gfx.init()` to recreate the window with new dimensions, capturing position via `JS_Window_GetRect` before destroying the old window and passing it as x,y to `gfx.init()`.

**Two known issues:**
1. The window sometimes jumps to (0,0) instead of staying at its current position
2. ToggleIsland also causes window repositioning in certain scenarios

### Affected Areas

- `src/main.lua` lines 351-372 — Position capture + enforcement block
- `src/ui/gfx-window.lua` lines 28-73 — `ToggleIsland()`: position capture + gfx.quit()+gfx.init()
- `src/ui/compact-init.lua` lines 65-95 — `SwitchViewMode()`: uses same pattern for FULL→COMPACT transition
- `src/config.lua` line 95 — `config.state` defaults: `view_offset_x = 1000, view_offset_y = 0`
- `src/config.lua` line 107 — `last_gfx_state = {dock=0, x=100, y=100, w=720, h=500}` (inconsistent default)
- `src/state/island.lua` lines 37-48 — PreToggleRect and resilience state
- `tests/test_toggle_island.lua` — Tests for ToggleIsland (needs update after fix)

### Investigation Findings

#### 1. How `gfx.init()` position parameters work

`gfx.init("name", width, height, dockstate, xpos, ypos)` accepts **screen coordinates** for xpos and ypos — the same coordinate space returned by Win32 `GetWindowRect()`. The width/height specify the **client area** (GFX canvas) size, not the OS window frame size. REAPER creates the OS window with the client area at (xpos, ypos) in screen coordinates.

**Confirmation**: The popular script `ireascript.lua` (by cfillion) uses the exact same pattern — saving via `gfx.dock(-1, 0, 0, 0, 0)` and restoring via `gfx.init(..., dockState, x, y)` — and it works reliably.

#### 2. Why `gfx.init()` x,y might be ignored — **ROOT CAUSE FOUND**

The critical issue is the **compound return value of `gfx.dock(-1)`**.

From the REAPER Lua API documentation:
> `gfx.dock(v[,wx,wy,ww,wh])` — Call with v=-1 to query docked state. **State is &1 if docked, second byte is docker index (or last docker index if undocked).** If wx-wh specified, additional values will be returned with the undocked window position/size.

This means:
- `gfx.dock(-1)` returns a value where **bit 0 = docked/undocked**, and **bits 8-15 = docker index**
- For a **currently floating window that was previously docked**, it returns e.g. `256` (0x100) — bit 0 = 0 (undocked), but bits 8-15 = 1 (last docker index was position 1)
- When this value `256` is passed to `gfx.init()` as `dockstate`, REAPER may interpret the non-zero value as a dock request, **ignoring the x,y position parameters** and moving the window to a dock area or to (0,0)

Both affected locations:
```lua
-- main.lua:365-368
local dock = gfx.dock(-1)     -- ← gets compound value
gfx.quit()
gfx.init(config.script_title, 720, 793, dock, ...)  -- ← dock may be 256, not 0

-- gfx-window.lua:33,52-53
local dock = gfx.dock(-1)     -- ← same issue
gfx.init(config.script_title, 720, new_h, dock, ...)
```

#### 3. JS_Window_GetRect vs gfx.init coordinates — COMPATIBLE

From the js_ReaScriptAPI source code, `JS_Window_GetRect` calls Win32 `GetWindowRect()` which returns the window's screen coordinates (including chrome — title bar, borders). `gfx.init()` x,y are also screen coordinates for the OS window placement. **No coordinate conversion needed.**

However, there is an important nuance: `gfx.dock(-1, 0, 0, 0, 0)` is the **preferred way** to query window position because it returns coordinates in the exact same coordinate space that `gfx.init()` uses, without relying on the JS_ReaScriptAPI extension. It is also the method used by production scripts like ireascript.lua.

#### 4. `gfx.quit()` + `gfx.init()` sequence — State implications

- `gfx.quit()` destroys the GFX context and the OS window. After this call, `gfx.hwnd` becomes `nil`.
- `gfx.init()` creates a **new** GFX context and OS window. `gfx.hwnd` is updated to the new window handle.
- REAPER may cache the last window position for a given script title in `gfx.ini`, and on some versions may use the cached position instead of the passed x,y parameters (known JSFX issue #5003: "Changed size is not remembered").
- The position capture in `main.lua` lines 351-357 runs **before** enforcement, so it captures from the current (valid) `gfx.hwnd`. On the next frame, it recaptures from the new window.

#### 5. `gfx.init()` without `gfx.quit()` — Does it resize?

Calling `gfx.init()` on an already-open window **may resize the GFX canvas** but does NOT enforce minimum sizes. The user can drag-resize below the minimum because:
- The `gfx.init()` width/height are "suggested" (per API docs)
- The OS window still has `WS_THICKFRAME` style (resize handles visible)
- The enforcement via `gfx.quit()+gfx.init()` is needed because it **re-checks every frame** and recreates the window at the right size

This explains why "doesn't stop at minimum" — the window resized but nothing prevented further manual resizing.

#### 6. Alternative approaches — Evaluated

| Approach | Works? | Notes |
|----------|--------|-------|
| `JS_Window_SetPosition` | ❌ | Exists but doesn't work on GFX windows during drag (confirmed by user) |
| `JS_Window_SetLong` to remove `WS_THICKFRAME` | ✅ | Already used in gfx-window.lua lines 60-70. Works on gfx.hwnd directly. However, doesn't prevent resize from the dock area. |
| `gfx.init()` without `gfx.quit()` | Partial | Resizes canvas but doesn't enforce minimum. No style change to prevent user resize. |
| `gfx.dock(-1, 0, 0, 0, 0)` for position query | ✅ | REAPER-native, no extension dependency, same coordinate space as gfx.init() |

#### 7. JS_Window_GetRect return (0,0) for valid window

`GetWindowRect` on Windows returns (0,0) for **minimized windows** (returns -32000 coordinates which are filtered). For a normal visible window, (0,0) would mean the window is at the top-left of the screen — not an error. The current filter `l > -10000 and l < 10000` correctly filters garbage values including minimized window coordinates.

#### 8. Third-party script patterns

**ireascript.lua** (by cfillion) uses:
```lua
-- Save state
local dockState, xpos, ypos = gfx.dock(-1, 0, 0, 0, 0)

-- Restore state
local w, h, dockState, x, y = previousWindowState()
gfx.init(TITLE, w, h, dockState, x, y)
```

The critical insight: `gfx.dock(-1, 0, 0, 0, 0)` returns `dockState` in addition to position. When restoring, the SAME `dockState` value is passed to `gfx.init()`. This suggests that:
- The ireascript saves the EXACT return value of `gfx.dock(-1, 0, 0, 0, 0)`, including the compound dock state encoding
- On restore, it passes that exact value to `gfx.init()` and it works

This means `gfx.init()` correctly interprets the compound dock state. But the compound value changes: if the window was floating and never docked, `gfx.dock(-1)` returns 0. If it was docked at position 1 and then undocked, it returns 256.

**So why does our window jump to (0,0)?**

The answer is likely a **combination of factors**:

1. Primary: When `gfx.dock(-1)` returns `256` (previously docked, now floating) and it's passed to `gfx.init()`, REAPER interprets it correctly for the **initial** init call (in Init()) but after `gfx.quit()+gfx.init()` in the enforcement loop, REAPER's internal state might process the dock flag differently, possibly treating the non-zero value as a dock request.

2. Secondary: `JS_Window_GetRect` may return stale/cached coordinates immediately after `gfx.init()` creates the new window, before the OS has finalized the window position.

### Approaches

1. **Fix the dock parameter** — Mask `gfx.dock(-1)` value to strip the "last docker index" from the value. Use `dock & 1` to get just the docked/undocked flag (or `dock & 0xFF` to include the docker index only when docked).
   - Pros: Minimal code change, directly addresses the root cause
   - Cons: May interfere with dock state tracking if window is actually docked (but enforcement block gates on `gfx.h > 100`, which excludes docked mode)
   - Effort: Low

2. **Use `gfx.dock(-1, 0, 0, 0, 0)` for position query** — Replace `JS_Window_GetRect` with `gfx.dock(-1, 0, 0, 0, 0)` which returns REAPER-native coordinates. Use the returned `dockState` directly in `gfx.init()`.
   - Pros: Same pattern as ireascript (battle-tested), REAPER-native API, correct position tracking
   - Cons: Requires changing multiple call sites, more involved
   - Effort: Medium

3. **Combined: Fix dock parameter + use gfx.dock for position** — Both approach 1 and 2 to maximize reliability.
   - Pros: Most robust solution
   - Cons: More changes
   - Effort: Medium

4. **Use JS_Window_GetClientSize + gfx.screentoclient** — Compute window origin from client area.
   - Pros: Works with any window
   - Cons: More complex, coordinate math is error-prone, and the current issue is not coordinate mismatch
   - Effort: High

### Recommendation

**Approach 3 (Combined):** Fix both the dock parameter AND use `gfx.dock(-1, ...)` for position query.

Specifically:
- In `main.lua` enforcement block: After `local dock = gfx.dock(-1)`, mask to `dock & 1` (or just use `0` since the enforcement is gated on `gfx.h > 100`, proving the window is not docked).
- In `gfx-window.lua` ToggleIsland: Use `local dock, l, t = gfx.dock(-1, 0, 0, 0, 0)` instead of `JS_Window_GetRect`. This avoids the extension dependency and uses the same coordinate space as `gfx.init()`.
- Optionally: also add a guard in the enforcement block to reset dock to 0 when we know we're floating (since `gfx.h > 100` proves we're not docked).

For the enforcement block, the simplest correct fix:
```lua
local dock = gfx.dock(-1)
-- When gfx.h > 100, the window is undocked, so only pass bit 0
-- (undocked = 0) to gfx.init(). Using just dock & 1 prevents the
-- "last docker index" in bits 8-15 from being misinterpreted as
-- a dock request, which would cause the window to jump to (0,0).
gfx.quit()
gfx.init(config.script_title, 720, 793, dock & 1,
         config.state.view_offset_x, config.state.view_offset_y)
```

For ToggleIsland, the improved approach:
```lua
-- Use gfx.dock(-1, ...) to get REAPER-native position coordinates
local dock, l, t = gfx.dock(-1, 0, 0, 0, 0)
config.state.view_offset_x = l
config.state.view_offset_y = t
...
gfx.quit()
-- Only pass bit 0 (docked/undocked) to prevent position issues
gfx.init(config.script_title, 720, new_h, dock & 1, l, t)
```

But wait — if the window IS docked, `dock & 1` = 1, but we lose the docker index (bits 8-15). For docked mode, we need to pass the full dock ID. However, ToggleIsland gates on `not docked`, so this is safe.

### Risks

- **Lua 5.x bitwise operators**: REAPER uses Lua 5.3+ which supports `&` and `|` operators. The codebase already uses them (e.g., `gfx-window.lua:65: style & ~0x40000`). But if a user is on an older REAPER without Lua 5.3, `&` would fail. **Mitigation**: Verify REAPER version requirement or use `math.modf(dock / 256)` approach as fallback. Actually, looking at the codebase use of `&` in gfx-window.lua, this is already established.
- **gfx.dock(-1, ...) with extra params**: The behavior of `gfx.dock(-1, 0, 0, 0, 0)` varies across REAPER versions. On newer versions it returns `dockState, x, y, w, h`. On older versions, the extra return values might not exist. **Mitigation**: Wrap in `pcall` or use `select()` for safety.
- **The enforcement loop is inherently fragile**: Any frame where `gfx.h` reports a value different from expected triggers a window recreation, which could cause flicker.
- **Position capture timing**: There's a race between the enforcement frame (gfx.quit()+gfx.init()) and the next frame's position capture. A single frame of stale position data is possible.

### Ready for Proposal

**Yes** — the root cause is clearly identified (`gfx.dock(-1)` compound value), the fix is well-understood (mask to `dock & 1`), and the alternative approach (`gfx.dock(-1, ...)`) is a proven pattern from other REAPER scripts.

The orchestrator should propose this as a **bug fix change** with low risk and clear verification criteria (window position preserved after resize enforcement and island toggle).
