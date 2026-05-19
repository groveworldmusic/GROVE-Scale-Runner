# Spec: complete-test-suite

## Capability: snap-tests-fix

### Requirements

| ID | Requirement | Scenario |
|----|-------------|----------|
| S1 | `SnapBeat(2.2, 8, true)` SHALL use tolerance-based comparison (`math.abs(... - expected) < 0.001`) instead of exact equality for floating point values like 2.333 and 2.667 | GIVEN a triplet snap assertion on line 70 WHEN comparing `SnapBeat(2.2, 8, true)` to 2.333 THEN the assertion MUST use `math.abs(actual - 2.333) < 0.001` not `== 2.333` |
| S2 | `island_store.GetSnapEnabled()` default SHALL assert `false`, matching the store's Init default | GIVEN `island_store.Init({})` WHEN checking `GetSnapEnabled()` THEN the assertion MUST expect `false`, not `true` |
| S3 | `new_duration` at line 267 SHALL assert 2.0, not 2.5 (test author miscalculated: 4.0 - 2.0 = 2.0) | GIVEN `SnapBeat(4.2, 8, false) = 4.0` WHEN computing `new_duration = 4.0 - 2.0` THEN the assertion MUST expect 2.0 |

### Edge Cases
- Floating point: 2.333 is 7/3, 2.667 is 8/3 — neither is exactly representable in binary. Tolerance MUST be used for ALL triplet snap assertions.

---

## Capability: api-guard-tests

### Requirements

| ID | Requirement | Scenario |
|----|-------------|----------|
| AG1 | `CheckAPI(name)` with `reaper.APIExists` available SHALL delegate to `reaper.APIExists(name)` | GIVEN `reaper.APIExists` is a function WHEN `CheckAPI("JS_VKeys_GetState")` is called THEN it MUST return `reaper.APIExists("JS_VKeys_GetState")` |
| AG2 | `CheckAPI(name)` without `reaper.APIExists` SHALL fall back to `type(reaper[name]) == "function"` | GIVEN `reaper.APIExists` is nil WHEN `CheckAPI("StuffMIDIMessage")` is called THEN it MUST return `type(reaper.StuffMIDIMessage) == "function"` |
| AG3 | `CheckAPI(name)` SHALL return `false` for a missing API in either code path | GIVEN `reaper.NonexistentFunc` is nil WHEN `CheckAPI("NonexistentFunc")` is called THEN it MUST return `false` |
| AG4 | `AssertAPIs(checks)` SHALL return `false` and call `reaper.MB` when APIs are missing | GIVEN `checks = { NonexistentFunc = "Missing!" }` WHEN `AssertAPIs(checks)` is called THEN `reaper.get_mock("MB").call_count == 1` AND the function returns `false` |
| AG5 | `AssertAPIs(checks)` SHALL return `true` when all APIs exist | GIVEN `checks = { JS_VKeys_GetState = "VKeys" }` AND `reaper.APIExists` returns `true` WHEN `AssertAPIs(checks)` is called THEN `reaper.get_mock("MB").call_count == 0` AND the function returns `true` |
| AG6 | `AssertAPIs(checks)` with empty checks table SHALL return `true` | GIVEN an empty `checks = {}` WHEN `AssertAPIs(checks)` is called THEN the function returns `true` with no calls to `reaper.MB` |
| AG7 | `ClampIndex(value, min, max)` SHALL clamp `value` to the inclusive range `[min, max]` | GIVEN `ClampIndex(5, 1, 3)` WHEN called THEN returns `3`. GIVEN `ClampIndex(0, 1, 3)` WHEN called THEN returns `1` |
| AG8 | `ClampIndex` SHALL floor the value before clamping | GIVEN `ClampIndex(2.9, 1, 5)` WHEN called THEN returns `2` (floor of 2.9) |
| AG9 | `ClampIndex` SHALL default `min` to 1, `max` to 1, and value to min when nil | GIVEN `ClampIndex(nil)` WHEN called THEN returns `1`. GIVEN `ClampIndex(3, nil, nil)` WHEN called THEN returns `1` |
| AG10 | `ClampIndex` SHALL handle degenerate ranges where `min == max` | GIVEN `ClampIndex(100, 5, 5)` WHEN called THEN returns `5` |

### Edge Cases
- `reaper.APIExists` can be `nil` (REAPER < 6.0) or a function — MUST handle both
- `ClampIndex` with `nil` value: `math.floor(nil or min)` → `math.floor(1)` → `1`. With `nil` min/max: `min or 1` → 1
- Negative values below min: `ClampIndex(-5, 1, 3)` → `1`
- Floating point: `ClampIndex(0.5, 1, 3)` → `1` (floor first)

---

## Capability: persist-tests

### Requirements

