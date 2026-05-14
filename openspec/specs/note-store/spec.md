# note-store Specification

**Type**: New
**Purpose**: Extract note CRUD, UUID, undo/redo, and progression→notes conversion from island.lua into a dedicated store. Reduces island.lua from 566 LOC to ~310 LOC.

## Requirements

### Requirement: Note Data Management

The store SHALL manage a flat ordered array of notes `{pitch, start_beat, duration, velocity, muted, uuid, origin?}` with CRUD operations.

#### Scenario: Add note with auto-UUID

- GIVEN an empty note store
- WHEN `AddNote({pitch=60, start_beat=0, duration=1, velocity=100, muted=false})` is called
- THEN `note.uuid` is set to 1 (auto-increment)
- AND `note.origin` is set to `"manual"`
- AND `GetNoteCount()` returns 1

#### Scenario: Remove note adjusts selection

- GIVEN 3 notes with indices 1, 2, 3 and snapshot `{selected_indices={[2]=true, [3]=true}}`
- WHEN `RemoveNoteAtIndex(2)` is called
- THEN the note at old index 3 shifts to index 2
- AND `selected_indices` adjusts to `{[2]=true}` (old index 3 → new index 2)

### Requirement: UUID Index

The store SHALL maintain a monotonic UUID counter and a reverse index (uuid → array index). The index SHALL be rebuilt after removal or replacement.

#### Scenario: Find note by UUID

- GIVEN a note at index 2 with `uuid=42`
- WHEN `FindNoteByUUID(42)` is called
- THEN returns 2

### Requirement: Undo/Redo Stacks

The store SHALL maintain undo/redo stacks capped at 50 entries. New edits SHALL clear the redo stack. FIFO eviction on overflow.

#### Scenario: Push undo clears redo

- GIVEN redo stack has 3 entries
- WHEN `PushUndo({type="move"})` is called
- THEN redo stack is empty

### Requirement: Progression→Notes Conversion

The store SHALL provide `ProgressionToNotes(progression, beats_per_slot?, velocity?)` returning a flat note array with UUIDs allocated for each chord pitch.

#### Scenario: Single progression entry produces chord notes

- GIVEN a progression entry `{degree=1, root_index=1, scale_index=1, octave=4, chord_mode_index=2}` (Tri chord)
- WHEN `ProgressionToNotes({[1]=entry})` is called
- THEN returns 3 notes (Tri = 3 offsets) at `start_beat=0`
- AND each note has a unique UUID

### Requirement: Visible Notes Filter

`GetVisibleNotes(notes, p_start, p_end, b_start, b_end)` SHALL return a subset of notes within the given pitch and beat range (inclusive bounds). Used for virtual scrolling in piano roll rendering.
