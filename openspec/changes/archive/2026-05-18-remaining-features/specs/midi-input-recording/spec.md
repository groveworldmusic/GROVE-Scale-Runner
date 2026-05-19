# Delta for midi-input-recording

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Stuck Note Safety

On recording deactivation (disarm or CleanupAll), `midi-input.lua` SHALL finalize all open (unpaired note-on) notes by setting their duration to `current_beat - start_beat`. Additionally, the 5-second auto-close timeout SHALL run each Poll cycle to catch lost note-offs. On script cleanup, `AllNotesOff(true)` SHALL silence any held MIDI notes.
(Previously: only disarm/cleanup finalization, no timer-based auto-close)

#### Scenario: Unpaired notes close on disarm (unchanged)

- GIVEN 2 unpaired note-ons for pitch 60 and 64
- WHEN record is disarmed or `CleanupAll`
- THEN both notes SHALL have positive `duration` set

#### Scenario: Lost note-off auto-closes (new)

- GIVEN a note-on for pitch 72 with no matching note-off
- WHEN 5 seconds elapse
- THEN the note SHALL auto-close with `duration = 5.0`
- AND the note SHALL appear in the piano roll with the computed duration
