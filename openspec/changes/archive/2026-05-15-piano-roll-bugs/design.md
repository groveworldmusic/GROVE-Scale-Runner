# Design: Piano Roll Bugs

## Technical Approach

Five localized fixes across 4 files. Each fix targets a specific rendering or interaction bug in the MIDI island. No refactors, new abstractions, or state changes. All changes are <10 lines each and independently revertible.

**Context**: All code runs in REAPER GFX immediate-mode context (main GFX window). No compact panel or dual-GFX issues. The piano-roll note store (`note-store.lua`) and island store (`island.lua`) provide the selection/notes API consumed by `velocity.lua` and `note.lua`.

## Bug 1 — Pad Drag Hitbox Too Permissive

### Problem

`DrawScalePad()` in `pads.lua` sets `PendingDegree` on **any** frame where `(gfx.mouse_cap & 1) == 1` and hover is true (lines 59-63). If the user clicks outside all pads and drags into one, `PendingDegree` gets set to that pad because `StartX/Y` is captured at the entry position (not the click origin). The 8px threshold (line 67) is then trivially met since the mouse is already inside the pad.

### Fix

**File**: `src/ui/pads.lua`, line 60

**Change**: Add `ui_store.GetMouseClick()` guard on the initial `PendingDegree` assignment — the click must have **originated** within this pad's hover area.

```lua
-- Before (line 60):
if not drag_store.GetPendingDegree() then

-- After:
if not drag_store.GetPendingDegree() and ui_store.GetMouseClick() then
```

**Why this works**: `GetMouseClick()` is the frame-level click-transition event bus (`(gfx.mouse_cap & 1) == 1 && last_mouse_cap == 0`, set in MainLoop). It's true only on the exact frame the mouse button was pressed. If the user clicks outside all pads, no pad sees both `hover == true` and `GetMouseClick() == true` in the same frame. Subsequent drag-into-pad frames have `GetMouseClick() == false`, so `PendingDegree` is never assigned.

