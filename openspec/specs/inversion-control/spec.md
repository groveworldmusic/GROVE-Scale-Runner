# Inversion Control Specification

## Purpose

Add global chord inversion voicing to allow users to control how chord notes are distributed across octaves. Follows the same pattern as `chord_mode_index` — a global 4-mode selector rendered as a button island.

## State Changes

New global field `inversion_index` (1–4), stored in `config.state` alongside `chord_mode_index`:

| Value | Label | Notes |
|-------|-------|-------|
| 1 | Base | Root position — no reordering (default) |
| 2 | 1st Inv | Bottom note raised 1 octave |
| 3 | 2nd Inv | Bottom 2 notes raised 1 octave |
| 4 | 3rd Inv | Bottom 3 notes raised 1 octave |

## Constants

```lua
config.INVERSION_LABELS = {"Base", "1st Inv", "2nd Inv", "3rd Inv"}
```

No offsets table needed — inversion is a pure reordering function.

## Requirements

### Requirement: Inversion Island UI

A new island MUST appear in `DrawIslands()` with 4 buttons labeled Base / 1st Inv / 2nd Inv / 3rd Inv. The active inversion MUST be highlighted. Clicking a button MUST set `config.state.inversion_index`.

#### Scenario: Select inversion mode

- GIVEN the inversion island is visible in the right column
- WHEN the user clicks "1st Inv"
- THEN `config.state.inversion_index` becomes 2
- AND the 2nd button renders as active (highlighted)

### Requirement: InvertChord() pure function

A new function `midi.InvertChord(notes, inversion)` MUST accept a table of MIDI note numbers and an inversion index (0-based for internal use: 0=Base, 1=1st, 2=2nd, 3=3rd). It MUST move the bottom N notes up 12 semitones and reorder. It MUST be pure — no state reads, no side effects.

#### Scenario: 1st inversion of Tri chord

- GIVEN notes = {60, 64, 67} (C E G, Tri)
- WHEN `midi.InvertChord(notes, 1)` is called
- THEN returns {64, 67, 72} (E G C, bottom note +12)

#### Scenario: 2nd inversion of Tri chord

- GIVEN notes = {60, 64, 67}
- WHEN `midi.InvertChord(notes, 2)` is called
- THEN returns {67, 72, 76} (G C E, bottom two notes +12)

### Requirement: Inversion cap at chord size − 1

`midi.InvertChord()` MUST clamp the inversion argument to `#notes - 1`. A Tri (3 notes) MUST NOT allow 3rd inversion. Note mode (1 note) MUST behave as Base regardless.

#### Scenario: Cap 3rd inversion on Tri

- GIVEN notes = {60, 64, 67}
- WHEN `midi.InvertChord(notes, 3)` is called
- THEN behaves as 2nd inversion (cap at 2)
- AND returns {67, 72, 76}

#### Scenario: Note mode ignores inversion

- GIVEN notes = {60} (single note, chord_mode_index=1)
- WHEN `midi.InvertChord(notes, 2)` is called
- THEN returns {60} (unchanged)

### Requirement: TriggerChord() applies inversion

`midi.TriggerChord()` MUST accept a new optional `inversion` parameter. After generating chord notes via offsets, it MUST call `midi.InvertChord(notes, inversion)` before sending MIDI.

#### Scenario: Inversion passed through TriggerChord

- GIVEN `config.state.inversion_index = 2` (1st Inv)
- WHEN `midi.TriggerChord(1, true, ctx)` is called
- THEN notes are generated normally first
- AND THEN InvertChord is applied with inversion=1 (0-based)
- AND MIDI messages are sent for the reordered notes

### Requirement: Inversion affects real-time playback

Inversion MUST apply to ALL chord triggers: keyboard keypress, mouse pad click, slot click-to-play, and sequencer playback. Changing inversion while sequencer is running MUST affect the next chord triggered.

#### Scenario: Inversion change during playback

- GIVEN the sequencer is playing at step 3
- WHEN the user changes inversion from Base to 1st Inv
- THEN step 4 triggers with 1st inversion applied
- AND previously playing notes are NOT affected

## GFX Behavior Notes

- The new island sits in the right-side column. If 5 items exceed the available height, existing buttons MUST be condensed (smaller gaps or smaller font).
- The island title is "INVERSION". Button labels use `config.INVERSION_LABELS`.
- Tooltips: "Root position", "First inversion", "Second inversion", "Third inversion".
- When active inversion is capped (e.g., Tri showing "2nd Inv"), the capped button shows as active.
