# Quantize Specification

## Purpose

Align selected note start beats to the current snap grid with selectable strength and optional swing offset. Enables rhythmic correction and groove feel, standard in every DAW.

## Requirements

### Requirement: Quantize Dispatch

Ctrl+Q SHALL quantize all notes in `selected_indices` (from the piano roll store). The operation SHALL be a no-op when no notes are selected. Quantize SHALL use the current snap resolution from preferences as the target grid, including triplet modes.

#### Scenario: Ctrl+Q quantizes selection

- GIVEN 3 selected notes at beats 1.23, 2.67, 3.99, snap at 1/8 (0.125)
- WHEN user presses Ctrl+Q
- THEN notes snap to beats 1.25, 2.625, 4.0
- AND non-selected notes SHALL remain unchanged

#### Scenario: No-op on empty selection

- GIVEN no notes selected
- WHEN user presses Ctrl+Q
- THEN nothing happens (no crash, no error)

#### Scenario: Triplet snap

- GIVEN selected notes, triplet snap active (1/8t = 0.0833 resolution)
- WHEN user presses Ctrl+Q
- THEN notes SHALL snap to the nearest triplet subdivision

### Requirement: Strength Parameter

A strength parameter SHALL range from 0-100%, persisted in `piano-roll-store` or `ui_store`. At 100% strength, notes snap perfectly to the grid (same as full quantize). At 50%, each note moves half the distance toward its target snap position, preserving some of the original feel. At 0%, no movement occurs. Strength SHOULD have a default of 100%.

#### Scenario: 50% strength moves half-way

- GIVEN a note at beat 1.23, snap 1/8 (target 1.25), strength = 50%
- WHEN Ctrl+Q is pressed
- THEN note moves to beat 1.24 (1.23 + (1.25 - 1.23) * 0.5)
- AND note does NOT snap perfectly to 1.25

#### Scenario: 0% strength is no-op

- GIVEN a note at beat 1.23, strength = 0%
- WHEN Ctrl+Q is pressed
- THEN note remains at beat 1.23

### Requirement: Swing Parameter

A swing parameter SHALL apply an offset to every other beat subdivision (the "offbeat" 1/8 notes). Swing SHALL offset the note's snap position by a percentage of the subdivision width. At 0% swing, no offset. At 50% swing, offbeats shift by half the subdivision width (maximum swing, similar to "shuffle" feel). Swing SHOULD have a default of 0%. Strength and swing SHALL interact: strength is applied first (move toward snapped position), then swing offset is added.

#### Scenario: 30% swing on offbeat note

- GIVEN a note at beat 1.0 (onbeat) and a note at beat 1.5 (offbeat), snap 1/8, swing = 30%
- WHEN Ctrl+Q is pressed
- THEN the onbeat note SHALL snap to 1.0 (no swing offset)
- AND the offbeat note SHALL snap toward 1.5 + (0.125 * 0.30) = 1.5375

#### Scenario: 0% swing is standard quantize

- GIVEN swing = 0%, strength = 100%
- WHEN Ctrl+Q is pressed
- THEN notes snap to the standard grid (no shuffle offset)

### Requirement: Single Undo Entry

All note position changes from a single quantize operation SHALL be captured in one undo entry. Undo SHALL restore all affected notes to their pre-quantize positions. The undo entry type SHALL be `"quantize"`.

#### Scenario: Undo restores all quantized notes

- GIVEN 5 selected notes, positions changed by quantize
- WHEN user presses Ctrl+Z after quantize
- THEN all 5 notes return to their original start beats
- AND the undo stack shows a single "quantize" entry (not 5 individual entries)

## Acceptance Criteria

- [ ] Ctrl+Q quantizes selected notes to current snap grid (including triplets)
- [ ] Empty selection is a no-op
- [ ] Strength 0-100% controls how far notes move toward grid (0 = no move, 100 = perfect snap)
- [ ] Swing 0-50% offsets offbeat 1/8 notes for shuffle feel
- [ ] Strength applies first, then swing offset
- [ ] Single undo entry captures all position changes
- [ ] No crash on zero selected, single selected, or all selected
