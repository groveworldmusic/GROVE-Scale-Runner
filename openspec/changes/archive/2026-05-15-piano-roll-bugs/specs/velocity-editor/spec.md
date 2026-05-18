# Delta for velocity-editor

## Overview

Three behavior changes in the velocity editor: overlapping bars stack instead of offset (Bug 2); hit test defers to pre-selected note when one is selected (Bug 3); velocity click does not clear piano roll selection (Bug A).

## MODIFIED Requirements

### Requirement: Velocity Bar Display

The velocity editor SHALL render a vertical bar for each note in the visible piano roll region. Bar height MUST be proportional to `velocity / 127` relative to the panel's available height. Bar color MUST use the theme's note color for that pitch. Muted notes MUST render using a defined `MUTED_BAR_COLOR` constant at full opacity. Notes at the same `start_beat` SHALL stack at the same X position; the last-drawn bar renders on top. The velocity panel height SHALL use EXACTLY `velocity.EDITOR_H` (100px when expanded) or `velocity.COLLAPSED_H` (10px when collapsed). The excess space from `pr_h_full % piano_roll.PITCH_ROW_H` SHALL be given to the piano roll grid height instead of the velocity panel.

(Previously: notes at same start_beat offset bars horizontally by 1-2px)

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

#### Scenario: Collapsed velocity uses exactly COLLAPSED_H

- GIVEN `vel_expanded = false`, `velocity.COLLAPSED_H = 10`
- WHEN layout calculates heights
- THEN `ve_h` SHALL equal exactly 10
- AND all excess from `pr_h_full % PITCH_ROW_H` SHALL go to piano roll

### Requirement: Click-to-Edit Velocity

The user SHALL click and drag vertically on a velocity bar to change that note's velocity. When `selected_indices` contains multiple entries, drag SHALL apply the SAME relative change to ALL selected notes. If `island_store.GetPrimarySelectedIndex()` returns a valid non-nil index (note pre-selected in piano roll), velocity editing MUST target that note regardless of hit test — hit test is only used when nothing is pre-selected. Velocity click MUST NOT clear the piano roll selection. The velocity value SHALL update in real time during drag (rounded to nearest integer, clamped 0-127).

(Previously: hit test determines target unconditionally; ClearSelection() called on velocity click against non-selected note)

#### Scenario: Drag changes velocity

- GIVEN a bar for note at index 0 with velocity 64
- WHEN the user clicks bar and drags from y=100 to y=50 (upward = higher)
- THEN `notes[0].velocity` changes to a value > 64 (proportional to drag distance)

#### Scenario: Drag changes all selected velocities

- GIVEN selected_indices = {[2]=true, [5]=true}, both velocity 64
- WHEN user clicks bar at index 2, drags upward
- THEN notes[2].velocity and notes[5].velocity both increase by the same delta

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

#### Scenario: Zero-velocity is allowed

- GIVEN a bar for note index 0 with velocity 10
- WHEN user drags to the bottom of the panel
- THEN `notes[0].velocity` becomes 0

### Requirement: Mute Toggle

Unchanged — see main spec. Right-click toggles mute on ALL selected_indices.

#### Scenario: Toggle mute on selected

- GIVEN selected_indices = {[2]=true, [5]=true}, notes[2].muted = false
- WHEN user right-clicks on note 5's velocity bar
- THEN notes[2].muted AND notes[5].muted both become `true`

## Acceptance Criteria (Delta)

- [ ] Bars at same beat render stacked at same X (no offset_map)
- [ ] Pre-selected piano roll note is velocity-edited even if hit test returns different note
- [ ] Velocity click does not clear piano roll selection
- [ ] Zero-velocity still clamps 0-127
- [ ] Mute toggle still works on multi-selection
