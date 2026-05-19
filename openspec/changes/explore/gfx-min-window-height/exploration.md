# Exploration: Enforce Minimum Window Height on REAPER GFX Windows

## Current State

The MIDI island toggle expands the main GFX window from 720×497 to 720×793 via `gfx.quit() + gfx.init()` in `src/ui/gfx-window.lua`. The **current minimum-height enforcement** in `src/main.lua` (lines 336-349) uses the same `gfx.quit() + gfx.init()` pattern — every frame where `gfx.h < 793`, it destroys and recreates the window:

```lua
if island_store.GetMidiIslandExpanded() and gfx.h < 793 then
    local dock = gfx.dock(-1)
    local _, l, t, r, b = reaper.JS_Window_GetRect(gfx.hwnd)
    if l then
        gfx.quit()
        gfx.init(config.script_title, r - l, 793, dock, l, t)
        gfx.setfont(1, "Calibri", 16)
        gfx_needs_redraw = true
    end
end
```

**Problems with this approach:**
1. **Flicker**: Every `gfx.quit() + gfx.init()` pair destroys and recreates the HWND, causing visual white flash
2. **Position jitter**: `r - l` is used for width, but this is wrong — it gives the window width in screen coords which includes the invisible frame borders. The actual GFX client area width would be different
3. **Font reset**: `gfx.setfont` is needed after every `gfx.init()` call, adding overhead
4. **Dirty redraw**: The `gfx_needs_redraw = true` still leaves one frame with stale content
5. **During active drag**: If the user drags the resize handle, this can fire repeatedly, rapidly destroying and recreating the window many times per second

## Affected Areas

- `src/main.lua` — Lines 336-349: The current `gfx.quit()+gfx.init()` enforcement loop
- `src/ui/gfx-window.lua` — Lines 34-35: The `JS_Window_GetRect` bug (wrong capture count)
- `src/ui/midi-island.lua` — Line 75: `EXPANDED_H = 793` constant, lines 439-445: Deferred minimum height signal (not implemented)
- `src/ui/gfx-safe.lua` — Safe wrappers for GFX init/quit
- `src/state/ui.lua` — `last_window_w/h` fields
- `src/core/api-guard.lua` — Where new API checks would be added

## Affected Files Detail

| File | Lines | What |
|------|-------|------|
| `src/main.lua` | 336-349 | Current `gfx.quit()+gfx.init()` enforcement per frame |
| `src/ui/gfx-window.lua` | 34-35 | Bug: captures only 4 values from `JS_Window_GetRect` (5 returns) — first return is bool, so `l=true` |
| `src/ui/midi-island.lua` | 75, 439-445 | `EXPANDED_H` constant + deferred signal (stub, not wired) |
| `src/ui/gfx-safe.lua` | 22-28 | `SafeGfxInit` — pcall wrapper |
| `src/state/ui.lua` | 25-26, 129-132 | `last_window_w/h` getters/setters (not updated by MainLoop) |
| `src/core/api-guard.lua` | 22-35 | `AssertAPIs` — add new API checks here |

## JS_Window_GetRect Return Value Puzzle

The C++ source (`js_ReaScriptAPI.cpp` line 3137+) shows `JS_Window_GetRect` returns `bool` and fills 4 int pointers:

```cpp
bool JS_Window_GetRect(void* windowHWND, int* leftOut, int* topOut, int* rightOut, int* bottomOut)
```

In REAPER's Lua vararg wrapper, this translates to **5 return values**:
```lua
local ok, left, top, right, bottom = reaper.JS_Window_GetRect(hwnd)
```

**Current code analysis:**

| File | Capture | Actual Values | Bug? |
|------|---------|---------------|------|
| `gfx-window.lua:35` | `l, t, r, b = JS_Window_GetRect(hwnd)` | `l=bool`, `t=left`, `r=top`, `b=right` | **YES** — `l` is `true`, not the left coordinate. `gs.x = true`, `config.state.view_offset_x = true`. Passed to `gfx.init()` as xpos→coerced to 0/nil |
| `main.lua:352` | `_, l, t, r, b = JS_Window_GetRect(gfx.hwnd)` | `_=bool`, `l=left`, `t=top`, `r=right`, `b=bottom` | Correct — width is computed as `r-l` (screen coords, includes window chrome) |
| `compact-init.lua:75` | `_, left, top, right, bottom = JS_Window_GetRect(hwnd)` | correct | Correct |

