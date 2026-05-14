# Timeline Ruler Specification

## Purpose

Beat/measure markers displayed above the piano roll grid. Synchronizes with the sequencer clock to show playback head position. Displays beat number and measure number at configurable intervals.

## Requirements

### Requirement: Beat Marker Rendering

The timeline ruler SHALL render vertical tick marks at each beat boundary, synchronized with the piano roll's scroll and zoom. Measure-start beats (1, 5, 9, ... in 4/4) MUST have taller ticks and measure number labels. Inner beats MUST have shorter ticks.

#### Scenario: Measure markers align with grid

- GIVEN the piano roll at beat 0 with zoom 1.0
- WHEN the timeline ruler renders
- THEN a tall tick at beat 0 with label "1" (measure 1)
- AND shorter ticks at beats 1, 2, 3 each 1/4 of the measure interval apart

### Requirement: Playback Head

The timeline ruler MUST render a playhead (vertical line with triangle handle at top) at the position corresponding to `sequencer_store.GetProgress()` converted to beats. The playhead frame color MUST contrast with the beat grid (e.g., red/cyan). The playhead MUST only render when `sequencer_store.GetIsPlaying()` is true.

#### Scenario: Playhead follows sequencer

- GIVEN sequencer playing at beat 2.0
- WHEN the ruler renders
- THEN a playhead line appears at the pixel position of beat 2.0

#### Scenario: Playhead hidden when stopped

- GIVEN `GetIsPlaying()` returns false
- WHEN the ruler renders
- THEN no playhead line is drawn

### Requirement: Measure Number Display

The ruler SHALL display measure numbers (1-based) above measure-start ticks. Number font MUST use `gfx.setfont(1, ...)` for consistency with the rest of the UI. Numbers MUST NOT overlap — if zoom is too low to fit adjacent measure numbers, the ruler SHALL skip every other label.

#### Scenario: Label overlap prevention at low zoom

- GIVEN zoom = 0.25x where measure labels would overlap
- WHEN the ruler renders
- THEN only every 2nd or 4th measure number is shown
- AND no two measure numbers overlap in pixel space

## Acceptance Criteria

- [ ] Beat ticks render at pixel positions matching piano roll grid
- [ ] Measure numbers display and skip to prevent overlap
- [ ] Playhead moves smoothly with sequencer progress
- [ ] Playhead hidden when sequencer is stopped
- [ ] No rendering artifacts at zoom extremes (0.25x or 4.0x)
