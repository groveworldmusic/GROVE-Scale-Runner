# Proposal: MIDI Island Vertical Resize

## Intent

The MIDI island piano roll has a fixed height (`ISLAND_CONTENT_H = 14000` virtual units). When the user stretches the REAPER window vertically, the extra space goes unused below the island. This wastes screen real estate that could show more pitch rows.

## Scope

### In Scope
- Replace `ISLAND_CONTENT_H` constant with a `gfx.h`-based dynamic height in `midi-island.lua`
- Minimum-height guard (~200px) to prevent island collapse
- Bottom margin (~4px) for visual comfort
- Remove orphaned constants if no longer referenced

### Out of Scope
- Window resize detection / `ui_store.last_window_h` wiring — not needed (gfx.h is already live per frame)
- Scale system changes — the 500px base height constant stays untouched
- Proportional main content scaling with window height — island-only change
- ToggleIsland behavior — `gfx.quit()` + `gfx.init()` pattern preserved

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `midi-island`: Island height SHALL be dynamic based on available window vertical space instead of a fixed constant. The 500px base height constraint for the scale system is preserved — only the pixel-space island height changes.

## Approach

Replace the fixed `ISLAND_CONTENT_H = 14000` with a per-frame pixel-space computation:

```lua
-- In m.Draw(), replace:
--   local h = layout.US(ISLAND_CONTENT_H)
-- with:
local MIN_ISLAND_H = 200
local h = math.max(MIN_ISLAND_H, gfx.h - y - 4)
```

Remove the orphaned `ISLAND_CONTENT_H` constant. The internal layout already distributes extra height correctly — the piano roll receives all remaining height after timeline (30px), velocity editor (10-100px), and scrollbar (7px). More `pr_h` → more visible pitch rows automatically.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/midi-island.lua:55` | Modified | Remove `ISLAND_CONTENT_H = 14000` constant |
| `src/ui/midi-island.lua:~201` | Modified | Replace `layout.US(ISLAND_CONTENT_H)` with `math.max(200, gfx.h - y - 4)` |
| `src/ui/midi-island.lua` | Audit | Check for orphaned constants (`BTN_GAP_EXTRA` etc.) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Very tall window → perf degradation (O(rows+notes) per frame) | Low | 2000px → ~125 rows, well within Lua perf. Monitor-limited. |
| Very short window → clipped content | Low | `math.max(200, ...)` guard. Natural: users resize larger for MIDI editing. |
| `ISLAND_CONTENT_H` referenced elsewhere | Low | Search before removal. Exploration confirms no other references. |
| Violation of spec constraint "gfx.h MUST NOT drive note block scaling" | None | Scale system untouched. Only pixel-space island height changes. |

## Rollback Plan

1. Restore lines 54-55: re-add `local ISLAND_CONTENT_H = 14000`
2. Restore line ~201: `local h = layout.US(ISLAND_CONTENT_H)`
3. Single-commit revert or git checkout of `src/ui/midi-island.lua`

## Dependencies

- None. Single file, no new state, no new modules.

## Success Criteria

- [ ] Stretching the REAPER window vertically makes the MIDI island piano roll grow proportionally in height
- [ ] Shrinking the window to minimum height still shows at least 200px of island content
- [ ] Existing MIDI island functionality (toggle, notes, scroll, zoom, velocity editor) works unchanged
- [ ] No performance regression at very tall window sizes
