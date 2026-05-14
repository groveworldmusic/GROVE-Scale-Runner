# Delta for Timeline Ruler

## MODIFIED Requirements

### Requirement: Beat Marker Rendering

The timeline ruler SHALL render tick marks at each beat boundary, synced with piano roll scroll/zoom. Measure-start beats MUST have taller ticks and labels; inner beats shorter ticks. The top-left corner MUST render without double borders, shadow artifacts, or overlap with the container frame.
(Previously: no top-left corner constraint)

#### Scenario: Clean top-left corner

- GIVEN the ruler rendering above the piano roll
- WHEN the ruler draws its container border
- THEN top-left corner MUST have no double lines or shadow artifacts