**Why gfx-window.lua "works" despite the bug:** In Lua, when `true` (the bool return) is passed to `gfx.init()` as the x position, REAPER's C code calls `lua_tonumber` which returns `0` for non-numbers. Since the default `view_offset_x` is 1000, the first toggle makes the window jump to x=0, but subsequent toggles read from `config.state.view_offset_x` which is now `true` → continues to be 0. The window doesn't crash — it just appears at x=0. Since this only fires on toggle (not every frame), the position error is invisible unless you're looking for it.

## Function Inventory

### Available js_ReaScriptAPI Window Functions (relevant subset)

| Function | Signature (Lua) | Effect on GFX Window | Works? |
|----------|-----------------|---------------------|--------|
| `JS_Window_GetRect` | `bool, L, T, R, B = GetRect(hwnd)` | Returns screen coordinates (not client area). Width = R-L includes invisible frame borders | ✅ Works |
| `JS_Window_Resize` | `Resize(hwnd, w, h)` | Calls `SetWindowPos` with `SWP_NOMOVE`. Changes client size. **Does NOT prevent OS from overriding** | ❌ Won't constrain |
| `JS_Window_SetPosition` | `SetPosition(hwnd, L, T, W, H)` | Calls `SetWindowPos`. Same issue — OS can override immediately after | ❌ Won't constrain |
| `JS_Window_SetStyle` | `bool = SetStyle(hwnd, "THICKFRAME")` | Calls `SetWindowLongPtr` with `GWL_STYLE` + `ShowWindow`. Can **remove** `WS_SIZEBOX` (the resize border) entirely | ✅ Can lock size |
| `JS_Window_GetLong` | `GetLong(hwnd, "STYLE")` → number | Reads current window style via `GetWindowLongPtr` | ✅ Read current |
| `JS_Window_SetLong` | `SetLong(hwnd, "STYLE", value)` → number | Direct `SetWindowLongPtr` — allows bit-level manipulation | ✅ Direct control |
| `JS_Window_GetRoot` | `hwnd = GetRoot(hwnd)` | Gets top-level ancestor via `GetAncestor(GA_ROOT)` | ✅ Gets frame |
| `JS_Window_Update` | `Update(hwnd)` | `UpdateWindow()` — forces WM_PAINT | ✅ Useful after style change |
| `JS_Window_Enable` | `Enable(hwnd, bool)` | `EnableWindow()` — disables ALL input to window | ❌ Too aggressive |
| `JS_WindowMessage_Intercept` | `Intercept(hwnd, msg, enable)` | Hooks window proc for specific msgs. **Only supports listed WM_ constants** (LBUTTONDOWN, RBUTTONDOWN, MOUSEMOVE, etc.) | ❌ No WM_SIZING support |
| `JS_Window_AttachResizeGrip` | `AttachResizeGrip(hwnd)` | Undocumented. Adds a resize grip | Partial |

### JS_Window_SetStyle — Style Keywords from Source Code

From `JS_ConvertStringToStyle` (based on `GWLT_STYLE` on Windows):

| Keyword | Win32 Flag | Effect |
|---------|-----------|--------|
| `"THICKFRAME"` or `"SIZEBOX"` | `WS_SIZEBOX` (0x40000) | Enables resizable border — **this is what we want to toggle** |
| `"CAPTION"` | `WS_CAPTION` | Title bar |
| `"SYSMENU"` | `WS_SYSMENU` | System menu (close, etc.) |
| `"BORDER"` | `WS_BORDER` | Thin border |
| `"DLGFRAME"` | `WS_DLGFRAME` | Dialog-style frame |
| `"MAXIMIZEBOX"` | `WS_MAXIMIZEBOX` | Maximize button |
| `"MINIMIZEBOX"` | `WS_MINIMIZEBOX` | Minimize button |
| `"OVERLAPPEDWINDOW"` | `WS_OVERLAPPEDWINDOW` (= `WS_OVERLAPPED\|WS_CAPTION\|WS_SYSMENU\|WS_THICKFRAME\|WS_MINIMIZEBOX\|WS_MAXIMIZEBOX`) | Standard overlapping window |
| `"POPUP"` | `WS_POPUP` | No title bar, no border |
| `"VISIBLE"` | `WS_VISIBLE` | Visible |
| `"DISABLED"` | `WS_DISABLED` | Disabled |

