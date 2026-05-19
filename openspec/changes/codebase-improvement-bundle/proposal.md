# Proposal: Codebase Improvement Bundle

## Intent

9 tech debt items: fix view_offset lost-on-restart, remove ~300 LOC dead code, fix encoding rot in ~50% of files, invert core→UI dependency, deflate island.lua proxies, add note-store tests, decompose 880-LOC preset-browser.

## Scope

| # | Item | Effort |
|---|------|--------|
| 1 | view_offset_x/y → ui_store + persist.Load | Med |
| 2 | midi.lua: drop `require("ui.gfx-window")`, route via main.lua | Med |
| 3 | island.lua: drop ~35 pass-through proxies | Med |
| 4 | preset-browser.lua → sub-modules + barrel | High |
| 5 | views.lua: remove DrawSnapControls + DrawToolModeRow | Low |
| 6 | note-store.ProgressionEntryToPitch → midi.GetMidiNote | Low |
| 7 | Remove `use_legacy_tools` flag + handlers | Low |
| 8 | SPDX encoding: broken `í` → proper UTF-8 in ~30 files | Low |
| 9 | Tests for 6 pure note-store functions | Med |

**Out**: preset-browser rewrite, behavioral changes, new features.

## Capabilities

Pure refactor/bugfix. **New**: None. **Modified**: None.

## Approach

Order: 2 → 3 (midi infra before island dependent), then 1, 4, 9 (independent), then 5→6→7→8 (parallel). Each item = one commit.

## Affected Areas

`src/core/midi.lua`, `src/ui/gfx-window.lua`, `src/ui/island.lua`, `src/ui/views.lua`, `src/ui/midi-island/input.lua`, `src/state/note-store.lua`, `src/state/ui_store.lua`, `src/state/persist.lua`, `src/ui/preset-browser.lua` → `preset-browser/`, `tests/note-store-test.lua`, `src/**/*.lua` (~30 for encoding).

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| midi inversion breaks island toggle | Med | Manual test from keyboard + pads |
| encoding fix corrupts UTF-8 | Low | `git diff --binary`, re-test UI text |
| preset-browser import missed | Low | Grep all require sites before/after |

## Rollback Plan

Independent commits per item. `git revert <commit>` per item. Encoding fix: `git checkout -- src/` on commit before it.

## Dependencies

None.

## Success Criteria

- [ ] view_offset persists across REAPER restart
- [ ] midi.lua: zero `require("ui.*")` calls
- [ ] island.lua exports ≤ 35 (was ~70)
- [ ] preset-browser.lua is a barrel ≤ 20 LOC
- [ ] 6 note-store pure functions have passing tests
- [ ] `rg "DrawSnapControls\|DrawToolModeRow"` → 0 hits
- [ ] `ProgressionEntryToPitch` → delegates to midi.GetMidiNote
- [ ] `rg "use_legacy_tools"` → 0 hits
- [ ] Proper UTF-8 across all src/