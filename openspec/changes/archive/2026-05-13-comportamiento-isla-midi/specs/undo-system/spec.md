# Undo System Specification

## Purpose

Undo/redo integrity, UUID lifecycle, and preset-load behavior.

## Requirements

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
