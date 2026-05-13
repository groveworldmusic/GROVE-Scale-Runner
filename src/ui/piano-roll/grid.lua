-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
-- GROVE Scale Runner: Piano Roll Grid
-- Renders the pitch×time grid background, beat lines, and vertical keyboard strip.
-- Extracted from piano-roll.lua monolith (PR1a).
-- Handles: grid drawing, keyboard strip, scroll/zoom handlers, visible range computation.

local config = require("config")
local island_store = require("state.island")
local midi_store = require("state.midi")
local theme = require("ui.theme")
local helpers = require("ui.helpers")

local m = {}

-- =========================================================
-- Constants
-- =========================================================
m.PITCH_ROW_H = 16          -- Height per pitch row in pixels
m.PITCH_LABEL_W = 48        -- Width of pitch labels on the left (keyboard strip)
m.MIN_PITCH = 12            -- C0
m.MAX_PITCH = 119           -- B8 (octava 8 completa)
m.TOTAL_ROWS = 108          -- 119 - 12 + 1 (C0 a B8)
m.OCTAVE_BUFFER = 12        -- +1 octave buffer for virtual scroll

-- =========================================================
-- Internal color constants
-- =========================================================
local PITCH_ROW_WHITE = {0.3, 0.3, 0.3, 0.35}
local PITCH_ROW_BLACK = {0.12, 0.12, 0.12, 0.5}
local PITCH_ROW_DARK = {0.22, 0.22, 0.22, 0.25}  -- Slightly darker tint for black key rows

-- Pre-computed set of white key pitch classes (O(1) lookup, Issue 18 pattern).
local WHITE_KEY_SET = {}
for _, pc in ipairs({0, 2, 4, 5, 7, 9, 11}) do
    WHITE_KEY_SET[pc] = true
end

-- Frame-cache: avoid recomputing visible ranges when scroll/zoom unchanged
local _cache = {
    scroll_y = nil, scroll_x = nil, zoom_x = nil, w = nil, h = nil,
    pitch_row_h = nil,
    pitch_start = 0, pitch_end = 0, beat_start = 0, beat_end = 0,
    visible_rows = 0, top_pitch = 0,
}

-- =========================================================
-- Internal helpers
-- =========================================================

--- Get note name for keyboard label, with octave number only on C (pitch_class 0).
local function KeyboardNoteLabel(pitch)
    local note_names = config.NOTE_NAMES
    local name = note_names[(pitch % 12) + 1]
    if (pitch % 12) == 0 then
        local octave = math.floor(pitch / 12) - 1
        return name .. tostring(octave)
    end
    return name
end

-- =========================================================
-- ComputeVisibleRanges
-- =========================================================

--- Compute visible pitch and beat ranges for the current viewport.
--- Inverted Y: high pitch at TOP (low y), low pitch at BOTTOM (high y).
--- Results are cached and reused when scroll/zoom/dimensions haven't changed.
--- @param y number Viewport top (pixel)
--- @param h number Viewport height (pixel)
--- @param scroll_y number Vertical scroll offset (rows from top)
--- @param scroll_x number Horizontal scroll offset (beats)
--- @param zoom_x number Pixels per beat
--- @param w number Viewport width (pixel)
--- @return visible_rows, pitch_start, pitch_end, top_pitch, beat_start, beat_end
function m.ComputeVisibleRanges(y, h, scroll_y, scroll_x, zoom_x, w)
    -- Invalidate cache when parameters change
    if _cache.scroll_y == scroll_y and _cache.scroll_x == scroll_x
       and _cache.zoom_x == zoom_x and _cache.w == w and _cache.h == h
       and _cache.pitch_row_h == m.PITCH_ROW_H then
        return _cache.visible_rows, _cache.pitch_start, _cache.pitch_end,
               _cache.top_pitch, _cache.beat_start, _cache.beat_end
    end

    local visible_rows = math.ceil(h / m.PITCH_ROW_H) + 2
    local max_scroll = m.TOTAL_ROWS - visible_rows
    local clamped_scroll = math.max(0, math.min(max_scroll, scroll_y or 0))
    -- Floor clamped_scroll so top_pitch is always an integer pitch
    local top_pitch = math.max(m.MIN_PITCH, m.MAX_PITCH - math.floor(clamped_scroll))
    local pitch_start = math.max(m.MIN_PITCH, top_pitch - visible_rows - m.OCTAVE_BUFFER)
    local pitch_end = math.min(m.MAX_PITCH, top_pitch + m.OCTAVE_BUFFER)
    local beat_start = scroll_x - 1
    local beat_end = scroll_x + math.ceil((w or 0) / math.max(1, zoom_x)) + 1

    -- Cache for next frame
    _cache.scroll_y = scroll_y
    _cache.scroll_x = scroll_x
    _cache.zoom_x = zoom_x
    _cache.w = w
    _cache.h = h
    _cache.pitch_row_h = m.PITCH_ROW_H
    _cache.visible_rows = visible_rows
    _cache.pitch_start = pitch_start
    _cache.pitch_end = pitch_end
    _cache.top_pitch = top_pitch
    _cache.beat_start = beat_start
    _cache.beat_end = beat_end

    return visible_rows, pitch_start, pitch_end, top_pitch, beat_start, beat_end
