# Keyboard Shortcuts Specification

## Purpose

Standard DAW keyboard shortcuts for the piano roll: undo/redo, delete, arrow nudge.

## Requirements

### Requirement: Undo/Redo Shortcuts

Ctrl+Z SHALL trigger undo. Ctrl+Y SHALL trigger redo. Both SHALL consume the key event (not propagate to REAPER). Empty stack SHALL be a no-op (no error, no crash).

#### Scenario: Ctrl+Z triggers undo

- GIVEN note moved and undo stack has 1 entry
- WHEN user presses Ctrl+Z
- THEN undo is invoked AND note returns to original position

#### Scenario: Empty undo stack no-op

- GIVEN no edits made
- WHEN user presses Ctrl+Z
- THEN nothing happens (no crash, no error)

### Requirement: Delete Key

Delete SHALL remove all notes in `selected_indices`. A single undo entry SHALL capture the bulk deletion. Empty selection SHALL be a no-op.

#### Scenario: Delete selected notes

- GIVEN 5 notes, indices 2 and 4 selected
- WHEN user presses Delete
- THEN notes at 2 and 4 removed AND remaining notes shift AND one undo entry captures both deletions

### Requirement: Arrow Nudge

Arrow keys SHALL nudge selected notes. Left/Right change start_beat by 1 snap unit. Up/Down change pitch by ±1 semitone. Shift+arrow SHALL nudge by 1 beat (left/right) or 12 semitones (up/down). Snap awareness applies to X-axis nudge.

#### Scenario: Right arrow at 1/16 snap

- GIVEN note at start_beat 2.0, snap at 1/16 (0.0625)
- WHEN user presses Right arrow
- THEN start_beat = 2.0625

#### Scenario: Shift+Up octave jump

- GIVEN note at pitch 60
- WHEN user presses Shift+Up arrow
- THEN pitch = 72

#### Scenario: Multi-nudge

- GIVEN notes at indices 1 (pitch 60) and 2 (pitch 64) selected
- WHEN user presses Down arrow
- THEN both notes drop 1 semitone (to 59 and 63)

### Requirement: Fall-Through for Unhandled Keys

Keys not matching any piano roll shortcut SHALL NOT be consumed and MUST propagate to REAPER's default handling.

#### Scenario: Unknown key passes through

- GIVEN piano roll focused
- WHEN user presses a key not in the dispatch table (e.g., Space)
- THEN REAPER receives the native key event

## Acceptance Criteria

- [ ] Ctrl+Z/Y trigger undo/redo (no-op on empty stack)
- [ ] Delete removes selected notes with single undo entry
- [ ] Arrow keys nudge by snap unit (X) / 1 semitone (Y)
- [ ] Shift+arrow nudges by 1 beat / 12 semitones
- [ ] Empty selection: Delete and arrows are no-ops
- [ ] Unrecognized shortcuts fall through to REAPER
