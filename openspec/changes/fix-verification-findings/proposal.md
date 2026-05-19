# Proposal: fix-verification-findings

## Intent

Clean up technical debt and bugs identified during the verification of the `codebase-improvement-bundle` change to bring the codebase to the desired architectural state (Clean/Modular/Tested).

## Scope

### In Scope
- **Fix Unit Tests**: Correct assertions and sparse table handling in `tests/test_note_store.lua`.
- **Refactor Preset Browser**: Move all logic from `src/ui/preset-browser.lua` into its sub-modules (`io.lua`, `folder.lua`, `preset-list.lua`) and convert the main file into a thin barrel re-exporter.
- **De-inflate Island Store**: Remove note and selection proxies from `src/state/island.lua` and retarget all consumers to use `note_store` or `preset_store` directly.

### Out of Scope
- Any new features.
- Refactoring other modules.
- Fixing bugs in the existing UI logic (unless they are directly caused by these refactors).

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- None

## Approach

Execute fixes in the following order to maintain stability:

1. **Phase 1: Fix Unit Tests**: Ensures `note-store` logic is verified before structural changes.
2. **Phase 2: Refactor Preset Browser**: Cleans up the UI layer and reduces duplication.
3. **Phase 3: De-inflate Island Store**: Cleans up the state layer and removes redundant proxies.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `tests/test_note_store.lua` | Modified | Fix logic errors and sparse table handling |
| `src/ui/preset-browser.lua` | Modified | Convert to barrel |
| `src/ui/preset-browser/io.lua` | Modified | Move logic here |
| `src/ui/preset-browser/folder.lua` | Modified | Move logic here |
| `src/ui/preset-browser/preset-list.lua` | Modified | Move logic here |
| `src/state/island.lua` | Modified | Remove note/selection proxies |
| `src/ui/midi-island.lua` | Modified | Retarget consumers |
| `src/ui/preset-browser.lua` | Modified | Retarget consumers |
| `src/ui/piano-roll/interaction/handlers.lua` | Modified | Retarget consumers |
| `src/ui/velocity.lua` | Modified | Retarget consumers |
| `src/ui/piano-roll/clipboard.lua` | Modified | Retarget consumers |
| `src/main.lua` | Modified | Retarget consumers |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| **Consumer Breakage**: Retargeting many files might miss some calls. | Medium | Thoroughly grep for removed proxies and all consumer patterns. |
| **Regression in logic**: Moving logic between files might introduce bugs. | Low | Maintain high-coverage unit tests (Phase 1 fixes the test baseline). |
| **Side effects in island.lua**: Some proxies might have extra logic (e.g. clear selection). | Medium | Carefully verify proxy logic before removal and replicate if necessary. |

## Rollback Plan

1. **Undo tests change**: `git checkout tests/test_note_store.lua`
2. **Undo preset-browser refactor**: `git checkout src/ui/preset-browser.lua src/ui/preset-browser/`
3. **Undo island de-inflation**: `git checkout src/state/island.lua` and consumer files.

## Dependencies

- `note-store.lua`, `preset-store.lua`, `ui_store.lua` must be stable.

## Success Criteria

- [ ] `tests/test_note_store.lua` passes all tests.
- [ ] `src/ui/preset-browser.lua` is a thin barrel re-exporting sub-modules.
- [ ] `src/state/island.lua` contains no note or selection proxies.
- [ ] All consumers are correctly retargeted and the UI works as expected.
