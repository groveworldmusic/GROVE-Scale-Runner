# Archive: complete-test-suite

**Archived at**: 2026-05-13
**Source of truth**: `openspec/changes/archive/2026-05-13-complete-test-suite/` + Engram observations

## Summary

Closed the 3 biggest non-GFX coverage gaps in the test suite by creating 4 new test files (api-guard, persist, preferences, preset-store), fixing a misleading comment in `midi.lua`, and registering all new files in the test runner. The suite went from 574 PASS / 3 FAIL to 675 PASS / 0 FAIL — 100% green. Zero production logic was changed; all changes were test-only or comment-only.

## Scope Corrections vs Original Proposal

- **snap-tests-fix**: All 3 assertion bugs (lines 70, 103, 267) were already fixed in the file — no changes needed.
- **barrel-backward-compat registration**: Intentionally scoped out of tasks. Barrel coverage already exists in `snap-tests.lua:283-293` + `undo-tests.lua`. Refactoring barrel to use `helpers.check()` would be higher-risk (322 LOC, circular deps) for marginal gain.
- **Tasks.md naming mismatch**: Several nonexistent getter names listed (e.g. `SnapEnabled`) — actual 7 pairs match `preferences.lua` source.

## Engram Observation IDs

| Artifact | Observation ID | Topic Key |
|----------|---------------|-----------|
| exploration | #673 | `sdd/complete-test-suite/explore` |
| spec | #676 | `sdd/complete-test-suite/spec` |
| design | #678 | `sdd/complete-test-suite/design` |
| tasks | #680 | `sdd/complete-test-suite/tasks` |
| apply-progress | #681 | `sdd/complete-test-suite/apply-progress` |
| verify-report | #684 | `sdd/complete-test-suite/verify-report` |
| archive-report | *(this document)* | `sdd/complete-test-suite/archive-report` |

**Note**: The proposal artifact exists only as `proposal.md` in the archive directory — it was not persisted as a separate Engram observation.

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Inline mock for persist tests (local `extstate` table) | Follows existing `_vkey_string` / `time_precise` pattern. Lower blast radius than modifying `reaper.lua`. |
| Module cache isolation for preferences tests | `preferences.lua` has module-level closure state (`prefs_state`, `save_pending`). Requires `package.loaded["state.preferences"] = nil` before fresh `require()`. |
| Barrel file scoped out | Coverage exists elsewhere. Refactoring 322 LOC barrel for `helpers.check()` was disproportionate risk. |
| `ClampIndex(nil)` returns min (1), not nil | Code uses `math.floor(idx or min)` — `nil or min` evaluates to `min`. Correct behavior, confirmed by spec AG9. |

## Retrospective

### What Went Well
- **Exploration caught the right gaps**: analysis of coverage gaps was accurate and actionable.
- **Design decisions held up**: inline mock pattern, cache isolation, zero production changes — all matched reality.
- **100% green first try**: all 675 tests passed on first verification run. No regressions.
- **Comment fix actually mattered**: the misleading `force=true` comment in `midi.lua:55` was easy to overlook and could cause confusion about cleanup semantics.

### What Could Be Improved
- **Tasks.md contained nonexistent getter names**: Several references to `GetSnapEnabled()` etc. didn't match the actual `preferences.lua` API. Task authors should verify source before documenting getter names.
- **Spec TR1-TR3 became stale**: The barrel-registration spec requirements (TR1-TR3) remained in the spec after being scoped out of tasks. They should have been removed from the spec when the scope changed.
- **apply-progress.md was not produced**: The apply phase didn't create an `apply-progress.md` file. This is a gap in the SDD workflow that should be addressed.

### Delta Spec Status
The 4 new capabilities (api-guard-tests, persist-tests, preferences-tests, preset-store-tests) are **new test files created from scratch**. There were no existing main specs to merge into. The spec.md in the archive serves as the permanent record of these capabilities' requirements.

## Files Changed

| File | Action | LOC | Description |
|------|--------|-----|-------------|
| `tests/test_api_guard.lua` | Created | 66 | CheckAPI, AssertAPIs, ClampIndex — 20 checks |
| `tests/test_persist.lua` | Created | 82 | Load (canonical/legacy/missing), Save, coerce — 10 checks |
| `tests/test_preferences.lua` | Created | 131 | 7 round-trips, Init, SyncFromState, TickSaveDebounce — 31 checks |
| `tests/test_preset_store.lua` | Created | 129 | 9 field round-trips, ClearBrowserState, clamping, nil guards — 36 checks |
| `tests/run.lua` | Modified | 79 | Added 4 new test entries to `test_names` |
| `src/core/midi.lua` | Modified | 232 | Line 55: clarified `force=true` bypasses ref-count gate only |
