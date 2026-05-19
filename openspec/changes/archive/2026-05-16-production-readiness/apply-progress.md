# Batch 5 Implementation Progress

## Change: production-readiness-fixes
**Batch**: 5 (UX Edge Cases)
**Date**: 2026-05-16
**Tasks**: 2

---

## Task 1: `compact-menu.lua` — wheel zero after gfx.showmenu

**Status**: ✅ **Already fixed** (no-op)

**Details**:
- Line 59: `gfx.mouse_wheel = 0` already present immediately after `gfx.showmenu()` call on line 57.
- This fix was implemented in an earlier batch (likely Batch 2).
- No changes needed.

---

## Task 2: `compact-intercept.lua` — right-click intercept release on button release

**Status**: ✅ **Implemented**

**File**: `src/ui/compact-intercept.lua`

**Change**:
Added frame-based detection after the existing intercept logic (after line 78):

```lua
-- Batch 5: Detectar liberación del botón derecho incluso si el mouse no se mueve
-- Si el intercept está activo pero el botón ya no está presionado, liberar
if intercept_active_r and (gfx.mouse_cap & 2) == 0 then
    reaper.JS_WindowMessage_Release(hwnd, "WM_RBUTTONDOWN")
    intercept_active_r = false
end
```

**Purpose**:
- Detects when right mouse button is released even if mouse cursor stays on the compact bar.
- Previous logic only released on mouse move OFF the bar or post-menu guard window.
- New check runs every frame, ensures intercept is released when button is no longer pressed.

---

## Summary

- **Total tasks**: 2
- **Already fixed**: 1
- **Newly implemented**: 1
- **All tasks complete**: Yes

---

## Technical Notes

**Dual-context compliance**: Both fixes adhere to the dual GFX context rule:
- `compact-menu.lua`: wheel zero after menu in COMPACT mode only (temp window)
- `compact-intercept.lua`: release detection runs in MainLoop's ProcessMouseInterception call

No changes to existing behavior, only additions as per implementation instructions.
