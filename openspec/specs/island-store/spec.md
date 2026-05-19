# Island Store Specification

## Purpose

Define the island-specific state store — scroll position, zoom level, note edit buffer, preset metadata, and the note data model. Follows the existing store pattern (`state/*.lua`) with `Init()` receiving `config.state` as defaults source.

## Requirements

### Requirement: Note Data Model

The note data model MUST be `{pitch: number, start_beat: number, duration: number, velocity: number(0-127), muted: boolean}` — stored as an ordered array within the store's internal state. This is distinct from the progression entry data model whose schema extends to accept optional fields: `{degree: number, root_index: number, scale_index: number, octave: number, chord_mode_index: number, velocity?: number(1-127), duration?: number(beats)}`. When velocity or duration are absent, the system MUST default to 100 and the current `beats_per_slot` value respectively.

#### Scenario: Default note fields

- GIVEN a fresh island store Init
- WHEN a note is created via `AddNote(pitch, start_beat, duration, velocity)`
- THEN it MUST have `muted = false` and all provided fields set

#### Scenario: Progression entry with velocity and duration

- GIVEN a progression entry created via drag-drop from pads
- WHEN the entry is read from sequencer_store
- THEN it MUST carry `velocity` (default 100) and `duration` (default 4 beats) fields

#### Scenario: Legacy progression entry (no velocity/duration)

- GIVEN a progression entry with only `{degree, root_index, scale_index, octave, chord_mode_index}`
- WHEN `ProgressionToNotes` materializes it
- THEN notes MUST use default velocity 100 and default duration equal to beats_per_slot

### Requirement: Init Semantics

The store SHALL expose `Init(defaults)` following the existing pattern in `state/midi.lua`. Init MUST merge defaults by key — not replace the entire internal state table — to preserve sub-table references.

#### Scenario: Init from config.state

- GIVEN `config.state` with no island-related keys
- WHEN `Init(config.state)` is called
- THEN the store SHALL set all fields to safe defaults (scroll_x=0, zoom=1.0, notes={}, preset_list={})

### Requirement: Store API Surface

The store MUST expose getter/setter pairs for: `ScrollX(number)`, `Zoom(number 0.25-4.0)`, `Notes(table[])`, `PrimarySelectedNoteIndex(number|nil)`, `SelectedPreset(string|nil)`, `ToolMode(string)`, `LassoActive(boolean)`, `LassoStart/End({x,y})`. Notes MUST be returned by REFERENCE (mutable) following the convention in `sequencer_store.GetProgression()`.

(Previously: ActiveNoteIndex replaced by PrimarySelectedNoteIndex compat; ToolMode/Lasso fields added.)

#### Scenario: Get/Set ScrollX

- GIVEN an initialized island store
- WHEN `SetScrollX(42.5)` then `GetScrollX()`
- THEN the value MUST be `42.5`

#### Scenario: Notes table mutation

- GIVEN an initialized island store with 3 notes
- WHEN `GetNotes()` is called and a note's velocity is mutated in-place
- THEN `SetNotes()` is NOT needed — the internal table is the same reference

### Requirement: Tool Mode State

The store SHALL expose `GetToolMode() -> string` and `SetToolMode(string)`. Valid: `"pointer"`, `"pencil"`, `"eraser"`. Default: `"pointer"`.

### Requirement: Lasso State

The store SHALL expose: `GetLassoActive() -> boolean`, `SetLassoActive(bool)`, `GetLassoStart() -> {x, y}`, `SetLassoStart(t)`, `GetLassoEnd() -> {x, y}`, `SetLassoEnd(t)`. All default to nil/false after Init.

### Requirement: Multi-Selection (breaking change)

`selected_note_index (number | nil)` SHALL be replaced by `selected_indices (table {[idx]=true})`. Backward compat SHALL be provided via `GetPrimarySelectedNoteIndex() -> number | nil` returning the last selected index from the set. Existing consumers (velocity editor, info bar) MUST use this compat getter.

#### Scenario: Multi-select

- GIVEN selected_indices = {[2]=true, [5]=true}
- WHEN `GetPrimarySelectedNoteIndex()` called
- THEN returns 5 (last entry)

