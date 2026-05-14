# Velocity Editor Specification

## Purpose

Panel displaying per-note velocity as vertical bars. Supports click-and-drag to edit velocity. Shows mute toggle per note. Reads from and writes to the island store's note data model.

## Requirements

### Requirement: Velocity Bar Display

The velocity editor SHALL render a vertical bar for each note in the visible piano roll region. Bar height MUST be proportional to `note.velocity / 127` relative to the panel's available height. Bar color MUST use the theme's note color for that pitch. Muted notes MUST render at 30% opacity or with a diagonal hatch pattern.

#### Scenario: Display note velocities

- GIVEN 3 notes with velocities `[100, 60, 127]`
- WHEN the velocity editor renders
- THEN 3 vertical bars appear with heights proportional to 100/127, 60/127, 127/127

#### Scenario: Muted note dimmed

- GIVEN a note with `muted = true` and velocity 80
- WHEN the velocity editor renders
- THEN the bar is drawn at reduced opacity or with a visual mute indicator

### Requirement: Click-to-Edit Velocity

The user SHALL click and drag vertically on a velocity bar to change that note's velocity. The velocity value SHALL update in real time during drag (rounded to nearest integer, clamped 0-127). The island store's `edit_buffer` SHALL be set to the selected note index on click.

#### Scenario: Drag changes velocity

- GIVEN a bar for note at index 0 with velocity 64
- WHEN the user clicks bar and drags from y=100 to y=50 (upward = higher)
- THEN `notes[0].velocity` changes to a value > 64 (proportional to drag distance)
- AND `GetEditBufferIndex()` equals 0

#### Scenario: Zero-velocity is allowed

- GIVEN a bar for note index 0 with velocity 10
- WHEN user drags to the bottom of the panel
- THEN `notes[0].velocity` becomes 0 (note plays silently or is gated)

### Requirement: Mute Toggle

Each velocity bar SHALL have an adjacent mute button (small square or "M" label). Clicking it toggles `note.muted`. Muted notes MUST NOT play during sequencer trigger — this is enforced by the sequencer reading `muted` before sending MIDI.

#### Scenario: Toggle mute

- GIVEN a note where `muted = false`
- WHEN user clicks its mute button
- THEN `note.muted` becomes `true`
- AND the bar rendering dims immediately

## Acceptance Criteria

- [ ] Velocity bars render with correct heights for all notes in visible region
- [ ] Drag-to-edit changes velocity, clamps 0-127, updates in real time
- [ ] Mute toggle flips the `muted` flag
- [ ] Muted bars render visually distinct (dimmed/hatched)
- [ ] Edit buffer selects correct note on click
