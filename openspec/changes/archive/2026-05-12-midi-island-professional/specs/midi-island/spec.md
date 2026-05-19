# Delta for MIDI Island — ToggleIsland Resilience

## Overview

ToggleIsland controls the MIDI island expand/collapse. The standard REAPER GFX pattern (`gfx.quit()` + `gfx.init()`) MUST be preserved. This delta adds state preservation around the toggle cycle so that editor state survives `gfx.quit()` + `gfx.init()` without loss.

## Critical Constraints

- **MUST keep** `gfx.quit()` + `gfx.init()` — this is the standard REAPER GFX resize pattern, NOT replaced by gfx resize.
- **MUST preserve** 500px base height constant for scale system — `gfx.h` MUST NOT drive note block/timeline scaling.

## ADDED Requirements

### Requirement: State Preservation Across Toggle

All mutable island state SHALL survive the `gfx.quit()` + `gfx.init()` toggle cycle without explicit re-initialization. State lives in Lua/store modules, not in the GFX context, so this SHALL hold naturally. The following state keys MUST be verified preserved:

| State Key | Type | Source |
|-----------|------|--------|
| `notes[]` | table | island_store |
| `selected_indices` | table | island_store |
| `scroll_x` | number | island_store |
| `zoom` | number | island_store |
| `tool_mode` | string | island_store |
| `snap_enabled` | boolean | island_store |
| `snap_resolution` | string/number | island_store |
| `undo_stack` | table | island_store |
| `redo_stack` | table | island_store |
| `velocity_panel_expanded` | boolean | island_store |

#### Scenario: Notes survive toggle

- GIVEN the island expanded with 12 notes at various positions
- WHEN ToggleIsland collapses then re-expands
- THEN `island_store.GetNotes()` returns the same 12 notes
- AND no note data is mutated

#### Scenario: Scroll position restored

- GIVEN scroll_x = 42.5 before toggle
- WHEN island collapses and re-expands
- THEN `GetScrollX()` = 42.5

#### Scenario: Undo stack survives

- GIVEN 3 undo entries exist
- WHEN island toggles
- THEN undo stack depth remains 3
- AND redo stack is unchanged

### Requirement: No Visual Side Effects

The `gfx.quit()` + `gfx.init()` cycle SHALL produce no visual artifacts beyond the standard window close/reopen flash. The 500px base height constant SHALL remain the authoritative scale reference.

#### Scenario: 500px base invariant

- GIVEN the island expanded
- WHEN any toggle occurs
- THEN all note block and timeline scaling uses 500px base, NOT `gfx.h`
- AND layout proportions are identical pre- and post-toggle

## Acceptance Criteria

- [ ] Notes, selection, scroll, zoom, tool mode, snap state all survive toggle
- [ ] Undo/redo stacks survive toggle
- [ ] 500px base height is the scale constant (verify no gfx.h usage for scaling)
- [ ] gfx.quit() + gfx.init() remains the toggle mechanism (not replaced by gfx resize)
- [ ] No state loss or corruption across multiple rapid toggles
