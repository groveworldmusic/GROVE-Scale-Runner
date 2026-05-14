# Island Store Specification

## Purpose

Define the island-specific state store — scroll position, zoom level, note edit buffer, preset metadata, and the note data model. Follows the existing store pattern (`state/*.lua`) with `Init()` receiving `config.state` as defaults source.

## Requirements

### Requirement: Note Data Model

The note data model MUST be `{pitch: number, start_beat: number, duration: number, velocity: number(0-127), muted: boolean}` — stored as an ordered array within the store's internal state. This is distinct from the progression entry data model `{degree, root_index, scale_index, octave, chord_mode_index}`.

#### Scenario: Default note fields

- GIVEN a fresh island store Init
- WHEN a note is created via `AddNote(pitch, start_beat, duration, velocity)`
- THEN it MUST have `muted = false` and all provided fields set

### Requirement: Init Semantics

The store SHALL expose `Init(defaults)` following the existing pattern in `state/midi.lua`. Init MUST merge defaults by key — not replace the entire internal state table — to preserve sub-table references.

#### Scenario: Init from config.state

- GIVEN `config.state` with no island-related keys
- WHEN `Init(config.state)` is called
- THEN the store SHALL set all fields to safe defaults (scroll_x=0, zoom=1.0, notes={}, preset_list={})

### Requirement: Store API Surface

The store MUST expose getter/setter pairs for: `ScrollX(number)`, `Zoom(number 0.25-4.0)`, `Notes(table[])`, `ActiveNoteIndex(number|nil)`, `SelectedPreset(string|nil)`. Notes MUST be returned by REFERENCE (mutable) following the convention in `sequencer_store.GetProgression()`.

#### Scenario: Get/Set ScrollX

- GIVEN an initialized island store
- WHEN `SetScrollX(42.5)` then `GetScrollX()`
- THEN the value MUST be `42.5`

#### Scenario: Notes table mutation

- GIVEN an initialized island store with 3 notes
- WHEN `GetNotes()` is called and a note's velocity is mutated in-place
- THEN `SetNotes()` is NOT needed — the internal table is the same reference

### Requirement: Edit Buffer

The store MUST maintain an `edit_buffer` (number|nil) representing the index of the note currently being edited in the velocity editor. Setting to `nil` clears selection.

#### Scenario: Select note for editing

- GIVEN a note at index 2 in the notes array
- WHEN `SetEditBufferIndex(2)`
- THEN `GetEditBufferIndex()` returns `2`

### Requirement: Preset Browser State

The store MUST hold `CurrentDirectory(string)`, `PresetList(table[])`, `FavoriteList(table[])`, and `CurrentFilePath(string|nil)` — all with corresponding getter/setter pairs.

#### Scenario: Navigate to directory

- GIVEN island store initialized
- WHEN `SetCurrentDirectory(reaper.GetResourcePath() .. "/grove-presets")`
- THEN `GetCurrentDirectory()` returns that path

## Acceptance Criteria

- [ ] `Init(config.state)` produces safe defaults with no errors
- [ ] All getter/setter pairs round-trip correctly
- [ ] Notes table is mutable by reference (no defensive copy on get)
- [ ] Edit buffer clears on `nil` set
- [ ] Preset browser state keys are independent (no cross-contamination)
