# SequencerRun Tests — Specification

## Purpose
Transport-synced sequencer tick — play state guard, REAPER beat sync, progression boundary.

## Requirements

### Requirement: Not Playing Early Exit
Transport stopped MUST reset Progress=0 and skip MIDI.

#### Scenario: Stopped resets progress
- GIVEN `IsPlaying()` returns false
- WHEN `sequencer.Run()` is called
- THEN Progress = 0, no MIDI note-on calls

### Requirement: REAPER Sync — Measure Advance
Playing + new measure MUST advance `CurrentStep` and trigger chord.

#### Scenario: New measure triggers step
- GIVEN `IsPlaying()=true`, `CurrentStep=1`, `LastMeasure=0`, current measure=1
- WHEN `sequencer.Run()` is called
- THEN `CurrentStep=2`, `TriggerChord` called, `LastMeasure=1`

### Requirement: REAPER Sync — Same Measure
Same measure MUST NOT advance step or trigger.

#### Scenario: Same measure skipped
- GIVEN `IsPlaying()=true`, `CurrentStep=2`, `LastMeasure=1`, current measure=1
- WHEN `sequencer.Run()` is called
- THEN `CurrentStep` stays 2, `TriggerChord` NOT called

### Requirement: Empty Progression While Playing
Playing + empty progression MUST call `Stop()`.

#### Scenario: Empty stops sequencer
- GIVEN `IsPlaying()=true`, progression has no slots
- WHEN `sequencer.Run()` is called
- THEN `Stop()` is called — `IsPlaying` becomes false, note-offs sent

### Requirement: Catch-up Without Notes

Catch-up across multiple skipped measures MUST update state only — no TriggerChord or SendMidi calls.

#### Scenario: Multi-measure catch-up silent
- GIVEN `IsPlaying()=true`, `LastMeasure=0`, current measure=4 (3 skipped)
- WHEN `sequencer.Run()` processes catch-up
- THEN `CurrentStep` advances, `LastMeasure=4`, NO `TriggerChord` or `SendMidi` calls

#### Scenario: Single-measure advance still plays
- GIVEN `IsPlaying()=true`, `LastMeasure=0`, current measure=1
- WHEN `sequencer.Run()` runs
- THEN `TriggerChord` called as before (unchanged)
