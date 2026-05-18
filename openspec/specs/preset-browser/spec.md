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

The preset list panel SHALL show all `.grove` files in the current directory. Each entry SHALL display the filename (without extension), file size, and last-modified date if available via `io.*`. Clicking a preset SHALL dispatch to the modifier interaction model (plain click replaces, Ctrl+click toggles, Shift+click ranges) as defined by the preset-multiselect specification. Selected items SHALL render with the ITEM_SELECTED background color. Right-clicking a selected item SHALL show a context menu with batch operations (Delete N, Load Merge, Export to MIDI) when multiple items are selected.

#### Scenario: Empty directory shows placeholder

- GIVEN an empty `grove-presets/` directory
- WHEN the preset list renders
- THEN a placeholder text "(No presets)" or equivalent SHALL display

#### Scenario: Plain click selects single item

- GIVEN `selected_indices = {[2]=true, [5]=true}`
- WHEN user plain-clicks index 3
- THEN only `{[3]=true}` is selected AND item 3 renders with ITEM_SELECTED AND items 2,5 render normally

#### Scenario: Ctrl+click adds to selection set

- GIVEN `selected_indices = {[3]=true}`
- WHEN user Ctrl+clicks index 5
- THEN `selected_indices = {[3]=true, [5]=true}` AND both render with ITEM_SELECTED

#### Scenario: Right-click on multi-selection shows batch menu

- GIVEN `selected_indices = {[2]=true, [5]=true}`
- WHEN user right-clicks on item 5
- THEN the context menu contains "Delete 2 presets", "Load (Merge)", and "Export to MIDI" in addition to single-item options

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

### Requirement: Visual Multi-Select Feedback

The preset list SHALL render all items in `selected_indices` with the ITEM_SELECTED background color. No visual distinction between "primary" and other selected items SHALL exist.

#### Scenario: Three selected items highlighted

- GIVEN `selected_indices = {[2]=true, [5]=true, [7]=true}`
- WHEN `DrawPresetList` renders with these files
- THEN indices 2, 5, and 7 each render with the ITEM_SELECTED color

### Requirement: Batch Delete

When right-clicking a multi-selection, the context menu MUST show "Delete N presets". Selecting it SHALL show a `reaper.MB` confirm dialog referencing the count. On confirm, each file SHALL be removed via `os.remove`, each removed index SHALL trigger `RemoveSelectionFixup`, and `RefreshPresets()` SHALL be called once.

#### Scenario: Delete 3 selected presets

- GIVEN indices `{2, 5, 7}` selected among 10 files
- WHEN user right-clicks → "Delete 3 presets" → confirms Yes
- THEN files at indices 2, 5, 7 are deleted AND `RefreshPresets()` is called AND selection is empty after fixup

### Requirement: Merge Mode Load

When right-clicking a multi-selection, the context menu MUST show "Load (Merge)". Selecting it SHALL concatenate notes from all selected presets into the editor, preserving each preset's original `start_beat` positions. A single undo snapshot SHALL capture the pre-merge state.

#### Scenario: Merge two presets

- GIVEN 2 presets with 3 and 4 notes respectively are selected
- WHEN user right-clicks → "Load (Merge)"
- THEN editor contains all 7 notes AND undo reverts to pre-merge state in one step

### Requirement: Export to MIDI

When right-clicking a multi-selection, the context menu MUST show "Export to MIDI". Selecting it SHALL create one REAPER MIDI item per selected preset, each containing that preset's notes as MIDI events.

#### Scenario: Export 3 presets

- GIVEN 3 presets selected in the browser
- WHEN user right-clicks → "Export to MIDI"
- THEN 3 new MIDI items appear in the REAPER arrangement

### Requirement: Search Clears Selection

When the search query changes (any character input, backspace, Escape), `ClearSelection()` SHALL be called to prevent stale indices.

#### Scenario: Active search clears selection

- GIVEN `{[2]=true, [5]=true}` selected
- WHEN user types any character in the search bar
- THEN `GetSelectionCount()` returns 0 AND anchor is nil

### Requirement: Backward Compat Shim

`GetSelectedPresetIdx()` SHALL remain and delegate to `GetPrimarySelectedIndex()`. All existing single-preset consumers (Load button, Rename) SHALL continue working unchanged.

#### Scenario: Single selection via shim

- GIVEN `selected_indices = {[3]=true}`
- WHEN `GetSelectedPresetIdx()` is called
- THEN it returns 3

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
- [ ] Plain click selects single item, clears previous selection
- [ ] Ctrl+click toggles individual preset selection without losing others
- [ ] Shift+click selects range between anchor and clicked index
- [ ] Right-click on multi-selection shows batch menu (Load Merged, Delete N, Export N)
- [ ] Batch Delete shows confirmation dialog with count, removes files, fixes up indices
- [ ] Merge-mode Load appends notes from multiple presets, pushes single undo snapshot
- [ ] Export creates REAPER MIDI items from all selected presets' notes
- [ ] Search query change clears multi-selection to prevent stale indices
- [ ] Backward compat: `GetSelectedPresetIdx()` returns primary selected index or nil
- [ ] Index fixup after delete works for adjacent ({2,3,4}) and non-adjacent ({2,5,7}) selection sets
