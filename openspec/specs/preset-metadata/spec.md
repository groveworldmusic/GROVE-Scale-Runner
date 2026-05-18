# Preset Metadata Specification

## Purpose

Extend the `.grove` preset file format to version 3 with additive metadata fields: `key` (musical key), `bpm`, `genre`, `difficulty`, `tags` (string array), and `notes` (free-text). Maintain full backward compatibility with v2 files.

## Requirements

### Requirement: .grove v3 Format

Save SHALL write `version = 3` in the serialized return table. All v3 metadata fields SHALL be optional — a preset SHALL be valid with or without them. The following top-level fields MAY be present:

| Field | Type | Example |
|-------|------|---------|
| `key` | string | "C", "Am" |
| `bpm` | number | 120 |
| `genre` | string | "Jazz", "Electronic" |
| `difficulty` | string | "Easy", "Medium", "Hard" |
| `tags` | table (string array) | `{"ambient", "pad"}` |
| `notes` | string | "Verse progression, add arp later" |

All v2 fields (`name`, `version`, `notes[]`, `progression[]`, `root_index`, `scale_index`, `octave`, `chord_mode_index`) SHALL remain mandatory.

#### Scenario: Save v3 with full metadata

- GIVEN a preset with all 6 metadata fields populated
- WHEN saved
- THEN the file SHALL contain `version=3` AND all 6 metadata fields AND all mandatory v2 fields
- AND a v3 loader reading this file SHALL recover every field identically

#### Scenario: Save v3 with partial metadata

- GIVEN a preset with only `bpm=120` and `notes="test"` specified
- WHEN saved
- THEN the file SHALL contain `version=3`, `bpm=120`, `notes="test"`
- AND `key`, `genre`, `difficulty`, `tags` SHALL be absent (nil)
- AND the file SHALL load without error

### Requirement: Backward Compatible Load

Load SHALL detect `version >= 3` and read all present metadata fields as optional. Missing metadata fields SHALL default to nil and SHALL NOT cause load failure. v2 files (version absent or `version = 1` or `version = 2`) SHALL load identically to current behavior — metadata fields SHALL be nil after load.

#### Scenario: Load v3 file with metadata

- GIVEN a `.grove` file with `version=3`, `key="Cm"`, `bpm=140`, `tags={"dark","cinematic"}`, and no `difficulty` field
- WHEN loaded
- THEN `result.key = "Cm"`, `result.bpm = 140`, `result.tags = {"dark","cinematic"}`
- AND `result.difficulty` is nil
- AND notes/progression/context are restored normally

#### Scenario: v2 file loads without metadata

- GIVEN a `.grove` file with `version=2` and no metadata fields
- WHEN loaded
- THEN `result.version = 2` is preserved
- AND `result.key`, `result.bpm`, `result.genre`, `result.difficulty`, `result.tags`, `result.notes` are all nil
- AND notes/progression/context are restored identically to current v2 behavior

### Requirement: Notes Field UI

The preset browser SHALL expose a notes editor. Clicking a notes icon (or context menu entry "Edit Notes") SHALL call `reaper.GetUserInputs("Preset Notes", 1, "", current_notes)` with a multi-line input field. The entered text SHALL be stored in the in-memory preset entry and saved on next `SavePreset()`.

#### Scenario: Edit and persist notes

- GIVEN a preset with no notes field loaded
- WHEN user clicks the notes icon and enters "Work in progress"
- THEN the in-memory `notes` field SHALL be set to "Work in progress"
- AND when the user saves, the file SHALL contain `notes="Work in progress"`

#### Scenario: Notes survive load-save round-trip

- GIVEN a v3 file with `notes="Needs bass line"`
- WHEN loaded, then saved without changing notes
- THEN the output file SHALL still contain `notes="Needs bass line"`

### Requirement: Edit Metadata Dialog

The preset browser SHALL expose an "Edit Metadata" dialog (via context menu or button) that shows all 6 metadata fields. On save, the fields SHALL be written to the in-memory preset entry and persisted on next `SavePreset()`.

#### Scenario: Edit metadata and save

- GIVEN a preset loaded with no metadata
- WHEN user opens Edit Metadata, sets `key=C`, `bpm=120`, adds tag "ambient"
- THEN the in-memory entry SHALL reflect these values
- AND saving produces a file with `key="C"`, `bpm=120`, `tags={"ambient"}`

## Acceptance Criteria

- [ ] Save writes `version=3` by default; all 6 metadata fields are optional
- [ ] Load reads `version >= 3` and recovers all present metadata fields
- [ ] v2 files load identically without metadata (backward compat)
- [ ] v2 files saved after loading produce v3 output (upgrade on save)
- [ ] Notes editor via GetUserInputs works
- [ ] Metadata editor allows editing all 6 fields
- [ ] Round-trip: metadata survives load → edit → save → reload cycle
