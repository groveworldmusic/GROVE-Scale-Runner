# Proposal: Complete Test Suite

## Intent

Get the test suite to 100% green and close the 3 biggest non-GFX coverage gaps. No production code changes — only fixes to test assertions and new test files.

## Scope

### In Scope
1. Fix 3 snap-tests.lua assertion bugs (lines 70, 103, 267)
2. `test_api_guard.lua` — test CheckAPI, AssertAPIs, ClampIndex
3. `test_persist.lua` — test Load/Save/coerce (needs mock reaper.GetExtState/SetExtState)
4. `test_preferences.lua` — test all 7 getter/setter pairs + SyncFromState + TickSaveDebounce
5. `test_preset_store.lua` — test all 8 field pairs + ClearBrowserState
6. Register barrel-backward-compat.lua in run.lua's test_names
7. Fix misleading `force=true` comment in midi.lua line 55

### Out of Scope
- GFX UI modules (25 files) — need advanced GFX mocking
- core/slots.lua — GFX-bound, circular dep with components.lua
- piano-roll-store gaps (lasso, tool mode, velocity, selection)
- Auto-discovery of test files

## Capabilities

### New Capabilities
- `api-guard-tests`: Tests for core/api-guard.lua: CheckAPI, AssertAPIs, ClampIndex
- `persist-tests`: Tests for state/persist.lua: Load/Save/coerce with mock reaper
- `preferences-tests`: Tests for state/preferences.lua: getters/setters, SyncFromState, debounce
- `preset-store-tests`: Tests for state/preset-store.lua: field pairs, ClearBrowserState
- `test-runner-registration`: Update run.lua to include barrel-backward-compat.lua
- `snap-tests-fix`: Fix 3 precision/expectation bugs in snap-tests.lua
- `midi-comment-fix`: Clarify misleading `force=true` comment in midi.lua

### Modified Capabilities
None — no existing spec-level behavior changes.

## Approach

Fix-and-add: fix 3 snap assertions first, then add one test file at a time. Each follows existing patterns (require mocks, init stores, use helpers.check). Barrel-backward-compat gets registered last. Zero production logic changes.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| tests/snap-tests.lua | Modified | Fix 3 buggy assertions |
| tests/test_api_guard.lua | New | Test core/api-guard.lua |
| tests/test_persist.lua | New | Test state/persist.lua |
| tests/test_preferences.lua | New | Test state/preferences.lua |
| tests/test_preset_store.lua | New | Test state/preset-store.lua |
| tests/run.lua | Modified | Add barrel-backward-compat.lua |
| src/core/midi.lua | Modified | Fix `force` comment |
| tests/barrel-backward-compat.lua | Modified | Use io.write() for runner compat |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| persist.lua needs GetExtState mock — mock infra needs extension | Low | Add stubs to reaper.lua |
| preferences.lua module cache coupling | Low | Clear package.loaded in test setup |
| barrel-backward-compat uses own verify() — may not work with helpers.summary() | Low | Refactor to shared helpers or keep separate |

## Rollback Plan

Revert the 8 affected files. All changes are additive or test-assertion-only — zero risk to production behavior.

## Dependencies

None. Lua 5.4.6 is sufficient.

## Success Criteria

- [ ] `lua tests/run.lua` exits 0 with 100% PASS
- [ ] api-guard.lua has direct coverage for all 3 exported functions
- [ ] persist.lua has direct coverage for Load, Save, coerce
- [ ] preferences.lua has direct coverage for all getter/setter pairs
- [ ] preset-store.lua has direct coverage for all fields + ClearBrowserState
- [ ] barrel-backward-compat.lua runs as part of the test suite
