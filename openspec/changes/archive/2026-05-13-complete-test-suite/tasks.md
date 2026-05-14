# Tasks: complete-test-suite

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~310 (4 new test files + 1 comment line) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

> **Scope corrections (per design.md discovery)**: snap-tests-fix (3 assertions) already applied; barrel-backward-compat registration out of scope (coverage exists in snap-tests.lua 283-293 + undo-tests.lua). Replaced with 4 new test files + 1 comment fix.

---

## Phase 1: Mock Verification + Comment Fix

- [x] **T1.1 — Verify GetExtState/SetExtState stubs exist** (`tests/mock/reaper.lua`, P0)
  - Stubs already registered via `stub("GetExtState")` + `stub("SetExtState")` at lines 151-152. No changes needed.
  - persist test uses **inline override** (local `extstate` table) — mock infra supports this via `_vkey_string` / `time_precise` pattern.
  - Acceptance: both functions tracked via `make_mock_fn`, `reset_all_calls()` clears them.

- [x] **T1.2 — Fix midi.lua `force` comment** (`src/core/midi.lua`, line 55, P1)
  - Current: `-- Note-off: only send 0x80 when ref-count reaches 0 (or force=true bypasses gate)`
  - Change to: `-- Note-off: only send 0x80 when ref-count reaches 0 (or force=true bypasses ref-count gate only -- does NOT skip the cur=nil existence check)`
  - Acceptance: comment accurately clarifies `force` skips `cur <= 0` guard but NOT the `if cur then` check on line 57.

## Phase 2: New Test Files

- [x] **T2.1 — test_api_guard.lua** (`tests/test_api_guard.lua`, ~60 LOC, P0)
  - **Scenarios** (AG1–AG10, per spec): CheckAPI with APIExists, CheckAPI fallback (APIExists=nil), CheckAPI missing API returns false, AssertAPIs missing → MB call + false, AssertAPIs all present → true, AssertAPIs empty table → true, ClampIndex clamp max/min, ClampIndex nil value defaults, ClampIndex floor before clamp, ClampIndex degenerate min==max, ClampIndex negative values.
  - **Mock**: `reaper.APIExists` set/restored inline; `reaper.MB` tracked via existing stub.
  - **Setup**: none (pure Lua module, no Init needed).
  - **Pattern**: follows spec interface contracts (design.md lines 76-90).
  - **Acceptance**: all AG1–AG10 scenarios green.

- [x] **T2.2 — test_persist.lua** (`tests/test_persist.lua`, ~90 LOC, P0)
  - **Scenarios** (P1–P6, per spec): Load canonical key → coerced into state, Load legacy fallback + migration (canonical empty, legacy has value → SetExtState called with canonical ns + tostring'd value), Load missing key → keeps hardcoded default, Save → SetExtState with canonical namespace + persistent=true, coerce numeric string → number, coerce non-numeric string preserved, coerce empty string preserved, coerce nil edge.
  - **Mock**: inline override of `reaper.GetExtState` / `reaper.SetExtState` using local `extstate{}` table. Verify migration via `reaper.get_mock("SetExtState").calls[]`.
  - **Setup**: none (persist.lua is stateless — no module cache).
  - **Pattern**: follows design.md lines 94-104 (inline mock + restore).
  - **Acceptance**: all P1–P6 scenarios green; legacy migration verified via SetExtState call args.

- [x] **T2.3 — test_preferences.lua** (`tests/test_preferences.lua`, ~90 LOC, P0)
  - **Scenarios** (PR1–PR6, per spec): 7 getter/setter round-trips (RootIndex, ScaleIndex, Octave, ChordModeIndex, InversionIndex, InversionDirection, SubdivisionIndex), Init with defaults table, Init({}) keeps module defaults, SyncFromState reads 4 fields, TickSaveDebounce flushes pending saves (7 SetExtState calls), TickSaveDebounce no-op when no setter called.
  - **Mock**: needs `reaper.GetExtState`/`SetExtState` stubs (already exist). Module uses `persist.Save` which calls `reaper.SetExtState`.
  - **Setup**: `package.loaded["state.persist"] = nil; package.loaded["state.preferences"] = nil` before each fresh require (module-level `prefs_state{}` + `save_pending`).
  - **Pattern**: follows design.md lines 108-113 (cache isolation).
  - **Acceptance**: all PR1–PR6 scenarios green; TickSaveDebounce flushes all 7 keys exactly once.

- [x] **T2.4 — test_preset_store.lua** (`tests/test_preset_store.lua`, ~60 LOC, P0)
  - **Scenarios** (PS1–PS5, per spec): 8 field round-trips (CurrentDirectory, PresetRoot, PresetTree, PresetFiles, SelectedPresetIdx nil/number, BrowserScroll, BrowserError, Favorites, Bookmarks), Init({}) defaults, Init with current_directory + preset_root overrides, ClearBrowserState resets 5 browser fields (preserves preset_root/bookmarks/favorites), SetBrowserScroll clamps negative to 0, SetCurrentDirectory(nil) → "", SetPresetTree(nil) → {}.
  - **Mock**: none required (pure store — no reaper calls).
  - **Setup**: none (module-level `state{}` — no package cache needed since Init replaces all).
  - **Pattern**: follows test_stores.lua getter/setter round-trip style.
  - **Acceptance**: all PS1–PS5 scenarios green; ClearBrowserState preserves non-browser fields.
