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

On recording deactivation (disarm or CleanupAll), `midi-input.lua` SHALL finalize all open (unpaired note-on) notes by setting their duration to `current_beat - start_beat`. Additionally, the 5-second auto-close timeout SHALL run each Poll cycle to catch lost note-offs. On script cleanup, `AllNotesOff(true)` SHALL silence any held MIDI notes.
(Previously: only disarm/cleanup finalization, no timer-based auto-close)

#### Scenario: Unpaired notes close on disarm

- GIVEN 2 unpaired note-ons for pitch 60 and 64
- WHEN record is disarmed or `CleanupAll`
- THEN both notes SHALL have positive `duration` set
- AND no stuck MIDI output notes remain

#### Scenario: Lost note-off auto-closes (new)

- GIVEN a note-on for pitch 72 with no matching note-off
- WHEN 5 seconds elapse
- THEN the note SHALL auto-close with `duration = 5.0`
- AND the note SHALL appear in the piano roll with the computed duration

### Requirement: Unpaired Note Timeout

The system SHALL maintain a 5-second maximum open-note duration. For each `_open_notes` entry with no matching note-off within 5 seconds of its note-on timestamp, the system SHALL auto-close the note. On auto-close, duration SHALL be `current_beat - note_on_beat` and the note SHALL be finalized in `note_store`. This prevents stuck notes from lost note-off messages (e.g., unplugged controller).

#### Scenario: Note auto-closes after 5s

- GIVEN a note-on for pitch 60 at time t=0, record armed
- WHEN no note-off arrives by t=5.1
- THEN the note SHALL be auto-closed with duration = 5.0 beats
- AND a finalized note SHALL exist in the piano roll

#### Scenario: Note-off before timeout works normally

- GIVEN a note-on for pitch 60 at t=0
- WHEN note-off arrives at t=2.0
- THEN duration = 2.0 beats (exact match, no timeout involved)

### Requirement: UpdateOpenNoteDuration in note-store

`note-store.lua` SHALL export `UpdateOpenNoteDuration(pitch, duration)` that finds the most recent `origin="midi-input"` note with `muted=false` at the given pitch and updates its `duration` field. This SHALL be called when a matching note-off arrives, or on timeout auto-close.

#### Scenario: Note-off updates open note duration

- GIVEN a note with pitch 60, origin="midi-input", start_beat=0, duration=0
- WHEN `UpdateOpenNoteDuration(60, 2.0)` is called
- THEN the note's `duration` SHALL be 2.0

### Requirement: Record-Arm Toggle UI

The MIDI island header SHALL include a record-arm toggle button rendered as a red circle. When armed, the circle SHALL glow (pulsing brightness or steady brighter red). Clicking SHALL toggle `midi_input.SetArmed()`.

#### Scenario: Record arm toggle toggles state

- GIVEN record is disarmed, circle is dim red
- WHEN user clicks the red circle
- THEN `midi_input.IsArmed()` returns true
- AND the circle renders with a bright red glow

#### Scenario: Record remains disarmed after script reload

- GIVEN record was armed
- WHEN the script reloads
- THEN `midi_input.IsArmed()` SHALL return false (default)

### Requirement: MainLoop Wiring

`main.lua` SHALL require `core.midi-input` during Init, call `midi_input.Poll()` in MainLoop after `keyboard.HandleKeyboard()`, and call `midi_input.Cleanup()` in `CleanupAll()`.

#### Scenario: Poll runs each frame when armed

- GIVEN record is armed
- WHEN MainLoop executes
- THEN `midi_input.Poll()` SHALL be called each frame
- AND incoming MIDI notes SHALL be processed

#### Scenario: Cleanup finalizes open notes

- GIVEN 2 open notes when script is stopping
- WHEN `CleanupAll()` runs
- THEN `midi_input.Cleanup()` SHALL finalize both open notes
- AND `AllNotesOff(true)` SHALL silence any held MIDI output

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
- **P3 -> P1, P2**: P3 is the final phase — depends on P1 and P2 header space in MIDI island. P3 modifies `main.lua` (MainLoop integration) — no merge conflict with P1/P2. P3 depends on `note-store` delta for `origin` support.
- **External APIs**: `MIDI_GetRecentInputEvent()`, `TimeMap2_timeToBeats()`, `time_precise()`, `Master_GetTempo()`

## Test Requirements

| Assertion | Type |
|-----------|------|
| Note-on inserts `AddNote` with origin="midi-input" | Unit/Mock |
| Note-off updates duration of matching open note | Unit/Mock |
| Non-note messages produce zero side effects | Unit/Mock |
| Record disarmed -> all events ignored | Unit |
| Unpaired notes finalized on disarm/cleanup | Unit |
| `IsArmed()` returns correct state after toggle | Unit |
| Beat calculation uses `TimeMap2_timeToBeats` for correctness | Integration |
