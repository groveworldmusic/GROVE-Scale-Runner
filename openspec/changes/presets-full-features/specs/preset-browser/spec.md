# Delta for preset-browser

## ADDED Requirements

### Requirement: Preview Auditivo (Ghost MIDI)

The preset browser SHALL support ghost MIDI preview. Hovering a preset item in the list SHALL trigger a short ghost chord via `midi.TriggerChord()` using a dedicated temporary context that SHALL NOT increment the ref-counted `active_notes` store. On hover end, all ghost notes SHALL be immediately sent note-off. Ctrl+Space while hovering SHALL play the preview at full volume without mutating any state.

#### Scenario: Hover plays ghost chord

- GIVEN the user hovers over a preset item in the preset list
- WHEN the cursor remains on the item for 300ms (debounce)
- THEN `midi.TriggerChord()` SHALL be called with a temporary context
- AND no entry SHALL be added to `midi_store.GetActiveNotes()`
- AND when the cursor leaves the item, all ghost notes SHALL receive note-off

#### Scenario: Ctrl+Space triggers full preview

- GIVEN a preset item is hovered
- WHEN user presses Ctrl+Space
- THEN the preset SHALL play at full velocity for as long as Ctrl+Space is held
- AND on release, notes SHALL stop immediately
- AND no state (active_notes, last_note_played) SHALL be mutated

#### Scenario: Ghost preview on empty directory

- GIVEN an empty `grove-presets/` directory
- WHEN user hovers over the "(No presets)" placeholder
- THEN no MIDI SHALL be sent
- AND no error SHALL occur

### Requirement: Miniaturas de Patrón (8×8 Grid)

Each preset item in the list SHALL render an 8×8 pixel density thumbnail computed at scan time from the preset's note pitch-and-time distribution. The thumbnail SHALL be stored in the `preset_files` entry as an 8×8 array. Thumbnails SHALL be recomputed only on scan/refresh, not every frame.

#### Scenario: Thumbnail generated on scan

- GIVEN a preset file with notes spanning beats 0-15 and pitches C2-C5
- WHEN `m.ScanDirectory()` processes the file
- THEN the file entry SHALL contain an `8x8` thumbnail grid
- AND at least 2 cells SHALL be filled (non-zero) reflecting note density

#### Scenario: Thumbnail renders in preset list

- GIVEN a preset list with 5 files, each with computed thumbnails
- WHEN `DrawPresetList()` renders
- THEN each row SHALL show the 8×8 dot grid to the left of the filename
- AND filled cells SHALL render using the theme's primary color
- AND empty cells SHALL render as dim dots

#### Scenario: Empty preset has blank thumbnail

- GIVEN a preset file with 0 notes
- WHEN the thumbnail is computed
- THEN all 64 cells SHALL be 0 (empty)
- AND the dot grid SHALL render as all dim dots

### Requirement: Badges por Uso

The preset list SHALL display a usage badge next to each preset name based on its stats count. Badge thresholds and labels:

