-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Piano Roll Grid
-- Renders the pitch×time grid background, beat lines, and vertical keyboard strip.
-- Extracted from piano-roll.lua monolith (PR1a).
-- Handles: grid drawing, keyboard strip, scroll/zoom handlers, visible range computation.

local config = require("config")
local island_store = require("state.island")
local midi_store = require("state.midi")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local prefs = require("state.preferences")
local midi = require("core.midi")

local m = {}

-- =========================================================
-- Constants
-- =========================================================
m.PITCH_ROW_H = 16          -- Height per pitch row in pixels
m.PITCH_LABEL_W = 48        -- Width of pitch labels on the left (keyboard strip)
m.MIN_PITCH = 12            -- C0
m.MAX_PITCH = 119           -- B8 (octava 8 completa)
m.TOTAL_ROWS = 108          -- 119 - 12 + 1 (C0 a B8)
m.OCTAVE_BUFFER = 4         -- Reduced from 12: with Y clip guard, only need 1-2 rows for edge stability (PR: revision-isla-midi-bugs)

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

-- Piano key playable state: tracks currently pressed key for note-on/off
local _pressed_key_pitch = nil  -- MIDI pitch of the currently pressed key, or nil

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

    local visible_viewport_rows = h / m.PITCH_ROW_H
    local visible_rows = math.ceil(visible_viewport_rows) + 2
    local max_scroll = m.TOTAL_ROWS - visible_viewport_rows
    local clamped_scroll = math.max(0, math.min(max_scroll, scroll_y or 0))
    -- Floor clamped_scroll so top_pitch is always an integer pitch
    local top_pitch = math.max(m.MIN_PITCH, m.MAX_PITCH - math.floor(clamped_scroll))
    local pitch_start = math.max(m.MIN_PITCH, top_pitch - visible_rows - m.OCTAVE_BUFFER)
    local pitch_end = math.min(m.MAX_PITCH, top_pitch + m.OCTAVE_BUFFER)
    local beat_start = math.max(0, scroll_x - 1)  -- Clamp: never negative at extreme scroll positions (PR: revision-isla-midi-bugs)
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
    if _vpk_scale_root ~= prefs.GetRootIndex() or _vpk_scale_idx ~= prefs.GetScaleIndex() then
        _vpk_scale_notes, _vpk_note_to_degree = helpers.ComputeScaleNotes(prefs.GetRootIndex(), prefs.GetScaleIndex())
        _vpk_scale_root, _vpk_scale_idx = prefs.GetRootIndex(), prefs.GetScaleIndex()
    end

    -- Active note pitch-class O(1) lookup (Issue 18)
    local am12 = {}
    for mn, _ in pairs(midi_store.GetActiveNotes()) do
        am12[(mn % 12) + 1] = true
    end

    local col = require("ui.colors")

    -- Strip background (blend with preset panel when visible)
    if island_store.GetPresetPanelVisible() then
        helpers.SetColor(theme.colors.island_panel_bg)
    else
        helpers.SetColor({0.06, 0.06, 0.06, 0.95})
    end
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
        
        -- Clip row height to viewport TOP and BOTTOM
        if py + RH > ky and py < ky + kh then
            local clip_y = math.max(ky, py)
            local clip_h = math.min(py + RH, ky + kh) - clip_y
            
            if clip_h > 0 then
                local pc = (pitch % 12) + 1
                local is_white = WHITE_KEY_SET[pitch % 12]
                local root = prefs.GetRootIndex() == pc

                if is_white then
                    helpers.SetColor(root and theme.colors.btn_active or theme.colors.piano_white)
                else
                    helpers.SetColor(root and theme.colors.btn_active or theme.colors.piano_black)
                end
                gfx.rect(kx, clip_y, kw, clip_h, 1)
            end
        end
    end

    -- ================================================================
    -- PASS 2: Labels + scale indicators + active glow on ALL rows
    -- ================================================================
    local fs = math.min(18, math.max(14, math.floor(RH / 1.2)))
    for row = 0, visible_rows do
        local pitch = top_pitch - row
        if pitch < MIN then break end
        local py = ky + row * RH - scroll_px_offset
        
        -- Clip row height to viewport TOP and BOTTOM
        if py + RH > ky and py < ky + kh then
            local clip_y = math.max(ky, py)
            local clip_h = math.min(py + RH, ky + kh) - clip_y

            if clip_h > 0 then
                local pc = (pitch % 12) + 1
                local is_white = WHITE_KEY_SET[pitch % 12]
                local sc = _vpk_scale_notes[pc]
                local am = am12[pc]
                local root = prefs.GetRootIndex() == pc

                -- Scale indicator (right edge)
                if not root and sc then
                    helpers.SetColor(col.DegreeColor(_vpk_note_to_degree[pc]), 0.7)
                    gfx.rect(kx + kw - 5, clip_y + 1, 3, clip_h - 2, 1)
                end

                -- Active note glow
                if not root and am then
                    local dg = _vpk_note_to_degree[pc]
                    local gl = dg and col.DegreeColor(dg) or {1,1,1,0.3}
                    helpers.SetColor(gl, 0.25)
                    gfx.rect(kx, clip_y, kw, clip_h, 1)
                end

                -- Label
                if clip_h >= 8 then
                    if is_white then
                        helpers.SetColor(root and theme.colors.text or theme.colors.text_dark)
                    else
                        helpers.SetColor(theme.colors.text)
                    end
                    gfx.setfont(1, "Calibri", fs)
                    local lb = KeyboardNoteLabel(pitch)
                    local _, lh = gfx.measurestr(lb)
                    -- For label center, use py (the row's actual y) instead of clip_y
                    -- but ensure it's visually clipped if half-visible
                    local ty = py + math.floor((RH - lh) / 2)
                    if ty >= ky and ty + lh <= ky + kh then
                        gfx.x, gfx.y = kx + 2, ty
                        gfx.drawstr(lb)
                    end
                end
            end
        end
    end

    -- ================================================================
    -- Separator lines
    -- ================================================================
    for row = 0, visible_rows do
        local pitch = top_pitch - row
        if pitch < MIN then break end
        local py = ky + row * RH - scroll_px_offset
        if py + RH > ky and py + RH < ky + kh then
            helpers.SetColor({0.1, 0.1, 0.1, 0.35})
            gfx.line(kx, py + RH, kx + kw, py + RH)
        end
    end

    helpers.SetColor({0.15, 0.15, 0.15, 0.6})
    gfx.line(kx + kw, ky, kx + kw, ky + kh)

    -- ================================================================
    -- PASS 3: Mouse interaction — playable piano keys
    -- Detect mouse position relative to the keyboard strip, find the
    -- corresponding pitch, and send note-on/off on press/release.
    -- Visual feedback: pressed key gets a 40% lighter overlay.
    -- ================================================================
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local in_key_strip = mx >= kx and mx < kx + kw and my >= ky and my < ky + kh

    if in_key_strip then
        -- Find pitch at mouse Y (inverted: higher pitch = lower Y)
        local row = math.floor((my - ky + scroll_px_offset) / RH)
        local hover_pitch = math.max(MIN, top_pitch - row)

        if hover_pitch >= MIN and hover_pitch <= m.MAX_PITCH then
            -- Left mouse button pressed this frame (transition from not held to held)
            local left_down = (gfx.mouse_cap & 1) == 1

            if left_down and _pressed_key_pitch == nil then
                -- Note-on: ref-counted via midi_store (PR: revision-isla-midi-bugs)
                -- Use direct midi_store pattern to participate in ref-counted active notes
                -- so keyboard strip + pads + QWERTY don't conflict on note-off.
                local cur = midi_store.GetActiveNote(hover_pitch)
                midi_store.SetActiveNote(hover_pitch, (cur or 0) + 1)
                reaper.StuffMIDIMessage(midi.midi_channel - 1, 0x90, hover_pitch, 127)
                _pressed_key_pitch = hover_pitch
            end

            -- Draw hover/pressed visual feedback
            if _pressed_key_pitch == hover_pitch or (left_down and _pressed_key_pitch == nil) then
                local py = ky + row * RH - scroll_px_offset
                local clip_y = math.max(ky, py)
                local clip_h = math.min(py + RH, ky + kh) - clip_y
                if clip_h > 0 then
                    helpers.SetColor({1, 1, 1, 0.4})
                    gfx.rect(kx, clip_y, kw, clip_h, 1)
                end
            end
        end
    end

    -- Note-off helper: decrement ref-count, send 0x80 only when count reaches 0
    local function ReleasePitch(pitch)
        local cur = midi_store.GetActiveNote(pitch)
        if cur then
            cur = cur - 1
            if cur <= 0 then
                midi_store.SetActiveNote(pitch, nil)
                reaper.StuffMIDIMessage(midi.midi_channel - 1, 0x80, pitch, 0)
            else
                midi_store.SetActiveNote(pitch, cur)
            end
        end
    end

    -- Note-off: detect mouse release (no longer held) while a key was pressed
    local left_held = (gfx.mouse_cap & 1) == 1
    if _pressed_key_pitch ~= nil and not left_held then
        ReleasePitch(_pressed_key_pitch)
        _pressed_key_pitch = nil
    end

    -- Also release the pressed key if mouse leaves the strip
    if _pressed_key_pitch ~= nil and not in_key_strip and not left_held then
        ReleasePitch(_pressed_key_pitch)
        _pressed_key_pitch = nil
    end
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

    -- Refresh scale cache (Issue 13 pattern)
    if _vpk_scale_root ~= prefs.GetRootIndex() or _vpk_scale_idx ~= prefs.GetScaleIndex() then
        _vpk_scale_notes, _vpk_note_to_degree = helpers.ComputeScaleNotes(prefs.GetRootIndex(), prefs.GetScaleIndex())
        _vpk_scale_root, _vpk_scale_idx = prefs.GetRootIndex(), prefs.GetScaleIndex()
    end

    -- Draw pitch row backgrounds + horizontal lines
    -- py check uses >= to prevent overflow past bounds.
    for row_offset = 0, visible_rows do
        local pitch = top_pitch - row_offset
        if pitch < MIN_PITCH then break end

        local py = y + row_offset * RH - scroll_px_offset
        if py >= y + h then break end

        local pc = (pitch % 12) + 1
        local is_in_scale = _vpk_scale_notes[pc]
        local is_white = WHITE_KEY_SET[pitch % 12] == true

        -- Row background tint (clamped to remaining height)
        local row_h = math.min(RH, y + h - py)
        
        -- Base color
        helpers.SetColor(is_white and PITCH_ROW_WHITE or PITCH_ROW_DARK)
        gfx.rect(x, py, w, row_h, 1)
        
        -- Scale highlighting (Phase 5)
        if is_in_scale then
            helpers.SetColor(theme.colors.grid_scale_row)
            gfx.rect(x, py, w, row_h, 1)
        elseif not is_white then
            -- Black keys outside scale get an extra tint
            helpers.SetColor(theme.colors.grid_black_key_row)
            gfx.rect(x, py, w, row_h, 1)
        end

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
    -- Normalize snap_res to nearest power-of-2 first so triplet (3) and other non-standard
    -- values map to a valid grid tier (PR: revision-isla-midi-bugs).
    local min_grid_step = 0
    if snap_res > 0 then
        local norm = 1
        while norm * 2 <= snap_res do norm = norm * 2 end
        min_grid_step = 4 / norm
    end

    -- Measure lines (every 4 beats) — 2px wide via rect for consistent bold (H9)
    helpers.SetColor(theme.colors.grid_measure)
    local first_measure = math.ceil(beat_start / 4) * 4
    for beat = first_measure, beat_end, 4 do
        local bx = x + (beat - scroll_x) * zoom_x
        -- Guard: 2px rect at the rightmost boundary would overflow past grid edge (PR: revision-isla-midi-bugs)
        if bx >= x and bx + 2 <= x + w then
            gfx.rect(bx, y, 2, h, 1)
        end
    end

    -- Beat lines (integer beats that are not measures)
    -- Show only if snap allows beat-level (step <= 1.0) OR snap disabled
    -- When scale snap highlight is enabled, lines at beat positions whose pitch
    -- class matches the current scale get a distinct green tint.
    if min_grid_step <= 1.0 or min_grid_step == 0 then
        for beat = beat_start, beat_end do
            if (beat % 4) ~= 0 then
                local bx = x + (beat - scroll_x) * zoom_x
                if bx >= x and bx <= x + w then
                    local scale_snap = prefs.GetScaleSnapHighlight() and _vpk_scale_notes[(beat % 12) + 1]
                    helpers.SetColor(scale_snap and theme.colors.grid_scale_snap or theme.colors.grid_beat)
                    gfx.line(bx, y, bx, y + h)
                end
            end
        end
    end

    -- Subdivision lines — filtered by snap resolution when snap enabled
    -- Uses snap_res to determine which tiers to show; falls back to
    -- config.state.subdivision_index when snap is disabled.
    local sub_idx = prefs.GetSubdivisionIndex() or 1
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
                                -- Check scale snap highlight for 1/8 subdivision lines
                                if prefs.GetScaleSnapHighlight() and _vpk_scale_notes[(math.floor(sub_beat) % 12) + 1] then
                                    helpers.SetColor(theme.colors.grid_scale_snap)
                                else
                                    helpers.SetColor(theme.colors.grid_sub_1_8)
                                end
                            else
                                helpers.SetColor(theme.colors.grid_sub_1_16)
                            end
                        else
                            -- Check scale snap highlight for coarser subdivision lines
                            if prefs.GetScaleSnapHighlight() and _vpk_scale_notes[(math.floor(sub_beat) % 12) + 1] then
                                helpers.SetColor(theme.colors.grid_scale_snap)
                            else
                                helpers.SetColor(theme.colors.grid_sub_1_8)
                            end
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

--- Invalidate the visible ranges cache so it recomputes on next call.
--- Exported for use by midi-island auto-focus when programmatically changing zoom/scroll.
function m.InvalidateVisibleRangesCache()
    _cache.scroll_y = nil
    _cache.scroll_x = nil
    _cache.zoom_x = nil
    _cache.w = nil
    _cache.h = nil
    _cache.pitch_row_h = nil
end

--- Set pitch row height. Updates m.PITCH_ROW_H so grid drawing functions
--- see the change immediately. Invalidates the visible ranges cache when
--- the value actually changes.
--- @param h number New height in pixels
function m.SetPitchRowH(h)
    local clamped = math.max(6, math.min(24, h))
    if clamped ~= m.PITCH_ROW_H then
        m.PITCH_ROW_H = clamped
        m.InvalidateVisibleRangesCache()
    end
end

--- Handle vertical mouse wheel in piano roll area: scroll pitch rows.
--- Inverted Y: delta>0 (wheel up) → lower scroll_y → show higher pitches.
--- @param delta number Mouse wheel delta
--- @param scroll_y number Current vertical scroll offset
--- @return number New vertical scroll offset
function m.HandleMouseWheelVertical(delta, scroll_y)
    -- Factor 0.08: ~1.3px per delta unit (at PITCH_ROW_H=16).
    -- REAPER gfx.mouse_wheel: ±1 (smooth), ±3 (mechanical notch), ±6+ (fast).
    -- With sub-pixel positioning, each frame moves < 5px for true fluid scroll.
    local new_scroll = scroll_y - delta * 0.08
    return math.max(0, new_scroll)
end

return m