| ID | Requirement | Scenario |
|----|-------------|----------|
| P1 | `persist.Load(state)` SHALL read canonical keys from `reaper.GetExtState("GROVE_Scale_Runner", key)` and apply coerced values to `state` | GIVEN `reaper.GetExtState` returns `"3"` for `"root_index"` WHEN `Load(state)` is called THEN `state.root_index == 3` (number) |
| P2 | `persist.Load(state)` SHALL fall back to legacy namespace `"GROVE_FL_MIDI"` when a key is missing in canonical, and migrate it to canonical via `reaper.SetExtState` | GIVEN canonical returns `""` for `"octave"` and legacy returns `"5"` WHEN `Load(state)` is called THEN `state.octave == 5` AND `reaper.get_mock("SetExtState").call_count >= 1` with args `{"GROVE_Scale_Runner", "octave", "5", true}` |
| P3 | `persist.Load(state)` SHALL keep the hardcoded default when neither canonical nor legacy has the key | GIVEN both namespaces return `""` for `"root_index"` WHEN `Load(state)` is called THEN `state.root_index` MUST remain unchanged from its default |
| P4 | `persist.Save(key, value)` SHALL write `tostring(value)` to canonical namespace with persistent=true | GIVEN `Save("root_index", 3)` WHEN called THEN `reaper.get_mock("SetExtState")` MUST have been called with `{"GROVE_Scale_Runner", "root_index", "3", true}` |
| P5 | `coerce(val)` SHALL convert a numeric string to a Lua number | GIVEN `coerce("3")` WHEN called THEN returns `3` (type number) |
| P6 | `coerce(val)` SHALL preserve a non-numeric string as-is | GIVEN `coerce("grade")` WHEN called THEN returns `"grade"` (type string). GIVEN `coerce("true")` WHEN called THEN returns `"true"` (not boolean) |

### Edge Cases
- `coerce("")` — `tonumber("")` returns nil, so fallback preserves `""` (empty string)
- `coerce(nil)` — should not be called with nil per code, but if so, `tonumber(nil)` errors — guard not present
- PREF_KEYS contains both flat (`"root_index"`) and nested (`{"sequencer", "volume"}`) specs — Load SHALL apply to the correct path via `resolve()` / `apply()`
- Save with boolean value: `Save("snap_enabled", true)` would store the string `"true"` — coerce on Load would NOT convert back to boolean (returns string `"true"`)

---

## Capability: preferences-tests

### Requirements

| ID | Requirement | Scenario |
|----|-------------|----------|
| PR1 | All 7 getter/setter pairs SHALL round-trip: Set* X THEN Get* returns X | GIVEN `SetRootIndex(5)` WHEN `GetRootIndex()` is called THEN returns `5`. Repeat for ScaleIndex, Octave, ChordModeIndex, InversionIndex, InversionDirection, SubdivisionIndex |
| PR2 | Init SHALL set defaults from the provided state table | GIVEN `Init({ root_index = 3, octave = 2 })` WHEN `GetRootIndex()` is called THEN returns `3`. WHEN `GetOctave()` is called THEN returns `2`. Unprovided keys SHALL keep module defaults |
| PR3 | Init with empty table SHALL keep all module defaults | GIVEN `Init({})` THEN `GetRootIndex() == 1`, `GetScaleIndex() == 1`, `GetOctave() == 4`, `GetChordModeIndex() == 1`, `GetInversionIndex() == 1`, `GetInversionDirection() == 0`, `GetSubdivisionIndex() == 1` |
| PR4 | `SyncFromState(state)` SHALL read and apply values from a state table (used after `persist.Load`) | GIVEN `SyncFromState({ root_index = 7, octave = 5 })` WHEN checking values THEN `GetRootIndex() == 7` AND `GetOctave() == 5`. Unprovided keys SHALL remain unchanged |
| PR5 | `TickSaveDebounce()` SHALL call `persist.Save` for all 7 keys when `save_pending` is true, and reset `save_pending` to false | GIVEN a setter was called (e.g., `SetRootIndex(3)`) WHEN `TickSaveDebounce()` is called THEN `reaper.get_mock("SetExtState").call_count >= 1`. WHEN `TickSaveDebounce()` is called again THEN no additional SetExtState calls occur |
| PR6 | `TickSaveDebounce()` SHALL be a no-op when no setter was called (no save pending) | GIVEN no setter was called WHEN `TickSaveDebounce()` is invoked THEN `reaper.get_mock("SetExtState").call_count` MUST be 0 |

### Edge Cases
- Each setter MUST set `save_pending = true` — verify via TickSaveDebounce after set
- SyncFromState with nil values for some keys should not change those keys in the store
- Module defaults after `package.loaded["state.preferences"] = nil` + fresh require MUST be correct

---

## Capability: preset-store-tests

### Requirements

