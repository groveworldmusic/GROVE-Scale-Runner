# Delta for Snap Grid

## MODIFIED Requirements

### Requirement: Snap Resolution Selector

The system SHALL provide a resolution selector with options: beat modes (1/1, 1/2, 1/4, 1/8, 1/16, 1/32) and triplet modes (1/8T, 1/16T). Resolution SHALL be stored in island_store via `GetSnapResolution()` / `SetSnapResolution()`. Resolution 0 means "snap disabled". The triplet toggle button SHALL be REMOVED from the header toolbar. A separator line followed by a "Triplet: ON"/"Triplet: OFF" toggle SHALL appear at the bottom of the resolution `gfx.showmenu()` context menu.
(Previously: triplet was a separate button in DrawSnapControls at `stp_x`, rendering "3" or "·" glyph)

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

## REMOVED Requirements

### Requirement: Triplet Button in Header

(Reason: triplet toggle moved to resolution context menu for cleaner header layout)

The separate triplet toggle button at `stp_x` with `snap_trip_w = math.floor(b_w * 0.35)` SHALL be removed from `DrawSnapControls()` in `header.lua`. The associated hover/click/tooltip logic (lines 78-96 of header.lua) SHALL be deleted. The space reclaimed (~math.floor(b_w * 0.35) + 4px gap) SHALL be redistributed to other controls in the header.

#### Scenario: No triplet button renders

- GIVEN the MIDI island header renders
- WHEN the snap controls area is drawn
- THEN no separate triplet button SHALL appear after the snap resolution button
- AND the triplet state SHALL only be accessible through the resolution context menu

## ADDED Requirements

### Requirement: Scale Snap Mode (preferences_store toggle)

(Note: The grid rendering for scale snap highlight is specified in the piano-roll delta spec. This requirement covers the snap-grid toggle/behavior aspect.)

The `preferences_store` SHALL add a `scale_snap_highlight` boolean field (default `false`). This SHALL control whether vertical grid lines at scale pitches render with a distinct highlight color. The toggle SHALL be persisted via the existing debounced save pattern (`dirty_keys` + `TickSaveDebounce`).

#### Scenario: Toggle persists across restart

- GIVEN user toggles `scale_snap_highlight` to `true`
- WHEN the script restarts
- THEN `preferences_store.GetScaleSnapHighlight()` SHALL return `true`

## Acceptance Criteria

- [ ] Triplet button removed from header toolbar (no "3" or "·" glyph)
- [ ] Triplet ON/OFF appears as a toggle in the resolution `gfx.showmenu()` context menu
- [ ] Resolution menu shows separator before triplet entry
- [ ] Triplet state persists when changing resolutions
- [ ] Scale snap highlight toggle exists and persists via TickSaveDebounce