**Critical implementation detail** (from C++ source lines 2089-2118): `JS_Window_SetStyle` calls `JS_Window_GetRoot` to get the **top-level ancestor** (via `GetAncestor(GA_ROOT)`), then calls `SetWindowLongPtr(rootHWND, GWL_STYLE, styleNumber)` followed by `ShowWindow(rootHWND, SW_SHOW)`. For GFX windows, `gfx.hwnd` might be a child of the actual frame — `GetRoot` gives the correct frame HWND.

## Approaches Evaluated

### Approach A: Remove/Add THICKFRAME via JS_Window_SetStyle

**How it works:**
- When island expands: `JS_Window_SetStyle(gfx.hwnd, "CAPTION BORDER SYSMENU MINIMIZEBOX")` — everything EXCEPT resize border
- When island collapses: `JS_Window_SetStyle(gfx.hwnd, "OVERLAPPEDWINDOW")` — restore full style
- The `SetWindowLongPtr` + `SetWindowPos(SWP_FRAMECHANGED)` approach is the **standard Win32 way** to make a window non-resizable

**Pros:**
- ✅ No `gfx.quit()+gfx.init()` — **zero flicker**
- ✅ No font reset needed
- ✅ No position jitter
- ✅ Works at the OS level — Windows won't even let the user drag the resize border (it disappears)
- ✅ Well-documented Win32 pattern
- ✅ Supported explicitly by juliansader in v0.991 changelog: "Can add or remove frames from gfx and other windows"

**Cons:**
- ❌ Removes ALL resize capability — the user can't freely resize the window at all while the island is expanded
- ❌ Style change via `SetWindowLongPtr` + `ShowWindow` may cause brief visual artifact (window hides/shows briefly)
- ❌ On macOS/Linux behavior may differ (SWELL instead of native Win32)
- ❌ If the function doesn't call `SetWindowPos(SWP_FRAMECHANGED)`, the frame may not update properly

**Why it might work:** The C++ source already does `JS_Window_GetRoot` for us, so `gfx.hwnd` is correctly translated to the top-level frame. `WS_SIZEBOX` removal is the correct Win32 API for this.

**Why it might fail:** The source code comment at line 2111 says: "According to stuff in the Web, SetWindowPos with FRAMECHANGED is necessary and sufficient to apply new frame style. Doesn't seem to work for me. Use ShowWindow instead." — This means the extension already tried `SWP_FRAMECHANGED` and fell back to `ShowWindow`. The `ShowWindow` call may cause a brief visual blink.

**Effort:** Low (2 calls + api-guard check)

---

### Approach B: JS_Window_SetLong to Manipulate WS_SIZEBOX Bit

**How it works:**
- Read current style: `style = reaper.JS_Window_GetLong(gfx.hwnd, "STYLE")`
- Clear the resize bit: `new_style = style & ~0x40000` (clear WS_SIZEBOX)
- Write back: `reaper.JS_Window_SetLong(gfx.hwnd, "STYLE", new_style)`
- Signal frame changed: `reaper.JS_Window_Update(gfx.hwnd)`

**Pros:**
- ✅ Full control — only toggle `WS_SIZEBOX`, keep everything else
- ✅ No window destruction
- ✅ Same end result as Approach A

**Cons:**
- ❌ Same as Approach A (lose all resize)
- ❌ Raw bit manipulation is less readable than named strings
- ❌ `SetWindowLongPtr` alone may not refresh the frame — need `SetWindowPos(SWP_FRAMECHANGED)` which `JS_Window_SetLong` doesn't call
- ❌ Even more fragile across platforms than Approach A

**Effort:** Low

---

### Approach C: JS_Window_Resize Every Frame (Debounced)

