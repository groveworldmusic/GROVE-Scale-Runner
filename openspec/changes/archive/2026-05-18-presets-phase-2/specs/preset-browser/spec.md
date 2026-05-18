# Delta for Preset Browser

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Preset List Display

The preset list panel SHALL show all `.grove` files in the current directory. Each entry SHALL display the filename (without extension), file size, and last-modified date if available via `io.*`. Clicking a preset SHALL dispatch to the modifier interaction model (plain click replaces, Ctrl+click toggles, Shift+click ranges) as defined by the preset-multiselect specification. Selected items SHALL render with the ITEM_SELECTED background color. Right-clicking a selected item SHALL show a context menu with batch operations (Delete N, Load Merge, Export to MIDI) when multiple items are selected.
(Previously: Single-select only. Click always selected the clicked item. Right-click always showed single-item context menu.)

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
