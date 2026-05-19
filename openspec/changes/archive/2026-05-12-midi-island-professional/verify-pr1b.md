# Verification Report: PR1b — Interaction + View + ToggleIsland

**Change**: midi-island-professional (PR1b)
**Version**: 1.0
**Mode**: Standard (no Lua CLI, no automated test runner)
**Verification type**: Static analysis + manual source inspection

---

## Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 6 (1.5–1.10) |
| Tasks complete | 6 |
| Tasks incomplete | 0 |

### Task Completion Status

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1.5 | Create interaction.lua | ✅ Complete | HandleMouseClick, HandleRightClickMute, HandlePencilClick, HandleEraserClick, DrawLassoRect, CtrlA, shift-click param |
| 1.6 | Create view.lua | ✅ Complete | DrawPianoRoll coordinator: visible ranges → grid → notes → scrollbar → lasso |
| 1.7 | Update barrel (piano-roll.lua) | ✅ Complete | Re-exports all 4 sub-modules; SetPitchRowH keeps sync |
| 1.8 | Modify midi.lua ToggleIsland | ✅ Complete | State preservation: dock, rect, transitioning flag, font restore |
| 1.9 | Modify island.lua | ✅ Complete | 3 new fields + getters/setters |
| 1.10 | Update tests | ✅ Complete | Barrel-backward-compat.lua covers all sub-module exports |

---

## Spec Compliance Matrix

### Piano Roll Structural Split (specs/piano-roll/spec.md)

| Req | Scenario | Evidence | Result |
|-----|----------|----------|--------|
| Modular Split (4 sub-modules) | 4 modules + barrel exist | `grid.lua` (556L), `note.lua` (290L), `interaction.lua` (203L), `view.lua` (65L) + barrel `piano-roll.lua` (63L) | ✅ COMPLIANT |
| Barrel preserves consumer API | All exports match monolith | barrel-backward-compat.lua enumerates 22 expected exports; all verified via static analysis against views.lua call sites (52 references, all covered) | ✅ COMPLIANT |
| Hit-testing centralized | Mouse dispatch → correct target | interaction.lua owns HandleMouseClick, HandleRightClickMute, HandlePencilClick, HandleEraserClick; all delegate to note.NoteBlockHitTest | ✅ COMPLIANT |
| Grid rendering unchanged | Beat line hierarchy preserved | grid.lua DrawPianoRollGrid draws measure/beat/subdivision lines using theme.colors.grid_measure/beat/sub_1_8/sub_1_16 — identical to monolith | ✅ COMPLIANT |
| All scroll scenarios valid | Wheel/zoom/scroll identical | HandleMouseWheel, HandleZoomX, HandleZoomVertical, HandleMouseWheelVertical in grid.lua — pure functions, no behavioral change | ✅ COMPLIANT |

**Deviation**: Spec names sub-modules `grid-renderer.lua`, `note-block.lua`, `keyboard-strip.lua`. Actual names are `grid.lua`, `note.lua`, `interaction.lua`, `view.lua`. Grid combines grid + keyboard strip (spec expected separate `keyboard-strip.lua`). View coordinator was not in spec. These are naming refinements, not behavioral changes. API surface (what consumers call) is identical.

### MIDI Island ToggleIsland Resilience (specs/midi-island/spec.md)

| Req | Scenario | Evidence | Result |
|-----|----------|----------|--------|
| gfx.quit()+gfx.init() preserved | Not replaced | midi.lua lines 182-183: `gfx.quit()` → `gfx.init(...)` | ✅ COMPLIANT |
| 500px base height preserved | Not using gfx.h | Window heights use constants 497/793; scale system in layout.lua uses 500px base | ✅ COMPLIANT |
| State preservation across toggle | Notes survive | All state in island_store (Lua heap), not GFX context — naturally survives gfx.quit() | ✅ COMPLIANT |
| Dock mode saved before quit | pre_toggle_dock | `island_store.SetPreToggleDock(dock)` at line 177; `gfx.dock(-1)` saved as local | ✅ COMPLIANT |
| Window rect saved before quit | pre_toggle_rect | `island_store.SetPreToggleRect({x=l, y=t})` at line 178 | ✅ COMPLIANT |
| Transition flag set before quit | transitioning=true | `island_store.SetIslandTransitioning(true)` at line 180 | ✅ COMPLIANT |
| Transition flag cleared after init | transitioning=false | `island_store.SetIslandTransitioning(false)` at line 185 | ✅ COMPLIANT |
| Font restored after init | setfont called | `gfx.setfont(1, "Calibri", 16)` at line 184 | ✅ COMPLIANT |

**Deviation**: pre_toggle_rect saves `{x, y}` (position only), not `{l, t, r, b}` (full rect) as design specified. The actual `gfx.init()` uses `gs.x, gs.y` from `compact_store.LastGfxState` (set from JS_Window_GetRect), so position IS correctly preserved — the island_store copy is a backup.

### Selection: Shift-Additive + Ctrl+A (specs/selection/spec.md)

