# Delta Spec: Progression Workflow

## Overview

Two features: P1 adds snapshot-based undo/redo to the 16-slot progression array with context-aware Ctrl+Z/Y. P2 adds progression-only `.grove-prog` file type with type-badge UI and dedicated save button.

---

## Feature 1: P1 — Progression Undo/Redo

**Affects:** progression-undo (new), undo-system (modified), keyboard-shortcuts (modified)

### Progression Undo Stack (New)

#### REQ-PU-01: Stack with snapshot

The sequencer store SHALL maintain `prog_undo_stack` (max 50 entries). Before each progression mutation, `ProgSnapshot()` SHALL deep-copy the 16-slot array. FIFO eviction at 51st entry.

#### Scenario: Undo restores progression

- GIVEN slots at [1]=C, [2]=D, [3]=E
- WHEN user removes slot 2
- THEN Remove pushes snapshot BEFORE mutation
- AND Ctrl+Z restores [1]=C, [2]=D, [3]=E

#### Scenario: FIFO eviction at 51

- GIVEN 50 undo entries
- WHEN 51st mutation occurs
- THEN oldest entry is discarded, stack stays at 50

#### Scenario: Empty stack no-op

- GIVEN no edits made
- WHEN Ctrl+Z pressed
- THEN nothing happens (no error)

#### REQ-PU-02: Redo stack

Undo SHALL push the snapshot to `prog_redo_stack` (50 cap). New edit after undo SHALL clear redo. Redo on empty stack SHALL be no-op.

#### Scenario: Undo then redo

- GIVEN slot 2 removed then undone
- WHEN Ctrl+Y pressed
- THEN slot 2 removed again

#### Scenario: New edit clears redo

- GIVEN slot removed and undone
- WHEN user adds new slot (instead of redo)
- THEN redo stack cleared, original slot not recoverable via redo

#### REQ-PU-03: Mutation coverage

The system SHALL snapshot before every call to `SetProgressionEntry`, `SetProgression`, and `ClearProgression`. Covers all 10 mutation sites.

#### Scenario: All progressions written

- GIVEN `SeqStore.SetProgression()`, `SetProgressionEntry()`, `ClearProgression()`
- WHEN called from any of the 10 mutation sites (slots: remove/swap/3x add; views/islands: Clear; docked: Clear; midi-island SyncNotes; io.lua SetProgression; note-store SyncNotesToProgression)
- THEN a snapshot is pushed BEFORE the mutation

### Modified: Undo System

#### REQ-US-01: Undo stack (modified)

(Piano-roll undo unchanged.) The system SHALL maintain TWO undo stacks: one for notes (existing, in note-store) and one for progression (new, in sequencer store). Each capped at 50. Undo stacks cleared on preset load applies to BOTH.

(Previously: single undo stack for notes only)

#### Scenario: Preset load clears both stacks (modified)

- GIVEN note undo stack has 3 entries, progression undo stack has 2 entries
- WHEN preset is loaded (any type)
- THEN both `ClearUndoStacks()` and `ClearProgressionUndoStacks()` are called, both stacks empty

(Previously: only note undo stack cleared)

#### REQ-US-02: Undo stacks cleared on preset load (modified)

`LoadPreset` MUST call BOTH `ClearUndoStacks()` AND `ClearProgressionUndoStacks()`.

(Previously: only `LoadPreset` -> `ClearUndoStacks()`)

### Modified: Keyboard Shortcuts

#### REQ-KS-01: Undo/Redo context-aware (modified)

Ctrl+Z (char 346) SHALL trigger progression undo when progression is focused, note undo when piano roll is focused. Ctrl+Y (char 345) mirrors for redo. Unfocused = no-op.

Focus detection: progression is focused when `gfx.mouse_y` is within the performance area (slots region) AND the MIDI island is not expanded. Otherwise, piano roll is focused.

(Previously: Ctrl+Z always triggered note undo, Ctrl+Y always triggered note redo)

#### Scenario: Ctrl+Z in progression area

- GIVEN progression undo stack has 1 entry, note undo stack has 1 entry, mouse in slots region
- WHEN user presses Ctrl+Z
- THEN progression undo fires (not note undo)

#### Scenario: Ctrl+Z in piano roll area

- GIVEN both stacks have entries, mouse in MIDI island piano roll area
- WHEN user presses Ctrl+Z
- THEN note undo fires (not progression undo)

