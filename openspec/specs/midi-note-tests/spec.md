# midi-note-tests Specification

## Purpose

Validate `midi.GetMidiNote` against the REAL module (not a local copy) via `require("core.midi")`, using `require("config")` for scales, note names, and chord modes.

## Requirements

| ID | Requirement | Scenarios |
|----|------------|-----------|
| M1 | Test MUST require the real module: `require("core.midi").GetMidiNote` and `require("config").{SCALES,NOTE_NAMES,CHORD_MODES}` | GIVEN real module loaded WHEN test calls midi.GetMidiNote THEN it reads config.SCALES (not a local duplicate). GIVEN chord tests WHEN computing per-offset notes THEN loop over CHORD_MODES[].offsets calling GetMidiNote for each |
| M2 | Basic calculations MUST produce correct MIDI note numbers | GIVEN C Major degree 1 octave 4 WHEN GetMidiNote(1,1,1,4) THEN 60 (C4). GIVEN degree 7 THEN 71 (B4). GIVEN A Minor Natural degree 1 octave 2 THEN 45 (A2) |
| M3 | All 21 scales MUST produce values in 0-127 | GIVEN each scale index 1..21 WITH degree 1 octave 4 WHEN GetMidiNote(1,i,1,4) THEN result in [0,127] |
| M4 | Degree wraparound MUST increment octave correctly | GIVEN Major scale degree 8 octave 4 WHEN GetMidiNote THEN 72 (C5). GIVEN Major Pentatonic degree 6 octave 4 THEN 72 (C5) |
| M5 | Octave 0 boundary MUST produce values >= 0 | GIVEN any degree 1..14 Major scale WHEN octave=0 THEN result >= 0 |
| M6 | Octave 8 boundary MUST produce values <= 127 | GIVEN any degree 1..7 Major scale WHEN octave=8 THEN result <= 127 |
| M7 | Exhaustive range (21 scales × 21 degrees × 9 octaves = 3969) MUST produce values in [0,127] | GIVEN all combinations WHEN GetMidiNote(1,s,d,o) iterated THEN every result is 0 <= n <= 127 |

## Edge Cases

- Negative degree: result clamped to [0,127]
- Degree 0: result clamped to [0,127] (root=-1 may produce negative, clamp to 0)
- Root index 0 (out of range): root = -1, result clamped to [0,127]
- Root index 13 (out of range): root = 12, result clamped to [0,127]
- Scale index beyond #SCALES: nil scale → errors (no guard expected)
