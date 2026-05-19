# MIDI Island Specification

## Purpose

Expandable panel header with tool modes, MIDI channel, PRESETS toggle, RELOAD/SYNC, snap controls, and SAVE/LOAD. This spec describes the header toolbar behavior and window lifecycle for the MIDI island.

## Requirements

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

- [ ] RELOAD/SYNC render as glyphs, not text, with smaller buttons
- [ ] SAVE/LOAD icon buttons exist next to PRESETS in the header
- [ ] SAVE triggers preset save dialog, LOAD triggers preset load
- [ ] Window position survives ToggleIsland collapse/expand
