# Design: Revisión de bugs en isla MIDI

## Technical Approach

Dual-strategy: (1) fix root cause — `ComputeVisibleRanges` overestimates `beat_end` by using full width `w` instead of `grid_w`, making note/ghost/bar renderers believe there's more visible space than there is; (2) add X clipping guards in all note rendering functions as belt-and-suspenders against any remaining overflow. Remaining 7 bugs are localized 1-3 line fixes.

## Architecture Decisions

### Decision: X Clipping Strategy

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `gfx.clip_rect()` imaginary | REAPER GFX has NO clip region API | ❌ Not available |
| Manual `math.max`/`math.min` on nx/nw | Proven by existing Y clipping pattern, 0 overhead | ✅ **Adopted** |

Pre- and post-clip: clamp `nx` to `>= grid_x` and `nx + nw` to `<= grid_x + grid_w`. Same pattern as Y clipping in `note.lua:203-204`.

### Decision: ComputeVisibleRanges Fix

Pass `grid_w` from `view.lua` instead of `w` to `ComputeVisibleRanges`. The `w` param is only used to compute `beat_end` (line 99). Fix at call site — one line change.

### Decision: OCTAVE_BUFFER Reduction

Reduce from 12 → 4. At PITCH_ROW_H=16, this drops 192px→64px of extra pitch range per frame (55 rows→39). Buffer only needs to cover sub-pixel scroll + 1-2 rows for edge stability; the existing Y clip guard handles anything beyond.

## Bug List

| # | Loc (file:line) | Root Cause | Fix | Ripple |
|---|-----------------|------------|-----|--------|
| 1 | `note.lua:196-207` | No X clip on `nx`/`nw` | Add `nx = math.max(x, nx)` + `nw = math.min(nw, x + w - nx)` | None |
| 2 | `view.lua:36` | Passes `w` (incl. LABEL_W) to CVR | Change to `grid_w` | beat_end shrinks ~3 beats — correct |
| 3 | `note.lua:172-183` | No X clip in ghost rendering | Same X clip as B1 | None |
| 4 | `velocity.lua:218-227` | No X clip on `nx`/`nw` | Same X clip pattern | None |
| 5 | `midi-island.lua:174,181,213,214` | Missing `local` on `_focus_pending` | Add `local _focus_pending = false` at line ~52 | None |
| 6 | `grid.lua:427` | 2px rect overflow at `bx == x + w` | Check `bx + 2 <= x + w` | None |
| 7 | `grid.lua:291-321` | Direct `midi.SendMidi` in keyboard strip | Use `midi_store.SetActiveNote` ref-counted pattern | None |
| 8 | `timeline.lua:195` | `local grid_x` shadows line 181 | Remove `local`, keep assignment | None |
| 9 | `grid.lua:26` | OCTAVE_BUFFER = 12 | Change to `m.OCTAVE_BUFFER = 4` | pitch_start/pitch_end ranges narrow |
| 10 | `grid.lua:98` | `beat_start = scroll_x - 1` unclamped | `math.max(0, scroll_x - 1)` | None |
| 11 | `grid.lua:416-419` | `4 / snap_res` only works for power-of-2 | Normalize snap_res to nearest power-of-2 | None |

## File Changes

| File | Action | Changes |
|------|--------|---------|
| `src/ui/piano-roll/view.lua` | Modify | Line 36: `w` → `grid_w` in CVR call |
| `src/ui/piano-roll/note.lua` | Modify | X clip guards in DrawNoteBlocks (lines ~196-204) + ghost (lines ~172-183) |
| `src/ui/piano-roll/grid.lua` | Modify | B6 (line 427 guard), B9 (OCTAVE_BUFFER 12→4), B10 (clamp beat_start), B11 (normalize snap_res), B7 (ref-counted keyboard) |
| `src/ui/velocity.lua` | Modify | X clip guard in DrawVelocityEditor (lines ~218-227) |
| `src/ui/midi-island.lua` | Modify | Add `local _focus_pending = false` at line ~52 |
| `src/ui/timeline.lua` | Modify | Line 195: remove `local` from `grid_x` redeclaration |

## Code Snippets (non-obvious patterns)

### X Clip Guard (applied in note.lua, velocity.lua)
```lua
-- After computing nx, nw:
local clip_nx = math.max(x, nx)
local clip_nw = math.max(1, math.min(nw, x + w - clip_nx))
-- Use clip_nx, clip_nw for all drawing calls
```

### Grid Step Normalization (grid.lua)
```lua
if snap_res > 0 then
    local norm = 1
    while norm * 2 <= snap_res do norm = norm * 2 end
    min_grid_step = 4 / norm
end
```

## Testing Strategy

No test runner exists. Manual verification checklist:

| Bug | Verification Steps |
|-----|-------------------|
| B1 | Scroll piano roll left → notes stop at keyboard strip edge. Scroll right → notes stop at scrollbar |
| B2 | At low zoom (10px/beat), beat_end should not exceed grid_w/zoom_x + 1 |
| B3 | Drag a note left past grid edge → ghost clipped, not over keyboard strip |
| B4 | Add notes and check velocity bar stems don't render over keyboard strip or scrollbar |
| B5 | Run `for k,v in pairs(_G) do print(k) end` → `_focus_pending` absent |
| B6 | Measure line at rightmost visible beat → 2px rect doesn't overflow |
| B7 | Trigger same pitch via keyboard pad + keyboard strip click → note-off from strip doesn't kill pad's note |
| B8 | No lua error about duplicate locals in timeline.lua |
| B9 | At PITCH_ROW_H=16, ~39 rows rendered instead of ~55 |
| B10 | Set scroll_x=0 → beat_start=0, not -1 |
| B11 | Set snap to triplet → subdivision grid renders correctly |
