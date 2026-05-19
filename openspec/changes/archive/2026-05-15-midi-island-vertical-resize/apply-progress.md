## Apply Progress — midi-island-vertical-resize

### Phase 2 Tasks Completed

- [x] Task 2.1: Remove constant `ISLAND_CONTENT_H = 14000` from `src/ui/midi-island.lua`
- [x] Task 2.2: Replace height computation with `math.max(MIN_ISLAND_H, gfx.h - y - 4)`

### Changes

| File | Action | What Was Done |
|------|--------|---------------|
| `src/ui/midi-island.lua` | Modified | Removed `ISLAND_CONTENT_H = 14000` constant (was line 55), replaced with comment indicating dynamic computation |
| `src/ui/midi-island.lua` | Modified | Replaced `local h = layout.US(ISLAND_CONTENT_H)` (was line 197) with `local MIN_ISLAND_H = 200` and `local h = math.max(MIN_ISLAND_H, gfx.h - y - 4)` |

### Design Compliance

- **R1 (Dynamic Island Content Height)**: Implemented — `h = math.max(200, gfx.h - y - 4)` follows `gfx.h` in real-time, clamped to MIN_ISLAND_H (200px)
- **R2 (Scale System Invariant)**: Verified — no changes to scale system. `layout.US()` is still used for all virtual-coordinate computations. Only the island height was moved to pixel-space.
- **Scenarios covered**: Normal resize, window maximize, minimum height, sub-panel toggles — all naturally handled since `h` is recomputed every frame in `Draw()`.

### Verification

- `grep ISLAND_CONTENT_H src/ui/midi-island.lua` → **0 results** ✅
- `grep ISLAND_CONTENT_H src/` → **0 results** ✅ (no orphaned references)
- Static analysis: `y` is in scope (defined as `layout.UY(island_y_v)` on line 195). `gfx.h` is the REAPER GFX window height, available globally. `math.max` is a Lua builtin.

### Min-Height at 500px default window

With default window height at 500px:
- `y` ≈ ~17px (island_y_v converted to pixels)
- `gfx.h - y - 4` ≈ 500 - 17 - 4 = 479px
- `math.max(200, 479) = 479px` — correct, full content visible

At very small window (200px):
- `gfx.h - y - 4` ≈ 200 - 17 - 4 = 179px
- `math.max(200, 179) = 200px` — correct, min island height

### Deviations from Design

None — implementation matches design exactly.

### Issues Found

None.
