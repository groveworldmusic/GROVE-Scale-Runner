# Delta for Note Editing

## ADDED Requirements

### Requirement: Alt+Drag Clone Notes

When Alt (gfx.mouse_cap & 16) is held at the moment of drag start on a note block, the system SHALL clone the dragged notes instead of moving them. Cloned notes SHALL be deep copies of the originals with new UUIDs, same pitch, duration, velocity, and muted state. The clone copies SHALL be placed at the drag-end position. The original notes SHALL remain unchanged at their original positions. When Alt is not held, existing move behavior is unchanged.

#### Scenario: Alt+drag clones a single note

- GIVEN a note at pitch 60, start_beat 2.0, snap disabled
- WHEN user holds Alt, clicks and drags the note 3 semitones up and 2 beats right
- THEN the original note remains at pitch 60, beat 2.0
- AND a new note appears at pitch 63, beat 4.0
- AND the new note has a unique UUID, same duration/velocity/muted as the original

#### Scenario: Alt+drag clones from multi-selection

- GIVEN notes at indices 1 (beat 1.0) and 3 (beat 4.0) both selected
- WHEN user holds Alt, clicks note at index 1, drags 2 beats right
- THEN both notes SHALL clone: originals remain at beats 1.0 and 4.0
- AND cloned copies SHALL appear at beats 3.0 and 6.0
- AND each clone SHALL have a unique UUID

#### Scenario: Ctrl key not active during Alt+drag

- GIVEN Alt held but Ctrl also held (gfx.mouse_cap bits 16 + 4)
- WHEN user drags a note
- THEN clone behavior SHALL take priority (Alt detected first)
- AND Ctrl modifiers SHALL NOT interfere with clone behavior

### Requirement: Clone Undo Entry

Cloned notes SHALL produce a single undo entry of type `"add"` on drag commit (mouse up). The undo entry SHALL capture all notes added by the clone operation. Undo SHALL remove the cloned notes and restore original selection state.

#### Scenario: Undo removes cloned notes

- GIVEN 1 original note, Alt+drag created 1 cloned note
- WHEN user presses Ctrl+Z (undo) after clone commit
- THEN the cloned note is removed
- AND the original note remains at its original position
- AND selection returns to pre-clone state

## MODIFIED Requirements

### Requirement: Note Move via Drag

The system MUST allow click-drag on a note block body to change its pitch (Y-axis, semitone granularity) and start_beat (X-axis). Drag delta MUST snap to the current snap resolution if snap is enabled. All selected notes SHALL move by the same delta (beats and semitones). A single undo entry SHALL be pushed on drag commit (mouse up).

When Alt (gfx.mouse_cap & 16) is held at drag start, the system SHALL clone the dragged notes instead of moving them (see Alt+Drag Clone requirement).
(Previously: standard drag always moves, no clone behavior)

#### Scenario: Move single note to new position

- GIVEN a note at pitch 60, start_beat 2.0, snap disabled
- WHEN user drags note 3 semitones up and 2 beats right (Alt NOT held)
- THEN pitch = 63, start_beat = 4.0
- AND the original note moves (no clone)

#### Scenario: Snap-aware move rounding

- GIVEN snap enabled at 1/4 resolution, note at beat 2.0
- WHEN user drags note right by 0.3 beats (Alt NOT held)
- THEN start_beat remains 2.0 (snapped to nearest 0.25 boundary)

#### Scenario: Multi-note group move

- GIVEN notes at indices 1 (beat 1.0) and 3 (beat 4.0) both selected
- WHEN user drags note at index 1 right by 1 beat (Alt NOT held)
- THEN note at index 1 moves to beat 2.0 AND note at index 3 moves to beat 5.0

#### Scenario: Undo entry on commit

- GIVEN a note moved via drag
- WHEN drag ends (mouse up)
- THEN an undo entry is pushed with pre-move positions of all affected notes

#### Scenario: Alt+drag clones instead of moving

- GIVEN a note at pitch 60, start_beat 2.0
- WHEN user holds Alt AND drags note 2 beats right
- THEN the original note stays at pitch 60, beat 2.0
- AND a cloned copy appears at pitch 60, beat 4.0

### Requirement: Note Resize via Edge-Drag

(Unchanged from main spec)

### Requirement: Drag Cancellation

(Unchanged from main spec)

## Acceptance Criteria

- [ ] Alt+drag clones selected notes instead of moving them
- [ ] Originals remain unchanged after clone operation
- [ ] Clone on multi-selection creates copies of all selected notes at drag delta
- [ ] Undo removes cloned notes with a single "add" entry
- [ ] Alt NOT held: existing move behavior preserved exactly
- [ ] Edge-drag and drag cancellation unchanged