**Existing drag flow preserved**: On the click frame where `hover == true && GetMouseClick() == true`, `PendingDegree` is set and `StartX/Y` captures the true click origin. Subsequent held frames continue past the `not drag_store.GetPendingDegree()` check (it's already set) to the 8px threshold — drag-to-slot works exactly as before.

### Impact Analysis

- **Normal click-and-drag on pad**: Click originates on pad → GetMouseClick is true + hover is true → PendingDegree set → drag proceeds as before. **No regression**.
- **Click outside, drag into pad**: GetMouseClick was true on the outside-click frame (but hover was false for this pad). On drag-into frame, GetMouseClick is false. PendingDegree never set. **Bug fixed**.
- **Rapid click on pad border**: If the click frame has GetMouseClick=true and the mouse is exactly between two pads... each pad checks its own hover independently. Only the hovered pad(s) set PendingDegree. Fine.

## Bug 2 — Velocity Bars Side by Side for Overlapping Notes

### Problem

`DrawVelocityEditor()` in `velocity.lua` builds an `offset_map` (lines 193-210) that spreads velocity bars of notes at the same beat by ±3px. This makes it look like notes are at different positions when they share the same beat. The `offset_map` is applied at line 218: `nx = ... + (offset_map[i] or 0)`.

### Fix

**File**: `src/ui/velocity.lua`

**Changes**:
1. Remove the `offset_map` construction block (lines 193-210) entirely.
2. Remove `+ (offset_map[i] or 0)` from line 218.

```lua
-- Remove lines 193-210 entirely:
--[[
        -- 2. GROUP ONLY VISIBLE NOTES (task 3.2)
        local offset_map = {}
        local beat_groups = {}
        for _, i in ipairs(visible_indices) do
            local note = notes[i]
            local beat = note.start_beat or 0
            if not beat_groups[beat] then beat_groups[beat] = {} end
            beat_groups[beat][#beat_groups[beat] + 1] = i
        end
        for _, indices in pairs(beat_groups) do
            local count = #indices
            if count > 1 then
                for j, idx in ipairs(indices) do
                    offset_map[idx] = (j - 1) * 3 - (count - 1) * 1.5
                end
            else
                offset_map[indices[1]] = 0
            end
        end
]]
```

```lua
-- Change line 218 from:
local nx = grid_x + (ns - scroll_x) * zoom_x + (offset_map[i] or 0)
-- To:
local nx = grid_x + (ns - scroll_x) * zoom_x
```

**Behavior**: All notes at the same beat draw their velocity bars at the same X position. The last-drawn bar (last index in `visible_indices`, i.e., highest pitch) renders on top. Selected/unselected color distinction still applies per `is_selected`.

### Edge Cases

- **0 notes in beat group**: `visible_indices` is already pre-culled. No empty groups exist.
- **Single note at beat**: Previously set `offset_map[idx] = 0` — removing the offset_map has no effect (was already 0).
- **Many notes at same beat**: All stack at same X. The z-order (last index wins) is the only visual distinction. Acceptable — velocity editor is for editing, not visual separation.

## Bug 3 — Velocity Edits Wrong Note When Selected

### Problem

`HandleVelocityMouse()` in `velocity.lua` always uses `VelocityHitTest()` to find the note under the cursor (line 387). If a note is already selected in the piano roll grid (via `GetPrimarySelectedIndex()`), the velocity editor ignores it and potentially picks a different overlapping note.

### Fix

**File**: `src/ui/velocity.lua`

**Location**: Inside `HandleVelocityMouse()`, in the `if click and mouse_down then` block (line 386).

**Change**: Check `GetPrimarySelectedIndex()` before falling back to hit-test:

```lua
-- Before (lines 386-388):
    if click and mouse_down then
        local idx = velocity.VelocityHitTest(mx, my, notes, grid_x, ed_y, ed_h, scroll_x, zoom_x)

-- After:
    if click and mouse_down then
        local idx = island_store.GetPrimarySelectedIndex()
        if not idx then
            idx = velocity.VelocityHitTest(mx, my, notes, grid_x, ed_y, ed_h, scroll_x, zoom_x)
        end
```

**Flow**:
1. If `GetPrimarySelectedIndex() ~= nil` → use it as the target note. Skip hit-test entirely.
2. If nothing selected → fall back to `VelocityHitTest()` to find note under cursor.
3. If hit-test also returns nil → no editing (same as before).

### Impact Analysis

- **Note selected in grid, click in velocity editor**: Always edits the selected note. User can adjust velocity without re-finding the note visually.
- **No note selected**: Pure hit-test behavior, unchanged.
- **Multi-selection**: `GetPrimarySelectedIndex()` returns `_last_selected_idx`. The `ApplyVelocity` function (line 301) already handles bulk delta when `GetSelectionCount() > 1`. This path is unchanged — it'll edit all selected notes using the primary index's delta. The primary index from `GetPrimarySelectedIndex()` feeds into `ApplyVelocity` which checks `GetSelectionCount()`.

### Extension: Velocity click should NOT clear piano roll selection

This is a corollary fix needed in the same block (around lines 394-398):

```lua
-- Before:
local selected = island_store.GetSelectedIndices()
if not selected[idx] then
    island_store.ClearSelection()
    selected[idx] = true
end

-- After:
local selected = island_store.GetSelectedIndices()
if not selected[idx] then
    -- Don't ClearSelection — preserve multi-selection from piano roll
    selected[idx] = true
    island_store.SetSelectedIndices(selected)  -- sync set (triggers _last_selected_idx update)
end
```

Wait — this interacts with the Bug 3 fix. If `idx` came from `GetPrimarySelectedIndex()`, then `selected[idx]` is already true and we skip this block entirely. If `idx` came from hit-test and `selected[idx]` is false (clicked a different note), we add it to selection without clearing existing selection.

Actually, the proposal says Bug A is separate: "Velocity click clears piano roll selection." Let me think about whether the proper behavior is:
- Clicking velocity bar of a non-selected note while another note is selected in grid: should we edit the selected note (Bug 3 fix) or switch selection to the clicked note?
- With the Bug 3 fix alone: clicking velocity bar always edits the selected note, so the ClearSelection block is unreachable when `GetPrimarySelectedIndex()` returns a value.
- When no note is selected: we hit-test and may find a note. The current code clears selection and sets the hit note as selected. This is fine for the case where nothing was selected.

Actually, I think Bug A is about the case where:
1. User has multiple notes selected in the piano roll grid (multi-selection)
2. User clicks on one of those notes' velocity bars
3. `VelocityHitTest` returns that note's index
4. `selected[idx]` is already true (note is in the multi-selection)
5. So the `if not selected[idx] then` block is skipped
6. Selection is preserved!

Wait, that case is fine. What about:
1. User has a multi-selection in the piano roll
2. User clicks velocity bar of a note NOT in the selection
3. Currently: ClearSelection + set clicked note as selected — this clears the multi-selection!

The fix for Bug A: when the clicked note is NOT already selected, don't clear the existing selection — just add the clicked note to it. This preserves multi-selection from the piano roll.

But this might be surprising UX — clicking a velocity bar adds to selection? The current behavior (clear + select single) could also be intentional. Let me re-read the proposal:

"Bug A: Velocity click clears piano roll selection" — the fix direction is "Don't clear selection on velocity click; only update selected note's velocity."

So the fix for Bug A is to simply NOT do the selection management in the velocity click handler at all. Just edit the velocity of the hit note without affecting selection. Combined with Bug 3 (use pre-selected note), this means:
- If note is selected: edit its velocity (selection unchanged)
- If no note selected: hit-test and edit (selection unchanged, no ClearSelection)

But wait, if no note is selected and you click a velocity bar, should the note become selected? That seems like normal behavior. Let me re-check the actual problem statement.

The proposal says: "Don't clear selection on velocity click; only update selected note's velocity"

This means: remove the ClearSelection line. The selected[idx] = true line can stay (mark the clicked note as selected too). Or perhaps remove the entire selection management block.

For the design, I'll recommend removing the `ClearSelection()` call, keeping the `selected[idx] = true` so clicking a velocity bar adds that note to the selection (or marks it as the primary selected note).

But if we apply the Bug 3 fix (use GetPrimarySelectedIndex), the click handler uses the already-selected note and the selection management block at lines 394-398 is only reached for the hit-test fallback path (when nothing was pre-selected). In that case, it's fine to set selection normally.

Actually, let me simplify: with Bug 3 fix applied, `idx` comes from either:
a) `GetPrimarySelectedIndex()` → `selected[idx]` is already true → selection block skipped entirely
b) hit-test → nothing was selected → `selected[idx]` is false → we ClearSelection (trivially, since nothing was selected) and set `selected[idx] = true`