**How it works:**
- Every frame, if `gfx.h < 793`, call `JS_Window_Resize(gfx.hwnd, gfx.w, 793)`
- Debounce to ~60ms to avoid fighting OS during drag resize

**Pros:**
- ✅ No `gfx.quit()+gfx.init()` — no flicker
- ✅ Preserves all window styles (resize border stays)
- ✅ User can still resize wider or move window
- ✅ Simple implementation

**Cons:**
- ⚠️ The OS may override — during active drag, `SetWindowPos` is called but Windows can re-resize after
- ⚠️ Creates a "rubber band" effect: user drags down, window snaps back up
- ⚠️ May fight with the OS resize loop, causing jitter
- ❌ Not a true constraint — it's reactive, not preventive
- ⚠️ `JS_Window_Resize` uses `SWP_NOMOVE` which doesn't change position, but it also doesn't use `SWP_FRAMECHANGED` or re-constrain properly

**Why it might work:** If called every frame during the drag (while `gfx.h` updates live), the window size would correct itself almost instantly.

**Why it might fail:** Windows' resize loop is a modal drag operation. `SetWindowPos` called from an external thread during the resize loop may be ignored or applied after the drag ends, causing a "jump" on mouse release instead of smooth constraint.

**Effort:** Low

---

### Approach D: gfx.quit() + gfx.init() — With Position Preservation Fix

**How it works:**
- Fix the current approach by correctly preserving position and width
- Use `JS_Window_GetRect` with correct 5-value capture
- Pass left, top as-is; compute height=793; pass client width raw
- Debounce to avoid rapid re-inits during drag

**Pros:**
- ✅ Already working in codebase (just buggy)
- ✅ Same pattern as ToggleIsland
- ✅ Reliable — REAPER processes the new init correctly
- ✅ Works on all platforms

**Cons:**
- ❌ **Flicker** is inherent — `gfx.quit()` destroys the window, `gfx.init()` creates a new one
- ❌ `gfx.setfont` must be called again after every `gfx.init()`
- ❌ Position might still jump because `JS_Window_GetRect` returns screen coords (not client area), and `gfx.init()` x/y position interpretation may differ
- ❌ Window frame borders may affect the positioning calculation
- ❌ If the user is actively dragging the window border, this will kill the drag operation

**Effort:** Low (fix bug + debounce)

---

### Approach E: Combined — Style Toggle + SetPosition Debounce

**How it works (hybrid):**
1. When island expands: Remove `WS_SIZEBOX` → user can't resize at all
2. Add `JS_Window_Resize` with min height as a safety net (for the brief moment between expand and style change)
3. When island collapses: Restore `WS_SIZEBOX` → full resize capability

**Pros:**
- ✅ Best UX: resize is locked when island is expanded, fully available when collapsed
- ✅ Two layers of safety
- ✅ No flicker

**Cons:**
- ❌ More code
- ❌ Still need to test `JS_Window_SetStyle` behavior on macOS/Linux
- ❌ User might want to resize wider while island is expanded — this would be blocked

**Effort:** Medium

---

### Approach F: Alternative Architecture — Scrollable Island Content

**How it works:**
Instead of enforcing a minimum window height, make the MIDI island content scrollable within whatever height is available. The piano roll already has scroll support — if the window is shorter, add a scrollbar to the island panel.

**Pros:**
- ✅ User can freely resize the window to ANY height
- ✅ No `gfx.quit()+gfx.init()` issues
- ✅ No style manipulation
- ✅ The internal layout already supports vertical scroll in the piano roll
- ✅ More flexible: the user can choose their preferred layout

**Cons:**
- ❌ Major refactor — the current island content layout assumes fixed pixel positions for header/timeline/velocity/piano-roll
- ❌ Adding scroll to the entire island panel (not just piano roll) is significant work
- ❌ The header, timeline, velocity editor all have fixed positions that would need to be "scroll container-aware"
- ❌ Changes the interaction model significantly

**Effort:** High (architectural)

---

### Approach G: rtk.Window (REAPER Toolkit)

**How it works:**
- Port the main GFX window to use `rtk.Window` which has native `minh` and `maxh` attributes
- `rtk.Window` internally uses `js_ReaScriptAPI` to constrain the window