end

-- =========================================================
-- Vertical Piano Keyboard (uniform rows)
-- Each semitone = full row height (1×RH). White keys get
-- piano_white fill, black keys get piano_black fill. Every
-- row gets label, scale indicator, and active note glow.
-- No piano-style key shaping — uniform grid, like FL Studio
-- or Ableton piano roll.
-- =========================================================

-- Scale note cache (Issue 13 pattern)
local _vpk_scale_root, _vpk_scale_idx
local _vpk_scale_notes, _vpk_note_to_degree = {}, {}

--- Draw the vertical piano keyboard for the visible pitch range.
--- Each semitone row (1×RH) is filled with its key color. All rows are
--- uniform height — no black key overlay, no shorter/narrower keys.
--- Every row gets label + scale indicator + active glow.
--- @param kx,ky,kw,kh Keyboard strip position & size (pixels)
--- @param scroll_y number Vertical scroll offset (unused, kept for API compat)
--- @param top_pitch Highest pitch visible at grid top
function m.DrawVerticalPianoKeyboard(kx, ky, kw, kh, scroll_y, top_pitch)
    local RH = m.PITCH_ROW_H
    local MIN = m.MIN_PITCH

    -- Compute sub-pixel offset for smooth scrolling
    local scroll_int = math.floor(scroll_y)
    local scroll_px_offset = (scroll_y - scroll_int) * RH

    -- Refresh scale cache (Issue 13 pattern)
    if _vpk_scale_root ~= config.state.root_index or _vpk_scale_idx ~= config.state.scale_index then
        _vpk_scale_notes, _vpk_note_to_degree = helpers.ComputeScaleNotes(config.state.root_index, config.state.scale_index)
        _vpk_scale_root, _vpk_scale_idx = config.state.root_index, config.state.scale_index
    end

    -- Active note pitch-class O(1) lookup (Issue 18)
    local am12 = {}
    for mn, _ in pairs(midi_store.GetActiveNotes()) do
        am12[(mn % 12) + 1] = true
    end

    local col = require("ui.colors")

    -- Strip background
    helpers.SetColor({0.06, 0.06, 0.06, 0.95})
    gfx.rect(kx, ky, kw, kh, 1)

    local visible_rows = math.ceil(kh / RH) + 2

    -- ================================================================
    -- PASS 1: Fill every row
    --   White keys: piano_white (or btn_active if root)
    --   Black keys: piano_black (or btn_active if root)
    -- ================================================================
    for row = 0, visible_rows do
        local pitch = top_pitch - row
        if pitch < MIN then break end
        local py = ky + row * RH - scroll_px_offset
        if py >= ky + kh then break end

        -- Clip row height to viewport bottom (prevents overflow into scrollbar area)
        local row_h = math.min(RH, ky + kh - py)
        if row_h <= 0 then break end

        local pc = (pitch % 12) + 1
        local is_white = WHITE_KEY_SET[pitch % 12]
        local root = config.state.root_index == pc

        if is_white then
            helpers.SetColor(root and theme.colors.btn_active or theme.colors.piano_white)
        else
            helpers.SetColor(root and theme.colors.btn_active or theme.colors.piano_black)
        end
        gfx.rect(kx, py, kw, row_h, 1)
    end

    -- ================================================================
    -- PASS 2: Labels + scale indicators + active glow on ALL rows
    -- ================================================================
    local fs = math.min(18, math.max(14, math.floor(RH / 1.2)))
    for row = 0, visible_rows do
        local pitch = top_pitch - row
        if pitch < MIN then break end
        local py = ky + row * RH - scroll_px_offset
        if py >= ky + kh then break end

        -- Clip row height to viewport bottom (same as PASS 1)
        local row_h = math.min(RH, ky + kh - py)
        if row_h <= 0 then break end

        local pc = (pitch % 12) + 1
        local is_white = WHITE_KEY_SET[pitch % 12]
        local sc = _vpk_scale_notes[pc]
        local am = am12[pc]
        local root = config.state.root_index == pc

        -- Scale indicator (right edge)
        if not root and sc then
            helpers.SetColor(col.DegreeColor(_vpk_note_to_degree[pc]), 0.7)
            gfx.rect(kx + kw - 5, py + 1, 3, row_h - 2, 1)
        end

        -- Active note glow
        if not root and am then
            local dg = _vpk_note_to_degree[pc]
            local gl = dg and col.DegreeColor(dg) or {1,1,1,0.3}
            helpers.SetColor(gl, 0.25)
            gfx.rect(kx, py, kw, row_h, 1)
        end

        -- Label
        if row_h >= 8 then
            if is_white then
                helpers.SetColor(root and theme.colors.text or theme.colors.text_dark)
            else
                helpers.SetColor(theme.colors.text)
            end
            gfx.setfont(1, "Calibri", fs)
            local lb = KeyboardNoteLabel(pitch)
            local _, lh = gfx.measurestr(lb)
            gfx.x, gfx.y = kx + 2, py + math.floor((row_h - lh) / 2)
            gfx.drawstr(lb)
        end
    end

    -- ================================================================
    -- Separator lines
    -- ================================================================
    for row = 0, visible_rows do
        local pitch = top_pitch - row
        if pitch < MIN then break end
        local py = ky + row * RH - scroll_px_offset
        if py + RH < ky + kh then
            helpers.SetColor({0.1, 0.1, 0.1, 0.35})
            gfx.line(kx, py + RH, kx + kw, py + RH)
        end
    end

    helpers.SetColor({0.15, 0.15, 0.15, 0.6})
    gfx.line(kx + kw, ky, kx + kw, ky + kh)
