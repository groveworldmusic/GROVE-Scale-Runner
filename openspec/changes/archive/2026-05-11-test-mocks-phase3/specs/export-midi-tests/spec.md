# ExportToMidi Tests — Specification

## Purpose
Export sequencer progression to a new MIDI track with proper track selection and finalization.

## Requirements

### Requirement: Empty Progression Early Exit
Empty progression MUST return without MIDI calls.

#### Scenario: No slots, no inserts
- GIVEN `GetLastFilled()` returns 0
- WHEN ExportToMidi is called
- THEN no `MIDI_InsertNote` calls occur

### Requirement: Single Slot Export
One filled slot inserts each chord note.

#### Scenario: Single chord exported
- GIVEN `GetLastFilled()=1` and slot has 3 chord notes
- WHEN ExportToMidi is called
- THEN `MIDI_InsertNote` called 3 times with correct pitch/velocity/start

### Requirement: Multi-Slot Export
Multiple slots accumulate notes across all slots.

#### Scenario: Two slots exported
- GIVEN `GetLastFilled()=2`, each slot has 3 chord notes
- WHEN ExportToMidi is called
- THEN `MIDI_InsertNote` called 6 times total

### Requirement: Track Selection
No track selected → `InsertTrackAtIndex`. Track selected → skip.

#### Scenario: No track creates new
- GIVEN `GetSelectedTrack(nil)` returns nil
- WHEN ExportToMidi proceeds
- THEN `InsertTrackAtIndex` is called

#### Scenario: Existing track reused
- GIVEN `GetSelectedTrack` returns valid track handle
- WHEN ExportToMidi proceeds
- THEN `InsertTrackAtIndex` is NOT called

### Requirement: Finalization
`MIDI_Sort` and `UpdateArrange` MUST each be called once after all notes.

#### Scenario: Sort and arrange called
- GIVEN progression has 1+ filled slots
- WHEN ExportToMidi finishes inserting
- THEN `MIDI_Sort` called once, then `UpdateArrange` called once
