# Tasks: Click / Lasso / Selection Fixes

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~21 (net +17) |
| 400-line budget risk | Low |
| Chained PRs recommended | No (~21 lines, single-PR safe) |
| Delivery strategy | auto-chain (as instructed) |
| Chain strategy | feature-branch-chain (as instructed) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: feature-branch-chain
400-line budget risk: Low

**Note**: At ~21 net lines across 7 files, splitting into chained PRs is disproportionate. Recommend `size:exception` — single PR to `main`. Tasks below are ordered for apply batching regardless.

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | S1: Fix lasso finalization order | PR 1 | 1 file, 6 lines (3 del + 3 add) |
| 2 | S2 + S3: MainLoop dirty flag + bitmask | PR 2 | 1 file, 2 lines |
| 3 | S4: ConsumeMouseClick across 5 files | PR 3 | 5 files, 13 one-line adds |

## Phase 1: S1 — Reorder stale lasso guard (CRITICAL)

- [x] 1.1 Move stale guard block (lines 215–217) in `src/ui/midi-island.lua` to immediately after lasso finalization block (after line 573)
- [x] 1.2 Verify: `island_store.GetLassoActive()` is not referenced before the move (no stale reference issues)
- [ ] 1.3 Verify manual: lasso drag → mouse-up → notes inside rect selected via `GetNotesInRect`

## Phase 2: S2 + S3 — MainLoop dirty flag & bitmask (HIGH + LOW, same file)

- [x] 2.1 In `src/main.lua`, add `if island_store.GetLassoActive() then gfx_needs_redraw = true end` after line 278 (after PageOverrideTimer, before prev_dock)
- [x] 2.2 In `src/main.lua` line 265, change `ui_store.GetLastMouseCap() == 0` to `(ui_store.GetLastMouseCap() & 1) == 0`
- [ ] 2.3 Verify: dirty flag fires during lasso drag; bitmask detects left-click rising edge with right button held

## Phase 3: S4 — ConsumeMouseClick additions (MEDIUM)

- [x] 3.1 Add `ui_store.ConsumeMouseClick()` after 9 action handlers in `src/ui/views.lua` (lines 347, 369, 423, 461, 538, 556, 648, 667, 686) — do NOT add to PressOverlay-only sites (338, 356, 385, 399, 414)
- [x] 3.2 Add `ui_store.ConsumeMouseClick()` after `midi.TriggerChord` in `src/ui/pads.lua` line 141
- [x] 3.3 Add `ui_store.ConsumeMouseClick()` after `preferences_store.SetRootIndex` in `src/ui/piano.lua` line 163
- [x] 3.4 Add `ui_store.ConsumeMouseClick()` after `gfx.showmenu` in `src/ui/dropdown.lua` line 65
- [x] 3.5 Add `ui_store.ConsumeMouseClick()` after `SetCurrentPage(i)` in `src/ui/paginator.lua` line 39
- [ ] 3.6 Verify: each handler fires once per click — no double-fire on buttons, pads, piano, dropdown, or paginator

## Rollback Per Task

| Task | Rollback |
|------|----------|
| 1.x | Move stale guard block back to its original position |
| 2.1 | Remove the added dirty-flag line |
| 2.2 | Revert `& 1) == 0` back to `== 0` |
| 3.1–3.5 | Remove each `ConsumeMouseClick()` line added |
