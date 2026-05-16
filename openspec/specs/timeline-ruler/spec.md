# Timeline Ruler Specification

## Purpose

Beat/measure markers displayed above the piano roll grid. Synchronizes with the sequencer clock to show playback head position. Displays beat number and measure number at configurable intervals.

## Requirements

### Requirement: Beat Marker Rendering

The timeline ruler SHALL render tick marks matching the piano roll's 4-tier grid hierarchy. Measure ticks SHALL be tallest (16px) at alpha 0.60, beat ticks medium (8px) at alpha 0.35, subdivision ticks (4px) at alpha 0.15/0.08. Color values MUST match the new grid hierarchy colors from `theme.colors.grid_*`. The top-left corner MUST render without double borders, shadow artifacts, or overlap with the container frame. The "BEATS" label font size SHALL increase from `gfx.setfont(1, "Calibri", 10)` to `gfx.setfont(1, "Calibri", 14)` and SHALL be positioned via `layout.US()` for consistency with header label sizing. Measure numbers SHALL render BELOW the tick marks (bottom of ruler) instead of to the right of the tick. The BEATS label and the measure numbers SHALL use separate font sizes — BEATS at 14px, measure numbers at the existing 12px.

(Previously: "BEATS" at font 10, measure numbers to the right of tick at {x = bx + 5, y = y + h - lh})

#### Scenario: Measure markers align with grid

- GIVEN the piano roll at beat 0 with zoom 1.0
- WHEN the timeline ruler renders
- THEN a tall tick at beat 0 with label "1" (measure 1) at alpha 0.60
- AND medium ticks at beats 1, 2, 3 at alpha 0.35
- AND subdivision ticks at quarter-beats at alpha 0.15 or 0.08

#### Scenario: BEATS label renders larger

- GIVEN the timeline ruler renders
- WHEN the "BEATS" label is drawn over the master spine area
- THEN `gfx.setfont(1, "Calibri", 14)` SHALL be used (previously 10)
- AND the label MUST NOT clip outside the ruler's height (30px, with 14px font, meas ~11px)

#### Scenario: Measure numbers below tick

- GIVEN measure 1 at beat 4, zoom showing beats 0-8
- WHEN the ruler renders measure ticks
- THEN the "1" label SHALL appear vertically below the tick bottom, at `y + h - lh` (bottom of ruler)
- AND the tick line SHALL extend from `y` to `y + MEASURE_TICK_H`
- AND the label SHALL NOT overlap with the "BEATS" text in the LABEL_W zone

#### Scenario: No overlap between BEATS and measure numbers

- GIVEN the ruler rendering with LABEL_W = 48px
- WHEN "BEATS" renders in the left label zone
- THEN measure numbers at beats ≥ 0 SHALL NOT overlap with the "BEATS" label
- AND the first measure number SHALL render at least 4px from the right edge of LABEL_W

#### Scenario: Clean top-left corner

- GIVEN the ruler rendering above the piano roll
- WHEN the ruler draws its container border
- THEN top-left corner MUST have no double lines or shadow artifacts

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
- [ ] Measure ticks render at 16px with alpha 0.60, beat ticks at 8px alpha 0.35
- [ ] 1/8 and 1/16 subdivision ticks render at 4px with alpha 0.15/0.08
- [ ] Measure numbers display and skip to prevent overlap
- [ ] Playhead moves smoothly with sequencer progress
- [ ] Playhead hidden when sequencer is stopped
- [ ] No rendering artifacts at zoom extremes (0.25x or 4.0x)
- [ ] Top-left container corner has no double borders, shadow artifacts, or overlap
- [ ] BEATS renders at font 14 instead of 10
- [ ] Measure numbers render below tick mark bottom, not to the right
- [ ] No visual overlap between BEATS label and measure numbers
- [ ] BEATS fits within 30px ruler height at font 14
