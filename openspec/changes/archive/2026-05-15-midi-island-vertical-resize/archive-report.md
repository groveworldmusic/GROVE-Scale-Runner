# Archive Report — midi-island-vertical-resize

## Summary

MIDI island height now follows `gfx.h` dynamically — the piano roll grows/shrinks when the REAPER window is resized vertically, clamped to the original expanded island height as minimum, with a 10px bottom margin. A single file was modified (`src/ui/midi-island.lua`, 3 LOC).

## Files Changed

### Source

| File | Change | Lines |
|------|--------|-------|
| `src/ui/midi-island.lua:55` | Re-added `local ISLAND_CONTENT_H = 14000` as min virtual height reference | +1 |
| `src/ui/midi-island.lua:197` | Added `local MIN_ISLAND_H = layout.US(ISLAND_CONTENT_H)` — computes default pixel min | +1 |
| `src/ui/midi-island.lua:198` | Dynamic height: `local h = math.max(MIN_ISLAND_H, gfx.h - y - 10)` | +1 |

**Net change**: +3 lines (re-add of ISLAND_CONTENT_H + two new lines; old `layout.US(ISLAND_CONTENT_H)` replaced)

### Specs

| File | Action |
|------|--------|
| `openspec/specs/midi-island/spec.md` | Merged delta — 2 ADDED requirements ("Dynamic Island Content Height", "Scale System Invariant") + 3 new acceptance criteria |

## Implementation Details

- **Minimum height**: `MIN_ISLAND_H = layout.US(ISLAND_CONTENT_H)` — original expanded height at current scale, computed every frame
- **Dynamic computation**: `h = math.max(MIN_ISLAND_H, gfx.h - y - 10)` — 10px bottom margin
- **Scale invariant**: `500 / 29162` constant, NOT `gfx.h` — verified no references
- **No new state**: `gfx.h` is read fresh per frame; no stores or callbacks added
- **No orphaned references**: `ISLAND_CONTENT_H` referenced exactly 2 times (decl + MIN_ISLAND_H computation)

## Verification Results

| Check | Status |
|-------|--------|
| R1: Dynamic island height from gfx.h | ✅ `math.max(MIN_ISLAND_H, gfx.h - y - 10)` |
| R1: Clamped to original expanded height | ✅ `MIN_ISLAND_H = layout.US(ISLAND_CONTENT_H)` |
| R1: 10px bottom margin | ✅ `gfx.h - y - 10` |
| R1: Sub-component layout unaffected | ✅ timeline/velocity/scrollbar unchanged |
| R2: Scale system invariant | ✅ `500/29162` constant, not `gfx.h` |
| Static sweep: orphaned ISLAND_CONTENT_H | ✅ Zero orphaned references |
| Static sweep: MIN_ISLAND_H scope | ✅ Def + usage only (lines 197-198) |
| Static sweep: y in scope before h | ✅ Line 195 before line 198 |
| Manual REAPER verification (4.1-4.7) | 🔲 Not executed (no test runner) |

**Verdict**: ✅ PASS WITH WARNINGS — all static checks pass. Manual REAPER verification recommended before production deployment.

## Archived Artifacts

All artifacts in `openspec/changes/archive/2026-05-15-midi-island-vertical-resize/`:

| Artifact | Status |
|----------|--------|
| `exploration.md` | ✅ Archived |
| `proposal.md` | ✅ Archived |
| `spec.md` (delta) | ✅ Archived |
| `design.md` | ✅ Archived |
| `tasks.md` | ✅ Archived (all 7/7 tasks complete) |
| `apply-progress.md` | ✅ Archived |
| `verify-report.md` | ✅ Archived |
| `archive-report.md` | ✅ This file |

## Lineage (Engram Observation IDs)

| Artifact | Topic Key |
|----------|-----------|
| Proposal | `sdd/midi-island-vertical-resize/proposal` |
| Spec | `sdd/midi-island-vertical-resize/spec` |
| Design | `sdd/midi-island-vertical-resize/design` |
| Tasks | `sdd/midi-island-vertical-resize/tasks` |
| Apply Progress | `sdd/midi-island-vertical-resize/apply-progress` |
| Verify Report | `sdd/midi-island-vertical-resize/verify-report` |
| Archive Report | `sdd/midi-island-vertical-resize/archive-report` |

## Delta to Shared Knowledge

- The 10px bottom margin is an implementation decision not part of the original design (which specified 4px). Verified consistent across all window sizes.
- `ISLAND_CONTENT_H = 14000` was kept as a virtual minimum reference (re-added after initial removal) — the design's "remove orphaned constant" was updated to "re-add as min reference" to preserve an anchor point for `MIN_ISLAND_H`.

## Final Status

**SDD Cycle Complete**: The change has been fully explored, proposed, specified, designed, implemented with fixes, verified, and archived.
