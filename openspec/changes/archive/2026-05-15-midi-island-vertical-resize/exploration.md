## Exploration: midi-island-vertical-resize

### Current State
The MIDI island (piano roll + timeline + velocity editor + preset browser) has a **fixed virtual height** defined by `ISLAND_CONTENT_H = 14000` virtual units in `midi-island.lua`. This maps to pixels via `layout.US(14000)` using the frame's uniform scale factor `s`. The scale `s = min(gfx.w / 39914, 500 / 29162) * 1.025` is computed from `gfx.w` (width) and a **constant** base height of 500px — NOT from `gfx.h`. This means:

1. **Resizing the window wider**: the uniform scale `s` increases → ALL content scales up proportionally (the island grows both wider AND taller because the virtual→pixel mapping changes).
2. **Resizing the window taller**: `gfx.h` is ignored by the scale calculation → the extra vertical space is simply unused below the island.
3. **The island toggle** (`gfx-window.lua`) switches between two fixed window heights (497px collapsed, 793px expanded) via `gfx.quit() + gfx.init()` — no proportional resize.

The internal island layout (once height `h` is computed in pixels) is fully pixel-based: `pr_h = h - tl_h - ve_h - SB_SIZE`, `ve_y = pr_y + pr_h`, etc. All sub-components use pixel values derived from `h`. The piano roll (`DrawPianoRoll`) receives `pr_h` and passes it to `ComputeVisibleRanges()` which computes `visible_viewport_rows = pr_h / PITCH_ROW_H`. More height → more visible pitch rows.

Key observation: the internal layout already distributes extra height correctly. The timeline header (30px), velocity editor (10px collapsed / 100px expanded), and scrollbar (7px) are all fixed sizes. The piano roll receives ALL remaining height minus a small `excess` that goes to the velocity editor for pixel alignment.

### Affected Areas
- `src/ui/midi-island.lua` — **Primary target**. Line 55: `ISLAND_CONTENT_H = 14000` constant. Line 190: `h = layout.US(ISLAND_CONTENT_H)` — the single point where island height is computed.
- `src/ui/views.lua` — `DrawFullView()` computes the scale `s`. The `oy` offset determines pixel Y of island start. Must ensure the main content + island fill the window correctly.
- `src/ui/piano-roll/grid.lua` — `ComputeVisibleRanges()` accepts pixel height `h` and computes `visible_rows = math.ceil(visible_viewport_rows) + 2`. At very tall windows, `visible_rows` increases. Performance is O(rows) for grid drawing and O(notes) for note rendering.
- `src/state/ui.lua` — Already has `last_window_w/h` fields and getters/setters but they're **never updated from MainLoop**. Could be used to track window resize.
- `src/main.lua` — MainLoop reads `gfx.w`/`gfx.h` indirectly via `DrawFullView`. No current resize detection. Window close detection is via `gfx.getchar() == -1`.
- `src/ui/gfx-window.lua` — `ToggleIsland()` currently does `gfx.quit() + gfx.init()` with fixed dimensions (497/793). Future resize-aware toggle should preserve the current `gfx.h` instead of hardcoding.

### Approaches

1. **Dynamic island height from gfx.h** — Replace the fixed `ISLAND_CONTENT_H` with a computed value: `h = math.max(MIN_ISLAND_H, gfx.h - y - bottom_padding)`. The island fills from its pixel-Y start to the bottom of the window. No virtual→pixel conversion needed for the height — it's computed in pixels directly.
   - Pros: Minimal code change (midi-island.lua lines 55 and 190 only). Internal pixel-based layout handles distribution automatically. No new state required. Performance is bounded by window size.
   - Cons: Must add a minimum-height guard (~200px so the island never collapses to 0). Window must be large enough to show island content (header + at least a few rows). Bottom padding of ~4px for visual comfort.
   - Effort: **Low**

2. **Window resize detection + dynamic height** — Add explicit window resize tracking in MainLoop: compare `gfx.w`/`gfx.h` against `ui_store.GetLastWindowW/H()` each frame. When a resize is detected, optionally trigger layout recalc or store the new dimensions. Then use the dynamic height from Approach 1.
   - Pros: More robust — explicit tracking enables resize-triggered actions (e.g., auto-adjust zoom). Stores stay in sync with reality. Future-proof for proportional layouts.
   - Cons: More code (MainLoop change + ui_store wiring). The resize detection adds marginal value since `gfx.w`/`gfx.h` are already read fresh every frame by DrawFullView. Unused `last_window_w/h` fields suggest this was considered and not wired up for a reason.
   - Effort: **Low-Medium**

