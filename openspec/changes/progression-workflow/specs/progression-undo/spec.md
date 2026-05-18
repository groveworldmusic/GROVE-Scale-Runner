# Domain: Progression Undo — Full Specification

## Requirement: Snapshot-based Undo/Redo for Progression Slots

The system SHALL maintain a snapshot-based undo/redo system for the 16-slot progression array. Two FIFO stacks (`prog_undo_stack`, `prog_redo_stack`) capped at 50 entries each are held in the sequencer store. Before any mutation the system SHALL deep-copy all 16 slots via `{...}` per-entry copy and push the snapshot to the undo stack.
REQ-PU-01: Full-array deep-copy snapshots. REQ-PU-02: Redo stack mirroring; new edit after undo clears redo. REQ-PU-03: Keyboard shortcuts — Ctrl+Z (char 346) undo; Ctrl+Y (char 345) redo; context-aware routing between progression and piano-roll undo.

#### Scenario: Undo restores progression

- GIVEN slots [1]=C, [2]=D, [3]=E
- WHEN user removes slot 2
- THEN `ProgSnapshot()` pushes `[C,D,E]` to undo stack before mutation
- AND result is [1]=C, [2]=nil, [3]=E
- AND Ctrl+Z restores [1]=C, [2]=D, [3]=E

#### Scenario: FIFO eviction at 51

- GIVEN undo stack has 50 entries
- WHEN a 51st mutation occurs
- THEN the oldest entry is discarded
- AND stack remains at 50

#### Scenario: Empty undo stack no-op

- GIVEN progression untouched (no edits)
- WHEN user presses Ctrl+Z
- THEN nothing happens (no crash, no error)

#### Scenario: Redo restores after undo

- GIVEN slot 2 was removed then undone (stack: undo cleared, redo has [C,D,E])
- WHEN user presses Ctrl+Y
- THEN removed state is restored: slot 2 is nil again

#### Scenario: New edit clears redo

- GIVEN slot removed then undone (redo has entry)
- WHEN user removes a different slot (new edit)
- THEN the redo stack is cleared (forward branch lost)
