# Undo System Specification

## Purpose

Command pattern undo/redo for all note edit operations, UUID lifecycle, and preset-load integrity. 50-deep stack with shallow state capture.

## Requirements

### Requirement: Undo Stack

The system SHALL maintain a history stack of up to 50 entries. Each entry SHALL capture the state needed to reverse the edit. When the stack exceeds 50, the oldest entry SHALL be discarded (FIFO eviction).

#### Scenario: Undo restores note position

- GIVEN a note moved from beat 2.0 to beat 4.0
- WHEN user triggers undo
- THEN note returns to beat 2.0 AND stack depth decreases by 1

#### Scenario: Stack overflow eviction

- GIVEN 50 undo entries
- WHEN a 51st edit occurs
- THEN the oldest entry is discarded AND stack remains at 50

### Requirement: Edit Types Covered

The undo system SHALL cover: add note, delete note(s), move note(s), resize note, velocity change, and mute toggle. Each SHALL push a descriptive labeled entry.

#### Scenario: Delete undo restores removed notes

- GIVEN 3 notes, note at index 2 deleted
- WHEN undo is triggered
- THEN note at index 2 is restored with original all fields (pitch, start_beat, duration, velocity, muted)

#### Scenario: Bulk delete single undo entry

- GIVEN 5 notes, notes 2 and 4 selected and deleted
- WHEN undo is triggered
- THEN both notes 2 and 4 are restored in a single operation

### Requirement: Redo Stack

Undo SHALL move the entry to a redo stack (also capped at 50). A new edit after undo SHALL clear the redo stack.

#### Scenario: Undo then redo

- GIVEN note moved then undone
- WHEN user triggers redo
- THEN note moves back to the undone position

#### Scenario: New edit clears redo

- GIVEN note moved and undone
- WHEN user adds a new note (instead of redo)
- THEN the redo stack is cleared AND the move cannot be recovered via redo

### Requirement: Shallow State Capture

The undo system MUST NOT deep-copy the entire notes array on single-note edits. It SHALL capture only the affected note(s) by index + pre-edit snapshot. A full array snapshot MAY be taken before bulk destructive operations.

#### Scenario: Single note move capture

- GIVEN a single note at index 3 is moved
- WHEN undo entry is created
- THEN it captures only `{index=3, pre={pitch, start_beat, duration, velocity, muted}}` AND does not copy the full notes array

### Requirement: UUID allocation on preset load

`LoadPreset` MUST call `AllocNoteUUID()` per note before `SetNotes()`.

#### Scenario: Undo works after preset load

- GIVEN preset notes have no `uuid` field
- WHEN `LoadPreset` builds the note table
- THEN every note SHALL have a unique `uuid`
- AND `RebuildUUIDIndex()` SHALL index all loaded notes

### Requirement: Undo stacks cleared on preset load

`LoadPreset` MUST call `ClearUndoStacks()` after loading.

#### Scenario: No stale undo after load

- GIVEN undo history exists before loading
- WHEN the preset is loaded
- THEN `undo_stack` and `redo_stack` SHALL be empty

### Requirement: No dead code in velocity module

`base_initial_vel` in `velocity.lua` MUST be removed.

#### Scenario: No unused variable

- GIVEN the velocity module is loaded
- WHEN `HandleVelocityMouse` runs bulk drag
- THEN no unreferenced `base_initial_vel` SHALL exist

## Acceptance Criteria

- [ ] Undo restores all edit types (add, delete, move, resize, velocity, mute)
- [ ] Redo restores undone edits
- [ ] New edit clears redo stack
- [ ] 50-entry cap verified (FIFO eviction at 51st edit)
- [ ] Shallow capture verified — single-note edit does not copy full array
- [ ] Ctrl+Z/Y trigger undo/redo (see keyboard-shortcuts spec)
- [ ] LoadPreset assigns unique UUID to each note via AllocNoteUUID()
- [ ] LoadPreset calls ClearUndoStacks() after SetNotes()
- [ ] base_initial_vel removed from velocity.lua (dead code)
- [ ] Undo/redo works correctly after preset load
