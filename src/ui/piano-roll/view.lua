-- GROVE FL MIDI: Piano Roll View Coordinator
-- DrawPianoRoll entry point: computes visible ranges, calls grid/note/lasso.
-- Extracted from piano-roll.lua barrel (PR1b).

local island_store = require("state.island")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local grid = require("ui.piano-roll.grid")
local note = require("ui.piano-roll.note")
local interaction = require("ui.piano-roll.interaction")

local m = {}

-- Local references for hot path
local ComputeVisibleRanges = grid.ComputeVisibleRanges

-- =========================================================
-- Coordinator: DrawPianoRoll
-- =========================================================

--- Main piano roll entry point: draw grid, labels, and note blocks.
--- @param x number Left edge of the entire piano roll area (including label area)
--- @param y number Top edge of the piano roll area
--- @param w number Width of the entire piano roll area
--- @param h number Height of the piano roll area
function m.DrawPianoRoll(x, y, w, h)
    local scroll_y = island_store.GetScrollOffsetY()
    local scroll_x = island_store.GetScrollOffsetX()
    local zoom_x = island_store.GetZoomX()
    local LABEL_W = grid.PITCH_LABEL_W

    -- Compute visible ranges ONCE per frame (shared between grid + notes, P5-05)
    local visible_rows, pitch_start, pitch_end, top_pitch, beat_start, beat_end =
        ComputeVisibleRanges(y, h, scroll_y, scroll_x, zoom_x, w)

    -- Draw grid (to the right of labels)
    local grid_x = x + LABEL_W
    local grid_w = w - LABEL_W
    if grid_w <= 0 then return end

    grid.DrawPianoRollGrid(grid_x, y, grid_w, h, scroll_y, scroll_x, zoom_x,
                           visible_rows, pitch_start, pitch_end, top_pitch)

    -- Draw note blocks (uses shared pitch/beat ranges)
    note.DrawNoteBlocks(grid_x, y, grid_w, h, scroll_y, scroll_x, zoom_x,
                        pitch_start, pitch_end, beat_start, beat_end, top_pitch)

    -- Draw vertical scrollbar indicator (right side)
    local total_rows = grid.TOTAL_ROWS
    local actual_visible = math.ceil(h / grid.PITCH_ROW_H)
    local max_scroll_y = total_rows - actual_visible
    local clamped_scroll_y = math.min(scroll_y, math.max(0, max_scroll_y))
    local scroll_ratio_y = actual_visible / total_rows
    if scroll_ratio_y < 1 and max_scroll_y > 0 then
        local sb_x = x + w - 6
        local sb_h = math.max(20, h * scroll_ratio_y)
        -- Track background (H12)
        helpers.SetColor({0.15, 0.15, 0.15, 0.25})
        gfx.rect(sb_x, y, 6, h, 1)
        -- Thumb
        local sb_y = y + (clamped_scroll_y / max_scroll_y) * h
        helpers.SetColor({0.4, 0.4, 0.4, 0.35})
        gfx.rect(sb_x, sb_y, 6, sb_h, 1)
    end

    -- Draw lasso selection rect
    interaction.DrawLassoRect()
end

return m
