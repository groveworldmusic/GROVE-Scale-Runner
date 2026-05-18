# Delta for Velocity Editor

## MODIFIED Requirements

### Requirement: Velocity Bar Display

The velocity editor SHALL render a vertical bar for each note in the visible piano roll region. Bar height MUST be proportional to `velocity / 127` relative to the panel's available height. Bar color MUST use the theme's note color for that pitch. Muted notes MUST render using a defined `MUTED_BAR_COLOR` constant at full opacity. Adjacent notes with the same `start_beat` SHALL offset bars horizontally by 1-2px to prevent visual overlap. The velocity panel height SHALL use EXACTLY `velocity.EDITOR_H` (100px when expanded) or `velocity.COLLAPSED_H` (10px when collapsed). The excess space from `pr_h_full % piano_roll.PITCH_ROW_H` SHALL be given to the piano roll grid height instead of the velocity panel.
(Previously: `ve_h = base_ve_h + excess` — the modulo remainder was added to velocity height, making it potentially larger than EDITOR_H)

#### Scenario: Expanded velocity uses exactly EDITOR_H

- GIVEN `vel_expanded = true`, `velocity.EDITOR_H = 100`
- AND `pr_h_full = 600`, `PITCH_ROW_H = 16` (grid rows divide evenly)
- WHEN layout calculates `ve_h`
- THEN `ve_h` SHALL equal exactly 100
- AND `pr_h` SHALL be `600 - 100 = 500` (no excess transferred)

#### Scenario: Velocity height never exceeds EDITOR_H

- GIVEN `vel_expanded = true`, `velocity.EDITOR_H = 100`
- AND `pr_h_full = 605`, `PITCH_ROW_H = 16` (excess = 605 % 16 = 13)
- WHEN layout calculates heights
- THEN `ve_h` SHALL equal exactly 100 (NOT `100 + 13 = 113`)
- AND the 13px excess SHALL be added to `pr_h` instead
- AND `pr_h_full - ve_h` = 505, minus the 13 excess = 492 grid-aligned rows = `pr_h`

#### Scenario: Collapsed velocity uses exactly COLLAPSED_H

- GIVEN `vel_expanded = false`, `velocity.COLLAPSED_H = 10`
- WHEN layout calculates heights
- THEN `ve_h` SHALL equal exactly 10
- AND all excess from `pr_h_full % PITCH_ROW_H` SHALL go to piano roll

## Acceptance Criteria

- [ ] Velocity panel height is exactly EDITOR_H when expanded, COLLAPSED_H when collapsed
- [ ] Piano roll receives the remainder space (grid-aligned rows)
- [ ] No visual gap between velocity panel and piano roll due to misalignment
