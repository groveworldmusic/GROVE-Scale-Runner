# Preset Stats Specification

## Purpose

Track usage count and last-used date per preset file across sessions, persisted via `reaper.GetExtState`/`SetExtState`. Enables usage-based badges and recency sorting in the preset browser.

## Requirements

### Requirement: Stats Data Model

The system SHALL maintain a stats record for each loaded/saved preset, consisting of a usage count (non-negative integer) and a last-used timestamp (ISO date string `YYYY-MM-DD`). Stats SHALL be keyed by the preset's absolute file path.

#### Scenario: Stats record created on first load

- GIVEN a preset file `my-song.grove` has never been loaded
- WHEN the user loads it via `io_mod.LoadPreset()`
- THEN a stats record SHALL exist for that path
- AND the count SHALL equal 1
- AND the last-used date SHALL equal the current date in ISO format

### Requirement: Persistence via ExtState

Stats SHALL be persisted in the canonical `GROVE_Scale_Runner` ExtState namespace using key pattern `preset_stats:{path}`. On script init, all `preset_stats:*` keys SHALL be loaded into an in-memory stats table. On stat mutation, the corresponding ExtState key SHALL be written immediately.

#### Scenario: Stats survive REAPER restart

- GIVEN a preset loaded 3 times in session A
- WHEN REAPER is closed and reopened, and the script starts
- THEN the stats for that preset SHALL still show count=3 with the correct last-used date

#### Scenario: Flush on save

- GIVEN a preset is saved via `io_mod.SavePreset()`
- WHEN the save completes
- THEN a stats record SHALL be created/updated with count=1 (new file) and current date

### Requirement: Recency Query

The stats store SHALL expose `GetStats(path) → {count, last_used|nil}` and `GetAllStats() → {[path] = {count, last_used}}`. Stats SHALL be sorted by `last_used` descending when queried via `GetRecentPresets(N)`, returning the N most recently loaded/saved presets.

#### Scenario: Most recent presets query

- GIVEN 3 presets loaded on dates "2026-05-10", "2026-05-15", "2026-05-18"
- WHEN `GetRecentPresets(2)` is called
- THEN it returns the 2 presets from "2026-05-18" and "2026-05-15" in that order

#### Scenario: Preset never used returns nil

- GIVEN a preset file that exists on disk but has never been loaded
- WHEN `GetStats(path)` is called
- THEN it returns nil

### Requirement: Stats Increment on Load and Save

Every successful call to `io_mod.LoadPreset()` SHALL increment the stats count for the loaded path. Every successful call to `io_mod.SavePreset()` SHALL create or increment the stats record for the saved path. Stats SHALL NOT be modified on failed load/save operations.

#### Scenario: Load failure does not increment

- GIVEN a malformed `.grove` file that fails to load
- WHEN `io_mod.LoadPreset()` returns false
- THEN the stats count for that path SHALL remain unchanged

## Acceptance Criteria

- [ ] Stats store loads all `preset_stats:*` ExtState keys at init
- [ ] LoadPreset increments count and updates last_used
- [ ] SavePreset creates/updates stats for the saved file path
- [ ] Failed loads/saves do not mutate stats
- [ ] `GetRecentPresets(N)` returns N most recent entries sorted by date descending
- [ ] Stats survive REAPER restart (ExtState round-trip)
