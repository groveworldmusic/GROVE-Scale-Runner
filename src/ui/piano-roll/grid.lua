-- GROVE FL MIDI: Piano Roll Grid
-- Renders the pitch×time grid background, beat lines, and vertical keyboard strip.
-- Extracted from piano-roll.lua monolith (PR1a).
-- Handles: grid drawing, keyboard strip, scroll/zoom handlers, visible range computation.

local config = require("config")
local island_store = require("state.island")
local midi_store = require("state.midi")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")

local m = {}

-- =========================================================
-- Constants
-- =========================================================
m.PITCH_ROW_H = 12          -- Height per pitch row in pixels
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
       and _cache.zoom_x == zoom_x and _cache.w == w and _cache.h == h then
        return _cache.visible_rows, _cache.pitch_start, _cache.pitch_end,
               _cache.top_pitch, _cache.beat_start, _cache.beat_end
    end

    local visible_rows = math.ceil(h / m.PITCH_ROW_H) + 2
    local max_scroll = m.TOTAL_ROWS - visible_rows
    local clamped_scroll = math.max(0, math.min(max_scroll, scroll_y or 0))
    local top_pitch = math.max(m.MIN_PITCH, m.MAX_PITCH - clamped_scroll)
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
    _cache.visible_rows = visible_rows
    _cache.pitch_start = pitch_start
    _cache.pitch_end = pitch_end
    _cache.top_pitch = top_pitch
    _cache.beat_start = beat_start
    _cache.beat_end = beat_end

    return visible_rows, pitch_start, pitch_end, top_pitch, beat_start, beat_end
end

-- =========================================================
-- Vertical Keyboard Strip (per-row key)
-- =========================================================

--- Pre-computed scale note cache for vertical keyboard (reused per frame).
--- Matches piano.lua's Issue 13 pattern.
local _kb_scale_root = nil
local _kb_scale_idx = nil
local _kb_scale_notes = {}
local _kb_note_to_degree = {}

