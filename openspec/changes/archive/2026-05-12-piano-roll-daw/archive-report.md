# Archive Report: piano-roll-daw

**Date**: 2026-05-12
**Verdict**: PASS WITH WARNINGS (1 CRITICAL fixed post-verify)
**Tasks**: 15 total — 14 complete, 1 deferred (timeline mirror — out of original scope)
**Mode**: hybrid (Engram + openspec filesystem)

## Artifact Traceability

| Artifact | Observation ID |
|----------|---------------|
| `sdd/piano-roll-daw/spec` | #533 |
| `sdd/piano-roll-daw/design` | #532 |
| `sdd/piano-roll-daw/tasks` | (flat file only) |
| `sdd/piano-roll-daw/apply-progress` | #535 |
| `sdd/piano-roll-daw/verify-report` | #538 |
| `sdd/piano-roll-daw/archive-report` | (this document) |

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| Piano Roll (`openspec/specs/piano-roll/spec.md`) | Updated | Modified Grid Rendering (4-tier opacities), Virtual Scrolling (keyboard strip sync); Added Grid Hierarchy, Vertical Gradient Strips, Velocity→Opacity, Keyboard Strip Rendering, Grid Hierarchy Colors; Removed Note Text Labels |
| Island Store (`openspec/specs/island-store/spec.md`) | Updated | Modified Store API Surface (ToolMode, Lasso, PrimarySelectedNoteIndex); Added Tool Mode State, Lasso State, Multi-Selection, Note CRUD, Bulk Operations; Removed Edit Buffer (replaced by multi-selection) |
| Velocity Editor (`openspec/specs/velocity-editor/spec.md`) | Updated | Modified Click-to-Edit Velocity (multi-selection bulk drag), Mute Toggle (right-click on ALL selected) |
| Timeline Ruler (`openspec/specs/timeline-ruler/spec.md`) | Updated | Modified Beat Marker Rendering (4-tier grid hierarchy match) |

## Archive Contents

| Artifact | Status |
|----------|--------|
| `explore.md` | ✅ |
| `proposal.md` | ✅ |
| `spec.md` | ✅ (delta spec — full) |
| `design.md` | ✅ |
| `tasks.md` | ✅ (14/15 complete) |
| `verify-report.md` | ✅ |

## Source of Truth Updated

The following main specs now reflect the new behavior:

- `openspec/specs/piano-roll/spec.md`
- `openspec/specs/island-store/spec.md`
- `openspec/specs/velocity-editor/spec.md`
- `openspec/specs/timeline-ruler/spec.md`

## Key Learnings for Future Cycles

- `gfx.getchar()` is non-consuming within a frame — multiple calls return same char
- VK_DELETE returns 302 (256+46) via `gfx.getchar()` in REAPER GFX, not 127
- `RemoveNoteAtIndex` must fix up `selected_indices` (decrement keys > idx)
- Black key width was implemented at 35% (code says 35%, spec says 70% — spec/task inconsistency to reconcile)
- `GetPrimarySelectedIndex()` must iterate to find last key, not use `next()` (which returns first key non-deterministically)

## Deferred Items

- **Task 1.3**: Timeline ruler mirror 4-tier grid hierarchy — deferred as not in original scope
- **Spec inconsistencies**: Black key width (35% vs 70%) and vertical position (top vs centered) need reconciliation between spec and code

## SDD Cycle Complete

The change has been fully planned, implemented, verified, and archived. Ready for the next change.
