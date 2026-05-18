-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Piano Roll Coordinate Transforms
-- Pure functions for converting between beat/pitch space and pixel space.
-- No module state, no side effects.
--
-- Grid coordinate system:
--   X axis: beats, 0 = leftmost, increasing rightward
--   Y axis: MIDI pitch, inverted (higher pitch = lower Y value on screen)
-- Pixel coordinate system:
--   X: screen pixels, offset by grid_x (left edge of drawable area)
--   Y: screen pixels, offset by grid_y (top edge of drawable area)

local m = {}

--- Convert a beat to pixel X position within the grid.
--- @param beat number Beat position
--- @param scroll_x number Horizontal scroll offset (beats)
--- @param zoom_x number Pixels per beat
--- @param grid_x number Grid left edge pixel (screen X)
--- @return number Pixel X
function m.BeatToX(beat, scroll_x, zoom_x, grid_x)
    return grid_x + (beat - scroll_x) * zoom_x
end

--- Convert a pixel X position to beat position.
--- @param px number Screen pixel X
--- @param scroll_x number Horizontal scroll offset (beats)
--- @param zoom_x number Pixels per beat
--- @param grid_x number Grid left edge pixel (screen X)
--- @return number Beat position
function m.XToBeat(px, scroll_x, zoom_x, grid_x)
    return (px - grid_x) / zoom_x + scroll_x
end

--- Convert a MIDI pitch to pixel Y position in the grid (inverted Y).
--- Hard-clamps the result to the viewport extents for safety.
--- @param pitch number MIDI pitch (12=C0 .. 119=B8)
--- @param top_pitch number Highest pitch visible at grid top
--- @param scroll_y number Vertical scroll offset (rows from top, may be fractional)
--- @param pitch_row_h number Height per pitch row in pixels
--- @param grid_y number Grid top edge pixel (screen Y)
--- @return number Pixel Y (top of the pitch row)
function m.PitchToY(pitch, top_pitch, scroll_y, pitch_row_h, grid_y)
    local scroll_px_offset = (scroll_y - math.floor(scroll_y)) * pitch_row_h
    return grid_y + (top_pitch - pitch) * pitch_row_h - scroll_px_offset
end

--- Convert a pixel Y position to MIDI pitch (inverted Y).
--- Takes sub-pixel scroll offset into account.
--- @param py number Screen pixel Y
--- @param top_pitch number Highest pitch visible at grid top
--- @param scroll_y number Vertical scroll offset (rows from top, may be fractional)
--- @param pitch_row_h number Height per pitch row in pixels
--- @param grid_y number Grid top edge pixel (screen Y)
--- @return number MIDI pitch (clamped to valid range)
function m.YToPitch(py, top_pitch, scroll_y, pitch_row_h, grid_y)
    local scroll_px_offset = (scroll_y - math.floor(scroll_y)) * pitch_row_h
    local pitch_row = math.floor((py - grid_y + scroll_px_offset) / pitch_row_h)
    return math.max(12, math.min(119, top_pitch - pitch_row))
end

return m
