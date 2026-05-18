# Tasks: MIDI Island Vertical Resize

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~3 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Static Analysis Sweep (Confirm no orphaned references)

- [x] 1.1 Grep all `ISLAND_CONTENT_H` references in `src/` — confirm exactly 2 sites (definition line 55 + usage line 208)
- [x] 1.2 Grep `layout.US(ISLAND_CONTENT_H)` — confirm single usage at line 208

## Phase 2: Implementation (1 file, 2 changes)

- [x] 2.1 Remove `local ISLAND_CONTENT_H = 14000` constant at `src/ui/midi-island.lua:55`
- [x] 2.2 Replace `local h = layout.US(ISLAND_CONTENT_H)` at `src/ui/midi-island.lua:208` with `local h = math.max(200, gfx.h - y - 4)`

## Phase 3: Static Verification (grep-only, no test runner)

- [x] 3.1 Grep for remaining `ISLAND_CONTENT_H` — confirm zero hits
- [x] 3.2 Grep for `layout.US(ISLAND_CONTENT_H)` — confirm zero hits
- [x] 3.3 Verify `MIN_ISLAND_H` constant (200) only exists at definition point

## Phase 4: Manual REAPER Verification

- [ ] 4.1 Stretch window vertically → piano roll grows (more pitch rows visible)
- [ ] 4.2 Shrink window near-minimum → island clamps at ~200px (no collapse)
- [ ] 4.3 Toggle velocity editor expand/collapse at different window heights
- [ ] 4.4 Toggle preset browser panel at different window heights — renders correctly
- [ ] 4.5 ToggleIsland (expand/collapse island) at different window heights — dimensions preserved (497/793)
- [ ] 4.6 Verify scale system unchanged — header buttons, islands, performance area maintain size
- [ ] 4.7 Verify scroll, zoom, note editing, undo/redo still functional