3. **Virtual coords with bottom anchor** — Instead of switching to pixel-space for island height, extend the virtual coordinate system: compute a dynamic `ISLAND_CONTENT_H` in virtual units that maps to the remaining pixels: `ISLAND_CONTENT_H = (gfx.h - y) / s`. This keeps ALL calculations in the unified virtual space.
   - Pros: Fully consistent with existing virtual-coordinate pattern. Scales properly if the uniform scale changes.
   - Cons: Adds complexity. `s` can be very small at wide windows → division produces large numbers. Rounding errors create sub-pixel artifacts. The internal layout is already pixel-based anyway.
   - Effort: **Medium**

4. **Proportional split (gfx.h-aware scale)** — Change the scale calculation to use `gfx.h` instead of the 500px constant: `s = min(gfx.w / 39914, gfx.h / 29162) * 1.025`. This makes ALL content scale proportionally with window height, not just width.
   - Pros: Most natural behavior — content always fills the window. The 29162 canvas height becomes meaningful. Main content (header, islands, performance) also grows.
   - Cons: The MAIN content (not just the island) resizes with vertical window changes. This changes existing behavior significantly. The MIDI island toggle (497→793) would no longer make sense as a discrete jump. Existing `ui/AGENTS.md` explicitly warns against this: "Si se usara gfx.h en vez de constante, el contenido se encogería al expandir la isla."
   - Effort: **High**

### Recommendation
**Approach 1** is the clear winner: **Dynamic island height from gfx.h**. Here's why:

- It's the MINIMAL change that achieves the goal: the user wants the piano roll to grow vertically when the window is taller. Replacing one constant with a `gfx.h`-based computation does exactly that.
- The internal layout already distributes extra height correctly — the piano roll gets almost all of it.
- No new state, no new patterns, no breaking changes to the virtual coordinate system.
- The `oy` offset in DrawFullView ensures the main content stays at the top; only the island stretches to fill.
- A minimum-height guard (~200px) prevents edge cases with very short windows.
- Bottom margin of ~2-4px keeps visual comfort.

Implementation sketch:
```lua
-- In midi-island.lua, replace:
--   local CANVAS_W = layout.CANVAS_W
--   local ISLAND_CONTENT_H = 14000
-- with (remove ISLAND_CONTENT_H constant, keep CANVAS_W)
-- 
-- In Draw(), replace line 190:
--   local h = layout.US(ISLAND_CONTENT_H)
-- with:
--   local MIN_ISLAND_H = 200  -- minimum island height in pixels
--   local h = math.max(MIN_ISLAND_H, gfx.h - y - 4)
--
-- And remove unused ISLAND_CONTENT_H from module-level constants
-- (lines 54-55). Remove BTN_GAP_EXTRA if it becomes orphaned.
```

### Risks
- **Very tall windows**: Extreme `gfx.h` values (e.g., 2000px on multi-monitor setups) could trigger performance degradation in grid/note drawing loops (O(rows) + O(notes) per frame). Mitigation: REAPER GFX typically maxes out at monitor resolution. Even at 2000px, `visible_rows ≈ 2000/16 = 125`, which is well within Lua loop performance.
- **Very short windows**: If `gfx.h` is less than the island's header + minimum content, the piano roll gets 0 or negative height. The `math.max(MIN_ISLAND_H, ...)` guard ensures at least 200px. With the main content taking ~400px at scale, windows < 600px would show clipped content. Mitigation: this is an edge case — users naturally resize windows larger for MIDI editing.
- **Leftover ISLAND_CONTENT_H references**: The constant may be referenced elsewhere. Must audit before removing. Mitigation: search for `ISLAND_CONTENT_H` in the codebase.
- **gfx.h change detection**: REAPER GFX updates `gfx.w`/`gfx.h` frame-by-frame as the user drags the window edge. This is already read every frame by DrawFullView, so no extra detection needed.

### Ready for Proposal
Yes