| ID | Requirement | Scenario |
|----|-------------|----------|
| PS1 | All 8 field pairs SHALL round-trip: Set* X THEN Get* returns X | GIVEN `SetCurrentDirectory("/presets/jazz")` WHEN `GetCurrentDirectory()` is called THEN returns `"/presets/jazz"`. Repeat for PresetRoot, PresetTree (table), PresetFiles (table), SelectedPresetIdx (nil/number), BrowserScroll (number ≥0), BrowserError (string/nil), Favorites (table), Bookmarks (table) |
| PS2 | Init defaults SHALL match the module's initial state values | GIVEN a module-level state table with `current_directory = ""`, `preset_root = ""`, `preset_tree = {}`, `preset_files = {}`, `selected_preset_idx = nil`, `browser_scroll = 0`, `browser_error = nil`, `favorites = {}`, `bookmarks = {}` WHEN testing each getter after Init({}) THEN each MUST return the default value |
| PS3 | Init SHALL apply provided defaults for `current_directory` and `preset_root` | GIVEN `Init({ current_directory = "/presets", preset_root = "/root" })` WHEN `GetCurrentDirectory()` THEN returns `"/presets"`. WHEN `GetPresetRoot()` THEN returns `"/root"` |
| PS4 | `ClearBrowserState()` SHALL reset all browser fields to defaults | GIVEN non-default values for current_directory, preset_tree, preset_files, selected_preset_idx, browser_scroll, browser_error WHEN `ClearBrowserState()` THEN getters return: directory `""`, tree `{}`, files `{}`, idx `nil`, scroll `0`, error `nil` |
| PS5 | `SetBrowserScroll(v)` SHALL clamp negative values to 0 | GIVEN `SetBrowserScroll(-5)` WHEN `GetBrowserScroll()` THEN returns `0` |

### Edge Cases
- SetCurrentDirectory(nil) → stores `""` (guard: `v or ""`)
- SetPresetRoot(nil) → stores `""` (guard: `v or ""`)
- SetPresetTree(nil) → stores `{}` (guard: `t or {}`)
- SetBrowserScroll(nil) → stores `0` (guard: `math.max(0, v or 0)`)
- SelectedPresetIdx can be nil (nothing selected) or a number — MUST round-trip both
- ClearBrowserState does NOT reset `preset_root`, `bookmarks`, or `favorites` — those persist across browser state clears

---

## Capability: test-runner-registration

### Requirements

| ID | Requirement | Scenario |
|----|-------------|----------|
| TR1 | `tests/run.lua` SHALL include `"barrel-backward-compat.lua"` in its `test_names` list | GIVEN run.lua's `test_names` table WHEN inspected THEN it MUST contain the entry `"barrel-backward-compat.lua"` |
| TR2 | `barrel-backward-compat.lua` SHALL use `helpers.check()` and `helpers.summary()` instead of its own `verify()` / `print()` / `all_pass` | GIVEN barrel-backward-compat.lua WHEN loaded via `dofile()` in run.lua THEN it MUST NOT define its own `verify()` function — instead it SHALL use `require("tests.helpers").check()` for assertions. It MUST NOT call `os.exit()` or `return all_pass` — the runner owns summary/exit |
| TR3 | `barrel-backward-compat.lua` SHALL NOT call `os.exit()` or return a value that the runner could interpret as failure — the runner owns `summary()`/`os.exit()` | GIVEN barrel-backward-compat.lua runs as part of the test suite WHEN `helpers.summary()` runs after all files THEN the pass/fail counters SHALL include the barrel results |

### Edge Cases
- Barrel file registers helpers via require cache — `helpers.check()` appends to shared `passed`/`failed` counters across all files
- `reaper.reset_all_calls()` runs before barrel file (standard runner behavior)

---

## Capability: midi-comment-fix

### Requirements

| ID | Requirement | Scenario |
|----|-------------|----------|
| M1 | The comment on line 55 of `src/core/midi.lua` SHALL clarify that `force=true` only bypasses the ref-count gate (`cur <= 0`), NOT the existence check (`if cur then`) | GIVEN the current comment reads "Note-off: only send 0x80 when ref-count reaches 0 (or force=true bypasses gate)" WHEN reading it THEN it MUST be updated to clarify that force skips the `cur <= 0` guard but NOT the `if cur then` existence check — e.g., "or force=true bypasses ref-count gate only" |

### Edge Cases
- No functional change — comment only. The actual logic on lines 56-67 MUST remain unchanged: `if cur then ... if cur <= 0 or force then reaper.StuffMIDIMessage(...) end end`

---

## Cross-Cutting Constraints

- **Zero production logic changes** — all capabilities are test-only or comment-only. No `.lua` source behavior changes except comments.
- **Mock infra extension**: `reaper.GetExtState` and `reaper.SetExtState` stubs already exist in `tests/mock/reaper.lua` (lines 151-152) as tracked no-ops returning nil. persist-tests will need to override `reaper.GetExtState` to return specific values for canonical/legacy namespaces.
- **Module cache isolation**: preferences-tests and preset-store-tests MUST clear `package.loaded` entries before fresh `require()` calls if module-level state exists.
