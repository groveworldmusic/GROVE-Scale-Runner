# Tasks: Sprint 0 — Critical Bugs

## Breakdown

| Task | Focus | Files | LOC | Risk |
|------|-------|-------|-----|------|
| T1 | JS_VKeys hoisting — verify already done | keyboard.lua | 0 | Low |
| T2a | prefs.Set*() sync — views.lua (21 sites) | views.lua | ~22 | Medium |
| T2b | prefs.Set*() sync — compact-menu.lua (4 sites) | compact-menu.lua | ~5 | Low |
| T2c | prefs.Set*() sync — compact-init.lua (3 sites) | compact-init.lua | ~4 | Low |
| T3 | preset_browser.Init() per-frame guard | midi-island.lua | ~10 | Low |
| T4 | Documentation stale counts (do LAST) | 4 × AGENTS.md | ~30 | Low |
| **Total** | **6 tasks, 7 files** | | **~71** | |

## Implementation Order

```
T1 (verify) → T2a + T2b + T2c + T3 (parallel, independent) → T4 (last)
```

## Review Workload Forecast

- **Estimated changed lines**: ~71
- **400-line budget risk**: Low
- **Chained PRs recommended**: No
- **Decision needed before apply**: No
