# Delta for preset-browser

## ADDED Requirements

### Requirement: Dual-Extension Support

The preset browser SHALL scan for both `.grove` (full notes+progression) and `.grove-prog` (progression-only) file extensions. Directory navigation, folder tree, and file listing SHALL include both types.

#### Scenario: Both extensions visible in list

- GIVEN `grove-presets/` contains `song.grove`, `chords.grove-prog`, `beats.grove`
- WHEN the preset list renders
- THEN all 3 files SHALL appear in the list
- AND each SHALL display a type badge ("Notes" or "Progression")

### Requirement: Save Progression Preset

The system SHALL expose `browser.SaveProgressionPreset(name, dir)` that serializes only `progression[1..16]` entries and context fields `{root_index, scale_index, octave, chord_mode_index}` into a `.grove-prog` file. The serialized table MUST include `type="progression"`, `version = 3`, no `notes` array.

#### Scenario: Save progression-only preset

- GIVEN 8 progression slots filled, 5 notes in editor
- WHEN user saves as progression preset named "verse"
- THEN `verse.grove-prog` is created
- AND the file contains `type="progression"`, `version=3`, 8 progression entries, 4 context fields
- AND no `notes` array is present

### Requirement: Type Filter Tabs

The preset browser panel SHALL display "Notes" and "Progression" filter tabs at the top. Selecting a tab SHALL filter the preset list to show only presets of the matching type. An "All" tab SHALL show both types.

#### Scenario: Notes tab filters list

- GIVEN `.grove` and `.grove-prog` files in current directory
- WHEN user clicks "Notes" tab
- THEN only `.grove` files appear in the list

#### Scenario: Progression tab filters list

- GIVEN `.grove` and `.grove-prog` files
- WHEN user clicks "Progression" tab
- THEN only `.grove-prog` files appear

### Requirement: Type-Aware Preset List

`preset-list.lua` SHALL accept a `type_filter` parameter ("notes", "progression", or nil for all). Each list entry SHALL display a type badge: "Notes" for `.grove`, "Progression" for `.grove-prog`. The badge SHALL render using theme's `accent` and `dim` colors respectively.

#### Scenario: Type badge renders

- GIVEN a list with both `.grove` and `.grove-prog` files
- WHEN the list renders
- THEN each entry shows the file name AND a colored type badge

## MODIFIED Requirements

### Requirement: Save Preset

Save SHALL write the current island notes AND full progression context to disk. When the "Progression" filter tab is active, save SHALL invoke `SaveProgressionPreset()` instead (writing `.grove-prog`). When the "Notes" tab or "All" tab is active, save SHALL write the full `.grove` format (v2) as before.
(Previously: always wrote full `.grove` v2 format with notes + progression)

#### Scenario: Save creates file (unchanged)

- GIVEN the island store has 5 notes
- WHEN user presses Ctrl+S and enters "my-song" as the name
- THEN a file `my-song.grove` is created in the current directory
- AND the preset list refreshes showing the new entry

#### Scenario: Save as progression preset

- GIVEN the "Progression" filter tab is active
- WHEN user saves with name "verse"
- THEN `verse.grove-prog` is created with `type="progression"`
- AND only progression entries + context are serialized (no notes)

### Requirement: Load Preset

Load SHALL detect format version from the `version` field. For files where `type=="progression"`, the system MUST skip `SetNotes()` entirely, call `ClearProgressionUndoStacks()`, and restore only progression entries + context fields. For `type=="notes"` or absent type, load behavior is unchanged.
(Previously: only version-based branching between v1 (notes only) and v2 (notes + progression))

#### Scenario: Load progression preset restores progression only

- GIVEN a `.grove-prog` file with `type="progression"`, `version=3`, 3 progression entries
- WHEN user loads it
- THEN `ClearProgressionUndoStacks()` SHALL be called
- AND progression entries are restored with the 3 entries
- AND context fields (root/scale/octave/chord_mode) are updated
- AND `SetNotes()` SHALL NOT be called (existing notes unchanged)

#### Scenario: Load notes preset unchanged

- GIVEN a `.grove` file with `version=2` and `notes` array
- WHEN user loads it
- THEN notes are replaced as before
- AND progression + context are restored as before (v2 behavior)
