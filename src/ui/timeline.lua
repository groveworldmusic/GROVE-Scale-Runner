-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Timeline Ruler
-- Beat/measure markers displayed above the piano roll grid.
-- Synchronizes with sequencer clock for playback head position.

local config = require("config")
local island_store = require("state.island")
local seq_store = require("state.sequencer")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local prefs = require("state.preferences")
local grid = require("ui.piano-roll.grid")

local timeline = {}

-- Configuration
timeline.TIMELINE_H = 30               -- Height of the timeline ruler in pixels
timeline.PITCH_LABEL_W = grid.PITCH_LABEL_W  -- Single source: piano-roll/grid.lua

-- Colors (Now synced with theme where possible)
local MEASURE_TICK_COLOR = theme.colors.text_dim or {0.6, 0.6, 0.6, 0.7}
local BEAT_TICK_COLOR = {0.4, 0.4, 0.4, 0.3}
local MEASURE_TEXT_COLOR = theme.colors.text or {0.7, 0.7, 0.7, 0.8}
local PLAYHEAD_COLOR = {0.9, 0.2, 0.2, 0.9}

-- Tick heights
local MEASURE_TICK_H = 16
local BEAT_TICK_H = 8

--- Draw beat/measure ticks for the timeline ruler.
--- @param x number Left edge of the grid portion (after labels)
--- @param y number Top edge of the ruler
--- @param w number Width of the grid portion
--- @param h number Height of the ruler
--- @param zoom_x number Pixels per beat
--- @param scroll_x number Horizontal scroll offset in beats
function timeline.DrawBeatTicks(x, y, w, h, zoom_x, scroll_x)
    if w <= 0 or h <= 0 then return end

    local beat_start = math.max(0, math.floor(scroll_x))
    local beat_end = beat_start + math.ceil(w / zoom_x) + 2
    local ruler_bottom = y + h

    -- Track last measure number label position to prevent overlap
    local last_label_end = -100

    local edge_margin = 2  -- clip ticks near right rounded edge
    for beat = beat_start, beat_end do
        local bx = x + (beat - scroll_x) * zoom_x
        if bx >= x and bx < x + w - edge_margin then
            local is_measure = (beat % 4) == 0

            if is_measure then
                -- Measure tick (taller, bolder)
                helpers.SetColor(MEASURE_TICK_COLOR)
                gfx.line(bx, y, bx, y + MEASURE_TICK_H)

                -- Measure number label (bottom-right of tick line)
                local measure_num = math.floor(beat / 4)
                local label = tostring(measure_num)

                gfx.setfont(1, "Calibri", 12)
                local lw, lh = gfx.measurestr(label)

                -- Check for overlap: only draw if enough space
                local label_x = bx + 5
                local label_end = label_x + lw
                if label_x > last_label_end + 8 then
                    helpers.SetColor(MEASURE_TEXT_COLOR)
                    gfx.x, gfx.y = label_x, y + MEASURE_TICK_H + 2
                    gfx.drawstr(label)
                    last_label_end = label_end
                end
            else
                -- Beat tick (shorter, lighter)
                helpers.SetColor(BEAT_TICK_COLOR)
                gfx.line(bx, y, bx, y + BEAT_TICK_H)
            end
        end
    end

    -- Subdivision ticks (only when subdivision > 1)
    local sub_idx = prefs.GetSubdivisionIndex() or 1
    local subdivision = config.SUBDIVISION_MODES[sub_idx] or 1
    if subdivision > 1 then
        local SUB_TICK_COLOR = {0.3, 0.3, 0.3, 0.2}
        local SUB_TICK_H = 3
        local first_measure = math.floor(beat_start / 4) * 4
        for measure_start = first_measure, beat_end, 4 do
            for s = 1, subdivision - 1 do
                local sub_beat = measure_start + (s / subdivision) * 4
                if sub_beat >= beat_start and sub_beat <= beat_end then
                    local bx = x + (sub_beat - scroll_x) * zoom_x
                    if bx >= x and bx < x + w - edge_margin then
                        helpers.SetColor(SUB_TICK_COLOR)
                        gfx.line(bx, y, bx, y + SUB_TICK_H)
                    end
                end
            end
        end
    end
end

