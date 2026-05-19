# Delta for preset-browser

## MODIFIED Requirements

### Requirement: Save Preset

Save SHALL write the current island notes AND full progression context to disk as a `.grove` file (v2 format). The serialized table MUST include: `name`, `version = 2`, `notes` array, `progression` array (16 entries, may contain nils), `root_index`, `scale_index`, `octave`, `chord_mode_index`. The filename SHALL default to "untitled.grove". Save SHALL validate that all required context fields are present before writing.
(Previously: saved only `{notes, metadata}` with version=1)

#### Scenario: Save writes v2 format

- GIVEN island store has 5 notes, sequencer has progression entries at slots 1, 3, 5, and context `root_index=1, scale_index=1, octave=4, chord_mode_index=2`
- WHEN user saves as "my-song"
- THEN the file MUST contain `version=2`, all 5 notes, progression array with entries at indices 1,3,5, and all 4 context fields

### Requirement: Load Preset

Load SHALL detect format version from the `version` field. For `version = 2` (or absent, treated as v1), it MUST restore notes AND progression + context fields into sequencer_store. For v1 (no version field or `version = 1`), it MUST restore notes only — progression and context SHALL NOT be modified. Load MUST validate that `notes` is a table; for v2, it SHOULD also validate `progression` is a table if present.
(Previously: loaded only notes array; no version detection)

#### Scenario: Load v2 preset restores progression + context

- GIVEN a `.grove` file with `version=2`, notes with 5 entries, and progression with 3 entries
- WHEN user loads it
- THEN island notes are replaced with the 5 entries AND sequencer progression is restored with the 3 entries AND root/scale/octave/chord_mode are set

#### Scenario: Load v1 preset backward compatible

- GIVEN a `.grove` file with `version=1` (or no version field) and only a notes array
- WHEN user loads it
- THEN island notes are replaced AND sequencer progression remains unchanged AND context fields are NOT modified

## ADDED Requirements

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
