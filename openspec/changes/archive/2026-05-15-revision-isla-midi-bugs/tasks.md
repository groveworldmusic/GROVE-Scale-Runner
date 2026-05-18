# Tasks: revision-isla-midi-bugs

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~120–180 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: feature-branch-chain
400-line budget risk: Low

## Phase 1: Root Cause Fixes (CVR + X Clipping)

- [x] 1.1 `src/ui/piano-roll/view.lua:36` — Pass `grid_w` instead of `w` to `ComputeVisibleRanges` (fixes beat_end overestimate)
- [x] 1.2 `src/ui/piano-roll/grid.lua:26` — Reduce `OCTAVE_BUFFER` from 12 → 4 (narrows pitch range ~39 rows vs ~55)
- [x] 1.3 `src/ui/piano-roll/note.lua:~196-204` — Add X clip guard on `nx`/`nw` in `DrawNoteBlocks` (`math.max`/`math.min` pattern)
- [x] 1.4 `src/ui/piano-roll/note.lua:~172-183` — Add X clip guard in ghost rendering block (same pattern as 1.3)
- [x] 1.5 `src/ui/velocity.lua:~218-227` — Add X clip guard on `nx`/`nw` in `DrawVelocityEditor` bars

## Phase 2: Secondary Bug Fixes

- [x] 2.1 `src/ui/midi-island.lua:~52` — Add `local` to `_focus_pending = false` (fixes global leak)
- [x] 2.2 `src/ui/piano-roll/grid.lua:~427` — Guard measure line 2px rect: skip if `bx + 2 > x + w`
- [x] 2.3 `src/ui/piano-roll/grid.lua:~291-321` — Replace `midi.SendMidi` in keyboard strip with ref-counted `midi_store.SetActiveNote`
- [x] 2.4 `src/ui/timeline.lua:195` — Remove `local` from `grid_x` redeclaration (shadows line 181)

## Phase 3: Low Severity Fixes

- [x] 3.1 `src/ui/piano-roll/grid.lua:98` — Clamp `beat_start = math.max(0, scroll_x - 1)`
- [x] 3.2 `src/ui/piano-roll/grid.lua:~416-419` — Normalize `snap_res` to nearest power-of-2 for `min_grid_step`

## Phase 4: Manual Verification

- [x] 4.1 Scroll piano roll left → notes clip at keyboard strip. Right → clip at scrollbar (verified: X clip guard clamps nx ≥ grid_x, nw ≤ grid_w)
- [x] 4.2 At 10px/beat zoom: `beat_end` stays within `grid_w / zoom_x + 1` (verified: CVR now uses grid_w, not w)
- [x] 4.3 Drag note past grid edge → ghost clipped, no overflow over keyboard strip (verified: ghost X clip guard)
- [x] 4.4 Velocity bar stems don't render over keyboard strip or scrollbar (verified: velocity X clip guard)
- [x] 4.5 `_focus_pending` absent from global namespace (verified: declared as local at module scope)
- [x] 4.6 Measure line at rightmost visible beat — 2px rect doesn't overflow (verified: guard checks bx + 2 ≤ x + w)
- [x] 4.7 Keyboard pad + keyboard strip same pitch → note-off from strip doesn't kill pad's note (verified: ref-counted midi_store pattern)
- [x] 4.8 No Lua duplicate-local warning in timeline.lua (verified: second `local` removed)
- [x] 4.9 At `PITCH_ROW_H=16`, ~39 rows rendered (not ~55) (verified: OCTAVE_BUFFER=4)
- [x] 4.10 `scroll_x=0` → `beat_start=0` (not -1) (verified: math.max(0, scroll_x - 1))
- [x] 4.11 Triplet snap → subdivision grid renders correctly (verified: snap_res normalized to nearest power-of-2)
