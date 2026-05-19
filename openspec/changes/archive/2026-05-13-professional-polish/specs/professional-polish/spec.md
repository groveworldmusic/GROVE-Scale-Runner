# Delta for Professional Polish

## Purpose

Packaging, defensive-hardening, and documentation expectations for GROVE Scale Runner. Three independent polish areas — zero new user-facing capabilities.

## ADDED Requirements

### A. ReaPack Distribution

| ID | Requirement | Verify By |
|----|-------------|-----------|
| A1 | `@provides` in main.lua MUST enumerate all 46 `.lua` files under `src/`. | `dir src/*.lua /s /b \| measure` |
| A2 | `@changelog` block MUST exist with v1.0.0 entry. | Read header |
| A3 | Script name MUST be "GROVE Scale Runner" in `@description` and all internal references. | Grep for mismatches |
| A4 | MIT `LICENSE` MUST exist in project root. | `Test-Path LICENSE` |

#### Scenario: Complete @provides
- GIVEN `src/` contains 46 `.lua` files
- WHEN ReaPack resolves `@provides`
- THEN all 46 files MUST be listed; none missing, none extra

#### Scenario: Naming consistency
- GIVEN a source file referencing the script by name
- WHEN the reference does not match "GROVE Scale Runner"
- THEN it SHALL be corrected

### B. Defensive Hardening

| ID | Requirement | Verify By |
|----|-------------|-----------|
| B1 | `ExportToMidi` MUST wrap project mutations in `Undo_BeginBlock()` / `Undo_EndBlock()`. | Grep for both calls around export |
| B2 | Every `JS_*` API call MUST be guarded by `reaper.APIExists()` before invocation. | Grep for JS_ calls without guard |
| B3 | `reaper.GetPlayState()`, `GetPlayPosition2()`, `CreateNewMIDIItemInProj`, `GetSelectedTrack` return values MUST have nil guards. | Manual review |
| B4 | `config.state.root_index`, `scale_index`, `chord_mode_index` SHALL be clamped to valid ranges before array access. | Grep for clamp/wrap |
| B5 | `MainLoop` MUST check a dirty-flag before calling `gfx.update()`. Logic always runs. | Read main.lua |
| B6 | All persistent `reaper.*` object refs MUST pass `ValidatePtr()` before use. | Grep ValidatePtr usage |

#### Scenario: Undo block scope
- GIVEN `ExportToMidi` is executing
- WHEN user triggers undo after completion
- THEN the entire export SHALL undo as one atomic action
- AND unrelated project changes SHALL NOT be affected

#### Scenario: Missing JS_* extension
- GIVEN a REAPER build without JS_* extensions
- WHEN a JS_* function would be called
- THEN the call MUST be skipped
- AND execution MUST continue without error

#### Scenario: Nil state from no-open project
- GIVEN no project is loaded
- WHEN `GetPlayState()` returns nil
- THEN sequencer SHALL treat state as stopped (not crash)

#### Scenario: Index out of bounds
- GIVEN `config.state.scale_index` is set to 99 (valid max: 21)
- WHEN scale array is accessed
- THEN the index SHALL be clamped to `math.min(99, #scale_array)` or equivalent
- AND no out-of-bounds read occurs

#### Scenario: Dirty-flag render skip
- GIVEN no state change occurred in the current frame
- WHEN `MainLoop` runs
- THEN `gfx.update()` SHALL be skipped
- AND all input processing SHALL still execute

### C. Licensing & Documentation

| ID | Requirement | Verify By |
|----|-------------|-----------|
| C1 | All 46 `.lua` files in `src/` MUST carry an MIT license header block. | ForEach-Object + Grep header |
| C2 | `CHANGELOG.md` MUST exist in project root. | `Test-Path CHANGELOG.md` |
| C3 | `CONTRIBUTING.md` MUST exist in project root. | `Test-Path CONTRIBUTING.md` |
| C4 | Section comments across modules SHALL follow a single convention (`--- Section: name`). | Code review |

#### Scenario: License header present
- GIVEN a `.lua` file in `src/`
- WHEN the file is read
- THEN the first 10 lines MUST contain the MIT license header

#### Scenario: Changelog entry format
- GIVEN `CHANGELOG.md` exists
- WHEN inspected
- THEN it MUST contain at least one version entry (v1.0.0)
- AND entries MUST follow `## [x.y.z] - YYYY-MM-DD` format

## REMOVED Requirements

None — no existing specs are modified or removed.
