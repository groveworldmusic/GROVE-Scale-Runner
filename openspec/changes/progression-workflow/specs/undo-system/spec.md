# Delta for Undo System

## ADDED Requirements

### Requirement: Progression Undo Stacks in Sequencer Store (ADDED)

The sequencer store SHALL expose `prog_undo_stack` and `prog_redo_stack` (each capped at 50 entries, FIFO). `PushUndo()` SHALL deep-copy progression[1..16] and push to `prog_undo_stack`, clearing `prog_redo_stack`. `HandleUndo()` pops from `prog_undo_stack`, pushes the current state to `prog_redo_stack`, then calls `seq_store.SetProgression(snapshot)`. `HandleRedo()` mirrors this. `ClearProgressionUndoStacks()` empties both stacks with no side effects.

#### Scenario: PushUndo snapshot before mutation

- GIVEN progression is [C, D, E] (slots 1-3)
- WHEN `PushUndo()` is called (before SetProgressionEntry mutates)
- THEN `prog_undo_stack` has 1 entry: deep copy of [C, D, E]
- AND `prog_redo_stack` is empty

#### Scenario: HandleUndo restores via SetProgression

- GIVEN progression was [C, D, E], then slot 2 was removed — [C, nil, E]
- AND `prog_undo_stack` has 1 entry: [C, D, E]
- WHEN `HandleUndo()` is called
- THEN progression becomes [C, D, E] via `SetProgression`
- AND redo stack gets the [C, nil, E] snapshot

#### Scenario: HandleRedo after HandleUndo

- GIVEN progression restored to [C, D, E] via undo
- WHEN `HandleRedo()` is called
- THEN progression reverts to [C, nil, E] (the redo snapshot)

#### Scenario: New edit after undo clears redo

- GIVEN progression was undid (redo stack non-empty)
- WHEN `PushUndo()` is called on a new mutation
- THEN `prog_redo_stack` is cleared (redo branch abandon)

#### Scenario: 50-entry cap with eviction

- GIVEN `prog_undo_stack` has 50 entries
- WHEN a 51st snapshot is pushed
- THEN the oldest entry is discarded AND stack remains at 50

#### Scenario: Clear stacks is idempotent

- GIVEN stacks are empty
- WHEN `ClearProgressionUndoStacks()` is called
- THEN no error, no side effect

## MODIFIED Requirements

### Requirement: Undo stacks cleared on preset load (MODIFIED)

`LoadPreset` MUST call BOTH `ClearUndoStacks()` (note/piano-roll) and `ClearProgressionUndoStacks()` (progression) after successfully loading or after any load error.
(Previously: only `ClearUndoStacks()` was called)

#### Scenario: Preset load clears both stacks

- GIVEN note undo stack has 3 entries, progression undo stack has 2 entries
- WHEN any preset is loaded (notes or progression)
- THEN note undo stack is clean AND progression undo stack is clean
