# Snap Grid Specification

## Purpose

Toggle snap on/off with resolution selector and centralized SnapBeat() function. Affects note creation, move, resize, and grid line rendering.

## Requirements

### Requirement: Snap Toggle

The piano roll toolbar SHALL provide a snap toggle button. When enabled, all note operations snap to the current resolution. Grid lines SHALL filter to show only the active snap tier and above (e.g., snap at 1/4 hides 1/8 and 1/16 lines).

#### Scenario: Toggle snap on

- GIVEN snap disabled and grid showing 1/16 lines
- WHEN user toggles snap ON at 1/4 resolution
- THEN grid SHALL render only measure, beat, and 1/4 lines
- AND 1/8 and 1/16 lines are hidden

#### Scenario: Toggle snap off = free placement

- GIVEN snap disabled
- WHEN user drags a note to beat 2.37
- THEN start_beat is exactly 2.37 (no rounding)

### Requirement: Snap Resolution Selector

The system SHALL provide a resolution selector with options: beat modes (1/1, 1/2, 1/4, 1/8, 1/16, 1/32) and triplet modes (1/8T, 1/16T). Resolution SHALL be stored in island_store via `GetSnapResolution()` / `SetSnapResolution()`. Resolution 0 means "snap disabled". The triplet toggle button SHALL be REMOVED from the header toolbar. A separator line followed by a "Triplet: ON"/"Triplet: OFF" toggle SHALL appear at the bottom of the resolution `gfx.showmenu()` context menu.

#### Scenario: Resolution change affects snap granularity

- GIVEN snap enabled at 1/4 (0.25 beat), note at beat 2.0
- WHEN user changes resolution to 1/8 (0.125 beat) and drags right by 0.15 beats
- THEN start_beat = 2.125 (snapped to 1/8 boundary)

#### Scenario: Resolution menu includes triplet toggle

- GIVEN the snap resolution button in the header
- WHEN user clicks it
- THEN the `gfx.showmenu()` SHALL show:
  ```
  1/1|1/2|1/4|1/8|1/16|1/32|
  |Triplet: ON|Triplet: OFF
  ```
- AND a separator (`|` alone) SHALL appear before the triplet entry

#### Scenario: Triplet toggle from menu changes state

- GIVEN triplet is currently OFF
- WHEN user selects "Triplet: ON" from the resolution menu
- THEN `island_store.SetSnapTriplet(true)` SHALL be called
- AND the snap resolution menu SHALL remember the triplet state for next open

#### Scenario: Triplet state persists when changing resolution

- GIVEN triplet is ON and resolution is 1/4
- WHEN user opens the menu and selects 1/8
- THEN triplet remains ON (effective step = 4 / (8 * 1.5) = 1/12)
- AND `island_store.GetSnapTriplet()` returns `true`

### Requirement: SnapBeat() Pure Function

A centralized `SnapBeat(beat, resolution) -> snapped_beat` SHALL exist. All note geometry operations MUST call this function. The function SHALL have zero side effects. When resolution is nil or 0, SHALL return the input unchanged (identity function).

#### Scenario: SnapBeat at 1/4

- GIVEN SnapBeat(2.3, 0.25)
- THEN returns 2.25

#### Scenario: SnapBeat identity when disabled

- GIVEN SnapBeat(2.37, nil)
- THEN returns 2.37 (no change)

### Requirement: Scale Snap Mode (preferences_store toggle)

The `preferences_store` SHALL add a `scale_snap_highlight` boolean field (default `false`). This SHALL control whether vertical grid lines at scale pitches render with a distinct highlight color. The toggle SHALL be persisted via the existing debounced save pattern (`dirty_keys` + `TickSaveDebounce`). The grid rendering for scale snap highlight is specified in the piano-roll delta spec.

#### Scenario: Toggle persists across restart

- GIVEN user toggles `scale_snap_highlight` to `true`
- WHEN the script restarts
- THEN `preferences_store.GetScaleSnapHighlight()` SHALL return `true`

## Acceptance Criteria

- [ ] Snap toggle button visible in piano roll toolbar, visually indicates ON/OFF state
- [ ] Resolution selector cycles through all 9 options (6 beat + 2 triplet + off)
- [ ] SnapBeat() returns correct values for all resolutions and edge cases
- [ ] Snap state persists across ToggleIsland transitions
- [ ] Grid filters to snap resolution when snap enabled
- [ ] All note operations (move, resize, create from pencil tool) respect snap
- [ ] Triplet button removed from header toolbar (no "3" or "·" glyph)
- [ ] Triplet ON/OFF appears as a toggle in the resolution `gfx.showmenu()` context menu
- [ ] Resolution menu shows separator before triplet entry
- [ ] Triplet state persists when changing resolutions
- [ ] Scale snap highlight toggle exists and persists via TickSaveDebounce
