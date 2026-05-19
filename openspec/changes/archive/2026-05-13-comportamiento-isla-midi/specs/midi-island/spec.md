# MIDI Island Specification

## Purpose

State store init, window lifecycle, and toggle behavior for the island.

## Requirements

### Requirement: MAX_UNDO constant

The store MUST declare `local MAX_UNDO = 50`.

#### Scenario: FIFO eviction

- GIVEN PushUndo has >50 entries
- WHEN a new entry is pushed
- THEN the oldest SHALL be evicted

### Requirement: Undo stack initialization

`island_state` MUST include initialized `undo_stack`, `redo_stack`, `undo_depth`, `redo_depth`.

#### Scenario: First push safe

- GIVEN island state is initialized
- WHEN the first `PushUndo()` runs
- THEN `table.insert` MUST NOT error

### Requirement: UUID index scoped local

`_uuid_to_idx` MUST be `local`, not global.

#### Scenario: No global leak

- GIVEN the module is loaded
- WHEN `RebuildUUIDIndex()` runs
- THEN `_G._uuid_to_idx` SHALL be nil

### Requirement: Folder scroll state

`island_state` MUST have a `folder_scroll` field for folder list scroll offset.

#### Scenario: Folder list scrolls

- GIVEN folder list exceeds visible height
- WHEN the user scrolls
- THEN `folder_scroll` SHALL persist across frames

### Requirement: Window height from constants

`ToggleIsland` heights MUST derive from local constants, not hardcoded 793/497.

#### Scenario: Heights match layout

- GIVEN `ToggleIsland` runs
- WHEN expanded, height SHALL match the layout constant
- WHEN collapsed, height SHALL match the header constant