--- Draw a single vertical piano key in the keyboard strip, matching the style
--- of piano.lua's DrawPianoKeyboard (rounded rects, root highlight, scale
--- indicators, active note glow).
--- White keys: full row height, piano_white fill, rounded rect.
--- Black keys: narrow (50% width) dark section on the left, 1px shorter
--- above and below so the background shows through.
--- @param kx number Left edge of the key strip (pixel)
--- @param ky number Top edge of the row (pixel)
--- @param kw number Width of the key strip (pixels)
--- @param kh number Height of the row (pixels)
--- @param pitch number MIDI pitch number
function m.DrawVerticalKeyboard(kx, ky, kw, kh, pitch)
    local pc = (pitch % 12) + 1  -- 1-indexed: 1=C, 2=C#, ..., 12=B
    local is_white = WHITE_KEY_SET[pitch % 12] == true
    local is_root = (config.state.root_index == pc)

    -- Refresh scale note cache when root/scale changes (Issue 13 pattern)
    if _kb_scale_root ~= config.state.root_index or _kb_scale_idx ~= config.state.scale_index then
        _kb_scale_notes = {}
        _kb_note_to_degree = {}
        local intervals = config.SCALES[config.state.scale_index].intervals
        for degree, interval in ipairs(intervals) do
            local note_idx = ((config.state.root_index - 1 + interval) % 12) + 1
            _kb_scale_notes[note_idx] = true
            _kb_note_to_degree[note_idx] = degree
        end
        _kb_scale_root = config.state.root_index
        _kb_scale_idx = config.state.scale_index
    end
    local in_scale = _kb_scale_notes[pc] == true

    -- Active note check (Issue 18 pattern)
    local active_notes = midi_store.GetActiveNotes()
    local is_active = active_notes and active_notes[pitch] ~= nil

    local colors = require("ui.colors")

    if is_white then
        -- White key: full strip width, rounded rect
        if is_root then
            helpers.SetColor(theme.colors.btn_active)
            components.DrawRoundedRect(kx, ky, kw, kh, 3, true)
        else
            helpers.SetColor(theme.colors.piano_white)
            components.DrawRoundedRect(kx, ky, kw, kh, 3, true)
            -- Scale note indicator: VERTICAL bar on the RIGHT side of the key
            if in_scale then
                local deg = _kb_note_to_degree[pc]
                helpers.SetColor(colors.DegreeColor(deg), 0.7)
                gfx.rect(kx + kw - 5, ky + 4, 3, kh - 8, 1)
            end
        end

        -- Active note glow (semi-transparent overlay)
        if not is_root and is_active then
            local deg = _kb_note_to_degree[pc]
            local glow = deg and colors.DegreeColor(deg) or {1, 1, 1, 0.3}
            helpers.SetColor(glow, 0.25)
            components.DrawRoundedRect(kx, ky, kw, kh, 3, true)
        end

        -- Subtle outline for row-to-row separation
        local outline_alpha = is_root and 0.4 or 0.25
        helpers.SetColor({0.12, 0.12, 0.12, outline_alpha})
        components.DrawRoundedRect(kx, ky, kw, kh, 3, false)

        -- Note label on white keys
        local font_size = math.min(10, math.max(7, math.floor(kh / 2)))
        helpers.SetColor(is_root and theme.colors.text or theme.colors.text_dark)
        gfx.setfont(1, "Calibri", font_size)
        local label = KeyboardNoteLabel(pitch)
        local lw, lh = gfx.measurestr(label)
        if kh >= 8 then
            gfx.x, gfx.y = kx + (kw - lw) / 2, ky + (kh - lh) / 2
            gfx.drawstr(label)
        end
    else
        -- Black key: narrower (45% of kw), drawn SPANNING 1px into adjacent rows
        local span = 1
        local bk_w = math.max(1, math.floor(kw * 0.45))
        local bk_h = kh + 2 * span
        local bk_y = ky - span
        local bk_x = kx

        -- White continuation on the RIGHT side
        helpers.SetColor(theme.colors.piano_white)
        gfx.rect(kx + bk_w, ky, kw - bk_w, kh, 1)

        if is_root then
            helpers.SetColor(theme.colors.btn_active)
            components.DrawRoundedRect(bk_x, bk_y, bk_w, bk_h, 2, true)
        else
            helpers.SetColor(theme.colors.piano_black)
            components.DrawRoundedRect(bk_x, bk_y, bk_w, bk_h, 2, true)
            -- Scale note indicator at right border of black key section
            if in_scale then
                local deg = _kb_note_to_degree[pc]
                helpers.SetColor(colors.DegreeColor(deg), 0.7)
                gfx.rect(bk_x + bk_w - 5, bk_y + 3, 2, bk_h - 6, 1)
            end
        end

        -- Active note glow for black keys
        if not is_root and is_active then
            local deg = _kb_note_to_degree[pc]
            local glow = deg and colors.DegreeColor(deg) or {1, 1, 1, 0.3}
            helpers.SetColor(glow, 0.3)
            components.DrawRoundedRect(bk_x, bk_y, bk_w, bk_h, 2, true)
        end

        -- Note label on black keys
        local bk_font = math.min(8, math.max(6, math.floor(kh / 2) - 1))
        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", bk_font)
        local label = KeyboardNoteLabel(pitch)
        local lw, lh = gfx.measurestr(label)
        if kh >= 10 then
            gfx.x, gfx.y = bk_x + (bk_w - lw) / 2, (ky + kh / 2) - lh / 2
            gfx.drawstr(label)
        end
    end

    -- Key strip right edge separator
    helpers.SetColor({0.15, 0.15, 0.15, 0.6})
    gfx.line(kx + kw, ky, kx + kw, ky + kh)
end

-- =========================================================
-- Vertical Piano Keyboard (rotated 90° CCW from piano.lua)
-- Two-pass: white keys first (PASS 1), black keys overlay (PASS 2).
-- =========================================================
local VPK_WHITE_PCS = {1, 3, 5, 6, 8, 10, 12}  -- 1-idx pitch classes
local VPK_BLACK_PCS = {2, 4, 7, 9, 11}          -- 1-idx pitch classes

-- Scale note cache (Issue 13 pattern)
local _vpk_scale_root, _vpk_scale_idx
local _vpk_scale_notes, _vpk_note_to_degree = {}, {}