**Pros:**
- ✅ Native support for `minh` and `maxh` constraints
- ✅ Also gets `resizable` attribute for controlling resize capability
- ✅ Well-tested by the REAPER community
- ✅ JS_ReaScriptAPI is already a required dependency

**Cons:**
- ❌ Would require **rewriting the entire UI** — rtk has a completely different widget model than immediate-mode GFX
- ❌ Breaking change — cannot be done incrementally
- ❌ New learning curve for the codebase
- ❌ rtk's `minh` attribute only enforces on `open()` and programmatic `attr()` changes — NOT on external resize (from the rtk docs: "minh only exert any influence on the window geometry if any of the eight geometry-related attributes are changed programmatically")

**Effort:** Very High (full rewrite)

---

### Platform Support Table

| Approach | Windows | macOS | Linux |
|----------|---------|-------|-------|
| A: Remove THICKFRAME | ✅ Native Win32 `SetWindowLongPtr` | ⚠️ Uses SWELL `GetWindowLong`, may differ | ⚠️ Uses SWELL GDK |
| B: SetLong bit | ✅ `SetWindowLongPtr` | ⚠️ `SetWindowLong` via SWELL | ⚠️ Sets via SWELL |
| C: Resize per frame | ✅ `SetWindowPos` | ✅ SWELL `SetWindowPos` | ✅ SWELL `SetWindowPos` |
| D: gfx.quit()+gfx.init() | ✅ REAPER API | ✅ REAPER API | ✅ REAPER API |
| E: Hybrid | ✅ | ⚠️ | ⚠️ |
| F: Scrollable | ✅ GFX only | ✅ GFX only | ✅ GFX only |
| G: rtk rewrite | ✅ | ✅ | ✅ |

## The ToggleShortTiming Interaction

There's a subtle race condition the user may experience: after `ToggleIsland()` calls `gfx.quit()+gfx.init()`, the new `gfx.hwnd` is a **different HWND**. If the enforcement loop runs before the main loop processes the new frame, `JS_Window_GetRect` on a stale HWND could return garbage or error. The current code at line 329-333 has a guard for this (`midi_island_toggled` flag), but the enforcement at lines 340-349 does NOT check this flag. It could trigger during the transition window.

## JS_Window_SetStyle — Usage Example (from reference code in docs/)

The reference code at `docs/refenrencia_transport_bar_menú/Adaptive grid/Gridbox.lua` line 1590 shows:
```lua
reaper.JS_Window_SetStyle(gfx_hwnd, 'POPUP')
```
This confirms `JS_Window_SetStyle` IS used on GFX windows in practice.

## JS_Window_GetRoot + Style Manipulation — Win32 Caveats

From the C++ source (line 2098):
```cpp
HWND rootHWND = (HWND)JS_Window_GetRoot(windowHWND);
if (!ValidatePtr(rootHWND, "HWND")) rootHWND = (HWND)windowHWND;
```

On Windows, `GetAncestor(hwnd, GA_ROOT)` returns the top-level owner window. For a GFX window, `gfx.hwnd` is typically the REAPER-created child, and `GetRoot` returns the actual frame. So `JS_Window_SetStyle(gfx.hwnd, ...)` SHOULD correctly target the frame. Good.

However, `SetWindowLongPtr(GWL_STYLE)` + `ShowWindow(SW_SHOW)` to apply frame changes may cause:
1. The window to briefly hide and re-show (the SW_SHOW call)  
2. The window to lose its Z-order position
3. On some Windows versions, the window may need `SWP_FRAMECHANGED` to fully apply

The C++ author's own comment at line 2111 admits: "According to stuff in the Web, SetWindowPos with FRAMECHANGED is necessary and sufficient to apply new frame style. Doesn't seem to work for me."

## Recommendation

**Approach E (Hybrid: Style Toggle + SetPosition safety) is the recommended approach**, with **Approach C (Debounced Resize) as the fallback** if the style toggle causes visual artifacts.

### Primary: Remove WS_SIZEBOX via JS_Window_SetStyle

The most robust solution is toggling the resize border on/off using `JS_Window_SetStyle`. This is the **correct Win32 approach** and is explicitly supported by js_ReaScriptAPI since v0.991.

