# midi-runtime-tests Specification

## Purpose

Verify core MIDI runtime functions (SendMidi, TriggerChord, AllNotesOff) operate correctly using mocked reaper globals.

## Requirements

### M1: SendMidi note-on/off

SendMidi MUST send correct MIDI message via reaper.StuffMIDIMessage.

#### Scenario: Note-on channel 1
- GIVEN reaper mock with call tracking AND `config.state.midi_channel = 1`
- WHEN `midi.SendMidi(60, true, 100)`
- THEN `reaper.StuffMIDIMessage.mock.calls[1] == {1, 0x90, 60, 100}`

#### Scenario: Note-off
- GIVEN reaper mock
- WHEN `midi.SendMidi(60, false, 0)`
- THEN reaper call has message byte 0x80 (note off)

### M2: Ref-counted active notes

SendMidi MUST increment active note count on note-on, decrement on note-off.

#### Scenario: Double note-on increments twice
- GIVEN two sequential note-on calls for note 60
- WHEN checking `midi_store.GetActiveNote(60)`
- THEN count == 2

#### Scenario: Note-off decrements, nil at zero
- GIVEN active note 60 with count 2
- WHEN first note-off THEN count == 1
- WHEN second note-off THEN `GetActiveNote(60)` == nil

### M3: Volume applied

SendMidi MUST scale velocity by sequencer_store.GetVolume().

#### Scenario: Half volume
- GIVEN `sequencer_store.GetVolume() == 0.5`
- WHEN `midi.SendMidi(60, true, 100)`
- THEN velocity in reaper call == 50

### M4: TriggerChord

TriggerChord MUST send correct number of notes based on chord_mode_index.

#### Scenario: Triad (index 2)
- GIVEN `config.state.chord_mode_index = 2`
- WHEN `midi.TriggerChord(root_note, true, ctx)`
- THEN 3 note-on calls via reaper

#### Scenario: 7th chord (index 3)
- GIVEN `config.state.chord_mode_index = 3`
- WHEN TriggerChord
- THEN 4 notes sent

### M5: AllNotesOff

AllNotesOff MUST send CC 123 + note-off for each held note + ClearActiveNotes.

#### Scenario: CC 123 on channel 1
- GIVEN `config.state.midi_channel = 1`
- WHEN `midi.AllNotesOff()`
- THEN reaper received `StuffMIDIMessage(1, 0xBB, 123, 0)` (CC 123)

#### Scenario: Held notes released
- GIVEN held notes 60 and 64 in key_states and mouse_pad_state
- WHEN AllNotesOff()
- THEN note-off sent for each held note AND `ClearActiveNotes()` called
