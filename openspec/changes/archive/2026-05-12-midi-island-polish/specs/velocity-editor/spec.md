# Delta for Velocity Editor

## MODIFIED Requirements

### Requirement: Velocity Bar Display

The velocity editor SHALL render a vertical bar for each note in the visible region. Bar height MUST be proportional to `velocity / 127`. Bar color MUST use the theme's note color for that pitch. Muted notes MUST render using a defined `MUTED_BAR_COLOR` constant at full opacity. Adjacent notes with the same `start_beat` SHALL offset bars horizontally by 1-2px to prevent visual overlap.
(Previously: muted used 30% opacity or hatch; no bar offset)

#### Scenario: Muted note uses defined color constant

- GIVEN a note with `muted = true`, velocity 80
- WHEN the velocity editor renders
- THEN the bar uses `MUTED_BAR_COLOR` at full opacity, no crash

#### Scenario: Overlapping bars offset

- GIVEN two notes at `start_beat=2.0` with velocities `[100, 80]`
- WHEN the velocity editor renders
- THEN the bars offset horizontally by 1-2px, both fully visible