In case (b), ClearSelection on an empty selection is a no-op. So actually, Bug A (ClearSelection clearing multi-selection) can't happen with Bug 3 fix applied, because the only way we reach the ClearSelection line is when nothing was pre-selected.

BUT — there's another scenario: what if the user clicks on a velocity bar at a beat that doesn't correspond to the selected note? With Bug 3 fix, `idx` = primary selected index (even though that note is not under the cursor). The velocity change applies to the selected note. The selection is unchanged. This is the desired behavior.

OK, I think Bug A is implicitly fixed by Bug 3. The ClearSelection issue can't manifest because:
- If a note IS selected, we skip hit-test entirely (use pre-selected index)
- If nothing is selected, ClearSelection is a no-op

So Bug A doesn't need an additional fix beyond Bug 3. But I'll note it in the design for clarity.

## Bug 4 — Note Rendering Artifacts

### Bug 4A: DrawRoundedRect Overshoot (+1)

**Problem**: The opaque fast path of `DrawRoundedRect()` (components.lua lines 50-56) and `DrawRoundedRectEx()` (lines 117-128) uses `+1` overshoots on rect widths/heights to prevent 1px seams. The overshoot causes visible valley-like artifacts at the edges of rounded rects (1px protrusion beyond the intended boundary).

**Fix File**: `src/ui/components.lua`

**Changes in `DrawRoundedRect()` (lines 54-56)**:

```lua
-- Before:
gfx.rect(x, y + r, w + 1, math.max(0, h - r * 2) + 1, 1)
gfx.rect(x + r, y, math.max(0, w - r * 2) + 1, r + 1, 1)
gfx.rect(x + r, y + h - r, math.max(0, w - r * 2) + 1, r + 1, 1)

-- After:
gfx.rect(x, y + r, w, math.max(0, h - r * 2), 1)
gfx.rect(x + r, y, math.max(0, w - r * 2), r, 1)
gfx.rect(x + r, y + h - r, math.max(0, w - r * 2), r, 1)
```

