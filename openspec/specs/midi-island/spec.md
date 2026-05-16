# MIDI Island Specification

## Purpose

State store init, window lifecycle, and toggle behavior for the island. Expanded header toolbar with icon-based RELOAD/SYNC buttons, SAVE/LOAD preset controls, and window position persistence across collapse/expand cycles.

## Overview

ToggleIsland controls the MIDI island expand/collapse. The standard REAPER GFX pattern (`gfx.quit()` + `gfx.init()`) MUST be preserved. This spec defines state preservation around the toggle cycle so that editor state survives `gfx.quit()` + `gfx.init()` without loss.

## Critical Constraints

- **MUST keep** `gfx.quit()` + `gfx.init()` — this is the standard REAPER GFX resize pattern, NOT replaced by gfx resize.
- **MUST preserve** 500px base height constant for scale system — `gfx.h` MUST NOT drive note block/timeline scaling.

## Requirements

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

### Requirement: MAX_UNDO constant

The store MUST declare `local MAX_UNDO = 50`.

#### Scenario: FIFO eviction

- GIVEN PushUndo has >50 entries
- WHEN a new entry is pushed
- THEN the oldest SHALL be evicted

### Requirement: Undo stack initialization

`island_state` MUST include initialized `undo_stack`, `redo_stack`, `undo_depth`, `redo_depth`.

#### Scenario: First push safe

- GIVEN island state is initialized
- WHEN the first `PushUndo()` runs
- THEN `table.insert` MUST NOT error

### Requirement: UUID index scoped local

`_uuid_to_idx` MUST be `local`, not global.

#### Scenario: No global leak

- GIVEN the module is loaded
- WHEN `RebuildUUIDIndex()` runs
- THEN `_G._uuid_to_idx` SHALL be nil

### Requirement: Folder scroll state

`island_state` MUST have a `folder_scroll` field for folder list scroll offset.

#### Scenario: Folder list scrolls

- GIVEN folder list exceeds visible height
- WHEN the user scrolls
- THEN `folder_scroll` SHALL persist across frames

### Requirement: Window height from constants

`ToggleIsland` heights MUST derive from local constants, not hardcoded 793/497.

#### Scenario: Heights match layout

- GIVEN `ToggleIsland` runs
- WHEN expanded, height SHALL match the layout constant
- WHEN collapsed, height SHALL match the header constant

### Requirement: Dynamic Island Content Height

The island content pixel height `h` in `m.Draw()` SHALL be computed from available window vertical space instead of a fixed virtual constant. A minimum-height guard SHALL prevent island collapse below the original expanded height.

The system MUST compute `h` as `math.max(MIN_ISLAND_H, gfx.h - y - 10)`, where:
- `MIN_ISLAND_H` is `layout.US(ISLAND_CONTENT_H)` — the original expanded island height in pixels
- `ISLAND_CONTENT_H = 14000` is a virtual-coordinate constant used as minimum reference
- `gfx.h` is the current REAPER GFX window height
- `y` is the pixel-space top edge of the island content area
- `10` is the bottom margin in pixels

The internal pixel layout (timeline 30px → piano roll → velocity editor 10–100px → scrollbar 7px) SHALL distribute the dynamic height without modification — the piano roll receives all remaining height after subtracting fixed sub-component sizes.

#### Scenario: Island grows with vertical window resize

- GIVEN the REAPER window height is 793px and the island is expanded
- WHEN the user stretches the window to 1000px
- THEN island height `h` SHALL be approximately `1000 - y - 10` pixels
- AND the piano roll SHALL display proportionally more visible pitch rows

#### Scenario: Minimum height guard prevents collapse

- GIVEN a very short window (e.g., 400px total height)
- WHEN the island is expanded
- THEN `h` SHALL be at least `MIN_ISLAND_H` pixels (`math.max(MIN_ISLAND_H, gfx.h - y - 10)`)
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

### Requirement: RELOAD/SYNC → Icon Buttons

The RELOAD (discard edits, reload from progression) and SYNC (write notes to progression slots) buttons SHALL render as Unicode glyphs inside rounded rects instead of text labels. RELOAD SHALL use `↺` (U+21BA, clockwise open circle arrow) and SYNC SHALL use `⇄` (U+21C4, rightwards arrow over leftwards arrow). The action and confirmation logic SHALL remain unchanged — only the visual representation changes.

