# Apply Progress: revision-isla-midi-bugs

## Status
11/11 tasks complete. Ready for verification.

## Phase 1: Root Cause Fixes (CVR + X Clipping)

- [x] 1.1 `view.lua:36` — Changed `w` → `grid_w` in CVR call so `beat_end` doesn't overestimate visible beats
- [x] 1.2 `grid.lua:26` — Reduced `OCTAVE_BUFFER` from 12 → 4 (~55 rows → ~39 rows)
- [x] 1.3 `note.lua:206-208` — Added X clip guard: `clip_nx = math.max(x, floor(nx))`, `clip_nw = math.max(1, min(nw, x + w - clip_nx))`
- [x] 1.4 `note.lua:178-180` — Same X clip guard for ghost note rendering during drag
- [x] 1.5 `velocity.lua:223-225` — Same X clip guard for velocity bars (bounds: `grid_x` to `grid_x + grid_w`)

## Phase 2: Secondary Bug Fixes

- [x] 2.1 `midi-island.lua:55` — Added `local _focus_pending = false` declaration (was leaking to global namespace)
- [x] 2.2 `grid.lua:448-449` — Changed measure line guard from `bx <= x + w` to `bx + 2 <= x + w` (2px rect overflow fix)
- [x] 2.3 `grid.lua:291-338` — Replaced `midi.SendMidi` with direct `midi_store.SetActiveNote` + `reaper.StuffMIDIMessage` ref-counted pattern. Added `ReleasePitch()` helper to avoid code duplication.
- [x] 2.4 `timeline.lua:195-196` — Removed `local` from `grid_x`/`grid_w` redeclarations (shadowed originals at lines 181-182)

## Phase 3: Low Severity Fixes

- [x] 3.1 `grid.lua:98` — Changed `beat_start = scroll_x - 1` to `math.max(0, scroll_x - 1)`
- [x] 3.2 `grid.lua:437-440` — Normalized `snap_res` to nearest power-of-2 before computing `min_grid_step = 4 / norm`

## Phase 4: Manual Verification (Static Analysis)

- [x] 4.1 Notes clip at keyboard strip — X clip guard clamps nx to ≥ grid_x
- [x] 4.2 beat_end in bounds — CVR passes grid_w, not w
- [x] 4.3 Ghost notes clip — Same X clip guard pattern applied
- [x] 4.4 Velocity bars clip — Clip guard uses grid_x/grid_w bounds
- [x] 4.5 No global leak — `_focus_pending` declared as `local`
- [x] 4.6 Measure lines don't overflow — Guard checks bx + 2 ≤ x + w
- [x] 4.7 Ref-counted notes — Keyboard strip uses `midi_store.SetActiveNote` pattern
- [x] 4.8 No duplicate locals — Second `local` removed from grid_x, grid_w
- [x] 4.9 ~39 rows — OCTAVE_BUFFER=4 (was 12)
- [x] 4.10 beat_start ≥ 0 — math.max(0, scroll_x - 1)
- [x] 4.11 Triplet snap — Normalized to power-of-2

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `src/ui/piano-roll/view.lua` | Modified | CVR call: `w` → `grid_w` (line 37) |
| `src/ui/piano-roll/grid.lua` | Modified | OCTAVE_BUFFER 12→4 (26), beat_start clamped (98), ref-counted keyboard strip (291-338), measure line guard (448), snap_res normalization (437-440) |
| `src/ui/piano-roll/note.lua` | Modified | X clip on actual notes (206-208) + ghost notes (178-180) |
| `src/ui/velocity.lua` | Modified | X clip on velocity bars (223-225) |
| `src/ui/midi-island.lua` | Modified | Added `local _focus_pending` (55) |
| `src/ui/timeline.lua` | Modified | Removed duplicate `local` from grid_x/grid_w (195-196) |

## Deviations from Design
None — implementation matches design.md exactly.

## Issues Found
None.

## Workload / PR Boundary
- Mode: single PR
- Estimated review budget impact: ~130-150 lines
- Chained PRs: No (size within 400-line budget)
