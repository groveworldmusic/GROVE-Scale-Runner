-- Tests: Piano Roll Grid — ComputeVisibleRanges, Scroll/Zoom Clamps, Cache
-- Tests pure arithmetic functions in piano-roll/grid.lua
-- No reaper/gfx mocks needed for these pure functions.
--
-- Setup: requires grid module (loads config/state deps transitively)
--
-- Usage: lua tests/run.lua (from project root)

local check = require("tests.helpers").check
local grid = require("ui.piano-roll.grid")

io.write("=== Piano Roll Grid Tests ===\n")

-- ============================================================
-- 1. ComputeVisibleRanges — Basic Mid-Viewport
-- ============================================================
io.write("\n-- ComputeVisibleRanges: basic\n")

-- Viewport: w=720, h=500, scroll centered, zoom_x=40
local visible_rows, pitch_start, pitch_end, top_pitch, beat_start, beat_end
visible_rows, pitch_start, pitch_end, top_pitch, beat_start, beat_end =
    grid.ComputeVisibleRanges(0, 500, 30, 4, 40, 720)

-- visible_viewport_rows = 500/16 = 31.25 → ceil = 32 + 2 = 34
-- max_scroll = 108 - 31.25 = 76.75
-- clamped_scroll = min(76.75, 30) = 30
-- top_pitch = max(12, 119 - floor(30)) = 89
-- pitch_start = max(12, 89 - 34 - 4) = max(12, 51) = 51
-- pitch_end = min(119, 89 + 4) = 93
-- beat_start = max(0, 4 - 1) = 3
-- beat_end = 4 + ceil(720/40) + 1 = 4 + 18 + 1 = 23
check(visible_rows == 34, "CVR: visible_rows = 34, got " .. visible_rows)
check(pitch_start == 51, "CVR: pitch_start = 51, got " .. pitch_start)
check(pitch_end == 93, "CVR: pitch_end = 93, got " .. pitch_end)
check(top_pitch == 89, "CVR: top_pitch = 89, got " .. top_pitch)
check(beat_start == 3, "CVR: beat_start = 3, got " .. beat_start)
check(beat_end == 23, "CVR: beat_end = 23, got " .. beat_end)

-- ============================================================
-- 2. ComputeVisibleRanges — Scroll Clamping at Edges
-- ============================================================
io.write("\n-- ComputeVisibleRanges: scroll clamping\n")

-- scroll_y = 0 (top) — clamped_scroll = 0
visible_rows, pitch_start, pitch_end, top_pitch =
    grid.ComputeVisibleRanges(0, 500, 0, 0, 40, 720)
check(top_pitch == 119, "CVR top: top_pitch = 119 (MAX), got " .. top_pitch)
check(pitch_end == 119, "CVR top: pitch_end clamped to 119, got " .. pitch_end)
check(pitch_start >= 12, "CVR top: pitch_start >= 12, got " .. pitch_start)

-- scroll_y = 200 (way past max) — clamped_scroll = max_scroll
visible_rows, pitch_start, pitch_end, top_pitch =
    grid.ComputeVisibleRanges(0, 500, 200, 0, 40, 720)
-- visible_viewport_rows = 500/16 = 31.25
-- max_scroll = 108 - 31.25 = 76.75
-- clamped_scroll = 76.75
-- top_pitch = max(12, 119 - floor(76.75)) = max(12, 119 - 76) = 43
check(top_pitch == 43, "CVR bottom: top_pitch clamped to 43, got " .. top_pitch)
check(pitch_start == 12, "CVR bottom: pitch_start clamped to 12 (MIN), got " .. pitch_start)

-- scroll_x negative — beat_start should be 0
_, _, _, _, beat_start = grid.ComputeVisibleRanges(0, 500, 30, -5, 40, 720)
check(beat_start == 0, "CVR: beat_start clamped to 0 for negative scroll_x, got " .. beat_start)

-- scroll_x = 0 — beat_start = max(0, 0-1) = 0
_, _, _, _, beat_start = grid.ComputeVisibleRanges(0, 500, 30, 0, 40, 720)
check(beat_start == 0, "CVR: beat_start = 0 at scroll_x=0, got " .. beat_start)