end

-- =========================================================
-- DrawPianoRollGrid — Grid Background + Beat Lines
-- =========================================================

--- Draw the piano roll grid background, pitch rows, and beat lines.
--- Uses pre-computed visible ranges for consistency.
--- @param x number Left edge of the grid area (pixel)
--- @param y number Top edge of the grid area (pixel)
--- @param w number Width of the grid area (pixel)
--- @param h number Height of the grid area (pixel)
--- @param scroll_y number Vertical scroll offset in pitch rows
--- @param scroll_x number Horizontal scroll offset in beats
--- @param zoom_x number Pixels per beat
--- @param visible_rows number Pre-computed from ComputeVisibleRanges
--- @param pitch_start number Pre-computed from ComputeVisibleRanges
--- @param pitch_end number Pre-computed from ComputeVisibleRanges
--- @param top_pitch number Pre-computed from ComputeVisibleRanges
function m.DrawPianoRollGrid(x, y, w, h, scroll_y, scroll_x, zoom_x,
                             visible_rows, pitch_start, pitch_end, top_pitch)
    local LABEL_W = m.PITCH_LABEL_W
    local MIN_PITCH = m.MIN_PITCH
    local RH = m.PITCH_ROW_H
    local has_key_strip = (x - LABEL_W) >= 0

    -- Compute sub-pixel offset for smooth scrolling
    local scroll_int = math.floor(scroll_y)
    local scroll_px_offset = (scroll_y - scroll_int) * RH

    -- Draw piano keyboard strip
    if has_key_strip then
        m.DrawVerticalPianoKeyboard(x - LABEL_W, y, LABEL_W, h, scroll_y, top_pitch)
    end

    -- Draw pitch row backgrounds + horizontal lines
    -- py check uses >= to prevent overflow past bounds.
    for row_offset = 0, visible_rows do
        local pitch = top_pitch - row_offset
        if pitch < MIN_PITCH then break end

        local py = y + row_offset * RH - scroll_px_offset
        if py >= y + h then break end

        local is_white = WHITE_KEY_SET[pitch % 12] == true

        -- Row background tint (clamped to remaining height)
        local row_h = math.min(RH, y + h - py)
        helpers.SetColor(is_white and PITCH_ROW_WHITE or PITCH_ROW_DARK)
        gfx.rect(x, py, w, row_h, 1)

        -- Horizontal line at row boundary (skip if it would overflow)
        if py + row_h < y + h then
            helpers.SetColor(PITCH_ROW_BLACK)
            gfx.line(x, py + row_h, x + w, py + row_h)
        end
    end

    -- Draw vertical beat lines (4-tier hierarchy)
    local beat_start = math.max(0, math.floor(scroll_x))
    local beat_end = beat_start + math.ceil(w / zoom_x) + 1

    -- Snap-aware grid filtering (PR2): when snap is enabled, only show grid lines
    -- at the active snap resolution and above (coarser tiers).
    -- e.g., snap at 1/4 (resolution 4) → hide 1/8 and 1/16 subdivision lines.
    local snap_enabled = island_store.GetSnapEnabled()
    local snap_res = snap_enabled and island_store.GetSnapResolution() or 0
    -- Map snap_resolution to minimum beat step to show
    -- snap_res 1 (whole) → step 4.0 (show only measure lines)
    -- snap_res 2 (half)  → step 2.0 (show half/measure)
    -- snap_res 4 (beat)  → step 1.0 (show beat/measure)
    -- snap_res 8 (1/8)   → step 0.5 (show 1/8+)
    -- snap_res 16 (1/16) → step 0.25 (show 1/16+)
    -- snap_res 32 (1/32) → step 0.125 (show all)
    local min_grid_step = 0
    if snap_res > 0 then
        min_grid_step = 4 / snap_res
    end

    -- Measure lines (every 4 beats) — 2px wide via rect for consistent bold (H9)
    helpers.SetColor(theme.colors.grid_measure)
    local first_measure = math.ceil(beat_start / 4) * 4
    for beat = first_measure, beat_end, 4 do
        local bx = x + (beat - scroll_x) * zoom_x
        if bx >= x and bx <= x + w then
            gfx.rect(bx, y, 2, h, 1)
        end
    end

    -- Beat lines (integer beats that are not measures)
    -- Show only if snap allows beat-level (step <= 1.0) OR snap disabled
    if min_grid_step <= 1.0 or min_grid_step == 0 then
        helpers.SetColor(theme.colors.grid_beat)
        for beat = beat_start, beat_end do
            if (beat % 4) ~= 0 then
                local bx = x + (beat - scroll_x) * zoom_x
                if bx >= x and bx <= x + w then
                    gfx.line(bx, y, bx, y + h)
                end
            end
        end
    end

    -- Subdivision lines — filtered by snap resolution when snap enabled
    -- Uses snap_res to determine which tiers to show; falls back to
    -- config.state.subdivision_index when snap is disabled.
    local sub_idx = config.state.subdivision_index or 1
    local subdivision = config.SUBDIVISION_MODES[sub_idx] or 1

    -- When snap is enabled, calculate effective subdivision from snap_res
    local effective_subdivision = subdivision
    if snap_res > 0 then
        -- Convert snap resolution to equivalent subdivision mode:
        --   snap_res   subdivision_mode
        --   1 (whole)      1 (none)
        --   2 (half)       2
        --   4 (beat)       4 (same as 1/16 subdivision) — actually no
        --   ... let's derive from min_grid_step
        if min_grid_step >= 4.0 then
            -- snap at whole note: no subdivision lines
            effective_subdivision = 1
        elseif min_grid_step >= 2.0 then
            -- snap at half note: one line per half-beat
            effective_subdivision = 2
        elseif min_grid_step >= 1.0 then
            -- snap at beat: three subdivision lines per measure
            effective_subdivision = 4
        elseif min_grid_step >= 0.5 then
            -- snap at 1/8: seven lines per measure
            effective_subdivision = 8
        elseif min_grid_step >= 0.25 then
            -- snap at 1/16: fifteen lines per measure
            effective_subdivision = 16
        else
            -- snap at 1/32 or finer: show all
            effective_subdivision = subdivision
        end
    end

    if effective_subdivision > 1 then
        local has_16th_tier = effective_subdivision >= 4
        local first_measure = math.floor(beat_start / 4) * 4
        for measure_start = first_measure, beat_end, 4 do
            for s = 1, effective_subdivision - 1 do
                local sub_beat = measure_start + (s / effective_subdivision) * 4
                -- Skip whole beats — already drawn by beat/measure loops (H3)
                if sub_beat ~= math.floor(sub_beat) and sub_beat >= beat_start and sub_beat <= beat_end then
                    local bx = x + (sub_beat - scroll_x) * zoom_x
                    if bx >= x and bx <= x + w then
                        if has_16th_tier then
                            -- Use snap_grid color when snap is enabled for the active tier
                            if snap_enabled and snap_res > 0 then
                                helpers.SetColor(theme.colors.snap_grid)
                            elseif (s % 2) == 0 then
                                helpers.SetColor(theme.colors.grid_sub_1_8)
                            else
                                helpers.SetColor(theme.colors.grid_sub_1_16)
                            end
                        else
                            helpers.SetColor(theme.colors.grid_sub_1_8)
                        end
                        gfx.line(bx, y, bx, y + h)
                    end
                end
            end
        end
    end
