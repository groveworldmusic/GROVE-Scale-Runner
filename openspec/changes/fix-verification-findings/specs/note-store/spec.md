# note-store Specification (Delta)

## ADDED Requirements

### Requirement: SyncNotesToProgression

The system SHALL provide `SyncNotesToProgression(seq_store, prefs_store, beats_per_slot?)` which iterates through the 16 progression slots, groups notes by beat range, detects the degree, chord mode, and octave for each group, and writes them back to `sequencer_store` using `SetProgressionEntry`.

#### Scenario: Syncing with single note in slot

- GIVEN a single note at `start_beat=0` (e.g., pitch 60, octave 4)
- WHEN `SyncNotesToProgression` is called
- THEN the progression entry at slot 1 SHALL be updated with the detected degree, root, scale, and octave
- AND `sequencer_store.SetProgressionEntry` MUST be called for slot 1

#### Scenario: Tie-break in FindNearestScaleDegree

- GIVEN a note at `pitch=61` and a scale containing both `60` and `62`
- WHEN `FindNearestScaleDegree` is called
- THEN it SHALL tie-break towards the higher scale degree (62) to ensure deterministic behavior

#### Scenario: Sparse table handling in GroupNotesByBeat

- GIVEN a sparse notes table `{ [1]=note1, [3]=note2 }` (with index 2 missing)
- WHEN `GroupNotesByBeat` is called
- THEN it MUST correctly group all notes by iterating through all existing keys (not using `#` length)
- AND it SHALL NOT miss `note2` because of the gap at index 2
