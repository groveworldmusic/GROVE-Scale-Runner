# Delta for Velocity Editor

## MODIFIED Requirements

### Requirement: Click-to-Edit Velocity

The user SHALL click and drag vertically on a velocity bar to change that note's velocity. 

**Absolute Set Mode**: When a modifier key (e.g., Shift) is held or a specific toggle is active, dragging SHALL set ALL selected notes to the EXACT same absolute velocity value, rather than applying a relative delta.

When `selected_indices` contains multiple entries, drag SHALL apply the SAME relative change to ALL selected notes (unless Absolute Set Mode is active). If `island_store.GetPrimarySelectedIndex()` returns a valid non-nil index, velocity editing MUST target that note regardless of hit test. Velocity click MUST NOT clear the piano roll selection. The velocity value SHALL update in real time during drag (rounded to nearest integer, clamped 0-127).

(Previously: The user SHALL click and drag vertically on a velocity bar to change that note's velocity. When `selected_indices` contains multiple entries, drag SHALL apply the SAME relative change to ALL selected notes. If `island_store.GetPrimarySelectedIndex()` returns a valid non-nil index (note pre-selected in piano roll), velocity editing MUST target that note regardless of hit test — hit test is only used when nothing is pre-selected. Velocity click MUST NOT clear the piano roll selection. The velocity value SHALL update in real time during drag (rounded to nearest integer, clamped 0-127).)

#### Scenario: Absolute velocity set

- GIVEN selected_indices = {[1]=true, [2]=true}, velocities `[60, 100]`
- WHEN user Shift-drags a velocity bar to the position corresponding to value 80
- THEN both notes[1].velocity and notes[2].velocity become exactly 80
- AND NOT a relative delta (e.g. both becoming 80, 120)

#### Scenario: Relative velocity drag (unchanged)

- GIVEN selected_indices = {[1]=true, [2]=true}, velocities `[60, 100]`
- WHEN user drags a velocity bar upward by 10 units
- THEN both notes[1].velocity and notes[2].velocity increase by 10 (to 70, 110)

## ADDED Requirements

### Requirement: Velocity Context Menu

The system SHALL provide a right-click context menu when clicking on a velocity bar.

1. **Reset to 100**: Sets the velocity of ALL selected notes to exactly 100.
2. **Normalize**: Scales the velocities of ALL selected notes so that the quietest becomes 1 and the loudest becomes 127, preserving relative ratios.

#### Scenario: Reset all to 100

- GIVEN selected notes with velocities `[40, 70, 110]`
- WHEN user right-clicks a bar and selects "Reset to 100"
- THEN all 3 selected notes have velocity = 100

#### Scenario: Normalize velocities

- GIVEN selected notes with velocities `[50, 60, 70]`
- WHEN user right-clicks a bar and selects "Normalize"
- THEN the note with 50 becomes 1, 70 becomes 127, and 60 is scaled proportionally (~64)
