# Tasks: piano-roll-bugs

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~50-65 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | size-exception |

```
Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low
```

## Phase 1: Rendering Fixes (components.lua + note.lua)

- [x] **1.1** — `src/ui/components.lua`, `DrawRoundedRect()` lines 54-56: change `w + 1` → `w`, `h + 1` → `h`, etc. on all 3 opaque rects.
- [x] **1.2** — `src/ui/components.lua`, `DrawRoundedRect()` alpha-safe path lines 81-83: same `+1` removal on all 3 supersampled rects.
- [x] **1.3** — `src/ui/components.lua`, `DrawRoundedRectEx()` opaque path lines 122-128: remove `+1` overshoots on all 7 rects (3 main + 4 corner fills).
- [x] **1.4** — `src/ui/components.lua`, `DrawRoundedRectEx()` alpha-safe path lines 153-159: remove `+1` overshoots on all 7 supersampled rects.
- [x] **1.5** — `src/ui/piano-roll/note.lua`, `DrawNoteWithGradient()` line 82: replace `gfx.rect(...)` with `components.DrawRoundedRect(nx + 1, ny + 1, math.max(1, nw - 2), math.max(1, nh - 2), 3, true)` — velocity dim overlay preserves rounded corners.
- [x] **1.6** — `src/ui/piano-roll/note.lua`, `DrawNoteBlocks()` ghost notes line 179 and notes line 208: change `x - grid.PITCH_LABEL_W` → `x` in `math.max`.
- [x] **1.7** — `src/ui/velocity.lua`, `DrawVelocityEditor()` lines 193-210: delete the entire `offset_map` block (beat-grouping loop + offset_map table). Change line 218 to remove `+ (offset_map[i] or 0)`.

## Phase 2: Interaction Fixes (pads.lua + velocity.lua)

- [x] **2.1** — `src/ui/pads.lua`, `DrawScalePad()` line 59: gate `PendingDegree` set with `and ui_store.GetMouseClick()` so drag only starts when click originates on the pad.
- [x] **2.2** — `src/ui/velocity.lua`, `HandleVelocityMouse()` line 387: before `velocity.VelocityHitTest(...)`, add `local idx = island_store.GetPrimarySelectedIndex()` — if valid and mouse in editor area, use it directly; fall back to hit test.
- [x] **2.3** — `src/ui/velocity.lua`, `HandleVelocityMouse()` lines 396-398: remove `island_store.ClearSelection()`. Only update `selected[idx] = true` for the clicked note — preserve existing piano roll selection.

## Commit Plan

| Commit | Scope | Message |
|--------|-------|---------|
| `git commit` | Bug 4A | `fix: remove +1 overshoot on rounded rect opaque fills (components.lua)` |
| `git commit` | Bug 4B | `fix: velocity dim overlay uses DrawRoundedRect instead of gfx.rect (note.lua)` |
| `git commit` | Bug 5+C | `fix: clip notes at grid edge instead of pitch label strip (note.lua)` |
| `git commit` | Bug 2 | `fix: remove offset_map — velocity bars at same beat stack at same X (velocity.lua)` |
| `git commit` | Bug 1 | `fix: gate pad drag with GetMouseClick to prevent stray drags (pads.lua)` |
| `git commit` | Bug 3 | `fix: velocity edit respects pre-selected note over hit test (velocity.lua)` |
| `git commit` | Bug A | `fix: velocity click preserves piano roll multi-selection (velocity.lua)` |

## Dependencies

All tasks are independent — no cross-file or cross-function dependencies. Order within each phase is cosmetic.