--- Draw the playback head line and triangle handle.
--- @param x number Left edge of the grid portion
--- @param y number Top edge of the ruler
--- @param h number Height of the ruler
--- @param grid_h number Height of the piano roll grid below (line extends through it)
--- @param playback_pos number Current playback position in beats
--- @param zoom_x number Pixels per beat
--- @param scroll_x number Horizontal scroll offset in beats
--- @param grid_w number Width of the grid
--- @param ruler_only boolean If true, only draw within the ruler (for the ruler area call)
function timeline.DrawPlaybackHead(x, y, h, grid_h, playback_pos, zoom_x, scroll_x, grid_w, ruler_only)
    if playback_pos < 0 then return end

    local hx = x + (playback_pos - scroll_x) * zoom_x
    -- Clip to visible grid area
    if hx < x or (grid_w and hx > x + grid_w) then return end

    local is_playing = seq_store.GetIsPlaying()

    if is_playing then
        -- Playing: bright red with subtle pulse (guard: gfx.frame may be nil outside GFX context)
        local pulse
        if gfx.frame then
            pulse = 0.8 + 0.15 * math.sin(gfx.frame * 0.1)
        else
            pulse = 0.9
        end
        helpers.SetColor({PLAYHEAD_COLOR[1], PLAYHEAD_COLOR[2], PLAYHEAD_COLOR[3], pulse})
    else
        -- Stopped: dim gray at low alpha
        helpers.SetColor({0.4, 0.4, 0.4, 0.2})
    end

    local total_h = ruler_only and h or (h + grid_h)
    gfx.line(hx, y, hx, y + total_h)

    -- Triangle handle at top of playhead (dimmed when stopped)
    local tri_size = 5
    if not is_playing then
        helpers.SetColor({0.4, 0.4, 0.4, 0.25})
    end
    gfx.triangle(hx - tri_size, y + tri_size, hx + tri_size, y + tri_size, hx, y)
end

--- Hit test: convert mouse x position to beat position.
--- @param mx number Mouse x (screen, relative to full area)
--- @param grid_x number Grid left edge (screen)
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return number Snapped beat position
function timeline.TimelineHitTest(mx, grid_x, scroll_x, zoom_x)
    if zoom_x <= 0 then return 0 end

    local beat = (mx - grid_x) / zoom_x + scroll_x
    beat = math.max(0, beat)

    -- Snap to nearest beat
    local snapped = math.floor(beat + 0.5)
    return snapped
end

--- Draw the full timeline ruler.
--- @param x number Left edge of the ruler area (including label background)
--- @param y number Top edge of the ruler
--- @param w number Width of the ruler area
--- @param h number Height of the ruler
--- @param grid_h number Height of the piano roll grid below (for playhead line extension)
--- @param round_tl boolean|nil Round the top-left corner (default false)
function timeline.DrawTimelineRuler(x, y, w, h, grid_h, round_tl)
    local scroll_x = island_store.GetScrollOffsetX()
    local zoom_x = island_store.GetZoomX()
    local LABEL_W = timeline.PITCH_LABEL_W
    local SB_SIZE = 7

    -- 1. Ruler background (Only for the grid area to avoid spine overlap)
    local grid_x = x + LABEL_W
    local grid_w = w - LABEL_W - SB_SIZE
    
    helpers.SetColor({0.12, 0.12, 0.12, 0.98})
    components.DrawRoundedRectEx(grid_x, y, grid_w + SB_SIZE + 1, h, 10, {tr=true, tl=false, bl=false, br=false})

    -- 2. "BEATS" label (drawn directly over the master spine)
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 13)
    local lw, lh = gfx.measurestr("BEATS")
    gfx.x, gfx.y = x + (LABEL_W - lw) / 2, y + (h - lh) / 2
    gfx.drawstr("BEATS")

    -- 5. Content Ticks & Playhead
    grid_x = x + LABEL_W  -- Remove `local`: already declared at line 181 (PR: revision-isla-midi-bugs)
    grid_w = w - LABEL_W - SB_SIZE  -- Remove `local`: already declared at line 182
    if grid_w > 0 then
        timeline.DrawBeatTicks(grid_x, y, grid_w, h, zoom_x, scroll_x)
        timeline.DrawPlaybackHead(grid_x, y, h, grid_h, island_store.GetPlaybackPos(), zoom_x, scroll_x, grid_w, false)
    end
end

return timeline
