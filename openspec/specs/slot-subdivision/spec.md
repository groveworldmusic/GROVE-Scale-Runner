# Slot Subdivision Specification

## Purpose

Allow each slot to contain multiple chords per measure by dividing the slot into N equal sub-beats. Each sub-beat triggers its own chord during playback. A global dropdown selects the subdivision mode.

## State Changes

New global field `subdivision_index` (1–6), stored in `config.state`:

| Index | Label | Beats per sub-chord | Max sub-chords per slot |
|-------|-------|---------------------|--------------------------|
| 1 | 1/1 | 4.0 | 1 (default, backward compat) |
| 2 | 1/2 | 2.0 | 2 |
| 3 | 1/3 | 1.333 | 3 |
| 4 | 1/4 | 1.0 | 4 |
| 5 | 1/8 | 0.5 | 8 |
| 6 | 1/16 | 0.25 | 16 |

## Slot Data Model

Existing progression entries remain unchanged and work at subdivision=1/1. For subdivision > 1/1, slot behavior changes:

- The slot's `degree` becomes the chord for ALL sub-beats (initial implementation)
- Future: per-sub-beat chord overrides via `entry.chords[]` array
- No persistent model change needed in Phase 1 — subdivision is applied at playback time

## Requirements

### Requirement: Subdivision dropdown UI

A dropdown selector MUST appear offering all 6 modes: 1/1, 1/2, 1/3, 1/4, 1/8, 1/16. Changing the selection MUST immediately update `subdivision_index`.

#### Scenario: Select subdivision mode

- GIVEN the dropdown shows "1/1" as default
- WHEN the user selects "1/4"
- THEN `config.state.subdivision_index` becomes 4
- AND the dropdown shows "1/4"

### Requirement: Sequencer sub-beat stepping

`sequencer.Run()` MUST advance within a measure at subdivisions finer than 1. On each sub-beat boundary, it MUST trigger the next sub-chord and send note-off for the previous one.

#### Scenario: 1/4 subdivision during playback

- GIVEN subdivision_index = 4 (1/4), sequencer is playing step 1
- WHEN the beat reaches quarter-note boundary 3 times within the measure
- THEN the chord triggers 4 times: at beat 0, beat 1, beat 2, beat 3
- AND each trigger sends note-off for the previous sub-chord before playing the new one

#### Scenario: Backward compat at 1/1

- GIVEN subdivision_index = 1 (1/1, default)
- WHEN the sequencer plays
- THEN behavior is IDENTICAL to pre-subdivision: 1 chord per measure, triggers at measure boundary
- AND progress is 0..1 over the full measure as before

### Requirement: Progress circles in slots

Each slot MUST render N progress circles at the bottom (N = sub-chords per slot). Circles MUST light up sequentially during playback to indicate which sub-chord is active.

#### Scenario: 4 progress circles at 1/4

- GIVEN subdivision_index = 4, slot width = 200px
- WHEN the slot renders
- THEN 4 small circles appear at the bottom, evenly spaced
- AND the circle corresponding to the active sub-chord is filled/highlighted
- AND inactive circles are dimmed

#### Scenario: 16 circles at 1/16 scale down

- GIVEN subdivision_index = 6 (1/16)
- WHEN the slot renders
- THEN 16 circles appear at the bottom
- AND circle radius scales down dynamically to fit within slot width

### Requirement: Dynamic chord text during playback

The slot's chord label MUST update each frame to reflect the currently playing sub-chord. At rest/not playing, it MUST show the slot's primary chord name.

#### Scenario: Chord text changes per sub-beat

- GIVEN subdivision = 1/4, slot has degree 1 (C Major)
- WHEN sub-beat 2 is playing
- THEN the slot label shows "C" (same chord — initial implementation reuses degree for all sub-beats)
- AND the label remains visually anchored within the slot bounds

### Requirement: Subdivision grid lines in piano roll

`piano_roll.DrawPianoRollGrid()` MUST render thinner vertical lines at sub-beat positions when subdivision > 1/1.

#### Scenario: Grid lines at 1/4 subdivision

- GIVEN subdivision_index = 4, measure beats 0–4
- WHEN the piano roll grid renders
- THEN vertical lines appear at beat 1, 2, 3 (in addition to the existing measure line at 4)
- AND these sub-beat lines are thinner/more transparent than measure lines

### Requirement: Subdivision ticks in timeline

`timeline.DrawBeatTicks()` MUST render smaller tick marks at sub-beat positions when subdivision > 1/1.

#### Scenario: Timeline sub-beat ticks

- GIVEN subdivision_index = 4
- WHEN the timeline ruler renders
- THEN small tick marks appear at each quarter-note boundary
- AND these ticks are shorter than beat ticks

### Requirement: Subdivision-aware export

`midi.ExportToMidi()` MUST write all sub-chords as individual MIDI notes at the correct beat position within each slot's measure.

#### Scenario: Export with 1/4 subdivision

- GIVEN 1 slot with subdivision 1/4, slot 1 fills beats 0–4
- WHEN ExportToMidi() runs
- THEN 4 chords are written at beat offsets 0, 1, 2, 3 within the slot
- AND the total duration is still 4 beats per slot

### Requirement: ProgressionToNotes() subdivision-aware

`island_store.ProgressionToNotes()` MUST produce individual note entries for each sub-chord beat position. The existing `beats_per_slot` parameter splits subdivision correctly: each sub-chord duration = `beats_per_slot / sub_chord_count`.

#### Scenario: Notes created per sub-beat

- GIVEN progression with 1 slot at 1/4 subdivision
- WHEN `ProgressionToNotes()` is called
- THEN 4 note groups are created at start_beat offsets 0, 1, 2, 3
- AND each note has duration = 1.0 beat (4 beats / 4)

## GFX Behavior Notes

- Progress circles use `gfx.circle()` with radius dynamically computed: `radius = min(w / (N * 3), 4)` where N = sub-chord count.
- Active circle uses `theme.colors.slot_playing` color; inactive uses `theme.colors.text_dim` at 30% alpha.
- Subdivision dropdown follows the same pattern as the scale/octave dropdown in DrawIslands().
- Piano roll subdivision lines use a distinct color (e.g., `{0.3, 0.3, 0.3, 0.15}`) to distinguish from weak beat lines.
