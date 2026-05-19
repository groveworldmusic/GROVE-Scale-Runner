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

Save SHALL write the current island notes array to disk as a Lua-serialized `.grove` file. The save dialog SHALL use `io.open(filename, "w")` and write `return {notes = {...}, metadata = {name, created, version}}`. The filename SHALL default to "untitled.grove".

#### Scenario: Save creates file

- GIVEN the island store has 5 notes
- WHEN user presses Ctrl+S and enters "my-song" as the name
- THEN a file `my-song.grove` is created in the current directory
- AND the preset list refreshes showing the new entry

### Requirement: Load Preset

Load SHALL read a `.grove` file via `dofile()` or `loadfile()` and populate the island store's notes array. Load MUST validate that the returned table has a `notes` array field. Load SHOULD handle malformed files gracefully (show error, keep existing notes unchanged).

#### Scenario: Load valid preset

- GIVEN a valid `my-song.grove` file with 5 notes
- WHEN user selects it from the list and presses Load
- THEN island store notes are replaced with the 5 notes from file

#### Scenario: Malformed file handled

- GIVEN a `.grove` file containing `return "invalid"`
- WHEN user attempts to load it
- THEN a REAPER MB dialog SHALL display the error
- AND existing notes MUST remain unchanged

## Acceptance Criteria

- [ ] Browser navigates directory tree (expand/collapse subdirs)
- [ ] Preset list shows `.grove` files, filters non-`.grove` files
- [ ] Save writes valid `.grove` files readable by Load
- [ ] Load replaces notes array, validates structure
- [ ] Malformed files show error dialog without data loss
- [ ] Empty directory shows placeholder, does not crash
