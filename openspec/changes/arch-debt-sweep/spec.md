# Spec: arch-debt-sweep

Three internal quality improvements with no spec-level behavioral change.

## 1. Window Position Persistence

ADDED domain — no existing spec describes window position persistence.

### ADDED Requirements

**REQ-WPP-01**: The system MUST persist `view_offset_x` and `view_offset_y` to REAPER ExtState when the GFX window position changes AND the window is undocked (`gfx.dock(-1) == 0`).

**REQ-WPP-02**: On Init, the system MUST restore `view_offset_x` and `view_offset_y` from ExtState, falling back to `config.state` defaults if no ExtState keys exist.

**REQ-WPP-03**: The save trigger MUST mirror the existing `window_w/h` pattern — write current position from `ui_store.GetWindowPosX/Y()` when position changes.

#### Scenario: Reposition survives restart

- GIVEN the script runs undocked at position (200, 150)
- WHEN the user closes and relaunches REAPER
- THEN the GFX window opens at (200, 150)

#### Scenario: Docked window skips save

- GIVEN the window is docked (`gfx.dock(-1) != 0`)
- WHEN position would be written to ExtState
- THEN NO write occurs for `view_offset_x` or `view_offset_y`

#### Scenario: First launch uses defaults

- GIVEN no ExtState keys exist for position
- WHEN the script initializes
- THEN `gfx.init` uses `config.state.view_offset_x/y` defaults

#### Scenario: Invalid ExtState falls back safely

- GIVEN ExtState contains `view_offset_x="NaN"` or negative values
- WHEN position is loaded during Init
- THEN the system falls back to `config.state` defaults WITHOUT crashing

---

## 2. Preset Browser Barrel Refactor

ADDED domain — internal module structure was not previously specified.

### ADDED Requirements

**REQ-PBB-01**: `src/ui/preset-browser.lua` MUST be rewritten as a barrel module (~120 LOC) requiring and re-exporting from 4 submodules: `io.lua`, `folder.lua`, `main.lua`, `preset-list.lua`.

**REQ-PBB-02**: All exported functions MUST preserve the identical behavioral contract described in `openspec/specs/preset-browser/spec.md`. No consumer SHALL require code changes.

**REQ-PBB-03**: Where the monolith has inline duplicates of submodule functions with different behavior, the barrel MUST use the submodule version as canonical.

**REQ-PBB-04**: The barrel MUST follow the same pattern as `piano-roll.lua` (93 LOC) and `views.lua` (73 LOC) — require + re-assign, no inline logic.

#### Scenario: Exports reach submodule implementations

- GIVEN the barrel re-exports from 4 submodules
- WHEN any consumer calls `preset_browser.SavePreset()` or `preset_browser.LoadPreset()`
- THEN the call reaches the submodule, NOT an inline duplicate

#### Scenario: Consumer compatibility preserved

- GIVEN existing code using `require("ui.preset-browser")`
- WHEN the barrel replaces the monolith
- THEN `pb.SavePreset(...)`, `pb.LoadPreset(...)`, `pb.RenamePreset(...)` work identically

#### Scenario: Missing export caught at load time

- GIVEN a submodule's public function is renamed but the barrel still references the old name
- WHEN the script initializes and the barrel `require` executes
- THEN Lua throws `attempt to index a nil value` (fail-fast at load time)

---

## 3. UI Test Coverage

ADDED domain — no existing spec describes UI-level test requirements for these modules.

### ADDED Requirements

**REQ-UTC-01**: The test runner MUST execute 4 new files: `tests/grid-tests.lua`, `tests/note-store-tests.lua`, `tests/io-tests.lua`, `tests/drag-tests.lua`.

**REQ-UTC-02**: Each test file MUST use only `check()` from `tests/helpers.lua` — zero new mocks or `_G` stubs.

**REQ-UTC-03**: The combined 4 files MUST produce ≥155 `check()` calls total.

**REQ-UTC-04**: Each test file SHALL test ONLY pure functions — those with zero `gfx.*` or `reaper.*` calls.

**REQ-UTC-05**: `tests/run.lua` MUST add the 4 new entries to its `test_names` table.

#### Scenario: Grid snap and beat calculations

- GIVEN `tests/grid-tests.lua` targets `piano-roll/grid.lua` pure functions
- WHEN all tests execute
- THEN ≥50 `check()` assertions pass for snap and beat math

#### Scenario: Note-store CRUD helpers

- GIVEN `tests/note-store-tests.lua` targets `note-store.lua` pure helpers
- WHEN all tests execute
- THEN ≥70 `check()` assertions pass for CRUD, UUID, and selection logic

#### Scenario: IO path utilities

- GIVEN `tests/io-tests.lua` targets `preset-browser/io.lua` pure functions
- WHEN all tests execute
- THEN ≥15 `check()` assertions pass for path normalization and validation

#### Scenario: Drag edge-detection

- GIVEN `tests/drag-tests.lua` targets `piano-roll/interaction/drag.lua` edge-detection
- WHEN all tests execute
- THEN ≥20 `check()` assertions pass for hit-testing and edge coordinates

#### Scenario: Zero new mocks required

- GIVEN all 4 test files follow the pure-function pattern
- WHEN each file loads via `require("tests.helpers")`
- THEN no mock setup code appears in any new test file
- AND each file runs under the existing runner without mock init

#### Scenario: Runner discovers all 4 files

- GIVEN `tests/run.lua` includes the 4 files in `test_names`
- WHEN the runner executes
- THEN all 4 files are found and produce ≥0 passes each
- AND `os.exit(1)` only if any file has failures

#### Scenario: Total assertion threshold met

- GIVEN all 4 test files execute
- WHEN the runner aggregates `check()` counts
- THEN the combined total is ≥155

---

## Success Criteria

- [ ] P1: Move window → close → reopen → position restored from ExtState
- [ ] P2: All `preset_browser.*` calls work identically before and after barrel; grep shows no monolith-internal calls remain
- [ ] P3: 4 new test files pass under `tests/run.lua`; combined ≥155 `check()` assertions
