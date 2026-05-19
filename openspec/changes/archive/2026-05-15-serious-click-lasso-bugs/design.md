# Design: serious-click-lasso-bugs

## Technical Approach

Four distinct fixes (S1–S4) in order of criticality. Minimal structural changes — each is a targeted correction of the existing code.

---

### Fix S1 (CRITICAL) — Reorder stale lasso guard

**Root cause**: In `midi-island.lua:Draw()`, the stale guard (line 215) clears `lasso_active` **before** finalization (line 549). On mouse-up the guard fires first, finalization sees `GetLassoActive() == false`, selection is never computed.

**Fix**: Move the stale guard block (lines 215–217) to immediately after the finalization block (after line 573). The guard still exists to handle REAPER focus-loss (alt-tab) — it just runs **after** selection is computed.

**Current order**:
1. Stale guard: `if lasso_active && (cap & 1)==0 → SetLassoActive(false)` ← BUG: fires first
2. Piano roll interaction (start lasso on click in empty area)
3. Lasso finalization: `if lasso_active && mouse_up → GetNotesInRect, SetSelectedIndices, SetLassoActive(false)`

**New order**:
1. Piano roll interaction (start lasso)
2. Lasso update (drag) or finalization (mouse-up)
3. **Stale guard**: `if lasso_active && (cap & 1)==0 → SetLassoActive(false)`

The safeguard at line 418 (`force-finalize any stale lasso before new action`) stays — it only fires on `fresh_click` (rising edge), not on mouse-up frames. No conflict.

---

### Fix S2 (HIGH) — Add lasso_active to dirty flags

**Root cause**: During lasso drag, no dirty flag triggers redraw. The lasso rect position updates in store but GFX doesn't re-render, so the visual lasso rectangle freezes.

**Fix**: In `main.lua` dirty-flag block (line 270–278), add:

```lua
if island_store.GetLassoActive() then gfx_needs_redraw = true end
```

`island_store` is already required at line 97 — no new import needed.

Placed after line 278 (after `PageOverrideTimer` check), before line 280 (`prev_dock`). This ensures every frame during lasso drag triggers a redraw, updating `DrawLassoRect` position.

---

### Fix S3 (LOW) — Fix fresh_click bitmask

**Root cause**: Line 265 compares `ui_store.GetLastMouseCap() == 0` for equality. If the user holds right-click (cap=2) then adds left-click (cap=3), `last_cap == 2` means `fresh_click` is false — the left-click rising edge is missed.

**Fix**: Change `== 0` to `& 1) == 0`:

```lua
-- BEFORE:
local fresh_click = (gfx.mouse_cap & 1) == 1 and ui_store.GetLastMouseCap() == 0
-- AFTER:
local fresh_click = (gfx.mouse_cap & 1) == 1 and (ui_store.GetLastMouseCap() & 1) == 0
```

Single-bit mask isolates left-button state. Other buttons held (right, middle) no longer suppress left-click detection.

---

### Fix S4 (MEDIUM) — Add ConsumeMouseClick to raw handlers

**Root cause**: After a click is handled by one widget, `GetMouseClick()` still returns true for subsequent widgets on the same frame. This can cause double-fire (e.g., clicking a dropdown also triggers piano keyboard).

**Fix**: Add `ui_store.ConsumeMouseClick()` inside each action handler's `if` block, **after** the action fires. Key rules:

1. **PressOverlay-only lines** (visual feedback) — do NOT consume; the paired action handler needs the click.
2. **Action handlers** — consume after the action.
3. **icons.DrawToolIcon** already consumes internally (icons.lua:105) — no change needed there.

**Files and specific sites**:

| File | Line | Handler | Add consume? |
|------|------|---------|-------------|
| `views.lua` | 338 | PressOverlay (VEL) | No — paired with 347 |
| `views.lua` | 347 | `midi_store.SetUseVelocity` | **Yes** |
| `views.lua` | 356 | PressOverlay (PLAY/STOP) | No — paired with 369 |
| `views.lua` | 369 | `sequencer.Stop / SetIsPlaying` | **Yes** |
| `views.lua` | 385 | PressOverlay (CLEAR) | No — DrawToolIcon consumes internally |
| `views.lua` | 399 | PressOverlay (EXPORT) | No — DrawToolIcon consumes internally |
| `views.lua` | 414 | PressOverlay (MIDI) | No — paired with 423 |
| `views.lua` | 423 | `midi.ToggleIsland` | **Yes** |
| `views.lua` | 461 | `SetSliderDragging` | **Yes** |
| `views.lua` | 538 | `SetCurrentPage(-1)` prev | **Yes** |
| `views.lua` | 556 | `SetCurrentPage(+1)` next | **Yes** |
| `views.lua` | 648 | Docked VEL toggle | **Yes** |
| `views.lua` | 667 | Docked PLAY/STOP | **Yes** |
| `views.lua` | 686 | Docked UNDOCK | **Yes** |
| `pads.lua` | 141 | `midi.TriggerChord` | **Yes** |
| `piano.lua` | 163 | `preferences_store.SetRootIndex` | **Yes** |
| `dropdown.lua` | 65 | `gfx.showmenu` | **Yes** |
| `paginator.lua` | 39 | `SetCurrentPage(i)` | **Yes** |

**Pattern for each addition** (example from views.lua:347):
```lua
-- BEFORE:
if ui_store.GetMouseClick() and v_hover and not drag_store.GetIsDragging() then
    midi_store.SetUseVelocity(not midi_store.GetUseVelocity())
end

-- AFTER:
if ui_store.GetMouseClick() and v_hover and not drag_store.GetIsDragging() then
    midi_store.SetUseVelocity(not midi_store.GetUseVelocity())
    ui_store.ConsumeMouseClick()
end
```

## Affected Files

| File | Change |
|------|--------|
| `src/ui/midi-island.lua` | **S1**: Move stale guard block (lines 215–217) to after line 573 |
| `src/main.lua` | **S2**: Add `if island_store.GetLassoActive() then gfx_needs_redraw = true end` to dirty flags (after line 278) |
| `src/main.lua` | **S3**: Change `== 0` to `& 1) == 0` on line 265 |
| `src/ui/views.lua` | **S4**: Add `ConsumeMouseClick()` after actions at lines 347, 369, 423, 461, 538, 556, 648, 667, 686 |
| `src/ui/pads.lua` | **S4**: Add `ConsumeMouseClick()` after action at line 141 |
| `src/ui/piano.lua` | **S4**: Add `ConsumeMouseClick()` after action at line 163 |
| `src/ui/dropdown.lua` | **S4**: Add `ConsumeMouseClick()` after action at line 65 |
| `src/ui/paginator.lua` | **S4**: Add `ConsumeMouseClick()` after action at line 39 |

## Edge Cases

1. **Alt-tab during lasso drag** (S1): Mouse-up delivered outside GFX, stale guard fires after finalization → lasso cleared, no notes selected. No stuck state.

2. **Lasso + pointer tool interaction** (S1): The safeguard at line 418 (`force-finalize any stale lasso before new action`) fires on fresh_click in pointer mode. With the reordered guard, by the time a user clicks again the lasso is already finalized and cleared — the safeguard is a harmless redundant clear.

3. **Right-click then left-click in piano roll** (S3): `fresh_click` correctly detects left-button rising edge even when right button is held. Verified: cap=2→3 → `(3 & 1)==1`, `(2 & 1)==0` → true.

4. **No click — no consume** (S4): If `GetMouseClick()` returns false, `ConsumeMouseClick()` is never called inside an un-entered `if` block. Event bus retains existing value, available for other handlers.

5. **Consume already done by DrawToolIcon** (S4): icons.lua:105 already calls `ConsumeMouseClick()`. Calls via `components.DrawToolIcon` (views.lua:387, 400) do not need a second consume — the event bus is already false for any later handler.

## Rollback

| Fix | Rollback |
|-----|----------|
| **S1** | Move stale guard block back to its original position (before line 215 → after line 573 → back to before line 215) |
| **S2** | Remove `if island_store.GetLassoActive() then gfx_needs_redraw = true end` from main.lua |
| **S3** | Revert `(ui_store.GetLastMouseCap() & 1) == 0` to `ui_store.GetLastMouseCap() == 0` |
| **S4** | Remove every `ui_store.ConsumeMouseClick()` line added to views.lua, pads.lua, piano.lua, dropdown.lua, paginator.lua — 13 additions total |