#### Scenario: Empty selection

- GIVEN selected_indices = {}
- WHEN `GetPrimarySelectedNoteIndex()` called
- THEN returns nil

### Requirement: Note CRUD

The store SHALL expose `AddNote({pitch, start_beat, duration, velocity, muted})` appending to notes[] and `RemoveNoteAtIndex(idx)` removing the entry at that index and shifting subsequent entries. Both SHALL update note_count. `AddNote` SHALL set `origin = "manual"` automatically.

### Requirement: Bulk Operations

Right-click on any selected note SHALL toggle mute on ALL selected_indices. Delete key SHALL remove all selected_indices from notes[]. See "Requirement: Click-to-Edit Velocity" in the velocity editor spec for velocity bulk edit.

<!-- Requirement removed: Edit Buffer — replaced by Multi-Selection with backward compat shim GetPrimarySelectedNoteIndex() -->

### Requirement: Preset Browser State

The store MUST hold `CurrentDirectory(string)`, `PresetList(table[])`, `FavoriteList(table[])`, and `CurrentFilePath(string|nil)` — all with corresponding getter/setter pairs.

#### Scenario: Navigate to directory

- GIVEN island store initialized
- WHEN `SetCurrentDirectory(reaper.GetResourcePath() .. "/grove-presets")`
- THEN `GetCurrentDirectory()` returns that path

### Requirement: Per-Slot Note Materialization

`ProgressionToNotes(progression, beats_per_slot, velocity)` MUST read per-entry `velocity` and `duration` when present, falling back to the function parameter defaults otherwise. Unchanged entries (no `degree`) MUST be skipped.

#### Scenario: Per-slot velocity override

- GIVEN progression entry at slot 3 has `velocity = 85`
- WHEN `ProgressionToNotes` processes slot 3
- THEN the resulting note(s) MUST have velocity 85, NOT the default 100

#### Scenario: Per-slot duration override

- GIVEN progression entry at slot 1 has `duration = 2`
- WHEN `ProgressionToNotes` is called with `beats_per_slot = 4`
- THEN the note at slot 1 MUST have `duration = 2`, while other slots use 4

### Requirement: Load From Progression

`LoadNotesFromProgression(seq_store)` MUST call `ProgressionToNotes` with the current progression from sequencer_store, defaulting to `beats_per_slot = 4` and `velocity = 100`. Slot-level overrides in progression entries SHALL propagate through.

#### Scenario: Slot override survives load

- GIVEN a progression with slot 2 having `velocity = 75, duration = 3`
- WHEN `LoadNotesFromProgression(seq_store)` is called
- THEN the island notes array MUST contain notes with velocity 75 and duration 3 at the corresponding beat positions

### Requirement: Velocity Panel Collapse State

The store MUST expose `GetVelocityPanelExpanded() -> boolean` and `SetVelocityPanelExpanded(boolean)`. Default after Init MUST be `true`. When `false`, the velocity panel collapses upward and freed space allocates to the piano roll.

#### Scenario: Default expanded

- GIVEN fresh Init
- WHEN `GetVelocityPanelExpanded()` called
- THEN returns `true`

#### Scenario: Collapse via setter

- GIVEN expanded panel
- WHEN `SetVelocityPanelExpanded(false)`
- THEN getter returns `false`

## Acceptance Criteria

- [ ] `Init(config.state)` produces safe defaults with no errors
- [ ] All getter/setter pairs round-trip correctly
- [ ] Notes table is mutable by reference (no defensive copy on get)
- [ ] Preset browser state keys are independent (no cross-contamination)
- [ ] `GetVelocityPanelExpanded()` returns `true` after Init
- [ ] `SetVelocityPanelExpanded(false)` → getter returns `false`
- [ ] `GetToolMode()` defaults to `"pointer"`, accepts `"pencil"` and `"eraser"`
- [ ] `GetSelectedIndices()` returns the selection set; `GetPrimarySelectedNoteIndex()` returns last selected or nil
- [ ] `AddNote` appends and sets `origin="manual"`; `RemoveNoteAtIndex` shifts subsequent entries
- [ ] Selecting multiple notes (via lasso or programmatic) populates `selected_indices` correctly
