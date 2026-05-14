# Delta for sequencer-run-tests

## ADDED Requirements

### Catch-up Without Notes

Catch-up across multiple skipped measures MUST update state only — no TriggerChord or SendMidi calls.

#### Scenario: Multi-measure catch-up silent
- GIVEN `IsPlaying()=true`, `LastMeasure=0`, current measure=4 (3 skipped)
- WHEN `sequencer.Run()` processes catch-up
- THEN `CurrentStep` advances, `LastMeasure=4`, NO `TriggerChord` or `SendMidi` calls

#### Scenario: Single-measure advance still plays
- GIVEN `IsPlaying()=true`, `LastMeasure=0`, current measure=1
- WHEN `sequencer.Run()` runs
- THEN `TriggerChord` called as before (unchanged)
