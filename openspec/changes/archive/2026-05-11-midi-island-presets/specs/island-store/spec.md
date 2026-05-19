# Delta for island-store

## MODIFIED Requirements

### Requirement: Note Data Model

The note data model MUST be `{pitch: number, start_beat: number, duration: number, velocity: number(0-127), muted: boolean}` — stored as an ordered array within the store's internal state. This is distinct from the progression entry data model whose schema extends to accept optional fields: `{degree: number, root_index: number, scale_index: number, octave: number, chord_mode_index: number, velocity?: number(1-127), duration?: number(beats)}`. When velocity or duration are absent, the system MUST default to 100 and the current `beats_per_slot` value respectively.
(Previously: progression entry model had no velocity/duration fields; ProgressionToNotes always used hardcoded defaults)

#### Scenario: Progression entry with velocity and duration

- GIVEN a progression entry created via drag-drop from pads
- WHEN the entry is read from sequencer_store
- THEN it MUST carry `velocity` (default 100) and `duration` (default 4 beats) fields

#### Scenario: Legacy progression entry (no velocity/duration)

- GIVEN a progression entry with only `{degree, root_index, scale_index, octave, chord_mode_index}`
- WHEN `ProgressionToNotes` materializes it
- THEN notes MUST use default velocity 100 and default duration equal to beats_per_slot

## ADDED Requirements

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
