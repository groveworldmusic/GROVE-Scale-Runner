## Exploration: serious-click-lasso-bugs

### Current State

**Click system (`main.lua` → `state/ui.lua`):**
- `MainLoop` (line 265): `fresh_click = (gfx.mouse_cap & 1) == 1 and ui_store.GetLastMouseCap() == 0`
- `SetMouseClick(fresh_click)` sets the one-frame event
- `SetLastMouseCap(gfx.mouse_cap)` is called AFTER `DrawFullView()` (line 296)
- Two read patterns coexist:
  - `GetMouseClick()` — returns value WITHOUT clearing (used by VEL, PLAY, MIDI toggle, pads, piano, dropdown, paginator, slots, volume slider)
  - `ConsumeMouseClick()` — returns AND clears to `false` (used by `DrawButton`, `DrawTransportButton`, `DrawToolIcon`/`DrawIcon`)
- `ConsumeMouseWheelDelta()` is called in `midi-island.lua` line 395

**Lasso system (`midi-island.lua` + `piano-roll-store.lua`):**
- **Start**: lasso starts on click + empty grid area (line 443-449) — uses `ui_store.GetMouseClick()`
- **Stale guard**: line 215-217 — clears `lasso_active` if `(gfx.mouse_cap & 1) == 0`
- **Update/finalize**: lines 549-573 — reads `gfx.mouse_cap` directly, updates EndX/Y or finalizes selection
- **Draw**: `interaction.DrawLassoRect()` called from `view.lua:53`
- **Collapse cleanup**: lines 206-208 — clears lasso on MIDI island collapse

**Selection state (`piano-roll-store.lua`):**
- `selected_indices` is a table returned by REFERENCE (`GetSelectedIndices()`)
- `ClearSelection()` replaces it with `{}`
- `SetSelectedIndices(t)` replaces it with the new table
- All callers use within-same-frame patterns (no cross-frame reference caching)

**Rendering order in `DrawFullView()` (views.lua):**
1. `DrawHeader()` — 3 DrawToolIcon calls (each CONSUMES)
2. `DrawIslands()` — piano keyboard → dropdowns → DrawButtons for octave/chord/inv (each CONSUMES) → VEL handler → PLAY/STOP → CLEAR (DrawToolIcon, CONSUMES) → EXPORT (DrawToolIcon, CONSUMES) → MIDI toggle → volume slider
3. `DrawPerformanceArea()` — 7 pads → 4 slots → paginator → prev/next
4. `DrawMIDIIsland()` — piano roll interaction, lasso

### Root Causes Found

- **Bug 1: Stale lasso guard kills lasso finalization**
  - **Root cause**: `midi-island.lua` line 215 stale guard executes BEFORE line 549 lasso finalization. On mouse-up frame, the guard sees `lasso_active == true AND (gfx.mouse_cap & 1) == 0` and clears `lasso_active` to `false`. When finalization at line 549 runs, it sees `lasso_active == false` and skips. **The selection is never computed.**
  - **Files**: `src/ui/midi-island.lua` (lines 215-217 vs 549-573)
  - **Severity**: **Critical** — lasso has never actually worked since the stale guard was added

- **Bug 2: gfx_needs_redraw skips lasso visual updates during drag**
  - **Root cause**: `main.lua` lines 271-278 — `gfx_needs_redraw` is only set for: fresh_click, right_click, sequencer playing, timers active, dock state change. **Lasso active state does NOT trigger redraw.** During a lasso drag (mouse held, moving), no new state changes fire, so `gfx_needs_redraw` stays `false`, `DrawFullView` is not called, and the lasso rect and position stop updating. On release, the stale guard bug #1 prevents finalization anyway. Compound: even if bug #1 were fixed, the release might land on a non-redraw frame and miss finalization.
  - **Files**: `src/main.lua` (lines 270-278), `src/ui/midi-island.lua` (lines 549-573)
  - **Severity**: **High** — makes lasso drag invisible and misses mouse-up events

