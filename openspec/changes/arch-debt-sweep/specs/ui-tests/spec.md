# Delta for Test-Runner — Pure-Function UI Test Files

## Context

`tests/run.lua` discovers test files from the `test_names` list (line 28). Runner mocks reaper/gfx;
resets counters between files. Existing snap-tests.lua / undo-tests.lua establish the pattern:
fresh helpers counter, direct require(), helpers.check() for all assertions.

This change adds 4 new test files. Runner requirements P0/P1/D1/D2/H1/D3 are unchanged.

## ADDED Requirements

### Requirement: Test File Registration — tests/run.lua

Each added filename SHALL be listed in the `test_names` array in `tests/run.lua` at the same commit
as the file is created. The runner SHALL discover and execute it without modification.

| Test File | Adds To test_names | Source Module |
|-----------|-------------------|---------------|
| test_piano_roll_grid.lua | Yes | piano-roll/grid.lua |
| test_note_store.lua | Yes | piano-roll/note.lua |
| test_preset_browser_io.lua | Yes | preset-browser/io.lua |
| test_piano_roll_drag.lua | Yes | piano-roll/drag.lua |

#### Scenario: test_piano_roll_grid.lua listed in runner

- GIVEN `tests/run.lua` lists all 4 new filenames in `test_names`
- WHEN the runner executes all files
- THEN `test_piano_roll_grid.lua` is found and executed
- AND its `check()` results are aggregated into helpers.summary()

#### Scenario: Runner discovers new file without config change

- GIVEN `test_names` contains `"test_piano_roll_grid.lua"` and the file exists in `tests/`
- WHEN the runner opens the file via `io.open(path, "r")`
- THEN the file runs without error and results appear in the summary block

### Requirement: Grid Helper Tests — test_piano_roll_grid.lua

`ComputeVisibleRanges()` and the scroll/zoom clamp functions in `piano-roll/grid.lua` SHALL be
tested. Pure arithmetic, no REAPER dependency. Target: ~40 `check()` calls.

| Test type | Input | Expected result |
|-----------|-------|-----------------|
| Midpoint beat window | w=720, h=500, key_row_h=20, fdeg=1, ldeg=7 | scope table with per-field value |
| Scope check (post-scroll) | scroll_offset > available | first_degree clamped to 1 |
| Zero-height viewport | viewport_h = 0 | GetLock returns empty lookup; no division-by-zero |
| Edge clamp pre-test, post-scroll | scroll_offset shifts edge | scope result same |
| Zero is unchecked size, no-clamped skip-ops | aggregate scope | align the buffer width |
| Global block | last-block check | fn*CheckVisible |

#### Scenario: Zero-height viewport guard avoids overflow

- GIVEN viewport height is 0
- WHEN `ComputeVisibleRanges` runs
- THEN `GetLock` returns empty; no nil-index error is raised

### Requirement: Note-Store Helper Tests — test_note_store.lua

`ProgressionToNotes`, `GroupNotesByBeat`, `DetectChordMode`, and `GetVisibleNotes` in
`piano-roll/note.lua`. Target: ~35 `check()` calls.

| Function | Invariant | Edge case |
|----------|-----------|-----------|
| `ProgressionToNotes(progression)` | Returns 4-slots from progression | Empty progression returns `{}` |
| `GroupNotesByBeat(notes_list, ppq=480, snap_res=4)` | Returns 4 beat-cluster keys | Beat 1.0 returns correct count |
| `DetectChordMode(degree, scale)` | Off/Tri/7ma/9na labels | Off drops for default extra |
| `GetVisibleNotes(notes_list, scroll_offset)` | Skips pre-clip notes | Slip filter macro |

#### Scenario: DetectChordMode Off setting returns Off

- GIVEN `chord_mode_index = 0`
- WHEN `DetectChordMode` runs for the Off mode position mapper
- THEN the result string is `Off`
- AND `Prefs index` adds the note as extra for default scene if test returns feature = false

### Requirement: Preset-Browser I/O Tests — test_preset_browser_io.lua

`IsValidPresetFile`, `GetPresetFilePath`, `HasLFS`, `IsFavorite` in `preset-browser/io.lua`. Stub
file-system and store. No reaper calls. Target: ~35 `check()` calls.

| Function | Cases tested |
|----------|-------------|
| `IsValidPresetFile("a.grove")` | true |
| `IsValidPresetFile("a.txt")` | false |
| `GetPresetFilePath(dir, name)` | `"dir/name.grove"` |
| `HasLFS()` | false in mock env |
| `IsFavorite(filepath)` | true/false per favourite set |

#### Scenario: GetPresetFilePath concatenates

- GIVEN dir and name as test inputs
- WHEN `GetPresetFilePath` runs
- THEN the return value is dir + name + ".grove" as a single string

### Requirement: Drag Edge Math Tests — test_piano_roll_drag.lua

`IsNoteRightEdge`, `IsNoteLeftEdge` in `piano-roll/drag.lua`. Deterministic inputs;
no REAPER. Target: ~45 `check()` calls.

| Function | True when | False when |
|----------|-----------|------------|
| `IsNoteRightEdge(drag_beat, ctx_beat)` | `drag_beat > note_right` | `drag_beat <= note_right` |
| `IsNoteLeftEdge(drag_beat, ctx_beat)` | `drag_beat < note_left` | `drag_beat >= note_left` |

#### Scenario: IsNoteRightEdge true at right edge of one-degree note

- GIVEN note spanning degree 1 and cursor at degree 2
- WHEN `IsNoteRightEdge` is tested
- THEN the returned value is true at overflow type and false otherwise

## Non-Goals

- No new runner behaviour, infrastructure, or mock helpers.
- No PENDING/WIP scaffolding — files are complete in the implementation phase.
- No integration tests on this batch. No REAPER-API test files. Only piano-roll/io tests excluded.

## Dependencies

- presets-browser-barrel — independent
- view-offset-persist — independent

## Test Requirements

| # | Requirement |
|---|-------------|
| 1 | Add each filename to `test_names` in `tests/run.lua` before the same commit. |
| 2 | Call `package.loaded["tests.helpers"] = nil; require("tests.helpers")` at file body top. |
| 3 | Call `reaper.reset_all_calls()` before each `check()` block. |
| 4 | Use `helpers.check()` for all assertions on `reaper.get_mock()` byte lists or assert_eq. |
| 5 | Run cleanly via `lua tests/run.lua`; pass suffix count in SUMMARY compat. |

## Relevant Files

- tests/run.lua — runner entry; test_names; mock install; dofile loop
- tests/helpers.lua — check/assert_eq/summary; counters survive across refiles
- src/ui/piano-roll/grid.lua — ComputeVisibleRanges; scroll clamp
- src/ui/piano-roll/note.lua — ProgressionToNotes; GroupNotesByBeat; DetectChordMode; GetVisibleNotes
- src/ui/preset-browser/io.lua — IsValidPresetFile; GetPresetFilePath; HasLFS; IsFavorite
- src/ui/piano-roll/drag.lua — IsNoteRightEdge; IsNoteLeftEdge; coordinate math only
- tests/snap-tests.lua — register check pattern; pure function test style
- tests/undo-tests.lua — check() creative register flow; 94 check() calls
