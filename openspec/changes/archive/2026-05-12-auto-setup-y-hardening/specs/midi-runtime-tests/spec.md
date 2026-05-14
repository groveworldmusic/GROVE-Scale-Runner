# Delta for midi-runtime-tests

## MODIFIED Requirements

### M1: SendMidi note-on/off

SendMidi MUST send correct MIDI message via reaper.StuffMIDIMessage. Note-off (0x80) MUST only fire when ref-count reaches 0 after decrement.
(Previously: 0x80 sent unconditionally on every false velocity call)

#### Scenario: Note-on channel 1
- GIVEN reaper mock with call tracking AND `config.state.midi_channel = 1`
- WHEN `midi.SendMidi(60, true, 100)`
- THEN `reaper.StuffMIDIMessage.mock.calls[1] == {1, 0x90, 60, 100}`

#### Scenario: Note-off at count zero
- GIVEN active note 60 with ref-count 1
- WHEN `midi.SendMidi(60, false, 0)` — decrements to 0
- THEN reaper call has byte 0x80 (note off)

#### Scenario: Note-off gated by ref-count
- GIVEN active note 60 with ref-count 2
- WHEN `midi.SendMidi(60, false, 0)` — decrements to 1
- THEN no 0x80 call

### M5: AllNotesOff

AllNotesOff MUST send CC 123 + note-off for each held note + ClearActiveNotes. When `force=true`, bypass ref-count gate.
(Previously: no force param — AllNotesOff always sent note-offs)

#### Scenario: CC 123 on channel 1
- GIVEN `config.state.midi_channel = 1`
- WHEN `midi.AllNotesOff()`
- THEN reaper received `StuffMIDIMessage(1, 0xBB, 123, 0)`

#### Scenario: Held notes released with force
- GIVEN held notes 60 (ref-count 2) and 64 (ref-count 3)
- WHEN `midi.AllNotesOff(true)`
- THEN note-off sent for both (bypasses gate) AND `ClearActiveNotes()` called

## ADDED Requirements

### M6: Nil item guard

ExportToMidi MUST guard nil item before GetActiveTake.

#### Scenario: CreateNewMIDIItemInProj fails
- GIVEN `CreateNewMIDIItemInProj` returns nil
- WHEN ExportToMidi continues
- THEN no crash — nil check before `GetActiveTake(nil)`