| Condition | Badge | Color |
|-----------|-------|-------|
| count >= 50 | "Veteran" | Gold (#FFD700) |
| count >= 10 | "Regular" | Silver (#C0C0C0) |
| count >= 1 | "Used" | Dim (#808080) |
| count == 0 or nil | "New" | Green (#4CAF50) |
| last_used == today | "Today" | Cyan (#00BCD4) |

"Today" badge SHALL take precedence over all others. A preset may show at most one badge.

#### Scenario: Veteran badge shown after 50 loads

- GIVEN a preset with stats count = 52
- WHEN the preset list renders
- THEN the item SHALL show a "Veteran" badge in gold
- AND the badge text SHALL render using `gfx.setfont` at size 9

#### Scenario: Today badge overrides Veteran

- GIVEN a preset with stats count = 60 AND `last_used = "2026-05-18"` (today)
- WHEN the preset list renders
- THEN the item SHALL show "Today" badge, NOT "Veteran"

#### Scenario: Never-loaded preset shows "New"

- GIVEN a preset file with no stats record (never loaded)
- WHEN the preset list renders
- THEN the item SHALL show a "New" badge in green

### Requirement: Auto-save por Slot

The system SHALL auto-save the current notes to a slot-specific preset on progression changes. When `progression.Add()` or `progression.SetProgressionEntry()` is called, a 3-second debounce timer SHALL start. On timer expiry, the current editor notes SHALL be saved to `_autosave/<progression_revision>-slot-<idx>.grove` in the preset root. Each slot SHALL maintain at most 5 auto-save snapshots (evict oldest).

#### Scenario: Auto-save triggers after 3s

- GIVEN the user drags a degree to slot 5 at T=0s
- WHEN no further progression changes occur
- THEN at T=3s, a file `_autosave/<rev>-slot-5.grove` SHALL be created
- AND the file SHALL contain the current notes as of T=3s

#### Scenario: Auto-save debounced (multiple changes in 3s window)

- GIVEN the user modifies slot 5 at T=0s and slot 5 again at T=2s
- WHEN the timer reset on each change
- THEN the save SHALL occur at T=5s (3s after the last change)
- AND the file SHALL contain the latest notes state

#### Scenario: Auto-save eviction

- GIVEN 5 auto-save files already exist for slot 3
- WHEN a 6th auto-save triggers
- THEN the oldest (earliest timestamp) file SHALL be deleted
- AND the new file SHALL be created

### Requirement: Versionado Automático (Save Conflict)

When `SavePreset()` is called with a name that matches an existing `.grove` file, the system SHALL NOT overwrite. Instead, it SHALL append `_v1`, `_v2`, etc. to the filename until finding an unused name. The version suffix SHALL be inserted before the `.grove` extension.

#### Scenario: Save generates _v1 suffix

- GIVEN `my-song.grove` already exists in the current directory
- WHEN user saves as "my-song"
- THEN the file SHALL be created as `my-song_v1.grove`
- AND `my-song.grove` SHALL remain unchanged

#### Scenario: Save generates _v2 when _v1 exists

- GIVEN `my-song.grove` exists AND `my-song_v1.grove` exists
- WHEN user saves as "my-song"
- THEN the file SHALL be created as `my-song_v2.grove`

#### Scenario: Versioning skips to next gap

- GIVEN `my-song.grove`, `my-song_v1.grove`, `my-song_v3.grove` exist
- WHEN user saves as "my-song"
- THEN the file SHALL be created as `my-song_v2.grove` (fills the gap)

### Requirement: Dark/Light Sync

The preset browser SHALL inherit `ui_store.GetColorMode()` and adjust its color palette accordingly. Folder icons, preset list background, search bar, and badge colors SHALL use the active theme's color set rather than hardcoded values.

#### Scenario: Light mode renders lighter backgrounds

- GIVEN `ui_store.GetColorMode()` returns "flat"
- WHEN the preset browser renders
- THEN the background area (search bar, list area, folder panel) SHALL use lighter shades from the active theme
- AND text SHALL use `theme.colors.text` (dark on light)

#### Scenario: Grade mode renders graded backgrounds

- GIVEN `ui_store.GetColorMode()` returns "grade"
- WHEN the preset browser renders
- THEN the background areas SHALL use the current graded background from the active theme

#### Scenario: Dynamic switch without re-init

- GIVEN the preset browser is visible
- WHEN the user toggles color mode via the theme dropdown
- THEN the preset browser SHALL reflect the new colors on the next frame
- AND no `gfx.init()` or full re-render SHALL be required

### Requirement: Export/Import Packs

The system SHALL support exporting selected presets into a `.grove-pack` file and importing such packs back into the preset tree. A pack file SHALL contain a JSON manifest (with `version`, `created`, `preset_count`, and a SHA-256-like integrity hash) followed by concatenated `.grove` file data with length-prefixed boundaries.

#### Scenario: Export 3 presets to pack

- GIVEN 3 presets selected in the browser (multi-select or single selection)
- WHEN user triggers "Export Pack..." from the context menu
- THEN a file dialog opens via `reaper.GetUserFileNameForWrite` with filter `*.grove-pack`
- AND the resulting file SHALL contain a valid manifest header
- AND all 3 preset files SHALL be recoverable via import

#### Scenario: Import pack restores files

- GIVEN a valid `.grove-pack` file with 3 presets
- WHEN user triggers "Import Pack..." and selects the file
- THEN 3 `.grove` files SHALL be created in the current preset directory
- AND each file SHALL match the original preset byte-for-byte

#### Scenario: Malformed pack shows error

- GIVEN a file with `.grove-pack` extension containing invalid data
- WHEN user attempts to import it
- THEN an error dialog SHALL display "Invalid pack file: manifest missing"
- AND no files SHALL be created in the preset directory

#### Scenario: Import skips duplicate files

- GIVEN a pack containing `my-song.grove` AND `my-song.grove` already exists on disk
- WHEN user imports the pack
- THEN the existing `my-song.grove` SHALL NOT be overwritten
- AND a warning SHALL display: "Skipped 1 duplicate preset(s)"

## MODIFIED Requirements

### Requirement: Save Preset

Save SHALL write the current island notes AND full progression context to disk as a `.grove` file (v3 format). The serialized table MUST include: `name`, `version = 3`, `notes` array, `progression` array (16 entries, may contain nils), `root_index`, `scale_index`, `octave`, `chord_mode_index`. The file SHALL also include any populated metadata fields (`key`, `bpm`, `genre`, `difficulty`, `tags`, `notes`). The filename SHALL default to "untitled.grove". On name collision, Save SHALL NOT overwrite — instead it SHALL append `_v1`, `_v2`, etc. to find an unused name (versionado automático). Save SHALL validate that all required context fields are present before writing. After successful save, the stats count for the saved file SHALL be incremented.
(Previously: v2 format, no metadata fields, no versioning, no stats)

#### Scenario: Save creates v3 file (updated)

- GIVEN the island store has 5 notes, and metadata fields `key="C"` and `bpm=120` are set
- WHEN user presses Ctrl+S and enters "my-song" as the name
- THEN a file `my-song.grove` is created with `version=3`
- AND the file contains `key="C"` and `bpm=120`
- AND the stats count for `my-song.grove` is incremented to 1

#### Scenario: Save with versioning on conflict

- GIVEN `my-song.grove` already exists
- WHEN user saves as "my-song"
- THEN the file is created as `my-song_v1.grove` (NOT overwrite)
- AND both files appear in the preset list

#### Scenario: Save writes v2 format (unchanged — backward compat reference)

- GIVEN island store has 5 notes, sequencer has progression entries at slots 1, 3, 5, and context `root_index=1, scale_index=1, octave=4, chord_mode_index=2`
- WHEN user saves as "my-song" (no name conflict)
- THEN the file MUST contain `version=3`, all 5 notes, progression array with entries at indices 1,3,5, all 4 context fields
- AND `version=3` is the new default, replacing version=2

### Requirement: Load Preset

Load SHALL detect format version from the `version` field. For `version >= 3`, it MUST restore notes, progression, context fields, AND all present metadata fields (`key`, `bpm`, `genre`, `difficulty`, `tags`, `notes`) into memory. For `version = 2` (or absent, treated as v1), it MUST restore notes AND progression + context fields into sequencer_store. For v1 (no version field or `version = 1`), it MUST restore notes only — progression and context SHALL NOT be modified. Load MUST validate that `notes` is a table; for v2+, it SHOULD also validate `progression` is a table if present. Load SHOULD handle malformed files gracefully (show error, keep existing notes unchanged). After successful load, the stats count for the loaded file SHALL be incremented.
(Previously: version detection stopped at v2, no metadata fields, no stats)

#### Scenario: Load v3 preset with metadata (updated)

- GIVEN a `.grove` file with `version=3`, notes with 5 entries, `key="Am"`, `tags={"verse"}`
- WHEN user loads it
- THEN island notes are replaced with the 5 entries
- AND `result.key = "Am"` and `result.tags = {"verse"}` are available in memory
- AND stats count for that preset increments by 1

#### Scenario: Load v2 preset backward compatible (unchanged)

- GIVEN a `.grove` file with `version=2` and only a notes array and progression
- WHEN user loads it
- THEN island notes are replaced AND sequencer progression restored AND metadata fields all nil
- AND stats count increments by 1
