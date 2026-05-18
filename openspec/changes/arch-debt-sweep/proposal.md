# Proposal: arch-debt-sweep

## Intent

Three architectural debt items that have been fully explored and validated: (1) a missing save trigger for `view_offset_x/y` that leaves window position unsaved across sessions, (2) a half-finished refactor where `preset-browser.lua` (784 LOC) was split into 4 submodules but the monolith was never converted to a barrel, and (3) zero UI-layer tests despite 497 assertions in core+state covering pure-function modules that are fully testable.

## Scope

### In Scope

- **P1 — view_offset_x/y persistence**: ~12 LOC save trigger in `main.lua` using the identical pattern as `window_w/h` (line 333-340). Infrastructure already exists (`persist.lua PREF_KEYS`, `ui_store` getters/setters, position captured every frame).
- **P2 — Preset browser barrel refactor**: Replace 784 LOC monolith with ~120 LOC barrel that re-exports from the 4 existing submodules (`io.lua`, `folder.lua`, `main.lua`, `preset-list.lua`). Normalize any API surface mismatches between inline functions and submodule exports.
- **P3 — UI tests for untestable modules**: ~155 new `check()` assertions across 4 test files targeting pure functions in `piano-roll/grid.lua`, `note-store.lua`, `preset-browser/io.lua`, and `piano-roll/interaction/drag.lua`. Add to `test_names` in `tests/run.lua`. Zero new mocks needed.

### Out of Scope

- island.lua split (A2) — already validated as complete: preset browser state extracted to `preset-store.lua`, undo/redo proxies in `note-store.lua`. Remaining ~30 LOC proxies not worth the caller churn.
- Non-pure UI test coverage (e.g. rendering, event dispatch) — requires mock infrastructure not yet built.
- Any behavioral or spec-level changes — all 3 proposals are pure refactors or test additions.

## Capabilities

### New Capabilities

None — all 3 proposals are internal quality improvements (persistence bugfix, barrel refactor, test addition) with no spec-level behavior change.

### Modified Capabilities

None — no existing specs describe window position persistence, internal module structure, or UI test coverage requirements.

## Approach

**P1** (trivial): Insert save block in `main.lua` after line 364, mirroring `persist.PersistConfigKeys({"window_w", "window_h", ...})` but using `view_offset_x/y` from `config.state`. Write SAVE position from `ui_store.GetWindowPosX/Y()` every frame when changed.

**P2** (replace monolith): Model after `piano-roll.lua` barrel (93 LOC) and `views.lua` barrel (73 LOC). The barrel will `require()` each submodule and re-export their public functions. Where the monolith has inline duplicates with different behavior (e.g. bare `dofile()` vs `safe_loader.LoadSandboxed()`), the barrel uses the **submodule version**. API surface must be checked for callers outside the monolith — grep all `preset-browser.` callsites before writing.

**P3** (test files): One test file per module, following `tests/snap-tests.lua` conventions — pure functions, `local check = require("tests.helpers").check`, no mocks. Add each file to the `test_names` table in `tests/run.lua`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/main.lua` | Modified (P1) | ~12 LOC save trigger for view_offset_x/y |
| `src/ui/preset-browser.lua` | Rewritten (P2) | 784 LOC → ~120 LOC barrel |
| `src/ui/preset-browser/` submodules | Possibly modified (P2) | API normalization if surface mismatch found |
| `tests/grid-tests.lua` | New (P3) | ~50 assertions for piano-roll/grid.lua pure functions |
| `tests/note-store-tests.lua` | New (P3) | ~70 assertions for note-store.lua helpers |
| `tests/io-tests.lua` | New (P3) | ~15 assertions for preset-browser/io.lua pure functions |
| `tests/drag-tests.lua` | New (P3) | ~20 assertions for drag.lua edge-detection |
| `tests/run.lua` | Modified (P3) | Add 4 test names to runner |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| P2 breaks callers if API surface differs between inline and submodule exports | Med | Grep all `preset-browser.` refs before barrel; diff each inline function vs submodule |
| P3 pure functions may have hidden GFX/REAPER dependencies not visible from signatures | Low | Verify each candidate function has no `gfx.*` or `reaper.*` calls before writing tests |
| P1 writes position every frame — possible perf concern | Low | Same pattern as `window_w/h` already writing every frame; trivially gated on `gfx.dock(-1) == 0` |
| Merge conflict with concurrent preset-browser work | Low | P2 isolated to the rewrite file; conflicts unlikely given project maturity |

## Rollback Plan

1. **P1**: Single-line revert of the save trigger block in `main.lua` — no side effects.
2. **P2**: Keep the original `preset-browser.lua` committed; if barrel has issues, revert to monolith. Submodules remain unchanged so zero data loss.
3. **P3**: New files only — no rollback needed. Remove from `test_names` if they fail.

All 3 are individually revertible. No schema or data migrations involved.

## Dependencies

- P1: None — `persist.lua` and `ui_store` already have the keys.
- P2: Must verify no other files have taken a hard dependency on internal (non-exported) functions of the monolith.
- P3: `tests/helpers.lua` must expose `check()` — already confirmed.

## Success Criteria

- [ ] P1: Launch script, reposition window, close. Reopen — window position restored from ExtState.
- [ ] P2: All user-facing preset browser functions (save, load, navigate, rename) produce identical behavior. `grep "preset-browser\."` shows barrel exports match callers.
- [ ] P3: All 4 new test files pass under `tests/run.lua`. Combined ≥155 `check()` calls across them.