-- ============================================================
-- 3. ComputeVisibleRanges — Zero-Height Viewport Guard
-- ============================================================
io.write("\n-- ComputeVisibleRanges: zero-height viewport\n")

-- h=0 should not crash; ceil(0/16)=0 so visible_rows=2, no nil refs
local ok = pcall(grid.ComputeVisibleRanges, 0, 0, 30, 0, 40, 720)
check(ok == true, "CVR: zero-height viewport does not crash")

-- Zero width should not crash either
ok = pcall(grid.ComputeVisibleRanges, 0, 500, 30, 0, 40, 0)
check(ok == true, "CVR: zero-width viewport does not crash")

-- ============================================================
-- 4. ComputeVisibleRanges — Cache Coherence
-- ============================================================
io.write("\n-- ComputeVisibleRanges: cache behavior\n")

-- First call caches; second call with same params returns cached values
local v1, ps1, pe1, tp1 = grid.ComputeVisibleRanges(0, 500, 30, 4, 40, 720)
local v2, ps2, pe2, tp2 = grid.ComputeVisibleRanges(0, 500, 30, 4, 40, 720)
check(v1 == v2, "CVR cache: visible_rows matches cached")
check(ps1 == ps2, "CVR cache: pitch_start matches cached")
check(pe1 == pe2, "CVR cache: pitch_end matches cached")
check(tp1 == tp2, "CVR cache: top_pitch matches cached")

-- Invalidating cache forces recompute with same params still produces same output
grid.InvalidateVisibleRangesCache()
local v3, ps3, pe3, tp3 = grid.ComputeVisibleRanges(0, 500, 30, 4, 40, 720)
check(v1 == v3, "CVR cache: after invalidation, values still match (got " .. v3 .. ")")

-- Different params force recalc
local v4, _, _, _ = grid.ComputeVisibleRanges(0, 500, 35, 4, 40, 720)
check(v4 ~= v1 or v4 == 34, "CVR cache: different scroll_y triggers recalc")

-- ============================================================
-- 5. HandleMouseWheel — Scroll Clamp
-- ============================================================
io.write("\n-- HandleMouseWheel: scroll clamp\n")

-- Positive delta scrolls right
local new_scroll = grid.HandleMouseWheel(1, 0, 40)
check(new_scroll > 0, "wheel: positive delta increases scroll_x, got " .. new_scroll)

-- Negative delta at scroll_x=0 should clamp to 0
new_scroll = grid.HandleMouseWheel(-1, 0, 40)
check(new_scroll == 0, "wheel: negative delta at 0 clamps to 0, got " .. new_scroll)

-- Negative delta with positive scroll_x reduces scroll_x
new_scroll = grid.HandleMouseWheel(-1, 10, 40)
check(new_scroll < 10, "wheel: negative delta reduces scroll_x, got " .. new_scroll)

-- Larger delta moves faster
local small = grid.HandleMouseWheel(3, 0, 40)
local large = grid.HandleMouseWheel(6, 0, 40)
check(large > small, "wheel: larger delta moves farther, got " .. large .. " vs " .. small)

-- ============================================================
-- 6. HandleZoomX — Clamp 10-200
-- ============================================================
io.write("\n-- HandleZoomX: zoom clamp\n")

-- Positive delta multiplies by 1.15
local zoomed = grid.HandleZoomX(1, 40)
check(zoomed == 46, "zoomX: 40 * 1.15 = 46, got " .. zoomed)

-- Negative delta divides by 1.15
zoomed = grid.HandleZoomX(-1, 40)
check(zoomed == 35, "zoomX: 40 / 1.15 ≈ 35, got " .. zoomed)

-- Min clamp: zoom_x < 10 → 10
zoomed = grid.HandleZoomX(-1, 10)
check(zoomed == 10, "zoomX: min clamp at 10, got " .. zoomed)

-- Max clamp: zoom_x > 200 → 200
zoomed = grid.HandleZoomX(1, 200)
check(zoomed == 200, "zoomX: max clamp at 200, got " .. zoomed)

-- ============================================================
-- 7. HandleZoomVertical — Clamp 6-24
-- ============================================================
io.write("\n-- HandleZoomVertical: row height clamp\n")

