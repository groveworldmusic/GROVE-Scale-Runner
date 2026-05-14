# sequencer-stop-tests Specification

## Purpose

Verify sequencer.Stop() resets all state and releases held notes.

## Requirements

### S1: Stop resets playing state

Stop MUST set IsPlaying to false and clear timing/position fields.

#### Scenario: State reset
- GIVEN sequencer is playing (IsPlaying=true, LastMeasure=2, CurrentStep=4, Progress=0.5, InternalBeats=8.0, LastTime=123.4)
- WHEN `sequencer.Stop()`
- THEN IsPlaying==false, LastMeasure==1, CurrentStep==1, Progress==0, InternalBeats==0, LastTime==0

### S2: Stop releases held notes

Stop MUST send note-off for each note in MidiNotes and clear them.

#### Scenario: Notes released
- GIVEN MidiNotes contains notes {60, 64, 67}
- WHEN `sequencer.Stop()`
- THEN note-off sent via reaper for each note (3 calls)
- AND MidiNotes table is cleared
