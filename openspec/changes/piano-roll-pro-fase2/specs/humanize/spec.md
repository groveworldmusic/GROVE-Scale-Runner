# Humanize Specification

## Purpose

Add natural, human-like timing and velocity imperfections to selected MIDI notes to reduce the mechanical feel of perfectly quantized sequences.

## Requirements

### Requirement: Humanize Operation

The system SHALL implement a `HumanizeNotes(selected_indices, timing_range, velocity_range)` operation. 

1. **Timing Jitter**: For each selected note, the start beat SHALL be offset by a random value: `new_beat = beat + (math.random() - 0.5) * (timing_range / 100) * current_grid_size`.
2. **Velocity Jitter**: For each selected note, the velocity SHALL be offset: `new_vel = clamp(velocity + (math.random() - 0.5) * velocity_range, 1, 127)`.

The operation SHALL be triggered by shortcut **Ctrl+H** (char 336).

#### Scenario: Basic Humanize

- GIVEN a selection of 4 notes perfectly quantized to 1/16, timing_range = 10%, velocity_range = 20
- WHEN user presses Ctrl+H
- THEN each note's start beat is shifted by up to +/- 0.003125 beats (0.05 * 0.0625)
- AND each note's velocity is shifted by up to +/- 10 units
- AND the result is visually apparent as slight misalignments from the grid

#### Scenario: No selection no-op

- GIVEN no notes selected
- WHEN user presses Ctrl+H
- THEN nothing happens (no crash)

### Requirement: Humanize Undo

All changes made during a single Humanize operation SHALL be captured in one undo entry of type `"humanize"`. The entry MUST store the pre-humanize and post-humanize state arrays (start_beat, velocity) for all affected notes.

#### Scenario: Undo restores original timing/velocity

- GIVEN notes were humanized
- WHEN user presses Ctrl+Z
- THEN all humanized notes return to their exact pre-humanize positions and velocities
- AND the undo stack shows a single "humanize" entry