Button containers SHALL shrink from `math.floor(b_w)` to `math.floor(b_w * 0.55)` (matching tool button width). The two extra pixels per button SHALL be redistributed as gap between adjacent controls, keeping the total header width unchanged.

#### Scenario: RELOAD renders as glyph

- GIVEN the MIDI island header renders
- WHEN `DrawHeader` draws the button area
- THEN the text "RELOAD" SHALL NOT appear and a glyph `↺` appears centered in a rounded rect at the same position
- AND the rounded rect width SHALL be `math.floor(b_w * 0.55)`

#### Scenario: SYNC renders differently when disabled

- GIVEN no edits have been made (notes_state == NOTES_STATE_LOADED)
- WHEN the header renders
- THEN the SYNC button SHALL show `⇄` in `text_dim` color (was `text` color on has_edits)
- AND clicking it SHALL produce no action (unchanged behavior)

### Requirement: SAVE/LOAD Header Buttons

Two new icon buttons SHALL appear next to the PRESETS toggle button (after the RELOAD/SYNC group, before snap controls). SAVE SHALL use `💾` (U+1F4BE, floppy disk) or a simple `⎙` (U+2399, print screen symbol for save). LOAD SHALL use `📂` (U+1F4C2, open file folder) or `⬆` (U+2B06, upload arrow icon).

SAVE SHALL call `preset_browser.SavePreset()` with a `reaper.GetUserInputs` dialog when clicked. LOAD SHALL prompt a file selection or call `preset_browser.LoadPreset()` for the currently selected preset.

#### Scenario: SAVE opens naming dialog

- GIVEN the MIDI island header is visible
- WHEN user clicks the SAVE icon button
- THEN `reaper.GetUserInputs("Save Preset", ...)` SHALL appear
- AND on confirmation `browser.SavePreset(filepath, name)` SHALL be called
- AND the preset list SHALL refresh if the panel is open

#### Scenario: LOAD loads selected preset

- GIVEN a preset is selected in the preset list
- WHEN user clicks the LOAD icon button
- THEN `browser.LoadPreset(files[idx].path)` SHALL be called
- AND island notes SHALL be replaced with the loaded preset

### Requirement: Window Position Persistence

The GFX window position (`gfx.w`, `gfx.h`, `config.state.view_offset_x/y`) SHALL be polled and saved to persist via `persist.Save()` during island toggle AND periodically (every ~60 frames or on resize). On ToggleIsland, the saved position SHALL be restored to `gfx.init()` parameters.

#### Scenario: Position restored after toggle

- GIVEN the window was at position (200, 150) when last saved
- WHEN user collapses and re-expands the MIDI island
- THEN the window SHALL reappear at (200, 150) rather than the default position

## Acceptance Criteria

- [ ] Notes, selection, scroll, zoom, tool mode, snap state all survive toggle
- [ ] Undo/redo stacks survive toggle
- [ ] 500px base height is the scale constant (verify no gfx.h usage for scaling)
- [ ] gfx.quit() + gfx.init() remains the toggle mechanism (not replaced by gfx resize)
- [ ] No state loss or corruption across multiple rapid toggles
- [ ] MAX_UNDO = 50 declared local; FIFO eviction at 51st push
- [ ] Undo_stack and redo_stack initialized in island_state (not nil)
- [ ] _uuid_to_idx is local (no global leak)
- [ ] Folder list scrolls when content exceeds visible height
- [ ] Window heights derived from local constants (793/497 not hardcoded)
- [ ] Island grows/shrinks dynamically when window is resized vertically (10px bottom margin)
- [ ] Minimum island height equals original expanded height — no collapse below `MIN_ISLAND_H`
- [ ] Scale system unchanged (500px base constant, not gfx.h) — header, islands, performance area maintain size
- [ ] RELOAD/SYNC render as glyphs, not text, with smaller buttons
- [ ] SAVE/LOAD icon buttons exist next to PRESETS in the header
- [ ] SAVE triggers preset save dialog, LOAD triggers preset load
- [ ] Window position survives ToggleIsland collapse/expand
