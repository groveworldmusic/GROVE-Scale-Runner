# Delta for Preset Browser

## ADDED Requirements

### Requirement: Progression-Only `.grove-prog` Files (ADDED)

The system SHALL support `.grove-prog` as a valid preset extension alongside `.grove`. `SavePresetProgression()` SHALL serialize `progression[1..16]`, `root_index`, `scale_index`, `octave`, `chord_mode_index`, `version=1` — no `notes` key. UI SHALL expose a "Save Progression" button adjacent to SAVE.

#### Scenario: Save Progression creates `.grove-prog`

- GIVEN progression has entries at slots 1, 5 and context root=1/scale=2/oct=4
- WHEN user clicks "Save Progression" and enters "my-prog"
- THEN `my-prog.grove-prog` is created with progression, 4 context fields, `version=1`, NO `notes`

### Requirement: Scan Returns Both Types

`ScanDirectory()` SHALL return both `.grove` and `.grove-prog` files. Each entry SHALL include a `type` field: `"notes"` for `.grove`, `"progression"` for `.grove-prog`.
(Previously: scanned only `.grove`; no type field)

#### Scenario: Scan returns both types

- GIVEN `song.grove` and `prog.grove-prog` in the current directory
- WHEN `ScanDirectory()` runs
- THEN both files appear with `type = "notes"` and `type = "progression"`

### Requirement: Load Branches on File Type

`LoadPreset()` SHALL branch on extension/type. `type == "progression"` (.grove-prog): restore progression + 4 context fields, skip all note restoration and validation. `type == "notes"` (.grove): existing behavior unchanged.
(Previously: only `.grove` existed; always restored notes + progression)

#### Scenario: Load progression-only preset

- GIVEN a `.grove-prog` file with progression at slots 1 and 5
- AND piano roll has 5 notes
- WHEN user loads the progression preset
- THEN progression is restored, context is updated, piano-roll notes are UNCHANGED

#### Scenario: Load progression-only malformed file

- GIVEN a `.grove-prog` file containing `return "not a table"`
- WHEN user attempts to load
- THEN error dialog shown AND existing progression AND notes are unchanged

### Requirement: Progression Undo Cleared on Preset Load

After loading any `.grove-prog`, `LoadPreset` SHALL call `ClearProgressionUndoStacks()`.

#### Scenario: Progression undo cleared after progression preset load

- GIVEN progression undo stack has 3 entries
- WHEN user loads a `.grove-prog` file
- THEN progression undo stack is empty, notes are unchanged

## MODIFIED Requirements

### Requirement: Load Preset

Load SHALL detect format version. For v2 (or absent/v1): restore notes + progression. Additionally, for `type == "progression"` (`.grove-prog`): restore progression + 4 context fields; skip all notes restoration and validation. The pre-existing note undo stack clear (`ClearUndoStacks()`) SHALL still run.
(Previously: only `.grove` files were handled; always restored notes)

#### Scenario: Load valid `.grove` notes-only (unchanged)

- GIVEN a valid `.grove` file with 5 notes
- WHEN user loads it
- THEN island store notes are replaced with 5 notes
- AND progression is also restored for v2
- AND both undo stacks are cleared
