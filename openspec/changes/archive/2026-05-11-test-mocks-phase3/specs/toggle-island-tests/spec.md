# ToggleIsland Tests — Specification

## Purpose
MIDI island window expand/collapse with dock guard and GFX lifecycle.

## Requirements

### Requirement: Dock Guard
When docked, `ToggleIsland` MUST return early with no GFX calls.

#### Scenario: Docked skips toggle
- GIVEN `ui_store.GetDockedMode()` returns true
- WHEN ToggleIsland is called
- THEN `gfx.quit` and `gfx.init` are NOT called

### Requirement: Expand from Collapsed
Collapsed → expanded: `gfx.quit()`, `gfx.init` with height 793, `gfx.setfont`.

#### Scenario: Expand island
- GIVEN `midi_island_expanded` is false
- WHEN ToggleIsland is called
- THEN `gfx.quit()` called, then `gfx.init` with height 793, then `gfx.setfont`, then `midi_island_toggled` = true

### Requirement: Collapse from Expanded
Expanded → collapsed: `gfx.quit()`, `gfx.init` with height 497, `gfx.setfont`.

#### Scenario: Collapse island
- GIVEN `midi_island_expanded` is true
- WHEN ToggleIsland is called
- THEN `gfx.quit()` called, then `gfx.init` with height 497, then `gfx.setfont`, then `midi_island_toggled` = true
