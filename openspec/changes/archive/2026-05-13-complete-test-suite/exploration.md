## Exploration: Test Infrastructure Analysis

### Current State

The test infrastructure for GROVE FL MIDI is a custom-built Lua-only framework with zero external dependencies. The runner (`tests/run.lua`) derives project paths from `debug.getinfo`, installs mock globals (`_G.reaper` and `_G.gfx`) from `tests/mock/`, extends `package.path` to include `src/` and the project root, then iterates a hardcoded list of test files via `dofile()`. Between files, mock call counters are reset via `reaper.reset_all_calls()` for state isolation.

The mock system in `reaper.lua` uses a `make_mock_fn(name)` factory that stores call data in an internal `_mock_storage` table keyed by function name. The mock provides 50+ stubs plus special handling for `JS_VKeys_GetState`, `time_precise`, `GetPlayState`, and `GetFocusedFX2`. The `gfx.lua` mock provides 17 no-op methods plus 9 mutable state fields.

The shared helpers (`tests/helpers.lua`) provide `check()`, `assert_eq()`, and `summary()` with pass/fail counters that persist across `dofile` calls.

The current run shows **574 PASS, 3 FAIL** across 14 test files. The barrel-backward-compat.lua file is NOT registered in the runner's file list.

### Failing Tests: Root Cause Analysis

All 3 failures are in `snap-tests.lua` — all are test-side precision/expectation bugs, NOT code bugs:

1. **SnapBeat(2.2, 8, true) ~= 2.333** (line 70): Floating point precision — `7/3` can't be exactly `2.333` in float. The tolerance check on the next line passes.

2. **island: snap_enabled default true** (line 103): The store default is `false`, test asserts `true`.

3. **snap resize: duration 2.5, got 2.0** (line 267): Test author miscalculated — `4.2` correctly snaps to `4.0` (closer by 0.2 vs 0.3 to 4.5).

### Bug or Not? — Verdict

**NO — zero code bugs.** All three failures are test-side issues. No production code needs fixing.

### Coverage Gaps

- **state/persist.lua** (119 LOC) — **ZERO coverage**
- **core/api-guard.lua** (49 LOC) — **ZERO coverage**
- **state/preferences.lua** (81 LOC) — **Indirect coverage only**
- **state/preset-store.lua** (72 LOC) — **ZERO coverage**
- **core/slots.lua** (194 LOC) — **ZERO coverage** (GFX-bound)
- **25 ui/* modules** — **ZERO coverage** (GFX-bound)
- **state/piano-roll-store.lua** (426 LOC) — **Partial**: snap + undo tested, lasso/tool/velocity/selection NOT tested
- **barrel-backward-compat.lua** — **Orphan test**, not registered in runner

### Dependencies Required

**Nothing.** Lua 5.4.6 is sufficient. Zero external modules needed.

### What's Needed for Full Coverage

**Test bug fixes** (3 changes in snap-tests.lua):
1. Remove exact-equality check `SnapBeat(2.2, 8, true) == 2.333` (keep tolerance check)
2. Fix `snap_enabled` assertion to match store default (`false`)
3. Fix expected value from `2.5` to `2.0`

**Test additions needed** (non-GFX):
1. `test_api_guard.lua` — `CheckAPI`, `AssertAPIs`, `ClampIndex`
2. `test_persist.lua` — `persist.Load/Save`, `coerce()` — needs mock `GetExtState/SetExtState`
3. `test_preferences.lua` — 7 getter/setter pairs, `SyncFromState`, `TickSaveDebounce`
4. `test_preset_store.lua` — 8 field pairs, `ClearBrowserState`
5. Register `barrel-backward-compat.lua` in `run.lua`'s `test_names`

### Risks

- Misleading `force=true` comment in midi.lua line 55 — says "bypasses gate" but only bypasses ref-count, not existence check
- Barrel-backward-compat is invisible to runner — future refactors could break barrel exports silently
- No GFX UI test coverage — 25 UI modules blind
- Module cache coupling — stale state from previous test files can persist

### Ready for Proposal

**Yes.** Ready for proposal, specs, design, and implementation.
