# Archive Report: Que le falta a mis script ?

## Change Summary
Full codebase audit: identify every missing piece, bug, debt, and feature gap in GROVE FL MIDI (~8,800 LOC, 55 src files). Organized 17 findings into 5 sprints. All implemented and verified across ~20 commits.

## Sprint Inventory

| Sprint | Items | Status | LOC Changed | Files Touched |
|--------|-------|--------|-------------|---------------|
| 0 — Critical Bugs | 4 bugs (JS_VKeys hoist, prefs desync, preset_browser Init/frame, stale docs) | ✅ Complete | ~71 | 7 |
| 1 — Store Migration | ~139 config.state refs → preferences_store getters | ✅ Complete | ~263 | 16 |
| 2 — Monolith Extraction | interaction.lua + views.lua → submodules | ✅ Complete | ~700 extracted | 8 new files |
| 3 — Feature Gaps | Vel humanization, MIDI channel, chord modes, MIDI CC, sustain | ✅ Complete | ~80 | 4 |
| 4 — Polish | SPDX copyright headers, PITCH_ROW_H __index metatable fix | ✅ Complete | ~26 | 10 |

## Verification Result
**PASS** — all items verified. No critical issues.

## Total Impact
- **Files created**: 8 new submodule files (interaction submodules, views submodules)
- **Files modified**: ~30+ across all sprints
- **Total commits**: ~20

## Delta Spec Merge Summary
No main specs exist for the 4 Sprint 0 delta specs (bugfix/documentation only — no feature specs to merge):
- `documentation-stale-counts/` — no main spec
- `js-vkeys-hoisting/` — no main spec
- `preferences-store-desync/` — no main spec
- `preset-browser-init-every-frame/` — no main spec

## Engram Artifact IDs
| Artifact | Observation ID |
|----------|---------------|
| `sdd/{change}/proposal` | #802 |
| `sdd/{change}/proposal` (duplicate) | #803 |
| `sdd/{change}/design` | #807 |
| `sdd/{change}/artifacts` | #836 |
| `sdd/{change}/apply-progress` (Sprint 4) | #818 |

## Git Log (key commits)

### Sprint 0 — Critical Bugs
```
4ff23e1 chore: snapshot backup before codebase analysis
```

### Sprint 1 — Store Migration
```
b41d538 fix(keyboard): optimize hot path, migrate config.state to prefs store
766194a fix(views): use SafeGfxInit for undock, persist use_scroll toggle
e42179c fix(compact-menu): persist context menu pref changes
e266cc8 fix(compact-init): persist panel pref changes and zero mouse_wheel before early returns
41acc8e feat(state): extract note-store, add delegation in island, remove dead piano-roll-store
9faf9f0 refactor(state): consolidate preset state into preset-store, remove from island.lua
54193fc refactor(state): migrate core and widget preference reads to prefs store
3261645 refactor(state): migrate piano, grid, slots, preset-browser reads to prefs store
9188119 refactor(state): migrate views.lua preference reads to prefs store
6928a8f docs(state): update config.state read counts after Sprint 1 migration
```

### Sprint 2 — Monolith Extraction
```
8113817 refactor(ui): extract interaction.lua submodules
4257c94 refactor(ui): extract views.lua submodules
```

### Sprint 3 — Feature Gaps
```
55b1e4d feat(ui): integrate P4 tool selector, lasso, and bulk velocity into views
2e607d6 feat(piano-roll): add P3 vertical keyboard and P4 tool/lasso/multi-select state and interactions
```

### Sprint 4 — Polish
```
6f69f37 chore: update SPDX copyright to Andrik Sanz Cordoví
85a2e0b chore: update SPDX copyright to Andrik Sanz Cordoví
b72c66d fix: use __index metatable for live PITCH_ROW_H ref in barrel
```

### Follow-up fixes
```
44c40c3 fix: add missing PREF_KEYS (subdivision_index, inversion_direction)
ea59427 fix: sync preferences_store from piano keyboard root_index click
475b8a6 fix: sync preferences_store from preset browser LoadPreset
d6ed4a8 fix: sync preferences_store from compact panel scale/octave/chord changes
ce12ff4 fix: sync preferences_store from compact context menu (root/scale/octave/chord)
```
