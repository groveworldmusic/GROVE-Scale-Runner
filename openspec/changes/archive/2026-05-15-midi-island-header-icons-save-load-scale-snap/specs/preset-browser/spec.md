# Delta for Preset Browser

## MODIFIED Requirements

### Requirement: Save Preset

Save SHALL write the current island notes AND full progression context to disk as a `.grove` file (v2 format). The serialized table MUST include: `name`, `version = 2`, `notes` array, `progression` array (16 entries, may contain nils), `root_index`, `scale_index`, `octave`, `chord_mode_index`. The filename SHALL default to "untitled.grove". Save SHALL validate that all required context fields are present before writing. The save flow SHALL also be triggered from the new SAVE icon button in the MIDI island header (see midi-island spec), which SHALL call the same `browser.SavePreset()` function.
(Previously: save only accessible from the SAVE button inside the preset browser panel)

#### Scenario: Save from header uses same function

- GIVEN the SAVE icon button in the MIDI island header
- WHEN clicked
- THEN `browser.SavePreset()` SHALL be called with the same parameters as when SAVE is clicked inside the preset panel
- AND the behavior is identical (same `reaper.GetUserInputs` dialog, name validation, file writing)

### ADDED Requirements

### Requirement: Larger PRESETS Title Font

The "PRESETS (N)" count label in the preset browser panel SHALL render at font size 14 (previously 11). The label position SHALL adjust accordingly to prevent clipping. The headroom around the label SHALL accommodate the larger font — `gfx.setfont(1, "Calibri", 14)` instead of 11 — while the divider line below SHALL maintain its current relative position.

#### Scenario: PRESETS label at font 14

- GIVEN the preset browser renders with 5 `.grove` files
- WHEN the "PRESETS (5)" label renders
- THEN `gfx.setfont(1, "Calibri", 14)` SHALL be used
- AND the label SHALL NOT clip at the top or bottom
- AND the divider line SHALL appear below the label with the same 4px gap as before

#### Scenario: No layout breakage at 0 files

- GIVEN an empty directory (0 `.grove` files)
- WHEN the label renders as "PRESETS (0)"
- THEN the label SHALL render at font 14 without overlapping adjacent elements
- AND the line spacing SHALL accommodate the larger font without breaking the folder/preset list below

## Acceptance Criteria

- [ ] SAVE in header (new) calls the exact same `browser.SavePreset()` as SAVE in panel
- [ ] PRESETS label renders at font 14 rather than 11
- [ ] No clipping or overlap with the larger font at any count value (0-100+)
