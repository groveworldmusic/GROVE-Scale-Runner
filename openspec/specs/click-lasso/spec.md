# Delta: Click & Lasso Fixes

## Purpose

Correct four implementation bugs in click detection, lasso finalization, GFX redraw, and click event propagation. These are remedial requirements — the existing piano-roll and selection specs already describe the correct lasso/selection behavioral contract.

## ADDED Requirements

### Requirement: Lasso Finalization Order (CRITICAL)

The stale lasso guard MUST run AFTER the lasso finalization block in `midi-island.lua`. On mouse-up, the system SHALL first compute the selection from the lasso rect via `GetNotesInRect`, THEN clean up stale lasso state. The stale guard SHALL still protect against REAPER focus-loss (mouse-up delivered outside GFX window) after finalization.

#### Scenario: Mouse-up computes selection before clearing

- GIVEN lasso is active and `(gfx.mouse_cap & 1) == 0` (mouse released)
- WHEN the lasso finalization block runs first
- THEN `GetNotesInRect` computes `selected_indices` from the lasso rect
- AND the stale guard's `SetLassoActive(false)` runs AFTER finalization
- AND selection persists in the store

#### Scenario: Alt-tab while dragging

- GIVEN the user alt-tabs during a lasso drag (mouse never released in GFX context)
- WHEN focus returns and the next frame processes with `(gfx.mouse_cap & 1) == 0`
- THEN the stale guard triggers `SetLassoActive(false)` after finalization
- AND no notes are selected (lasso never finalized)
- AND `lasso_active` is cleared without hanging state

### Requirement: Lasso Dirty Flag (HIGH)

The MainLoop dirty-flag block SHALL set `gfx_needs_redraw = true` when `island_store.GetLassoActive()` returns true. This ensures the lasso selection rect (drawn by `piano-roll/interaction.lua:DrawLassoRect`) updates position each frame during drag.

#### Scenario: Lasso rect updates during drag

- GIVEN the user starts a lasso drag (mouse held, moving)
- WHEN the dirty-flag block at `main.lua:~270` evaluates
- THEN `gfx_needs_redraw = true` when `GetLassoActive()` is true
- AND the lasso rect position catches up to cursor each frame

#### Scenario: No lasso — no extra redraw

- GIVEN lasso is NOT active
- WHEN the dirty-flag block evaluates
- THEN `GetLassoActive()` returns false
- AND the flag does NOT force a redraw

### Requirement: fresh_click Bitmask (LOW)

`fresh_click` SHALL use bitwise AND `(ui_store.GetLastMouseCap() & 1) == 0` instead of equality `ui_store.GetLastMouseCap() == 0`. This detects left-button rising edge even when other mouse buttons were held the previous frame.

#### Scenario: Right-click held then left-click

- GIVEN last frame had `mouse_cap == 2` (right button alone)
- WHEN this frame has `mouse_cap == 3` (left + right)
- THEN `(gfx.mouse_cap & 1) == 1` AND `(last_mouse_cap & 1) == 0`
- AND `fresh_click = true`

#### Scenario: Normal click unchanged

- GIVEN `last_mouse_cap == 0` and `mouse_cap == 1`
- WHEN the bitmask check evaluates
- THEN `fresh_click = true` (identical behavior)

### Requirement: Click Consumption in Raw Handlers (MEDIUM)

Raw `GetMouseClick()` handlers in `views.lua` (14 sites), `pads.lua:141`, `piano.lua:163`, `dropdown.lua:65`, and `paginator.lua:39` SHALL call `ui_store.ConsumeMouseClick()` after a successful click+handler match. This prevents the click event from propagating to subsequent widgets.

#### Scenario: Click consumed by dropdown

- GIVEN a dropdown and piano keyboard visible
- WHEN the user clicks the dropdown
- THEN `ConsumeMouseClick()` is called inside the `if` block
- AND the piano keyboard's `GetMouseClick()` reads false on the same frame

#### Scenario: No click — no consume

- GIVEN `GetMouseClick()` returns false
- WHEN the `if` block evaluates
- THEN `ConsumeMouseClick()` is NOT called
- AND the click event bus remains available for other handlers

## Acceptance Criteria

- [ ] S1: Lasso drag → mouse-up → notes inside rect selected (verified by `selected_indices` and visual highlight)
- [ ] S1: Alt-tab during lasso drag → no stuck state on return
- [ ] S2: Lasso rect updates each frame during drag (no visual freeze)
- [ ] S3: Right-click held → left-click in piano roll triggers selection correctly
- [ ] S4: No double-fire on buttons/pads/piano/dropdown/paginator — each handler fires once per click
