# Design: MIDI Island Vertical Resize

## Technical Approach

Replace the fixed virtual-coordinate island height (`ISLAND_CONTENT_H = 14000`) with a per-frame pixel-space computation using `gfx.h` (available window height). The internal pixel-based island layout already distributes extra height to the piano roll — this change simply feeds it more pixels.

**Approach: Dynamic island height from gfx.h** (Approach 1 from exploration, confirmed by proposal). Single source file affected.

## Architecture Decisions

### Decision: Pixel-space vs virtual-space height

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Pixel-space: `h = math.max(200, gfx.h - y - 4)` | Simple, 2-line change. Bypasses virtual coords for this single value. Internal layout already uses pixels. | **Selected** |
| Virtual-space: `h = layout.US((gfx.h - y) / s)` | Keeps all values in virtual units. Requires division by small `s` → large numbers → rounding artifacts. No benefit — internal layout is pixel-based anyway. | Rejected |

**Rationale**: The island uses `h` solely as a pixel value for all downstream calculations (`pr_h_full = h - tl_h - ve_h - SB_SIZE`, `sb_y = y + h - SB_SIZE`, `DrawPresetPanel(island_x, y, preset_w, h)`, `DrawRoundedRectEx(right_x, y, right_w, h, ...)`). Forcing `h` through `layout.US()` on a virtual constant that maps to pixels anyway adds unnecessary intermediate arithmetic. Bypassing it is cleaner.

### Decision: Scaling guard vs minimum height

The `math.max(MIN_ISLAND_H, ...)` guard protects against window heights smaller than the island's computed Y start. `MIN_ISLAND_H = 200` ensures at minimum the piano roll renders ~12 rows (200 / ~16px per row), which is usable for note editing.

## Data Flow

```
gfx.h (window height in pixels)
    │
    ▼
midi-island.Draw()
    │
    ├── y = layout.UY(island_y_v)     ← pixel Y of island start (unchanged)
    │
    └── h = math.max(200, gfx.h - y - 4)  ← NEW dynamic height in pixels
              │
              ▼
    pr_h_full = h - tl_h - ve_h - SB_SIZE  ← pixel-based (unchanged)
    pr_h = pr_h_full - (pr_h_full % PITCH_ROW_H)  ← row-aligned (unchanged)
              │
              ▼
    piano_roll.DrawPianoRoll(right_x, pr_y, right_w - SB_SIZE, pr_h)
              │
              ▼
    ComputeVisibleRanges(pr_h)  ← more pr_h → more visible rows
```

No new state, no new stores, no new callbacks. `gfx.h` is read fresh every frame by REAPER GFX — zero plumbing needed.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/midi-island.lua:55` | Remove | Delete `local ISLAND_CONTENT_H = 14000` constant |
| `src/ui/midi-island.lua:201` | Modify | Replace `local h = layout.US(ISLAND_CONTENT_H)` with `local h = math.max(200, gfx.h - y - 4)` |

## Interface / Contracts

No new interfaces. The existing contract for `pr_h` (piano roll pixel height) is preserved — it receives remaining height after subtracting timeline, velocity editor, and scrollbar. The only change is what value `h` starts from.

### MIN_ISLAND_H rationale

`MIN_ISLAND_H = 200` in pixels. At default scale (~0.0189), this maps to ~10,582 virtual units — somewhat smaller than the original 14,000. This is intentional: even in a short window, 200px allows ~12 pitch rows + 30px timeline + ~18px collapsed velocity editor + 7px scrollbar, ensuring the island remains usable.

## Edge Cases

| Case | Behavior | Safety |
|------|----------|--------|
| Very tall window (2000px+) | `h` → ~1570px, `pr_h` → ~125 rows | O(125) grid + O(N) notes per frame. Monitor-limited. |
| Very short window (< 400px) | `gfx.h - y` < 200 → `h = 200` | Island clips below window. Usable with scroll. |
| Window at default 497px (island collapsed) | Early return via `!GetMidiIslandExpanded()` | No effect. Only applied when island is visible. |
| Window at default 793px (island expanded) | `h = 793 - y - 4` → ~same as current ISLAND_CONTENT_H scaling | ~identical to existing behavior. |
| Window resize during playback | `gfx.h` updates every frame | Seamless. No state to invalidate. |
| ToggleIsland (gfx.quit + gfx.init) | Window destroyed and recreated at fixed height | This change only affects existing window resize, not island toggle. |

## Performance Analysis

At extreme window height (2000px on ultra-wide + taskbar setup):
- `pr_h ≈ 2000 - ~430(y) - 4 = ~1566px`
- `pr_h ≈ 1566 - 30(tl) - 18(ve) - 7(sb) = ~1511px`
- Rows: `1511 / 16 ≈ 94` visible pitch rows
- Grid drawing: O(94) for horizontal lines, O(notes) for note rendering
- Well within Lua single-frame budget (< 1ms for loop of this size)

No optimization needed. The existing cached total_beats computation and note-grid interaction paths are unchanged.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Static | Single source of `ISLAND_CONTENT_H` confirmed removed | Search grep for remaining references |
| Static | MIN_ISLAND_H only referenced at definition point | Search grep for second usage |
| Static | `layout.US()` usage removed | Confirm no `layout.US(ISLAND_CONTENT_H)` remains |
| Manual | Window resize → island grows | REAPER: stretch window vertically, verify piano roll rows increase |
| Manual | Window shrink → 200px minimum | REAPER: shrink window near-minimum, verify island does not collapse |
| Manual | Velocity editor toggle still aligns correctly | REAPER: expand/collapse VE at different window heights |
| Manual | Preset browser panel still renders correctly | REAPER: show preset panel at different heights |

## Migration / Rollback

No migration required. Single-commit revert: restore `ISLAND_CONTENT_H` constant and `layout.US()` call. Diff is ±3 lines.

## Open Questions

- None. Design is fully resolved from exploration and proposal.

## Delivery Budget

- Lines changed: 1 removal + 1 replacement = ~3 lines total (additions + deletions)
- **400-line budget risk: Low** — trivially under threshold
- **Chained PRs recommended: No**
