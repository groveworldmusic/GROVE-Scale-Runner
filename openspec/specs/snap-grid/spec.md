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

The system SHALL provide a resolution selector with options: beat modes (1/1, 1/2, 1/4, 1/8, 1/16, 1/32) and triplet modes (1/8T, 1/16T). Resolution SHALL be stored in island_store via `GetSnapResolution()` / `SetSnapResolution()`. Resolution 0 means "snap disabled".

#### Scenario: Resolution change affects snap granularity

- GIVEN snap enabled at 1/4 (0.25 beat), note at beat 2.0
- WHEN user changes resolution to 1/8 (0.125 beat) and drags right by 0.15 beats
- THEN start_beat = 2.125 (snapped to 1/8 boundary)

#### Scenario: Triplet grid

- GIVEN snap at 1/8T (1/12 beat divisions)
- WHEN user creates a note at beat 1.0
- THEN note snaps to nearest 1/12 beat boundary

### Requirement: SnapBeat() Pure Function

A centralized `SnapBeat(beat, resolution) -> snapped_beat` SHALL exist. All note geometry operations MUST call this function. The function SHALL have zero side effects. When resolution is nil or 0, SHALL return the input unchanged (identity function).

#### Scenario: SnapBeat at 1/4

- GIVEN SnapBeat(2.3, 0.25)
- THEN returns 2.25

#### Scenario: SnapBeat identity when disabled

- GIVEN SnapBeat(2.37, nil)
- THEN returns 2.37 (no change)

## Acceptance Criteria

- [ ] Snap toggle button visible in piano roll toolbar, visually indicates ON/OFF state
- [ ] Resolution selector cycles through all 9 options (6 beat + 2 triplet + off)
- [ ] SnapBeat() returns correct values for all resolutions and edge cases
- [ ] Snap state persists across ToggleIsland transitions
- [ ] Grid filters to snap resolution when snap enabled
- [ ] All note operations (move, resize, create from pencil tool) respect snap
