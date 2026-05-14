# Design: complete-test-suite

## Technical Approach

Fix-and-add on the test suite: verify 3 existing assertions are correct, create 4 new test files following established patterns (mock reaper, init stores, helpers.check), register barrel-backward-compat in the runner, fix one comment. Zero production logic changes.

---

## Architecture Decisions

### Decision: snap-tests-fix — already applied

| Option | Detail |
|--------|--------|
| Line 70 | Already uses `math.abs(...) < 0.001` tolerance — no change needed |
| Line 103 | `GetSnapResolution() == 4` is correct; `GetSnapEnabled() == false` at line 102 already matches spec S2 — no change needed |
| Line 267 | `new_duration == 2.0` and comment says "4.0" already correct — no change needed |

**All 3 assertion fixes are already present in the file.** Design work confirms zero changes required.

### Decision: persist mock — inline override

| Option | Tradeoff |
|--------|----------|
| Modify reaper.lua (add `_extstate` table) | Affects all tests, higher blast radius |
| **Inline override in test file** | Follows `_vkey_string` / `time_precise` pattern, explicit per test |

**Chosen**: Each test file sets up `reaper.GetExtState` with a local `extstate` table, then restores after. Matches existing conventions.

### Decision: barrel file — helpers.check()

The barrel file (322 LOC) uses a local `verify()` + `print()` + `all_pass`. The spec requires it to use `helpers.check()`/`io.write()` instead.

**Chosen**: Replace `verify()` with `helpers.check()`, replace `print()` with `io.write()`, remove `all_pass`/`return all_pass`. This integrates its pass/fail counters with the shared `helpers.passed`/`helpers.failed` totals in `run.lua`.

### Decision: module cache isolation

preferences.lua has module-level `local prefs_state = {...}` and `local save_pending = false`. Each test file needs a fresh state. **Chosen**: `package.loaded["state.preferences"] = nil` before `require()`, matching the keyboard test isolation pattern.

---

## Data Flow

```
tests/run.lua
  ├── test_api_guard.lua   → pure Lua, no reaper mock needed
  ├── test_persist.lua     → overrides reaper.GetExtState inline
  ├── test_preferences.lua → clears package.loaded, requires persist mock
  ├── test_preset_store.lua→ pure Lua, no reaper mock needed
  └── barrel-backward-compat.lua → helpers.check(), ui modules via pcall
```

All files: `dofile()` in runner → `helpers.check()` appends to shared counters → `helpers.summary()` at end.

---

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `tests/snap-tests.lua` | None | All 3 fixes already applied |
| `tests/test_api_guard.lua` | Create | ~60 LOC — CheckAPI, AssertAPIs, ClampIndex |
| `tests/test_persist.lua` | Create | ~90 LOC — Load (canonical/legacy/missing), Save, coerce |
| `tests/test_preferences.lua` | Create | ~90 LOC — 7 pairs, SyncFromState, TickSaveDebounce |
| `tests/test_preset_store.lua` | Create | ~60 LOC — 8 pairs, ClearBrowserState |
| `tests/run.lua` | Modify | Add `"barrel-backward-compat.lua"` to test_names |
| `tests/barrel-backward-compat.lua` | Modify | Replace verify/print/all_pass with helpers.check/io.write |
| `src/core/midi.lua` | Modify | Line 55: clarify force=true comment semantics |

---

## Interfaces / Contracts

### api-guard-tests pattern

```lua
local guard = require("core.api-guard")
-- CheckAPI: APIExists available path
reaper.APIExists = function(name) return name == "JS_VKeys_GetState" end
check(guard.CheckAPI("JS_VKeys_GetState"), "CheckAPI finds existing API")
check(guard.CheckAPI("NonExistent") == false, "CheckAPI returns false for missing")
-- CheckAPI: fallback path (no APIExists)
reaper.APIExists = nil
check(guard.CheckAPI("StuffMIDIMessage") == (type(reaper.StuffMIDIMessage) == "function"), "fallback")
-- ClampIndex
check(guard.ClampIndex(5, 1, 3) == 3, "clamp max")
check(guard.ClampIndex(0, 1, 3) == 1, "clamp min")
check(guard.ClampIndex(nil) == 1, "nil value")
check(guard.ClampIndex(100, 5, 5) == 5, "degenerate range")
```

### persist-tests pattern (inline mock)

```lua
local persist = require("state.persist")
local extstate = {}
reaper.GetExtState = function(ns, key)
    local tbl = extstate[ns] or {}
    return tbl[key] or ""
end
reaper.SetExtState = function(ns, key, val, persistent)
    extstate[ns] = extstate[ns] or {}; extstate[ns][key] = val
end
```

### preferences-tests pattern (cache isolation)

```lua
package.loaded["state.persist"] = nil
package.loaded["state.preferences"] = nil
local prefs = require("state.preferences")
```

### preset-store-tests — no mock required

Pure getter/setter round-trips. `Init({})` uses module defaults for all 8 fields.

---

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Unit | api-guard: CheckAPI | Both APIExists paths + fallback type check |
| Unit | api-guard: AssertAPIs | Missing API → MB call + return false; all present → true; empty table → true |
| Unit | api-guard: ClampIndex | Normal, nil in/out-of-range, degenerate min==max, floats, negative |
| Unit | persist: Load | Canonical key, legacy fallback+migration, missing key → default, nested PREF_KEYS path |
| Unit | persist: Save | Verifies SetExtState call count + arg shape `{ns, key, tostring(val), true}` |
| Unit | persist: coerce | Numeric string → number, non-numeric → string, empty string, nil edge |
| Unit | preferences: Init | Defaults from provided table; empty table → module defaults |
| Unit | preferences: Getters/Setters | 7 round-trip pairs |
| Unit | preferences: SyncFromState | 4 fields read from config state |
| Unit | preferences: TickSaveDebounce | Pending flush → SetExtState calls; no-op when nothing pending |
| Unit | preset-store: Init | Defaults current_directory + preset_root from Init |
| Unit | preset-store: Getters/Setters | 8 round-trip pairs incl. nil idx, table refs |
| Unit | preset-store: ClearBrowserState | 5 fields reset, 3 preserved |
| Unit | preset-store: SetBrowserScroll | Negative → 0 clamp |
| Integration | barrel-backward-compat | Registered in run.lua, uses helpers.check counters |

---

## Migration / Rollout

No migration required. Test files only + one comment change.

---

## Open Questions

- **Module cache for persist.lua in preferences tests**: preferences.lua requires `state.persist` at line 19. Should we clear `package.loaded["state.persist"]` before the test too? The persist module has no module-level state (all functions), so cache is harmless. But to be safe, yes — same isolation pattern.
- **Barrel file in test runner**: `ui.piano-roll` requires `gfx` globals plus possibly other UI modules. The barrel file uses `pcall` to handle load failures. With mocked `gfx`, it should load. If it doesn't, `helpers.check(false, ...)` correctly records a failure — no special handling needed.
