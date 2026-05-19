# Delta for Quantize (Swing)

## MODIFIED Requirements

### Requirement: Swing Parameter

A swing parameter SHALL apply an offset to every other beat subdivision (the "offbeat" 1/8 notes). Swing SHALL be stored as `quantize_swing` (0-50) in `island_store`. The `QuantizeBeat()` function MUST read this value to calculate the shuffle offset: `offset = (swing/100) * (grid_size / 2)`.

A UI control (dropdown or slider) SHALL be added to the Piano Roll header (next to the Quantize Strength control) to modify `island_store.quantize_swing` in real time.

(Previously: A swing parameter SHALL apply an offset to every other beat subdivision (the "offbeat" 1/8 notes). Swing SHALL offset the note's snap position by a percentage of the subdivision width. At 0% swing, no offset. At 50% swing, offbeats shift by half the subdivision width (maximum swing, similar to "shuffle" feel). Swing SHOULD have a default of 0%. Strength and swing SHALL interact: strength is applied first (move toward snapped position), then swing offset is added.)

#### Scenario: 30% swing on offbeat note

- GIVEN a note at beat 1.0 (onbeat) and a note at beat 1.5 (offbeat), snap 1/8, `island_store.quantize_swing` = 30
- WHEN Ctrl+Q is pressed
- THEN the onbeat note SHALL snap to 1.0 (no swing offset)
- AND the offbeat note SHALL snap toward 1.5 + (0.125 * 0.30) = 1.5375

#### Scenario: 0% swing is standard quantize

- GIVEN `island_store.quantize_swing` = 0, strength = 100%
- WHEN Ctrl+Q is pressed
- THEN notes snap to the standard grid (no shuffle offset)

#### Scenario: UI control updates state

- GIVEN the Piano Roll header is visible
- WHEN the user changes the Swing slider to 25
- THEN `island_store.quantize_swing` SHALL be updated to 25
- AND subsequent Ctrl+Q operations SHALL use this new value