--- Draw the vertical piano keyboard for the visible pitch range.
--- @param kx,ky,kw,kh Keyboard strip position & size (pixels)
--- @param scroll_y Vertical scroll offset in pitch rows
--- @param top_pitch Highest pitch visible at grid top
function m.DrawVerticalPianoKeyboard(kx, ky, kw, kh, scroll_y, top_pitch)
    local RH = m.PITCH_ROW_H
    local MIN = m.MIN_PITCH
    local MAX = m.MAX_PITCH
    local WHITE_H = 12 * RH / 7  -- ~1.714× RH
    local BK_W = math.max(1, math.floor(kw * 0.40))  -- narrower, left side
    local BK_H = math.max(1, math.floor(WHITE_H * 0.65))  -- shorter than white

    -- Refresh scale cache (Issue 13)
    if _vpk_scale_root ~= config.state.root_index or _vpk_scale_idx ~= config.state.scale_index then
        _vpk_scale_notes, _vpk_note_to_degree = {}, {}
        for d, iv in ipairs(config.SCALES[config.state.scale_index].intervals) do
            local ni = ((config.state.root_index - 1 + iv) % 12) + 1
            _vpk_scale_notes[ni], _vpk_note_to_degree[ni] = true, d
        end
        _vpk_scale_root, _vpk_scale_idx = config.state.root_index, config.state.scale_index
    end

    -- Active note pitch-class O(1) lookup (Issue 18)
    local am12 = {}
    for mn, _ in pairs(midi_store.GetActiveNotes()) do
        am12[(mn % 12) + 1] = true
    end

    local col = require("ui.colors")

    -- Strip background (dark; gaps between white keys show this color)
    helpers.SetColor({0.06, 0.06, 0.06, 0.95})
    gfx.rect(kx, ky, kw, kh, 1)

    -- Find visible octave range
    local lo, hi = 9, -1
    for o = 0, 8 do
        local oct_top = ky + (top_pitch - (MIN + o * 12 + 11)) * RH - WHITE_H / 2
        local oct_bot = ky + (top_pitch - (MIN + o * 12)) * RH + WHITE_H / 2
        if oct_bot >= ky and oct_top <= ky + kh then
            if o < lo then lo = o end
            if o > hi then hi = o end
        end
    end
    if lo > hi then lo, hi = 0, 0 end

    -- ========================
    -- PASS 1: White keys
    -- ========================
    for o = lo, hi do
        for _, pc in ipairs(VPK_WHITE_PCS) do
            local mn = MIN + o * 12 + (pc - 1)
            if mn < MIN or mn > MAX then goto pw end

            local cy = ky + (top_pitch - mn) * RH
            local kw_h = WHITE_H - 2  -- 1px gap top/bottom
            local wy = cy - WHITE_H / 2 + 1
            if wy + kw_h < ky or wy > ky + kh then goto pw end

            local root = config.state.root_index == pc
            local sc = _vpk_scale_notes[pc]

            -- Fill
            helpers.SetColor(root and theme.colors.btn_active or theme.colors.piano_white)
            components.DrawRoundedRect(kx, wy, kw, kw_h, 3, true)

            -- Subtle outline
            helpers.SetColor({0.1, 0.1, 0.1, 0.35})
            components.DrawRoundedRect(kx, wy, kw, kw_h, 3, false)

            -- Scale indicator (right side vertical bar)
            if not root and sc then
                helpers.SetColor(col.DegreeColor(_vpk_note_to_degree[pc]), 0.7)
                gfx.rect(kx + kw - 5, wy + 3, 3, kw_h - 6, 1)
            end

            -- Active note glow
            if not root and am12[pc] then
                local dg = _vpk_note_to_degree[pc]
                local gl = dg and col.DegreeColor(dg) or {1,1,1,0.3}
                helpers.SetColor(gl, 0.25)
                components.DrawRoundedRect(kx, wy, kw, kw_h, 3, true)
            end

            -- Label (left side)
            local fs = math.min(10, math.max(7, math.floor(WHITE_H / 2.5)))
            helpers.SetColor(root and theme.colors.text or theme.colors.text_dark)
            gfx.setfont(1, "Calibri", fs)
            local lb = KeyboardNoteLabel(mn)
            local _, lh = gfx.measurestr(lb)
            if kw_h >= 8 then gfx.x, gfx.y = kx + 2, wy + (kw_h - lh) / 2; gfx.drawstr(lb) end

            ::pw::
        end
    end

    -- ========================
    -- PASS 2: Black keys (overlay on top)
    -- ========================
    for o = lo, hi do
        for _, pc in ipairs(VPK_BLACK_PCS) do
            local mn = MIN + o * 12 + (pc - 1)
            if mn < MIN or mn > MAX then goto pb end

            local cy = ky + (top_pitch - mn) * RH
            local bk_h = BK_H - 2  -- 1px gap top/bottom
            local by = cy - BK_H / 2 + 1
            if by + bk_h < ky or by > ky + kh then goto pb end

            local root = config.state.root_index == pc
            local sc = _vpk_scale_notes[pc]

            -- Black key fill
            helpers.SetColor(root and theme.colors.btn_active or theme.colors.piano_black)
            components.DrawRoundedRect(kx, by, BK_W, bk_h, 2, true)

            -- Subtle outline
            helpers.SetColor({0.1, 0.1, 0.1, 0.35})
            components.DrawRoundedRect(kx, by, BK_W, bk_h, 2, false)

            -- Scale indicator (right border of black key section)
            if not root and sc then
                local dg = _vpk_note_to_degree[pc]
                helpers.SetColor(col.DegreeColor(dg), 0.7)
                gfx.rect(kx + BK_W - 5, by + 2, 2, bk_h - 4, 1)
            end

            -- Active note glow
            if not root and am12[pc] then
                local dg = _vpk_note_to_degree[pc]
                local gl = dg and col.DegreeColor(dg) or {1,1,1,0.3}
                helpers.SetColor(gl, 0.3)
                components.DrawRoundedRect(kx, by, BK_W, bk_h, 2, true)
            end

            -- Label
            local fs = math.min(8, math.max(6, math.floor(WHITE_H / 2.5) - 1))
            helpers.SetColor(theme.colors.text)
            gfx.setfont(1, "Calibri", fs)
            local lb = KeyboardNoteLabel(mn)
            local _, lh = gfx.measurestr(lb)
            if bk_h >= 8 then gfx.x, gfx.y = kx + 2, by + (bk_h - lh) / 2; gfx.drawstr(lb) end

            ::pb::
        end
    end

    -- Separator line between keyboard and grid
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
    local has_key_strip = (x - LABEL_W) >= 0

    -- Draw piano keyboard strip
    if has_key_strip then
        m.DrawVerticalPianoKeyboard(x - LABEL_W, y, LABEL_W, h, scroll_y, top_pitch)
    end

    -- Draw pitch row backgrounds + horizontal lines
    for row_offset = 0, visible_rows do
        local pitch = top_pitch - row_offset
        if pitch < MIN_PITCH then break end

        local py = y + row_offset * m.PITCH_ROW_H
        if py > y + h then break end

        local is_white = WHITE_KEY_SET[pitch % 12] == true

        -- Row background tint
        helpers.SetColor(is_white and PITCH_ROW_WHITE or PITCH_ROW_DARK)
        gfx.rect(x, py, w, m.PITCH_ROW_H, 1)

        -- Horizontal line (bottom of each row)
        helpers.SetColor(PITCH_ROW_BLACK)
        gfx.line(x, py + m.PITCH_ROW_H, x + w, py + m.PITCH_ROW_H)
    end

    -- Draw vertical beat lines (4-tier hierarchy)
    local beat_start = math.max(0, math.floor(scroll_x))
    local beat_end = beat_start + math.ceil(w / zoom_x) + 1

    -- Measure lines (every 4 beats)
    helpers.SetColor(theme.colors.grid_measure)
    local first_measure = math.ceil(beat_start / 4) * 4
    for beat = first_measure, beat_end, 4 do
        local bx = x + (beat - scroll_x) * zoom_x
        if bx >= x and bx <= x + w then
            gfx.line(bx, y, bx, y + h)
            gfx.line(bx + 1, y, bx + 1, y + h)  -- second pass for bold
        end
    end

    -- Beat lines (integer beats that are not measures)
    helpers.SetColor(theme.colors.grid_beat)
    for beat = beat_start, beat_end do
        if (beat % 4) ~= 0 then
            local bx = x + (beat - scroll_x) * zoom_x
            if bx >= x and bx <= x + w then
                gfx.line(bx, y, bx, y + h)
            end
        end
    end

    -- Subdivision lines (4-tier: 1/8, 1/16)
    local sub_idx = config.state.subdivision_index or 1
    local subdivision = config.SUBDIVISION_MODES[sub_idx] or 1
    if subdivision > 1 then
        local has_16th_tier = subdivision >= 4
        local first_measure = math.floor(beat_start / 4) * 4
        for measure_start = first_measure, beat_end, 4 do
            for s = 1, subdivision - 1 do
                local sub_beat = measure_start + (s / subdivision) * 4
                if sub_beat >= beat_start and sub_beat <= beat_end then
                    local bx = x + (sub_beat - scroll_x) * zoom_x
                    if bx >= x and bx <= x + w then
                        if has_16th_tier then
                            helpers.SetColor((s % 2) == 0 and theme.colors.grid_sub_1_8 or theme.colors.grid_sub_1_16)
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
    local new_scroll = scroll_y - delta
    return math.max(0, new_scroll)
end

return m