**Changes in `DrawRoundedRectEx()` (lines 122-128)**:

```lua
-- Before:
gfx.rect(x, y + r, w + 1, math.max(0, h - r * 2) + 1, 1)
gfx.rect(x + r, y, math.max(0, w - r * 2) + 1, r + 1, 1)
gfx.rect(x + r, y + h - r, math.max(0, w - r * 2) + 1, r + 1, 1)
if not tl then gfx.rect(x, y, r + 1, r + 1, 1) end
if not tr then gfx.rect(x + w - r, y, r + 1, r + 1, 1) end
if not bl then gfx.rect(x, y + h - r, r + 1, r + 1, 1) end
if not br then gfx.rect(x + w - r, y + h - r, r + 1, r + 1, 1) end

-- After:
gfx.rect(x, y + r, w, math.max(0, h - r * 2), 1)
gfx.rect(x + r, y, math.max(0, w - r * 2), r, 1)
gfx.rect(x + r, y + h - r, math.max(0, w - r * 2), r, 1)
if not tl then gfx.rect(x, y, r, r, 1) end
if not tr then gfx.rect(x + w - r, y, r, r, 1) end
if not bl then gfx.rect(x, y + h - r, r, r, 1) end
if not br then gfx.rect(x + w - r, y + h - r, r, r, 1) end
```

**Changes in the alpha-safe path (lines 81-83, 153-159)** — same change at 2x scale:

```lua
-- Line 81 (center fill at 2x):
gfx.rect(0, br, bw, math.max(0, bh - br * 2) + 1, 1)
-- Line 82-83 (top/bottom strips at 2x):
gfx.rect(br, 0, math.max(0, bw - br * 2) + 1, br + 1, 1)
gfx.rect(br, bh - br, math.max(0, bw - br * 2) + 1, br + 1, 1)

-- After (line 81):
gfx.rect(0, br, bw, math.max(0, bh - br * 2), 1)
-- After (lines 82-83):
gfx.rect(br, 0, math.max(0, bw - br * 2), br, 1)
gfx.rect(br, bh - br, math.max(0, bw - br * 2), br, 1)
```

Similarly for lines 153-155 (DrawRoundedRectEx alpha-safe path):
```lua
gfx.rect(0, brr, bw, math.max(0, bh - brr * 2), 1)
gfx.rect(brr, 0, math.max(0, bw - brr * 2), brr, 1)
gfx.rect(brr, bh - brr, math.max(0, bw - brr * 2), brr, 1)
```

And the corner fill rects at lines 156-159:
```lua
if not tl then gfx.rect(0, 0, brr, brr, 1) end
if not tr then gfx.rect(bw - brr, 0, brr, brr, 1) end
if not bl then gfx.rect(0, bh - brr, brr, brr, 1) end
if not br then gfx.rect(bw - brr, bh - brr, brr, brr, 1) end
```

**Tradeoff**: Removing the +1 may create sub-pixel seams between circles and rects in edge cases (very small r, odd dimensions). However, the GFX renderer's pixel coverage for circles already overlaps with adjacent rect fills at integer boundaries — the +1 was causing overshoot that was MORE visible than any potential seam. If 1px gaps appear, they can be addressed per-call-site with a 1px inset on the circles instead.

### Bug 4B: Velocity Dim Overlay Uses Square-Corner Rect

**Problem**: In `note.lua` line 82, `DrawNoteWithGradient()` draws a velocity-dim overlay using `gfx.rect()` (square corners) over a rounded-corner note block drawn with `DrawRoundedRect()`. The square corners protrude beyond the rounded corners, creating visible white/light corner artifacts.

**Fix File**: `src/ui/piano-roll/note.lua`, line 82

**Change**: Replace `gfx.rect()` with `components.DrawRoundedRect()` for the velocity dim overlay:

```lua
-- Before (lines 79-83):
    local dim = 1.0 - vel_alpha
    if dim > 0.01 then
        helpers.SetColor({0, 0, 0, dim})
        gfx.rect(nx + 1, ny + 1, math.max(1, nw - 2), math.max(1, nh - 2), 1)
    end

-- After:
    local dim = 1.0 - vel_alpha
    if dim > 0.01 then
        helpers.SetColor({0, 0, 0, dim})
        components.DrawRoundedRect(nx + 1, ny + 1, math.max(1, nw - 2), math.max(1, nh - 2), 3, true)
    end
```

**Performance note**: Since `dim` is derived from velocity (0.35 to 0.99 alpha), this will almost always trigger the alpha-safe supersampling path in `DrawRoundedRect()`. This is acceptable — note blocks are limited in number (typically <100 visible at a time) and the 2x blit path is fast enough at that count.

## Bug 5 — Horizontal Scroll Notes Bunch at Keyboard Strip

### Problem

`DrawNoteBlocks()` in `note.lua` clips the left edge of note blocks at `x - grid.PITCH_LABEL_W` (lines 208-209), which extends into the keyboard pitch label area. When the user scrolls horizontally, notes remain visible in the label strip instead of being clipped at the grid boundary `x`.

Same issue for ghost notes (line 179).

### Fix

**File**: `src/ui/piano-roll/note.lua`

**Changes**:

Line 179 (ghosts):
```lua
-- Before:
local clip_gx = math.max(x - grid.PITCH_LABEL_W, math.floor(gx))
-- After:
local clip_gx = math.max(x, math.floor(gx))
```

Line 208 (actual notes):
```lua
-- Before:
local clip_nx = math.max(x - grid.PITCH_LABEL_W, math.floor(nx))
-- After:
local clip_nx = math.max(x, math.floor(nx))
```

**Behavior**: Notes now clip at the grid edge `x` (the left edge of the grid area). When a note extends left of `x`, it clips cleanly at the grid boundary. The pitch label area (`x - PITCH_LABEL_W` to `x`) is never overlapped by note blocks.

### Edge Cases

- **Note exactly at grid edge** (`nx == x`): `math.max(x, math.floor(x)) == x` — renders normally.
- **Note partially off-screen left** (`nx < x`): `math.max(x, math.floor(nx)) == x` — clips to grid edge, note appears as a partial block starting at `x`. This is the correct behavior — the user sees a truncated note indicating there's more content to the left.
- **Note fully off-screen left** (`nx + nw < x`): The pre-culling at lines 197-199 (`in_time_range = ns <= beat_end and (ns + nd) >= beat_start`) already removes fully off-screen notes from rendering. This is unchanged.

### Interaction with Bug 4B

The ghost clip fix (line 179) and note clip fix (line 208) use the same `x` parameter — the left edge of the grid area. Bug 4B's velocity dim overlay is independent (deals with individual note block rendering, not clip boundaries).

## Architecture Decisions

### Decision: Gate drag initiation with GetMouseClick (Bug 1)

| Option | Tradeoff |
|--------|----------|
| **GetMouseClick gate** (chosen) | 1 line change; uses existing event bus; preserves drag-to-slot |
| Track click origin per degree | More state in drag_store; 3+ lines of new code; more surface area |
| Remove PendingDegree entirely | Breaks drag-to-slot; requires different slot-drop detection |
| Widen hit-test to check click origin | More complex; needs new store field |

**Rationale**: Minimal change, maximal correctness. The event bus already exists and fires exactly once per click. No new state.

### Decision: Remove offset_map entirely (Bug 2)

| Option | Tradeoff |
|--------|----------|
| **Remove offset_map** (chosen) | Simple delete; bars stack at same X (z-order separates them) |
| Default offset_map to 0 | Same effect but dead code left in |
| Render stems centered on note | More complex; need to track note layout for overlaps |

**Rationale**: The offset_map's visual purpose (separate overlapping notes) is invalid — it creates a false positional offset. Stacking at the same X is correct for notes at the same beat.

### Decision: Prefer GetPrimarySelectedIndex over hit-test (Bug 3)

