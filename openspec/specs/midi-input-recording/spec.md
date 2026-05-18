# MIDI Input Recording Specification

**Domain**: midi-input-recording
**Change**: expansion-features (P3)
**Type**: New — no existing spec

## Purpose

Allow users to record incoming MIDI from external controllers (keyboard, pad controller) directly into the piano roll. Frame-by-frame polling of REAPER's MIDI input buffer, converting note-on/off events to internal note-store entries with beat-accurate timing.

## Requirements

### Requirement: MIDI Input Polling

`src/core/midi-input.lua` MUST poll REAPER's MIDI input buffer each frame via `MIDI_GetRecentInputEvent()` or equivalent API. Only `0x90` (note-on) and `0x80` (note-off) message types SHALL be captured. All other MIDI messages (CC, aftertouch, pitch bend, sysEx) SHALL be silently ignored.

#### Scenario: Note-on captured as piano roll note

- GIVEN record is armed
- WHEN a note-on for pitch 60 (C4), velocity 100 arrives
- THEN `note_store.AddNote({pitch=60, start_beat=<current_beat>, duration=0, velocity=100, muted=false, origin="midi-input"})` SHALL be called
- AND the note SHALL appear in the piano roll

#### Scenario: Note-off sets duration

- GIVEN an open note pitch 60 from a prior note-on
- WHEN the corresponding note-off for pitch 60 arrives
- THEN the open note's duration SHALL be updated to `note_off_beat - note_on_beat`
- AND no new note SHALL be created

#### Scenario: Non-note MIDI messages ignored

- GIVEN record is armed
- WHEN a CC message (0xB0) or aftertouch arrives
- THEN no note SHALL be created or modified
- AND the input buffer position SHALL advance

### Requirement: Beat-Accurate Timing

Timing SHALL use `reaper.time_precise()` + `reaper.Master_GetTempo()` to convert wall-clock time to beat position. `TimeMap2_timeToBeats()` SHALL be used for absolute beat calculation from project time.

#### Scenario: Tempo change during note

- GIVEN the project tempo is 120 BPM at note-on
- WHEN the tempo changes to 140 BPM before note-off
- THEN `start_beat` uses tempo-at-event for note-on timestamp
- AND `duration` uses tempo-at-event for note-off timestamp
- AND the computed beat values reflect time-map-relative positions

### Requirement: Record Arm Toggle

`midi-input.lua` MUST export `SetArmed(bool)` and `IsArmed()`. When disarmed, all incoming MIDI events SHALL be ignored. The toggle SHALL NOT affect script cleanup.

#### Scenario: Disarmed ignores MIDI

- GIVEN record is disarmed
- WHEN any MIDI note-on arrives
- THEN no note SHALL be created
- AND `midi_input.IsArmed()` SHALL return `false`

### Requirement: Stuck Note Safety

On recording deactivation (disarm or CleanupAll), `midi-input.lua` SHALL finalize all open (unpaired note-on) notes by setting their duration to `current_beat - start_beat`. On script cleanup, `AllNotesOff(true)` SHALL silence any held MIDI notes.

#### Scenario: Unpaired notes close on disarm

- GIVEN 2 unpaired note-ons for pitch 60 and 64
- WHEN record is disarmed or `CleanupAll`
- THEN both notes SHALL have positive `duration` set
- AND no stuck MIDI output notes remain

### Requirement: Origin Tagging

All notes created via MIDI input SHALL have `origin="midi-input"`. This tag distinguishes them from manual or progression-generated notes during operations like save/export.

#### Scenario: Origin distinguishes from manual notes

- GIVEN a note added via recording (pitch=60, origin="midi-input")
- AND a note added via keyboard (pitch=60, origin="manual")
- WHEN filtering notes by origin
- THEN each SHALL be distinguishable by the `origin` field

## Non-Goals

- MIDI CC/aftertouch/pitch bend recording
- MIDI clock sync (recording is best-effort frame-capture timing)
- Multi-track recording (single track only)
- MIDI learn for script parameters
- MIDI channel filtering (all channels captured)
- Sample-accurate timing (frame-accurate is sufficient)
- Pre-roll/count-in metronome
- Quantize on record (post-hoc quantize via existing quantize workflow)

## Dependencies

- **Builds on**: `note-store.AddNote()` with `origin` support (delta spec), `preferences_store` pattern
- **P3 → P1, P2**: P3 is the final phase — depends on P1 and P2 header space in MIDI island. P3 modifies `main.lua` (MainLoop integration) — no merge conflict with P1/P2. P3 depends on `note-store` delta for `origin` support.
- **External APIs**: `MIDI_GetRecentInputEvent()`, `TimeMap2_timeToBeats()`, `time_precise()`, `Master_GetTempo()`

## Test Requirements

| Assertion | Type |
|-----------|------|
| Note-on inserts `AddNote` with origin="midi-input" | Unit/Mock |
| Note-off updates duration of matching open note | Unit/Mock |
| Non-note messages produce zero side effects | Unit/Mock |
| Record disarmed → all events ignored | Unit |
| Unpaired notes finalized on disarm/cleanup | Unit |
| `IsArmed()` returns correct state after toggle | Unit |
| Beat calculation uses `TimeMap2_timeToBeats` for correctness | Integration |
