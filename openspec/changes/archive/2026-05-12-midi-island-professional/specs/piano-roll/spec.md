# Delta for Piano Roll

## ADDED Requirements

### Requirement: Modular Split into 4 Sub-Modules

The `src/ui/piano-roll.lua` monolith (1022 LOC) SHALL be split into 4 sub-modules within `src/ui/piano-roll/`:
- `grid-renderer.lua` — grid lines, beat hierarchy rendering, scrollbar
- `note-block.lua` — note drawing, gradient strips, velocity→opacity mapping, muted rendering
- `keyboard-strip.lua` — vertical piano key strip, pitch labels
- `interaction.lua` — hit-testing, mouse dispatch, drag/select state machine, wheel scroll

A barrel module `src/ui/piano-roll.lua` SHALL re-export all public functions. Existing consumers (views.lua, velocity-editor, etc.) MUST NOT require refactoring.

#### Scenario: Barrel preserves consumer API

- GIVEN `local piano_roll = require("ui.piano-roll")`
- WHEN any consumer calls `piano_roll.Draw()` or other exported functions
- THEN behavior is identical to pre-split AND no require paths changed

#### Scenario: Hit-testing centralized

- GIVEN a mouse click at (x, y) over the piano roll region
- WHEN interaction.lua's hit-test dispatch runs
- THEN it returns correct target (note block, resize edge, scrollbar, keyboard strip, or empty)
- AND all mouse routing passes through this single function

#### Scenario: Grid rendering behavior unchanged

- GIVEN the modular split
- WHEN grid-renderer.lua draws beat lines
- THEN the 4-tier alpha hierarchy from the existing spec is identical
- AND `grid_measure`, `grid_beat`, `grid_sub_1_8`, `grid_sub_1_16` colors match

## MODIFIED Requirements

### Requirement: Virtual Scrolling

Same behavior as existing spec. The scroll and visible-range logic moves from the monolith's inline event loop to interaction.lua, which owns mouse wheel and scrollbar drag dispatch. No behavioral change.

(Previously: virtual scrolling and scrollbar interaction were inline in the monolithic piano-roll.lua event loop.)

#### Scenario: All existing scroll scenarios remain valid

- GIVEN the split
- WHEN piano roll scrolls via mouse wheel
- THEN the same visible region logic, 2-octave buffer, and scrollbar behavior apply
- AND no behavioral regression occurs

### Requirement: Mouse Wheel Scroll

Same as existing spec. The handler moves to interaction.lua. Existing zeroing pattern (`gfx.mouse_wheel` consumed per frame) MUST be preserved.

(Previously: mouse wheel handling inline in piano-roll.lua.)

#### Scenario: All existing wheel scenarios remain valid

- GIVEN the split
- WHEN mouse_wheel delta is consumed
- THEN delta is zeroed per the project pattern AND scroll updates are identical

## Acceptance Criteria

- [ ] All existing piano-roll acceptance criteria from the main spec remain passing
- [ ] Visual rendering is pixel-identical (verify via manual inspection)
- [ ] All mouse interactions (click, drag, wheel) produce identical results
- [ ] Barrel module exports the same public API as the original monolith
- [ ] No consumer code (views.lua, velocity.lua, etc.) requires changes
