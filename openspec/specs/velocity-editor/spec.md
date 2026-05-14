# Velocity Editor Specification

## Purpose

Panel displaying per-note velocity as vertical bars. Supports click-and-drag to edit velocity. Shows mute toggle per note. Reads from and writes to the island store's note data model.

## Requirements

### Requirement: Velocity Bar Display

The velocity editor SHALL render a vertical bar for each note in the visible piano roll region. Bar height MUST be proportional to `velocity / 127` relative to the panel's available height. Bar color MUST use the theme's note color for that pitch. Muted notes MUST render using a defined `MUTED_BAR_COLOR` constant at full opacity. Adjacent notes with the same `start_beat` SHALL offset bars horizontally by 1-2px to prevent visual overlap.

#### Scenario: Display note velocities

- GIVEN 3 notes with velocities `[100, 60, 127]`
- WHEN the velocity editor renders
- THEN 3 vertical bars appear with heights proportional to 100/127, 60/127, 127/127

#### Scenario: Muted note uses defined color constant

- GIVEN a note with `muted = true`, velocity 80
- WHEN the velocity editor renders
- THEN the bar uses `MUTED_BAR_COLOR` at full opacity, no crash

#### Scenario: Overlapping bars offset

- GIVEN two notes at `start_beat=2.0` with velocities `[100, 80]`
- WHEN the velocity editor renders
- THEN the bars offset horizontally by 1-2px, both fully visible

### Requirement: Click-to-Edit Velocity

The user SHALL click and drag vertically on a velocity bar to change that note's velocity. When `selected_indices` contains multiple entries, drag SHALL apply the SAME relative change to ALL selected notes. The `GetPrimarySelectedNoteIndex()` SHALL identify the bar the user initially clicked (for display/feedback). The velocity value SHALL update in real time during drag (rounded to nearest integer, clamped 0-127).

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
