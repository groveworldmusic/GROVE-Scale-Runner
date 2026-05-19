# Delta for note-store

**Change**: expansion-features (P3)
**Type**: Delta — origin support and open-note tracking for MIDI input recording

## MODIFIED Requirements

### Requirement: Note Data Management (modified)

The store SHALL manage a flat ordered array of notes `{pitch, start_beat, duration, velocity, muted, uuid, origin?}` with CRUD operations. The `origin` field SHALL default to `"manual"` when not provided, SHALL accept any string value, and SHALL be preserved through all store operations (copy, move, delete, undo/redo).

(Previously: `origin` field existed but was undefined for programmatic use; `AddNote` always set `origin="manual"`)

#### Scenario: Add note with custom origin (unchanged behavior extended)

- GIVEN an empty note store
- WHEN `AddNote({pitch=60, start_beat=0, duration=0, velocity=100, muted=false, origin="midi-input"})` is called
- THEN `note.uuid` SHALL be set to 1 (auto-increment)
- AND `note.origin` SHALL be `"midi-input"` (preserved, not overwritten to `"manual"`)
- AND `GetNoteCount()` SHALL return 1

#### Scenario: Existing manual notes unchanged

- GIVEN a note added without explicit origin
- WHEN `AddNote({pitch=60, ...})` is called via keyboard/chord playback
- THEN `note.origin` SHALL be `"manual"` (default)
- AND existing behavior is unchanged

### Requirement: Remove note adjusts selection (unchanged)

Unchanged — same behavior as existing spec.

### Requirement: UUID Index (unchanged)

Unchanged — same behavior as existing spec.

### Requirement: Undo/Redo Stacks (unchanged)

Unchanged — undo/redo stacks capture origin field like any other note property.

### Requirement: Progression→Notes Conversion (unchanged)

Unchanged — progression notes continue to set `origin` as defined by the progression layer.

## ADDED Requirements

### Requirement: Open Note Tracking for MIDI Input

The store SHALL support updating the `duration` of an open note in-place. `UpdateOpenNoteDuration(pitch, new_duration)` SHALL find the most recent note with matching `pitch` and `duration == 0` (sentinel for "ongoing") and set its `duration` field. If no matching note is found, the call SHALL be a silent no-op.

#### Scenario: Note-off updates duration

- GIVEN a note `{pitch=60, start_beat=1.0, duration=0, origin="midi-input"}`
- WHEN `UpdateOpenNoteDuration(60, 0.5)` is called
- THEN the note's duration SHALL be `0.5`
- AND note count SHALL remain unchanged (no new note created)

#### Scenario: No matching pitch is silent

- GIVEN no open note with pitch 72 exists
- WHEN `UpdateOpenNoteDuration(72, 1.0)` is called
- THEN it SHALL be a silent no-op
- AND `GetNoteCount()` SHALL be unchanged