| Option | Tradeoff |
|--------|----------|
| **Use pre-selected index** (chosen) | 4 lines; clear UX: selected note's velocity is editable regardless of click position |
| Merge: weighted nearest of selected | Complex; hard to predict user intent |
| Always hit-test | Current bug: ignores selection |

**Rationale**: The grid selection is the user's explicit intent. The velocity editor should respect it.

### Decision: Remove +1 overshoots (Bug 4A)

| Option | Tradeoff |
|--------|----------|
| **Remove +1** (chosen) | May introduce 1px seams; eliminates visible valley artifacts |
| Keep +1 but use smaller increment (+0.5) | GFX API uses integer pixel coords only |
| Use gfx.roundrect instead | No control over corner rendering; no alpha-safe path |

**Rationale**: The +1 was intended as a seam fix but the overshoot is more visible than potential seams. The circle + rect approach already has ±1px overlap at integer pixel boundaries.

### Decision: Use DrawRoundedRect for dim overlay (Bug 4B)

| Option | Tradeoff |
|--------|----------|
| **DrawRoundedRect** (chosen) | Triggers alpha-safe path (2x supersampling); correct corner rendering |
| Keep gfx.rect | Fast but produces visible corner artifacts |
| Manual corner clip with circles | More code; same alpha-safe path issue |

**Rationale**: Visual correctness over micro-optimization. Note block count is bounded.

### Decision: Clip at grid x (Bug 5)

| Option | Tradeoff |
|--------|----------|
| **Clip at x** (chosen) | 2 character changes; correct boundary |
| Clip at x + padding | More complex; pixel-perfect not needed |
| Don't clip at all | Current bug: notes bunch into label area |

**Rationale**: The grid edge `x` is the only correct clip boundary. Notes overlapping keyboard labels is a visual bug.

## Dependencies

| Bug | Depends On | Rationale |
|-----|------------|-----------|
| 1 | None | Isolated to pads.lua |
| 2 | None | Isolated to velocity.lua |
| 3 | None | Isolated to velocity.lua |
| 4A | None | Isolated to components.lua |
| 4B | 4A | Same file (note.lua) but independent fix; order doesn't matter |
| 5 | None | Isolated to note.lua |

No cross-file dependencies. All 5 bugs can be fixed independently in any order.

## File Changes Summary

| File | Action | Bugs | Lines Changed |
|------|--------|------|---------------|
| `src/ui/pads.lua` | Modify | Bug 1 | 1 (add `and ui_store.GetMouseClick()`) |
| `src/ui/velocity.lua` | Modify | Bug 2 | ~19 (remove offset_map block + inline offset) |
| `src/ui/velocity.lua` | Modify | Bug 3 | ~4 (add GetPrimarySelectedIndex gate) |
| `src/ui/velocity.lua` | Modify | Bug A | ~2 (remove ClearSelection call) |
| `src/ui/components.lua` | Modify | Bug 4A | ~12 (remove +1 from 3 rects in 2 functions + alpha-safe paths) |
| `src/ui/piano-roll/note.lua` | Modify | Bug 4B | 1 (gfx.rect → DrawRoundedRect) |
| `src/ui/piano-roll/note.lua` | Modify | Bug 5/C | 2 (x - PITCH_LABEL_W → x) |

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Static analysis | Lua syntax, nil safety | Visual review — all changes are local, no new branches or nil risk |
| Interaction (REAPER) | Bug 1: click outside pad → drag in | Manual: verify no pad activation |
| Interaction (REAPER) | Bug 1: click on pad → drag to slot | Manual: verify drag-to-slot still works |
| Rendering (REAPER) | Bug 2: overlapping notes velocity bars | Manual: verify bars at same X |
| Interaction (REAPER) | Bug 3: select note → click velocity | Manual: verify selected note edits |
| Rendering (REAPER) | Bug 4A: rounded rects no overshoot | Visual inspection of all DrawRoundedRect call sites |
| Rendering (REAPER) | Bug 4B: note dim overlay matches rounded corners | Visual inspection |
| Rendering (REAPER) | Bug 5: scroll notes clip at grid edge | Manual: horizontal scroll past edge |

Existing test suite (497 checks) should pass — no API changes, no new state, no new functions.

## Open Questions

None. All fixes have clear, minimal code changes with well-understood tradeoffs.
