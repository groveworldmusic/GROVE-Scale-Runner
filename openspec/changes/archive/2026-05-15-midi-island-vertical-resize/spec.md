# Delta for midi-island

## Purpose

This delta modifies the MIDI island content height from a fixed virtual constant to a dynamic pixel-space value based on `gfx.h`. The internal layout already distributes extra height correctly to the piano roll — this change makes the window's vertical resize actually usable for the island.

## ADDED Requirements

### Requirement: Dynamic Island Content Height

The island content pixel height `h` in `m.Draw()` SHALL be computed from available window vertical space instead of a fixed virtual constant. A minimum-height guard SHALL prevent island collapse.

The system MUST compute `h` as `math.max(MIN_ISLAND_H, gfx.h - y - 4)`, where:
- `MIN_ISLAND_H` is a local constant of 200 pixels
- `gfx.h` is the current REAPER GFX window height
- `y` is the pixel-space top edge of the island content area
- `4` is the bottom margin in pixels

The fixed virtual constant `ISLAND_CONTENT_H = 14000` SHALL be removed. The internal pixel layout (timeline 30px → piano roll → velocity editor 10–100px → scrollbar 7px) SHALL distribute the dynamic height without modification — the piano roll receives all remaining height after subtracting fixed sub-component sizes.

#### Scenario: Island grows with vertical window resize

- GIVEN the REAPER window height is 793px and the island is expanded
- WHEN the user stretches the window to 1000px
- THEN island height `h` SHALL be approximately `1000 - y - 4` pixels
- AND the piano roll SHALL display proportionally more visible pitch rows

#### Scenario: Minimum height guard prevents collapse

- GIVEN a very short window (e.g., 400px total height)
- WHEN the island is expanded
- THEN `h` SHALL be at least 200 pixels (`math.max(200, gfx.h - y - 4)`)
- AND all sub-components SHALL render within that minimum height

#### Scenario: Sub-component layout unaffected

- GIVEN the island height changes dynamically
- WHEN the new height is applied
- THEN timeline SHALL remain 30px, velocity editor SHALL keep its collapsed/expanded height (10/100px), scrollbar SHALL remain 7px
- AND only the piano roll SHALL receive the additional height

### Requirement: Scale System Invariant

The 500px base height constant for the virtual coordinate system SHALL remain the authoritative scale reference. Dynamic island height MUST NOT change the scale calculation — only pixel-space island height is affected.

#### Scenario: Scale unchanged by window height

- GIVEN the scale `s` is computed as `min(gfx.w / 39914, 500 / 29162) * 1.025`
- WHEN `gfx.h` changes
- THEN `s` SHALL remain unchanged (500px constant, NOT `gfx.h`)
- AND existing content above the island SHALL maintain its size and proportion

## MODIFIED Requirements

*None.* All existing requirements in `openspec/specs/midi-island/spec.md` remain valid:
- State preservation across toggle — unchanged (gfx.quit()+gfx.init() preserved)
- No visual side effects / 500px invariant — unchanged
- MAX_UNDO / undo stack — unchanged
- UUID index scoped local — unchanged
- Folder scroll state — unchanged
- Window height from constants (ToggleIsland) — unchanged (793/497 still from constants)

## REMOVED Requirements

*None.* The removal of `ISLAND_CONTENT_H` is an implementation detail; no behavioral requirement is removed.

## Out of Scope

- **Scale system changes**: 500px base height remains; `gfx.h` does NOT affect virtual scaling
- **Proportional main content**: header, islands, performance area do NOT resize with window height
- **ToggleIsland behavior**: `gfx.quit()` + `gfx.init()` pattern and 497/793 dimensions preserved
- **Window resize tracking**: no new state needed (`gfx.h` is live per frame)
- **Performance**: O(rows+notes) draw loop bounded by monitor resolution; no optimization required

## Acceptance Criteria

- [ ] Stretching REAPER window vertically grows island height proportionally (more pitch rows visible)
- [ ] Minimum island height of 200px when window is very short
- [ ] 4px bottom margin preserved below island content
- [ ] Scale system unchanged (500px base constant, not `gfx.h`)
- [ ] ToggleIsland dimensions unchanged (497/793 from local constants)
- [ ] All existing island functionality works: notes, scroll, zoom, velocity editor, undo/redo, preset browser, keyboard input
- [ ] No orphaned constant references (ISLAND_CONTENT_H fully removed from codebase)
- [ ] No performance regression at tall window sizes (~125 rows at 2000px)
