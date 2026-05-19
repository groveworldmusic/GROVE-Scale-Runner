# Progression Undo Hooks Specification

**Domain**: progression
**Change**: remaining-features (Phase A)
**Type**: New — dispatch hooks and composite wrapping for progression undo/redo

## Purpose

Wire the existing progression undo/redo stack (in `sequencer_store`) into the UI dispatch layer and progression mutation paths. Three hooks: composite wrap in `progression.Swap()`, Ctrl+Z/Y dispatch in `midi-island`, and undo snapshot in `SyncNotesToProgression()`.

## Requirements

### Requirement: Composite Wrap in Swap

`progression.Swap(a, b)` SHALL wrap the two `SetProgressionEntry` calls in a composite transaction so they produce a single undo entry instead of two. The system SHALL call `seq_store.SetProgUndoGate(true)` before the first swap, `false` after the second. The guard gate (`prog_undo_gate = true`) SHALL suppress snapshot creation during both `SetProgressionEntry` calls. A single `ProgSnapshot()` SHALL be taken and pushed to the undo stack before the gate opens.

#### Scenario: Swap produces one undo entry

- GIVEN progression has entries at slots 2 and 5, undo stack depth = N
- WHEN user swaps slots 2 and 5
- THEN undo stack depth = N + 1 (one entry, not two)
- AND undoing restores both slots to pre-swap state in one step

#### Scenario: Swap restores correctly

- GIVEN slot 2 = {degree=1, octave=4}, slot 5 = {degree=5, octave=3}
- WHEN Swap(2, 5) runs, then undo
- THEN slot 2 = {degree=1, octave=4} (restored)
- AND slot 5 = {degree=5, octave=3} (restored)

### Requirement: Ctrl+Z/Y Progression Dispatch

`midi-island/input.lua` `HandleKeyboard(char)` SHALL check for Ctrl+Z (char 26) and Ctrl+Y (char 25) BEFORE dispatching to piano-roll shortcuts. When `IsProgressionFocused()` is true (midi-island expanded, mouse not in piano roll grid), Ctrl+Z SHALL call `seq_store.HandleProgUndo()` and Ctrl+Y SHALL call `seq_store.HandleProgRedo()`. When `IsProgressionFocused()` is false, Ctrl+Z/Y SHALL fall through to `piano_roll.HandleKeyboardShortcut()`.

#### Scenario: Ctrl+Z in midi-island dispatches progression undo

- GIVEN midi-island expanded, mouse over progression slots
- WHEN user presses Ctrl+Z
- THEN `seq_store.HandleProgUndo()` SHALL be called
- AND the key SHALL be consumed (no piano-roll undo fires)

#### Scenario: Ctrl+Z over piano roll falls through

- GIVEN midi-island expanded, mouse over piano roll grid
- WHEN user presses Ctrl+Z
- THEN `piano_roll.HandleKeyboardShortcut()` SHALL handle it
- AND `HandleProgUndo()` SHALL NOT be called

### Requirement: SyncNotesToProgression Undo Hook

`note_store.SyncNotesToProgression()` SHALL call `seq_store.PushProgUndo(seq_store.ProgSnapshot())` at the top of the function, BEFORE any `SetProgressionEntry` calls. This captures the pre-sync progression state so the operation can be undone.

#### Scenario: Sync notes creates undo entry

- GIVEN progression has 3 entries, undo stack depth = N
- WHEN user clicks SYNC button
- THEN undo stack depth = N + 1
- AND undoing restores the original 3 progression entries

### Requirement: Empty Stack Resilience

Both `HandleProgUndo()` and `HandleProgRedo()` SHALL be no-ops when their respective stacks are empty. The system SHALL NOT crash or produce errors on empty-stack invocation.

#### Scenario: Empty undo stack no-op

- GIVEN no progression edits made
- WHEN user presses Ctrl+Z
- THEN nothing happens (no crash, no error)
