# Proposal: Window Repositioning Fix

## Intent

Every action that recreates the GFX window (MIDI Island toggle, size enforcement at min bounds, COMPACT↔FULL switch) causes the window to jump position. `gfx.init()` treats (x, y) as hints — the OS window manager and `gfx.ini` cache override them. The window should stay where the user put it.

## Scope

### In Scope
- Create `RecreateMainWindow(w, h, x, y, dock)` in `gfx-safe.lua` — captures current position, calls `gfx.quit()` + `gfx.init()`, forces position via `JS_Window_SetPosition`, restores title
- Replace 3 call sites: `main.lua:374` (size enforcement), `gfx-window.lua:53` (ToggleIsland), `compact-init.lua:97` (SwitchViewMode)
- Guard `JS_Window_SetPosition` with `CheckAPI()` + graceful fallback
- Remove duplicated position-capture logic across all 3 sites

### Out of Scope
- Fix `last_gfx_state` mutation-by-reference in ToggleIsland (separate concern, already mitigated)
- Dock-mode window positioning (docked windows ignore x/y entirely)
- New ExtState keys or schema changes

## Capabilities

### New Capabilities
None — pure infrastructure refactor, no new user-facing behavior.

### Modified Capabilities
None — no spec-level behavior changes. Window position stability is a bugfix, not a new requirement. Existing specs (`system-behaviors`, `ui`) are unaffected.

## Approach

1. **Add `RecreateMainWindow(w, h, x, y, dock?)` to `gfx-safe.lua`**:
   - Capture current position via `gfx.hwnd → JS_Window_GetRect` (safety-clamped like `main.lua:359-365`)
   - Fall back to `ui_store.GetViewOffsetX/Y()` if HWND unavailable
   - Generate unique temp title (`config.script_title .. reaper.time_precise()`)
   - `gfx.quit()` → `gfx.init(uid, w, h, dock or 0, x, y)` → `gfx.setfont(1, "Calibri", 16)`
   - If `JS_Window_SetPosition` exists: force position with it
   - Restore original title via `JS_Window_SetTitle(gfx.hwnd, config.script_title)`
   - Persist new offset to `ui_store.SetViewOffsetX/Y()` + `persist.Save()`
   - Return `ok, err` (pcall wrapped)

2. **Replace call sites**:
   - `main.lua:374-376` → `RecreateMainWindow(720, min_h, ox, oy, 0)`
   - `gfx-window.lua:51-57` → `RecreateMainWindow(720, new_h, ox, oy, 0)`
   - `compact-init.lua:97` → `RecreateMainWindow(gs.w, gs.h, gs.x, gs.y, gs.dock)`

3. **Guard**: `RecreateMainWindow` internally checks `CheckAPI("JS_Window_SetPosition")` — if missing, skips position forcing and returns success with no side effects beyond the normal `gfx.init()`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/gfx-safe.lua` | Modified | Add `RecreateMainWindow()` helper |
| `src/main.lua` (L374) | Modified | Replace inline gfx.quit+init with helper |
| `src/ui/gfx-window.lua` (L51-57) | Modified | Replace inline gfx.quit+init with helper |
| `src/ui/compact-init.lua` (L97) | Modified | Replace SafeGfxInit with helper |
| `src/state/ui.lua` | Unchanged | view_offset_x/y already exposed via getters |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `JS_Window_SetPosition` missing in old js_ReaScriptAPI | Medium | `CheckAPI()` guard + graceful fallback (current behavior) |
| Post-init position set could cause 1-frame visual flicker | Low | Flicker already exists from gfx.quit+init; position set is same frame |
| `dock` parameter mismatch for SwitchViewMode | Low | `compact-init.lua` already passes `gs.dock`; helper signature includes `dock?` defaulting to 0 |

## Rollback Plan

1. Revert `gfx-safe.lua` to remove `RecreateMainWindow`
2. Revert the 3 call sites to their original inline `gfx.quit()` + `gfx.init()` patterns
3. No schema or state changes — pure code revert

## Dependencies

- `JS_Window_SetPosition` from js_ReaScriptAPI (already listed in api-guard as optional)
- `JS_Window_SetTitle` (already used at all 3 call sites)

## Success Criteria

- [ ] Window does not jump position on MIDI Island toggle (expand/collapse)
- [ ] Window does not jump position on size enforcement at min bounds
- [ ] Window does not jump position on COMPACT↔FULL switch
- [ ] `JS_Window_SetPosition` missing → falls back silently to current behavior
- [ ] No regression in docked mode (window positioning is a no-op)
- [ ] All 3 call sites use `RecreateMainWindow` — no duplicate inline patterns remain
