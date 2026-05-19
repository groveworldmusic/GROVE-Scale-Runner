# Piano Roll Specification

## Purpose

Grid rendering, note interaction, selection, and visual correctness.

## Requirements

### Requirement: Shift+click additive selection

`HandleMouseClick` MUST receive `shift_held` from the caller.

#### Scenario: Shift toggles selection

- GIVEN a note is NOT selected
- WHEN shift+clicked
- THEN the note SHALL toggle into the selection

### Requirement: Cache key includes PITCH_ROW_H

`ComputeVisibleRanges` cache MUST include `PITCH_ROW_H` in its key.

#### Scenario: Grid correct after vertical zoom

- GIVEN the grid is visible
- WHEN the user zooms vertically (Alt+wheel)
- THEN visible rows SHALL recompute and note positions SHALL be correct

### Requirement: Scrollbar thumb within track

Scrollbar thumbs MUST compute position as `ratio * (track - thumb_size)`.

#### Scenario: Thumb stays inside at max scroll

- GIVEN scroll is at maximum
- THEN the thumb SHALL NOT extend past the track

### Requirement: Lasso pitch_high clamped

`GetNotesInRect` MUST clamp `pitch_high = math.min(MAX_PITCH, …)`.

#### Scenario: Lasso above grid

- GIVEN the mouse starts above the grid
- WHEN a lasso drag is performed
- THEN out-of-rect notes SHALL NOT be selected

### Requirement: No snap when snap is off

When `snap_res <= 0`, `HandlePencilClick` MUST NOT quantize the beat.

#### Scenario: Free placement

- GIVEN snap is disabled
- WHEN a note is placed with the pencil
- THEN the note SHALL be at the exact clicked beat