| Req | Scenario | Evidence | Result |
|-----|----------|----------|--------|
| Shift-click additive | Add to selection | interaction.lua HandleMouseClick accepts `shift_held` param, calls `ToggleNoteSelected` | ✅ COMPLIANT (function exists) |
| Shift-click toggle | Remove from selection | Same function: `ToggleNoteSelected` toggles if already selected | ✅ COMPLIANT (function exists) |
| Click without Shift clears | Clear previous | When `shift_held` is nil/false → `ClearSelection()` before `SetSelectedNoteIndex` | ✅ COMPLIANT |
| Shift on empty → preserve | No-op on empty | When `shift_held` is true and no hit → skip ClearSelection | ✅ COMPLIANT (function level) |
| Ctrl+A selects all | All selected | interaction.lua CtrlA: iterates all notes, sets all in selected_indices | ✅ COMPLIANT (function exists) |
| Ctrl+A toggles when all selected | Deselect all | Same CtrlA: checks if all selected first, then clears | ✅ COMPLIANT (function exists) |
| Ctrl+A on empty array | No-op | Returns early if notes nil or empty | ✅ COMPLIANT |

**⚠️ WARNING**: The shift-click and Ctrl+A functions exist in interaction.lua and are exported via the barrel, but **views.lua does not wire them up**:
- Line 844: `piano_roll.HandleMouseClick(...)` called WITHOUT `shift_held` argument (Shift state from `gfx.mouse_cap & 8` not passed through)
- No Ctrl+A detection in views.lua or main.lua (gfx.getchar() char==1 not handled)

These features exist at the sub-module level but will not function in the UI until views.lua and/or main.lua are updated (expected in Sprint 3 per tasks.md).

---

## Design Coherence Assessment

| Decision (design.md) | Implementation | Followed? | Notes |
|----------------------|---------------|-----------|-------|
| 4 sub-modules + barrel | grid, note, interaction, view + barrel | ✅ Yes | Names differ (grid vs piano-roll-grid) but structure matches |
| Module deps: view→interaction→note→grid | view.lua requires interaction, note, grid; interaction requires note, grid; note requires grid | ✅ Yes | Clean dependency chain, no cycles |
| ToggleIsland: keep quit+init | gfx.quit()+gfx.init() unchanged at lines 182-183 | ✅ Yes | |
| Pre-quit capture: dock, rect, transition flag | All 3 saved to island_store | ✅ Yes | |
| Island store: island_transition_in_progress, pre_toggle_dock, pre_toggle_rect | Fields defined with getters/setters (lines 228-233) | ✅ Yes | |
| Font restore after gfx.init() | gfx.setfont(1, "Calibri", 16) at line 184 | ✅ Yes | |
| Undo state fields (Sprint 3) | Not in scope for PR1b | ➖ N/A | Deferred to Sprint 3 |
| Snap state fields (Sprint 2) | Not in scope for PR1b | ➖ N/A | Deferred to Sprint 2 |

**Design/implementation naming differences** (non-blocking):

| design.md | Implementation |
|-----------|---------------|
| `piano-roll-grid.lua` | `grid.lua` |
| `piano-roll-note.lua` | `note.lua` |
| `piano-roll-interaction.lua` | `interaction.lua` |
| `piano-roll-view.lua` | `view.lua` |
| `pre_toggle_rect = {l, t, r, b}` | `pre_toggle_rect = {x, y}` (position only) |

---

## Issues Found

### CRITICAL: None

All 6 tasks are complete. No blocking issues.

### WARNING

1. **Selection features not wired in views.lua** — interaction.lua has correct shift_held handler and CtrlA function, but views.lua does not:
   - No Shift state (`gfx.mouse_cap & 8`) passed to `HandleMouseClick` (line 844)
   - No Ctrl+A dispatch from `gfx.getchar()` in main.lua or views.lua
   - Selection spec acceptance criteria will not be met until views.lua wiring is done

2. **No behavioral tests for shift-click or Ctrl+A** — barrel-backward-compat.lua only checks function existence, not behavior. The test at task 1.10 only validates exports, not interaction logic.

### SUGGESTION

1. **Rename sub-modules to match spec** — Or update the spec to reflect actual names. Current names (`grid.lua`, `note.lua`, `interaction.lua`, `view.lua`) are cleaner (no prefix redundancy since they're in `piano-roll/` directory), but deviate from spec and design.

2. **pre_toggle_rect could store full rect** — Currently saves `{x, y}`. Design spec says `{l, t, r, b}`. Consider adding `w, h` or full rect for completeness.

3. **views.lua line 844**: Add Shift state detection — `local shift_held = (gfx.mouse_cap & 8) == 8` and pass to `HandleMouseClick`. This is a small change (< 5 lines) that would activate the shift-click feature.

---

## Verdict

**PASS WITH WARNINGS**

PR1b achieves its core goals: all 6 tasks are complete, ToggleIsland resilience is correctly implemented (dock saved, rect saved, transition flag set/cleared, font restored), the barrel re-exports all 4 sub-modules correctly, and the barrel-backward-compat test covers all exports.

The two warnings are:
1. Selection features (shift-click, Ctrl+A) exist in interaction.lua but are not wired into the UI — expected to be resolved in Sprint 3 (task 3.5).
2. No runtime behavioral tests for shift-click or Ctrl+A scenarios — mitigated by correct function-level implementation verified via static analysis.