end

-- =========================================================
-- Scroll / Zoom Handlers
-- =========================================================

--- Handle horizontal mouse wheel in piano roll area (timeline-style).
--- @param delta number Mouse wheel delta
--- @param scroll_x number Current horizontal scroll (beats)
--- @param zoom_x number Pixels per beat
--- @return number New horizontal scroll
function m.HandleMouseWheel(delta, scroll_x, zoom_x)
    local scroll_speed = 4 / (zoom_x / 40)  -- base 4 beats at 40px/beat
    local new_scroll = scroll_x + delta * scroll_speed
    return math.max(0, new_scroll)
end

--- Handle horizontal zoom on timeline ruler: adjust zoom_x (pixels per beat).
--- @param delta number Mouse wheel delta
--- @param zoom_x number Current zoom
--- @return number New zoom_x
function m.HandleZoomX(delta, zoom_x)
    local factor = delta > 0 and 1.15 or (1/1.15)
    return math.max(10, math.min(200, math.floor(zoom_x * factor + 0.5)))
end

--- Handle vertical zoom on piano roll: adjust pitch row height.
--- @param delta number Mouse wheel delta
--- @param row_h number Current row height
--- @return number New row height
function m.HandleZoomVertical(delta, row_h)
    local factor = delta > 0 and 1.15 or (1/1.15)
    return math.max(6, math.min(24, math.floor(row_h * factor + 0.5)))
end

--- Set pitch row height. Updates m.PITCH_ROW_H so grid drawing functions
--- see the change immediately.
--- @param h number New height in pixels
function m.SetPitchRowH(h)
    m.PITCH_ROW_H = math.max(6, math.min(24, h))
end

--- Handle vertical mouse wheel in piano roll area: scroll pitch rows.
--- Inverted Y: delta>0 (wheel up) → lower scroll_y → show higher pitches.
--- @param delta number Mouse wheel delta
--- @param scroll_y number Current vertical scroll offset
--- @return number New vertical scroll offset
function m.HandleMouseWheelVertical(delta, scroll_y)
    -- Factor 0.25: ~4px per delta unit (at PITCH_ROW_H=16) for smooth scrolling
    local new_scroll = scroll_y - delta * 0.25
    return math.max(0, new_scroll)
end

return m
