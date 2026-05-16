# Preset Browser Specification

## Purpose

Filesystem-based preset browser for saving and loading island note configurations. Uses `io.*` for file I/O and `reaper.GetResourcePath()` for base directory navigation. Supports folder tree, preset list, and save/load dialogs. Presets use the `.grove` file extension.

## Requirements

### Requirement: Directory Navigation

The preset browser SHALL display a folder tree panel rooted at `reaper.GetResourcePath() .. "/grove-presets/"`. This directory MUST be created on first access if it does not exist. Subdirectory expansion and parent navigation (`..`) SHALL be supported via keyboard (`Enter`/`Backspace`) and mouse click.

#### Scenario: First access creates directory

- GIVEN no `grove-presets/` directory exists in the REAPER resource path
- WHEN the preset browser initializes
- THEN the directory SHALL be created via `reaper.RecursiveCreateDirectory()`
- AND the folder tree shows an empty directory

#### Scenario: Navigate into subdirectory

- GIVEN a subdirectory `grove-presets/my-scales/`
- WHEN user clicks on `my-scales` in the folder tree
- THEN `island_store.CurrentDirectory` updates to the subdirectory path
- AND the preset list panel updates with `.grove` files in that directory

### Requirement: Preset List Display

The preset list panel SHALL show all `.grove` files in the current directory. Each entry SHALL display the filename (without extension), file size, and last-modified date if available via `io.*`. Clicking a preset SHALL set `island_store.SelectedPreset`.

#### Scenario: Empty directory shows placeholder

- GIVEN an empty `grove-presets/` directory
- WHEN the preset list renders
- THEN a placeholder text "(No presets)" or equivalent SHALL display

### Requirement: Save Preset

Save SHALL write the current island notes AND full progression context to disk as a `.grove` file (v2 format). The serialized table MUST include: `name`, `version = 2`, `notes` array, `progression` array (16 entries, may contain nils), `root_index`, `scale_index`, `octave`, `chord_mode_index`. The filename SHALL default to "untitled.grove". Save SHALL validate that all required context fields are present before writing. The save flow SHALL also be triggered from the new SAVE icon button in the MIDI island header (see midi-island spec), which SHALL call the same `browser.SavePreset()` function.

#### Scenario: Save creates file

- GIVEN the island store has 5 notes
- WHEN user presses Ctrl+S and enters "my-song" as the name
- THEN a file `my-song.grove` is created in the current directory
- AND the preset list refreshes showing the new entry

#### Scenario: Save from header uses same function

- GIVEN the SAVE icon button in the MIDI island header
- WHEN clicked
- THEN `browser.SavePreset()` SHALL be called with the same parameters as when SAVE is clicked inside the preset panel
- AND the behavior is identical (same `reaper.GetUserInputs` dialog, name validation, file writing)

#### Scenario: Save writes v2 format

- GIVEN island store has 5 notes, sequencer has progression entries at slots 1, 3, 5, and context `root_index=1, scale_index=1, octave=4, chord_mode_index=2`
- WHEN user saves as "my-song"
- THEN the file MUST contain `version=2`, all 5 notes, progression array with entries at indices 1,3,5, and all 4 context fields

### Requirement: Load Preset

Load SHALL detect format version from the `version` field. For `version = 2` (or absent, treated as v1), it MUST restore notes AND progression + context fields into sequencer_store. For v1 (no version field or `version = 1`), it MUST restore notes only — progression and context SHALL NOT be modified. Load MUST validate that `notes` is a table; for v2, it SHOULD also validate `progression` is a table if present. Load SHOULD handle malformed files gracefully (show error, keep existing notes unchanged).

#### Scenario: Load valid preset

- GIVEN a valid `my-song.grove` file with 5 notes
- WHEN user selects it from the list and presses Load
- THEN island store notes are replaced with the 5 notes from file

#### Scenario: Malformed file handled

- GIVEN a `.grove` file containing `return "invalid"`
- WHEN user attempts to load it
- THEN a REAPER MB dialog SHALL display the error
- AND existing notes MUST remain unchanged

#### Scenario: Load v2 preset restores progression + context

- GIVEN a `.grove` file with `version=2`, notes with 5 entries, and progression with 3 entries
- WHEN user loads it
- THEN island notes are replaced with the 5 entries AND sequencer progression is restored with the 3 entries AND root/scale/octave/chord_mode are set

#### Scenario: Load v1 preset backward compatible

- GIVEN a `.grove` file with `version=1` (or no version field) and only a notes array
- WHEN user loads it
- THEN island notes are replaced AND sequencer progression remains unchanged AND context fields are NOT modified

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

### Requirement: Rename Preset

The preset browser SHALL expose a rename action. Rename MUST prompt via `reaper.GetUserInputs("Rename Preset", 1, "New name:", current_name)`. On confirmation, it SHALL rename the file on disk and rescan the directory. On failure (e.g. locked file), it SHALL display an error via `island_store.SetBrowserError()` and leave the original file intact.

#### Scenario: Rename succeeds

- GIVEN a selected preset `my-song.grove` in the preset list
- WHEN user triggers rename and enters "my-groove"
- THEN file is renamed to `my-groove.grove`, directory rescan runs, list shows `my-groove`

#### Scenario: Rename fails (locked file)

- GIVEN a selected preset that is open in another process
- WHEN rename is triggered
- THEN an error message SHALL display in the browser error banner AND the original file SHALL remain unchanged

### Requirement: Panel Dividing Line

A horizontal dividing line SHALL separate the action buttons from the content area below, rendered at the full content width using the theme's border color.

#### Scenario: Line between buttons and content

- GIVEN browser at 400px width
- WHEN rendered
- THEN a horizontal line appears across the full width between the action button row and the folder/preset content below

### Requirement: Action Button Styling

SAVE, RENAME, and LOAD buttons SHALL use rounded borders via `DrawButton` helper, matching the style of other UI rounded buttons (e.g., compact panel).

#### Scenario: Rounded buttons render

- GIVEN the preset browser rendering action buttons
- WHEN each button is drawn
- THEN it has rounded corners and responds visually on hover

## Acceptance Criteria

- [ ] Browser navigates directory tree (expand/collapse subdirs)
- [ ] Preset list shows `.grove` files, filters non-`.grove` files
- [ ] Save writes valid `.grove` files readable by Load
- [ ] Load replaces notes array, validates structure
- [ ] Malformed files show error dialog without data loss
- [ ] Empty directory shows placeholder, does not crash
- [ ] Horizontal dividing line renders between action buttons and content
- [ ] SAVE/RENAME/LOAD buttons render with rounded corners matching other UI buttons
- [ ] SAVE in header (new) calls the exact same `browser.SavePreset()` as SAVE in panel
- [ ] PRESETS label renders at font 14 rather than 11
- [ ] No clipping or overlap with the larger font at any count value (0-100+)
