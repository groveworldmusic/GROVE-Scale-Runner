# Delta for Timeline Ruler

## MODIFIED Requirements

### Requirement: Beat Marker Rendering

The timeline ruler SHALL render tick marks matching the piano roll's 4-tier grid hierarchy. Measure ticks SHALL be tallest (16px) at alpha 0.60, beat ticks medium (8px) at alpha 0.35, subdivision ticks (4px) at alpha 0.15/0.08. Color values MUST match the grid hierarchy colors from `theme.colors.grid_*`. The top-left corner MUST render without double borders, shadow artifacts, or overlap with the container frame. The "BEATS" label font size SHALL increase from `gfx.setfont(1, "Calibri", 10)` to `gfx.setfont(1, "Calibri", 14)` and SHALL be positioned via `layout.US()` for consistency with header label sizing. Measure numbers SHALL render BELOW the tick marks (bottom of ruler) instead of to the right of the tick. The BEATS label and the measure numbers SHALL use separate font sizes — BEATS at 14px, measure numbers at the existing 12px.
(Previously: "BEATS" at font 10, measure numbers to the right of tick at {x = bx + 5, y = y + h - lh})

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

## Acceptance Criteria

- [ ] BEATS renders at font 14 instead of 10
- [ ] Measure numbers render below tick mark bottom, not to the right
- [ ] No visual overlap between BEATS label and measure numbers
- [ ] BEATS fits within 30px ruler height at font 14