**Why this beats the alternatives:**
- No `gfx.quit()+gfx.init()` → zero flicker, no font loss, no position jitter
- The OS genuinely prevents resizing → no rubber-banding, no fighting
- Single API call per toggle — cheap
- Explicitly mentioned in js_ReaScriptAPI changelog: "Can add or remove frames from gfx and other windows"

### Implementation Caveats
1. Test with and without `JS_Window_Update(hwnd)` after the style change
2. If `JS_Window_SetStyle` causes visual artifacts (brief hide/show), fall back to Approach C
3. Add `JS_Window_Resize` with debounce as a safety net before the style change kicks in

### If Style Toggle Has Artifacts → Debounced Resize

If `JS_Window_SetStyle` causes hide/show flicker (the C++ code calls `ShowWindow` which may trigger this):

```lua
-- Debounce table (module-level, or in closure)
local min_h_debounce = 0
local MIN_H_DEBOUNCE_MS = 60

-- In MainLoop, after gfx.getchar():
if island_store.GetMidiIslandExpanded() and gfx.h < 793 then
    local now = reaper.time_precise()
    if now - min_h_debounce > MIN_H_DEBOUNCE_MS / 1000 then
        reaper.JS_Window_Resize(gfx.hwnd, gfx.w, 793)
        min_h_debounce = now
    end
end
```

This avoids fighting with the OS during the active drag loop (debounce ensures we only correct ~16 times/sec max during drag) while preventing the window from staying too small.

## Risks

1. **JS_Window_SetStyle might not work on GFX windows on macOS/Linux** — SWELL may not support `SetWindowLongPtr` style changes the same way. The cross-platform risk is real since SWELL abstracts HWND as a different structure. Mitigation: Add platform detection via `reaper.GetOS()` and fall back to Approach D (debounced resize).

2. **Window frame style update requires ShowWindow** — The C++ code calls `ShowWindow(rootHWND, SW_SHOW)` to apply the new frame style. This could briefly hide/re-show the window, causing a visual blink similar to `gfx.quit()+gfx.init()`. Mitigation: Test this; if it blinks, go with Approach C instead.

3. **User might want to resize wider while island is expanded** — Removing the resize border prevents ALL resizing, not just vertical shrinking. Mitigation: None for this approach. If wide-resize during island is desired, switch to Approach C.

4. **Z-order loss after ShowWindow** — Calling `ShowWindow` may bring the window to the top of the Z-order. Mitigation: Use `JS_Window_SetZOrder` after the style change if needed.

5. **Pixel alignment on GFX after JS_Window_Resize** — Resizing with `JS_Window_Resize` changes the GFX client area but does NOT trigger a `gfx.init()` event. `gfx.w`/`gfx.h` will update on the next `gfx.getchar()` call. If the user is currently drawing content based on stale `gfx.w`/`gfx.h`, there could be one frame of misalignment. Mitigation: The enforcement check already happens AFTER `gfx.getchar()`, so `gfx.w`/`gfx.h` should be current.

## Ready for Proposal

**Yes** — but with one caveat: Approach E (style toggle) needs empirical testing in REAPER to confirm `JS_Window_SetStyle` works without visual artifacts on GFX windows. If it does, it's the clear winner. If not, Approach C (debounced resize) is a solid fallback that's still dramatically better than the current `gfx.quit()+gfx.init()`.

Both approaches share the same first task (api-guard update for `JS_Window_SetStyle` and/or `JS_Window_Resize`), so the proposal should structure tasks to evaluate the primary approach and have the fallback ready.

## Known Bugs Discovered During Exploration

### Bug 1: gfx-window.lua JS_Window_GetRect capture
- **File**: `src/ui/gfx-window.lua:35`
- **Code**: `local l, t, r, b = reaper.JS_Window_GetRect(hwnd)`
- **Problem**: Captures 4 values from a 5-return function. `l = bool_return`, `t = actual_left`, etc.
- **Effect**: `gs.x = true` (not a number), `config.state.view_offset_x = true`. Window position resets to 0 on toggle.
- **Fix**: Change to `local _, l, t, r, b = reaper.JS_Window_GetRect(hwnd)`