#### Scenario: Unfocused Ctrl+Z no-op

- GIVEN progression NOT focused AND piano roll NOT focused (e.g., docked mode, header area)
- WHEN Ctrl+Z pressed
- THEN neither stack triggered (no-op, no error)

---

## Feature 2: P2 — Progression-Only Save/Load

**Affects:** preset-browser (modified)

### Modified: Preset Browser

#### REQ-PB-01: Progression-only file type (ADDED)

The system SHALL support `.grove-prog` as a valid preset file extension alongside `.grove`. `SavePresetProgression()` SHALL serialize `progression[1..16]`, `root_index`, `scale_index`, `octave`, `chord_mode_index`, `version=1`. No notes array.

#### Scenario: SaveProgression writes minimal file

- GIVEN 3 entries in progression slots 1,3,5, root=1, scale=2, oct=4, chord_mode=3
- WHEN user clicks "Save Progression"
- THEN `.grove-prog` file is created with progression entries, 4 context fields, `version=1`, NO notes key

#### REQ-PB-02: Scan dual types (MODIFIED)

`ScanDirectory()` SHALL return BOTH `.grove` AND `.grove-prog` files. Each file entry SHALL include a `type` field: `"notes"` for `.grove`, `"progression"` for `.grove-prog`.

(Previously: scanned only `.grove` files, no type field)

#### REQ-PB-03: Load branching (MODIFIED)

`LoadPreset()` SHALL detect type from extension. For `.grove-prog`: restore progression + 4 context fields, skip notes entirely — no note validation, no `SetNotes()`. For `.grove`: existing behavior unchanged.

(Previously: only `.grove` files, always restored notes + progression)

#### Scenario: Load `.grove-prog` restores progression only

- GIVEN a `.grove-prog` file with progression at slots 1,5 and root/scale/octave/chord_mode
- WHEN user loads it
- THEN progression is restored, context fields updated, piano-roll notes UNCHANGED

#### Scenario: Load `.grove-prog` with invalid data

- GIVEN a `.grove-prog` file containing `return "not a table"`
- WHEN user attempts to load
- THEN error dialog shown, existing progression AND notes unchanged

#### REQ-PB-04: UI type badge (ADDED)

Preset list SHALL display a type badge on each entry: "N" for `.grove` (notes+progression), "P" for `.grove-prog` (progression-only). OR filter tabs "Notes" / "Progression" / "All" above the preset list.

#### Scenario: Type badge renders

- GIVEN preset list with both `song.grove` and `prog.grove-prog`
- WHEN rendered
- THEN `song` shows "N" badge and `prog` shows "P" badge

#### REQ-PB-05: Save Progression button (ADDED)

The preset browser SHALL display a "Save Progression" button alongside the existing SAVE button. Clicking it SHALL call `SavePresetProgression()` with a `.grove-prog` filename prompt.

#### Scenario: Save Progression button exists

- GIVEN preset browser visible, some progression entries exist
- WHEN user clicks "Save Progression"
- THEN `reaper.GetUserInputs` prompt appears for name
- AND `.grove-prog` file is created

#### REQ-PB-06: Undo clear on progression load (ADDED)

After loading a `.grove-prog` file, `LoadPreset` MUST call `ClearProgressionUndoStacks()` to clear progression undo history.

#### Scenario: Undo cleared after progression load

- GIVEN progression undo stack has 3 entries
- WHEN user loads a `.grove-prog` file
- THEN progression undo stack is empty after load

---

## Acceptance Criteria

- [ ] P1: Every progression mutation pushes a snapshot before mutation
- [ ] P1: Undo restores exact previous progression state, redo restores forward
- [ ] P1: 50-entry cap with FIFO eviction (51st discards oldest)
- [ ] P1: Ctrl+Z triggers progression undo when focused, note undo when piano roll focused, no-op unfocused
- [ ] P1: Empty undo stack Ctrl+Z is no-op (no crash)
- [ ] P2: SaveProgression creates `.grove-prog` with progression + context fields, no notes
- [ ] P2: ScanDirectory returns both `.grove` and `.grove-prog` with type field
- [ ] P2: Load `.grove-prog` restores progression only, leaves notes unchanged
- [ ] P2: Preset browser shows type badge or filter tabs
- [ ] P2: "Save Progression" button exists and calls SavePresetProgression
- [ ] P2: Load progression preset clears progression undo stacks
