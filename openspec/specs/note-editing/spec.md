# Note Editing Specification

## Purpose

Click-drag to move notes (pitch + start_beat) and edge-drag to resize (duration). Snap-aware. Multi-selection group move.

## Requirements

### Requirement: Note Move via Drag

The system MUST allow click-drag on a note block body to change its pitch (Y-axis, semitone granularity) and start_beat (X-axis). Drag delta MUST snap to the current snap resolution if snap is enabled. All selected notes SHALL move by the same delta (beats and semitones). A single undo entry SHALL be pushed on drag commit (mouse up).

#### Scenario: Move single note to new position

- GIVEN a note at pitch 60, start_beat 2.0, snap disabled
- WHEN user drags note 3 semitones up and 2 beats right
- THEN pitch = 63, start_beat = 4.0

#### Scenario: Snap-aware move rounding

- GIVEN snap enabled at 1/4 resolution, note at beat 2.0
- WHEN user drags note right by 0.3 beats
- THEN start_beat remains 2.0 (snapped to nearest 0.25 boundary)

#### Scenario: Multi-note group move

- GIVEN notes at indices 1 (beat 1.0) and 3 (beat 4.0) both selected
- WHEN user drags note at index 1 right by 1 beat
- THEN note at index 1 moves to beat 2.0 AND note at index 3 moves to beat 5.0

#### Scenario: Undo entry on commit

- GIVEN a note moved via drag
- WHEN drag ends (mouse up)
- THEN an undo entry is pushed with pre-move positions of all affected notes

### Requirement: Note Resize via Edge-Drag

The system MUST allow edge-drag on the right edge of a note block to change its duration. A 4px hit zone on the right edge SHALL distinguish resize from move. Duration MUST snap to snap resolution. Minimum duration: 1 subdivision unit at current snap resolution.

#### Scenario: Resize extends duration

- GIVEN a note with duration 1.0, snap at 1/8
- WHEN user drags right edge right by 0.5 beats
- THEN duration = 1.5 (snapped to nearest 1/8)

#### Scenario: Minimum duration clamp

- GIVEN snap at 1/4 (0.25 beat units), note at duration 0.5
- WHEN user drags right edge leftward past 0.25
- THEN duration clamps to 0.25

#### Scenario: Edge hit zone detection

- GIVEN cursor within 4px of note's right edge
- WHEN user presses mouse
- THEN operation mode = resize (not move)

### Requirement: Drag Cancellation

The system MUST cancel an in-progress drag or resize if Escape is pressed. On cancel, notes return to their pre-drag positions. No undo entry SHALL be created.

#### Scenario: Cancel via Escape

- GIVEN an active note drag
- WHEN user presses Escape
- THEN all dragged notes snap back to original positions
- AND no undo entry is created

## Acceptance Criteria

- [ ] Click-drag moves note pitch and start_beat with snap awareness
- [ ] Edge-drag resizes duration with snap awareness, minimum 1 subdivision
- [ ] Multi-selection moves as a group preserving relative offsets
- [ ] Escape cancels drag, restores original state
- [ ] Undo entry pushed on drag commit
- [ ] Lasso disabled during drag (no conflating interactions)