- **Bug 3: fresh_click uses raw `last_mouse_cap` instead of bitmask**
  - **Root cause**: `main.lua` line 265: `fresh_click = (gfx.mouse_cap & 1) == 1 and ui_store.GetLastMouseCap() == 0`. Checks entire `last_mouse_cap` against `0` instead of `(last_mouse_cap & 1) == 0`. If a modifier was held on the previous frame (e.g., right-click `mouse_cap=2`), `last_mouse_cap=2`, the check `2 == 0` is `false`, so a subsequent left-click while right-click is held `mouse_cap=3` would be missed: `fresh_click = (3 & 1) == 1 and 2 == 0 → false`. In practice the right-click uses proper masking at line 273.
  - **Files**: `src/main.lua` line 265
  - **Severity**: **Low** — unlikely in normal use, but technically incorrect

- **Bug 4: VEL/PLAY/MIDI/volume handlers use GetMouseClick() without consuming**
  - **Root cause**: `views.lua` lines 347, 369, 423, 461 (and docked VEL/PLAY lines 648, 667) read `ui_store.GetMouseClick()` and act on it but DO NOT call `ConsumeMouseClick()`. This means the click event persists for later widgets in the render order. While current widget positions don't overlap, this is fragile and could cause double-triggers if positions change. The ConsumeMouseClick() in `DrawButton`/`DrawToolIcon` is actually **correct** — each button is in a distinct position.
  - **Files**: `src/ui/views.lua` (lines 338, 347, 356, 369, 385, 399, 414, 423, 452, 461, 538, 556, 648, 667), `src/ui/pads.lua` (line 141), `src/ui/piano.lua` (line 163), `src/ui/dropdown.lua` (line 65), `src/ui/paginator.lua` (line 39)
  - **Severity**: **Medium** — not currently causing bugs due to non-overlapping positions, but fragile

- **Bug 5: Volume slider interaction reads GetMouseClick() after CLEAR/EXPORT may have consumed it**
  - **Root cause**: In `DrawIslands()`, CLEAR (line 387) and EXPORT (line 400) call `DrawToolIcon` which calls `ConsumeMouseClick()`. The volume slider (line 461) reads `GetMouseClick()` after them. If the user clicks on CLEAR/EXPORT and the hover area happens to overlap with the volume slider, the slider wouldn't see a click that it should. In practice, hover areas are distinct, but the ordering dependency is fragile.
  - **Files**: `src/ui/views.lua` (lines 387-402, 461)
  - **Severity**: **Low** — no practical overlap in current layout

### Affected Areas

- `src/main.lua` — gfx_needs_redraw dirty flags don't check lasso_active; fresh_click uses raw last_mouse_cap instead of mask
- `src/state/ui.lua` — ConsumeMouseClick and GetMouseClick/SetMouseClick event bus (correct, no changes needed)
- `src/ui/midi-island.lua` — Stale lasso guard (line 215) kills lasso finalization (line 549); scrollbar drag states also not reset outside lasso
- `src/ui/piano-roll/interaction.lua` — DrawLassoRect (correct, no changes needed)
- `src/ui/piano-roll/view.lua` — Calls DrawLassoRect (correct)
- `src/ui/views.lua` — VEL/PLAY/MIDI/volume/prev/next handlers don't consume; fragile ordering dependency with CLEAR/EXPORT
- `src/ui/buttons.lua` — ConsumeMouseClick pattern in DrawButton/DrawTransportButton (correct)
- `src/ui/icons.lua` — ConsumeMouseClick pattern in DrawIcon (correct)
- `src/ui/pads.lua` — Uses GetMouseClick without consume
- `src/ui/piano.lua` — Uses GetMouseClick without consume
- `src/ui/dropdown.lua` — Uses GetMouseClick without consume
- `src/ui/paginator.lua` — Uses GetMouseClick without consume

### Ready for Proposal

Yes. Three concrete bugs found with clear root causes:

1. **Critical**: Stale lasso guard order — guard at line 215 kills finalization at line 549. Fix: move guard after finalization, or remove guard and handle stale lasso in finalization.
2. **High**: gfx_needs_redraw doesn't track lasso_active during drag. Fix: add `if island_store.GetLassoActive() then gfx_needs_redraw = true end` in main.lua.
3. **Low**: fresh_click mask. Fix: use `(ui_store.GetLastMouseCap() & 1) == 0`.

The proposal phase should recommend fixes for all three with clear task breakdown.
