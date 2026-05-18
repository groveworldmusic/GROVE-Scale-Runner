# Delta for midi-island

**Change**: expansion-features
**Type**: Delta — 3 new controls added to header

## MODIFIED Requirements

### Requirement: Dynamic Island Content Height (unchanged)

The existing dynamic height requirement is unaffected. The 3 new controls occupy the header area only and do not alter content height computation.

### Requirement: RELOAD/SYNC → Icon Buttons (unchanged)

Unchanged. New controls are positioned in the header region between existing buttons — no overlap with RELOAD/SYNC.

## ADDED Requirements

### Requirement: Theme Selector Dropdown

The header SHALL render a theme selector control positioned between the PRESETS toggle and the RELOAD button. It SHALL follow the existing header pattern: `DrawRoundedRect` + hover/active state + `ConsumeMouseClick`. The dropdown SHALL list 3 theme names (Current, Dark, High Contrast) and call `preferences_store.SetThemeIndex(n)` on selection.

#### Scenario: Theme dropdown switches palette

- GIVEN the MIDI island header is visible
- WHEN the user clicks the theme dropdown and selects "Dark"
- THEN `preferences_store.SetThemeIndex(2)` SHALL be called
- AND the dropdown label SHALL update to "Dark"

### Requirement: Record-Arm Toggle Button

The header SHALL render a record-arm toggle button next to the channel (CH) selector. When armed, the button SHALL display with an active glow color. When disarmed, it SHALL display in dim color. Clicking toggles `midi_input.SetArmed(bool)`. Follows header pattern: `DrawRoundedRect` + hover/active + `ConsumeMouseClick`.

#### Scenario: Record toggle toggles armed state

- GIVEN record is disarmed (dim icon)
- WHEN the user clicks the record toggle
- THEN `midi_input.SetArmed(true)` SHALL be called
- AND the icon SHALL render with active glow
- AND MIDI input polling SHALL commence

### Requirement: Remap Gear Button

The header SHALL render a gear/remap button that opens the key remap settings panel. Clicking SHALL toggle the visibility of the remap modal overlay. Follows header pattern: `DrawRoundedRect` + hover/active + `ConsumeMouseClick`.

#### Scenario: Remap button opens settings

- GIVEN the MIDI island header is visible
- WHEN the user clicks the gear/remap button
- THEN the key remap modal overlay SHALL open
- AND clicking again SHALL close it

### Requirement: Header Layout Coordination

The 3 new controls (theme dropdown, record toggle, remap gear) SHALL fit within the existing header width without overflow. Button widths SHALL match the existing `math.floor(b_w * 0.55)` pattern for icon buttons. The theme dropdown SHALL use a wider control consistent with other dropdowns in the header.

#### Scenario: All controls render within header bounds

- GIVEN the header renders with all 3 new controls
- WHEN the total width is computed
- THEN no control SHALL extend beyond the header bounding rect
- AND no existing control SHALL be displaced or clipped
