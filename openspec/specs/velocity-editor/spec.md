# Velocity Editor Specification

## Purpose

Panel displaying per-note velocity as vertical bars. Supports click-and-drag to edit velocity. Shows mute toggle per note. Reads from and writes to the island store's note data model.

## Requirements

### Requirement: Velocity Bar Display

The velocity editor SHALL render a vertical bar for each note in the visible piano roll region. Bar height MUST be proportional to `velocity / 127` relative to the panel's available height. Bar color MUST use the theme's note color for that pitch. Muted notes MUST render using a defined `MUTED_BAR_COLOR` constant at full opacity. Notes at the same `start_beat` SHALL stack at the same X position; the last-drawn bar renders on top. The velocity panel height SHALL use EXACTLY `velocity.EDITOR_H` (100px when expanded) or `velocity.COLLAPSED_H` (10px when collapsed). The excess space from `pr_h_full % piano_roll.PITCH_ROW_H` SHALL be given to the piano roll grid height instead of the velocity panel.

#### Scenario: Display note velocities

- GIVEN 3 notes with velocities `[100, 60, 127]`
- WHEN the velocity editor renders
- THEN 3 vertical bars appear with heights proportional to 100/127, 60/127, 127/127

#### Scenario: Muted note uses defined color constant

- GIVEN a note with `muted = true`, velocity 80
- WHEN the velocity editor renders
- THEN the bar uses `MUTED_BAR_COLOR` at full opacity, no crash

#### Scenario: Overlapping bars stack at same X

- GIVEN two notes at `start_beat=2.0` with velocities `[100, 80]`
- WHEN the velocity editor renders
- THEN both bars draw at the same X position (stacked, last-drawn on top)

#### Scenario: Expanded velocity uses exactly EDITOR_H

- GIVEN `vel_expanded = true`, `velocity.EDITOR_H = 100`
- AND `pr_h_full = 600`, `PITCH_ROW_H = 16` (grid rows divide evenly)
- WHEN layout calculates `ve_h`
- THEN `ve_h` SHALL equal exactly 100
- AND `pr_h` SHALL be `600 - 100 = 500` (no excess transferred)

#### Scenario: Velocity height never exceeds EDITOR_H

- GIVEN `vel_expanded = true`, `velocity.EDITOR_H = 100`
- AND `pr_h_full = 605`, `PITCH_ROW_H = 16` (excess = 605 % 16 = 13)
- WHEN layout calculates heights
- THEN `ve_h` SHALL equal exactly 100 (NOT `100 + 13 = 113`)
- AND the 13px excess SHALL be added to `pr_h` instead
- AND `pr_h_full - ve_h` = 505, minus the 13 excess = 492 grid-aligned rows = `pr_h`

#### Scenario: Collapsed velocity uses exactly COLLAPSED_H

- GIVEN `vel_expanded = false`, `velocity.COLLAPSED_H = 10`
- WHEN layout calculates heights
- THEN `ve_h` SHALL equal exactly 10
- AND all excess from `pr_h_full % PITCH_ROW_H` SHALL go to piano roll

### Requirement: Click-to-Edit Velocity

The user SHALL click and drag vertically on a velocity bar to change that note's velocity. When `selected_indices` contains multiple entries, drag SHALL apply the SAME relative change to ALL selected notes. If `island_store.GetPrimarySelectedIndex()` returns a valid non-nil index (note pre-selected in piano roll), velocity editing MUST target that note regardless of hit test — hit test is only used when nothing is pre-selected. Velocity click MUST NOT clear the piano roll selection. The velocity value SHALL update in real time during drag (rounded to nearest integer, clamped 0-127).

#### Scenario: Drag changes velocity

- GIVEN a bar for note at index 0 with velocity 64
- WHEN the user clicks bar and drags from y=100 to y=50 (upward = higher)
- THEN `notes[0].velocity` changes to a value > 64 (proportional to drag distance)

#### Scenario: Drag changes all selected velocities

- GIVEN selected_indices = {[2]=true, [5]=true}, both velocity 64
- WHEN user clicks bar at index 2, drags upward
- THEN notes[2].velocity and notes[5].velocity both increase by the same delta

#### Scenario: Zero-velocity is allowed

- GIVEN a bar for note index 0 with velocity 10
- WHEN user drags to the bottom of the panel
- THEN `notes[0].velocity` becomes 0 (note plays silently or is gated)

#### Scenario: Pre-selected note takes priority over hit test

- GIVEN note at index 3 is pre-selected in piano roll (`GetPrimarySelectedIndex()=3`)
- AND user click hits velocity bar at index 7 by position
- WHEN user drags vertically
- THEN note at index 3 receives the velocity change (NOT index 7)

#### Scenario: Velocity click preserves piano roll selection

- GIVEN piano roll has selected_indices = {[2]=true, [5]=true}
- WHEN user clicks velocity bar of a non-selected note (index 3) and drags
- THEN selected_indices remains {[2]=true, [5]=true} (selection unchanged)
- AND the velocity change applies to note index 3

### Requirement: Mute Toggle

Right-click on any selected note's velocity bar or on the piano roll SHALL toggle mute on ALL selected_indices. Muted notes MUST NOT play during sequencer trigger — this is enforced by the sequencer reading `muted` before sending MIDI.

#### Scenario: Toggle mute on selected

- GIVEN selected_indices = {[2]=true, [5]=true}, notes[2].muted = false
- WHEN user right-clicks on note 5's velocity bar
- THEN notes[2].muted AND notes[5].muted both become `true`

## Acceptance Criteria

- [ ] Velocity bars render with correct heights for all notes in visible region
- [ ] Drag-to-edit changes velocity, clamps 0-127, updates in real time
- [ ] Multi-selected velocity drag applies same relative delta to ALL selected notes
- [ ] Right-click toggles mute on ALL selected_indices (not just clicked note)
- [ ] Muted bars render using `MUTED_BAR_COLOR` at full opacity
- [ ] Velocity panel height is exactly EDITOR_H when expanded, COLLAPSED_H when collapsed
- [ ] Piano roll receives the remainder space (grid-aligned rows)
- [ ] No visual gap between velocity panel and piano roll due to misalignment
- [ ] Bars at same beat render stacked at same X (no offset_map)
- [ ] Pre-selected piano roll note is velocity-edited even if hit test returns different note
- [ ] Velocity click does not clear piano roll selection