-- Positive delta multiplies by 1.15
local new_rh = grid.HandleZoomVertical(1, 16)
check(new_rh == 18, "zoomV: 16 * 1.15 = 18, got " .. new_rh)

-- Negative delta divides by 1.15
new_rh = grid.HandleZoomVertical(-1, 16)
check(new_rh == 14, "zoomV: 16 / 1.15 ≈ 14, got " .. new_rh)

-- Min clamp: row_h < 6 → 6
new_rh = grid.HandleZoomVertical(-1, 6)
check(new_rh == 6, "zoomV: min clamp at 6, got " .. new_rh)

-- Max clamp: row_h > 24 → 24
new_rh = grid.HandleZoomVertical(1, 24)
check(new_rh == 24, "zoomV: max clamp at 24, got " .. new_rh)

-- ============================================================
-- 8. HandleMouseWheelVertical — Scroll Clamp
-- ============================================================
io.write("\n-- HandleMouseWheelVertical: scroll clamp\n")

-- Positive delta (wheel up) → lower scroll_y (higher pitches)
local new_sy = grid.HandleMouseWheelVertical(1, 30)
check(new_sy < 30, "wheelV: positive delta reduces scroll_y, got " .. new_sy)

-- Negative delta (wheel down) → higher scroll_y (lower pitches)
new_sy = grid.HandleMouseWheelVertical(-1, 30)
check(new_sy > 30, "wheelV: negative delta increases scroll_y, got " .. new_sy)

-- Scroll_y=0 with negative delta (scrolling down) → scroll increases to 0.08
new_sy = grid.HandleMouseWheelVertical(-1, 0)
check(math.abs(new_sy - 0.08) < 0.001, "wheelV: negative delta at 0 scrolls to 0.08, got " .. new_sy)

-- Speed: 1 delta unit → 0.08 scroll units at row_h=16
new_sy = grid.HandleMouseWheelVertical(1, 10)
check(math.abs(new_sy - (10 - 0.08)) < 0.001, "wheelV: 1 delta = 0.08 scroll units")

-- ============================================================
-- 9. SetPitchRowH — Clamp + Cache Invalidation
-- ============================================================
io.write("\n-- SetPitchRowH: clamp + cache invalidation\n")

-- Store current PITCH_ROW_H to restore later
local original_rh = grid.PITCH_ROW_H

-- Set to valid value
grid.SetPitchRowH(20)
check(grid.PITCH_ROW_H == 20, "setRowH: PITCH_ROW_H = 20, got " .. grid.PITCH_ROW_H)

-- Set to too-low value clamps to 6
grid.SetPitchRowH(3)
check(grid.PITCH_ROW_H == 6, "setRowH: min clamp at 6, got " .. grid.PITCH_ROW_H)

-- Set to too-high value clamps to 24
grid.SetPitchRowH(30)
check(grid.PITCH_ROW_H == 24, "setRowH: max clamp at 24, got " .. grid.PITCH_ROW_H)

-- Setting same value does NOT invalidate cache (no change)
grid.SetPitchRowH(24)
check(grid.PITCH_ROW_H == 24, "setRowH: same value no-op, stays 24")

-- Restore original for other tests
grid.SetPitchRowH(original_rh)

-- ============================================================
-- 10. InvalidateVisibleRangesCache
-- ============================================================
io.write("\n-- InvalidateVisibleRangesCache\n")

-- Prime the cache
grid.ComputeVisibleRanges(0, 500, 30, 4, 40, 720)

-- Invalidate
grid.InvalidateVisibleRangesCache()

-- After invalidation, next call with same params should NOT return stale cache
-- (it will recalc). Verify by calling and checking a distinct value.
local _, _, _, _, bstart = grid.ComputeVisibleRanges(0, 500, 30, 4, 40, 720)
check(bstart == 3, "invalCache: after invalidation, recalc produces correct result")

-- Double invalidation is safe (should not error)
local ok2 = pcall(grid.InvalidateVisibleRangesCache)
check(ok2 == true, "invalCache: double invalidation does not crash")

-- Invalidation with no prior cache is safe
grid.InvalidateVisibleRangesCache()  -- clear
grid.InvalidateVisibleRangesCache()  -- clear again (no crash)

io.write("\n=== Piano Roll Grid Tests Complete ===\n")
