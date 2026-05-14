-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Piano Roll Note Blocks
-- Renders note blocks with gradient strips and velocity-based opacity.
-- Handles hit testing, rect selection, and dirty cache.
-- Extracted from piano-roll.lua monolith (PR1a).

local config = require("config")
local island_store = require("state.island")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local grid = require("ui.piano-roll.grid")

local m = {}

-- =========================================================
-- Color constants
-- =========================================================
local NOTE_SELECTED_BORDER = {1, 1, 1, 0.8}
local NOTE_MUTED = {0.4, 0.4, 0.4, 0.4}
local NOTE_MUTED_OPAQUE = {0.4, 0.4, 0.4, 1.0}

local WHITE_KEY_PCS = {[0]=true, [2]=true, [4]=true, [5]=true, [7]=true, [9]=true, [11]=true}
local NOTE_WHITE = {0.55, 0.72, 0.88, 0.92}  -- light blue-gray for white keys
local NOTE_BLACK = {0.22, 0.38, 0.55, 0.92}  -- deeper blue for black keys

-- =========================================================
-- Internal helpers
-- =========================================================

--- Note block color: white keys get a lighter shade, black keys a darker shade.
local function NoteColorForPitch(pitch)
    local pc = pitch % 12
    if WHITE_KEY_PCS[pc] then
        return NOTE_WHITE
    else
        return NOTE_BLACK
    end
end

--- Get the octave name for a pitch number.
local function OctaveLabel(pitch)
    local octave = math.floor(pitch / 12) - 1
    local note_names = config.NOTE_NAMES
    return note_names[(pitch % 12) + 1] .. tostring(octave)
end

-- =========================================================
-- Note block gradient rendering
-- =========================================================

--- Draw a note block with vertical gradient strips and velocity-based opacity.
--- Muted notes: full alpha, flat fill using NOTE_MUTED color, no gradient.
--- Non-muted: 3-4 vertical strips (top lighter → bottom darker), velocity→alpha.
--- @param nx number Pixel x
--- @param ny number Pixel y
--- @param nw number Pixel width
--- @param nh number Pixel height (row height)
--- @param pitch number MIDI pitch (for white/black key color selection)
--- @param velocity number 0-127
--- @param muted boolean
local function DrawNoteWithGradient(nx, ny, nw, nh, pitch, velocity, muted)
    if muted then
        helpers.SetColor(NOTE_MUTED_OPAQUE)
        components.DrawRoundedRect(nx + 1, ny + 1, math.max(1, nw - 2), math.max(1, nh - 2), 3, true)
        return
    end

    local base_color = NoteColorForPitch(pitch)
    local vel_alpha = 0.35 + (velocity / 127) * 0.65
    local strips = math.max(1, math.floor(nh / 4))
    
    -- Optimization: Draw all strips into the alpha-safe buffer in one go
    -- We'll use components.DrawRoundedRect's logic but manually here to avoid multiple blits
    helpers.SetColor({base_color[1], base_color[2], base_color[3], vel_alpha})
    
    -- Instead of calling DrawRoundedRect per strip, we draw the WHOLE note 
    -- as one supersampled block, and then we'll overlay the strips if needed.
    -- Or simpler: use DrawRoundedRect for the base and draw simple opaque rects for strips.
    
    -- Let's use DrawRoundedRect for the background and then draw the gradient strips
    components.DrawRoundedRect(nx + 1, ny + 1, math.max(1, nw - 2), math.max(1, nh - 2), 3, true)
    
    -- Add subtle gradient overlays (Draw directly since base is already blitted with alpha)
    -- We use gfx.mode = 1 (additive) or just lower alpha to avoid destroying the corners
    for i = 0, strips - 1 do
        local t = i / strips
        local darken = 0.1 - t * 0.2 -- subtle darkening
        if math.abs(darken) > 0.01 then
            gfx.set(0, 0, 0, math.abs(darken))
            gfx.mode = (darken > 0) and 1 or 0 -- additive for highlight, normal for shadow
            local sy = ny + math.floor(i * nh / strips)
            local ey = ny + math.floor((i + 1) * nh / strips)
            gfx.rect(nx + 2, sy + 1, math.max(1, nw - 4), ey - sy - 1, 1)
        end
    end
    gfx.mode = 0
end

-- =========================================================
-- Exported Functions
-- =========================================================

--- Draw a single note block with gradient and velocity opacity.
--- @param note table {pitch, start_beat, duration, velocity, muted}
--- @param nx number Pixel x (already computed)
--- @param ny number Pixel y (already computed)
--- @param nw number Pixel width (already computed)
--- @param nh number Pixel height (row height)
--- @param selected boolean Whether this note is selected
function m.DrawNoteBlock(note, nx, ny, nw, nh, selected)
    if nw < 1 or nh < 1 then return end

    -- Draw gradient note (handles muted internally)
    DrawNoteWithGradient(nx, ny, nw, nh, note.pitch, note.velocity or 100, note.muted)

    -- Selected note: draw a bright border
    if selected then
        helpers.SetColor(NOTE_SELECTED_BORDER)
        gfx.roundrect(nx + 1, ny + 1, math.max(1, nw - 2), math.max(1, nh - 2), 3, 0)
    end

    -- Note label (only when wide enough)
    if nw > 30 then
        local label = OctaveLabel(note.pitch)
        local fs = math.min(20, math.max(16, nh - 1))
        gfx.setfont(1, "Calibri", fs)
        local lw, lh = gfx.measurestr(label)
        helpers.SetColor(theme.colors.text_dark)
        gfx.x, gfx.y = nx + (nw - lw) / 2, ny + (nh - lh) / 2
        gfx.drawstr(label)
    end
end

--- Mark note cache as dirty (call when notes change externally).
--- Kept for external callers; internal drawing always renders each frame
--- because the framebuffer is cleared by DrawFullView's background fill.
function m.MarkNotesDirty()
    -- Intentionally empty — notes always redraw.
    -- Cache was removed in PR1a refactor because background fill clears
    -- the framebuffer every frame, causing notes to "disappear" on frame 2.
end

--- Render all visible note blocks from island store.
--- Uses pre-computed visible ranges. Always redraws because the framebuffer
--- is cleared each frame by DrawFullView's opaque background fill.
--- @param x number Left edge of the grid area
--- @param y number Top edge of the grid area
--- @param w number Width of the grid area
--- @param h number Height of the grid area
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @param pitch_start number Pre-computed visible pitch start
--- @param pitch_end number Pre-computed visible pitch end
--- @param beat_start number Pre-computed visible beat start
--- @param beat_end number Pre-computed visible beat end
--- @param top_pitch number Pre-computed visible top pitch
function m.DrawNoteBlocks(x, y, w, h, scroll_y, scroll_x, zoom_x,
                          pitch_start, pitch_end, beat_start, beat_end, top_pitch)
    local PITCH_ROW_H = grid.PITCH_ROW_H
    local MIN_PITCH = grid.MIN_PITCH

    -- Sub-pixel offset for smooth scrolling (same formula as grid)
    local scroll_px_offset = (scroll_y - math.floor(scroll_y)) * PITCH_ROW_H

    local notes = island_store.GetNotes()
    if not notes then return end

    -- PASS 1: GHOSTS (Phase 5)
    -- Render semi-transparent silhouettes of notes at their original positions during drag/resize.
    if island_store.GetNoteDragActive() then
        local origins = island_store.GetNoteDragOrigins()
        for idx, orig in pairs(origins) do
            local op = orig.pitch
            local os = orig.start_beat
            local od = orig.duration or 1
            
            if op >= pitch_start and op <= pitch_end and os <= beat_end and (os + od) >= beat_start then
                local gx = x + (os - scroll_x) * zoom_x
                local gy = y + (top_pitch - op) * PITCH_ROW_H - scroll_px_offset
                local gw = od * zoom_x
                local gh = PITCH_ROW_H
                
                if gy < y + h and gy + gh > y then
                    helpers.SetColor(theme.colors.note_ghost or {1, 1, 1, 0.2})
                    components.DrawRoundedRect(gx + 1, gy + 1, math.max(1, gw - 2), math.max(1, gh - 2), 3, true)
                end
            end
        end
    end

    -- PASS 2: ACTUAL NOTES
    if #notes == 0 then return end
    for i, note in ipairs(notes) do
        local np = note.pitch
        local ns = note.start_beat
        local nd = note.duration or 1

        local in_pitch_range = np >= pitch_start and np <= pitch_end
        local in_time_range = ns <= beat_end and (ns + nd) >= beat_start

        if in_pitch_range and in_time_range then
            local nx = x + (ns - scroll_x) * zoom_x
            local ny = y + (top_pitch - np) * PITCH_ROW_H - scroll_px_offset
            local nw = nd * zoom_x
            local nh = PITCH_ROW_H

            -- Clip note height to viewport bottom
            if ny < y + h and ny + nh > y then
                local clipped_nh = math.min(nh, y + h - ny)
                m.DrawNoteBlock(note, nx, ny, nw, clipped_nh, island_store.IsNoteSelected(i))
            end
        end
    end
end

-- =========================================================
-- Hit testing
-- =========================================================

--- Hit test: find which note index is at a given mouse position.
--- Uses inverted Y: high pitch at top (low y), low pitch at bottom (high y).
--- @param mx number Mouse pixel x (relative to grid)
--- @param my number Mouse pixel y (relative to grid)
--- @param notes table Array of notes from island_store
--- @param scroll_y number Vertical scroll offset (rows from MAX_PITCH)
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @param grid_x number Grid left edge pixel
--- @param grid_y number Grid top edge pixel
--- @return number|nil Index of clicked note, or nil
function m.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    local PITCH_ROW_H = grid.PITCH_ROW_H
    local MAX_PITCH = grid.MAX_PITCH
    local MIN_PITCH = grid.MIN_PITCH

    if not notes then return nil end

    -- Convert mouse position to beat/pitch space (inverted Y)
    -- Account for sub-pixel smooth scroll offset: add back the fractional px
    -- so hit testing aligns with the actual drawn note positions.
    local scroll_px_offset = (scroll_y - math.floor(scroll_y)) * PITCH_ROW_H
    local beat = (mx - grid_x) / zoom_x + scroll_x
    local pitch_row = math.floor((my - grid_y + scroll_px_offset) / PITCH_ROW_H)
    local top_pitch = math.max(MIN_PITCH, MAX_PITCH - math.floor(scroll_y))
    local click_pitch = math.max(MIN_PITCH, top_pitch - pitch_row)

    -- Search from end to start (topmost first in render order)
    for i = #notes, 1, -1 do
        local note = notes[i]
        if note.pitch == click_pitch then
            local note_start = note.start_beat
            local note_end = note_start + (note.duration or 1)
            if beat >= note_start and beat <= note_end then
                return i
            end
        end
    end

    return nil
end

-- =========================================================
-- Rect hit-test (lasso selection)
-- =========================================================

--- Find all note indices whose note blocks fall within the given pixel rectangle.
--- Used by lasso on mouseup to populate selected_indices.
--- @param x1 number Pixel x of first corner
--- @param y1 number Pixel y of first corner
--- @param x2 number Pixel x of second corner
--- @param y2 number Pixel y of second corner
--- @param grid_x number Grid left edge (pixel)
--- @param grid_y number Grid top edge (pixel)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return table Array of note indices within the rect
function m.GetNotesInRect(x1, y1, x2, y2, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    -- Normalize rect
    local rx1, ry1 = math.min(x1, x2), math.min(y1, y2)
    local rx2, ry2 = math.max(x1, x2), math.max(y1, y2)

    -- Ignore tiny clicks (anti-flicker)
    if math.abs(x2 - x1) < 3 and math.abs(y2 - y1) < 3 then
        return {}
    end

    local PITCH_ROW_H = grid.PITCH_ROW_H
    local MIN_PITCH = grid.MIN_PITCH
    local MAX_PITCH = grid.MAX_PITCH

    local scroll_px_offset = (scroll_y - math.floor(scroll_y)) * PITCH_ROW_H
    local top_pitch = math.max(MIN_PITCH, MAX_PITCH - math.floor(scroll_y))

    -- Convert pixel rect to pitch/beat space (inverted Y)
    -- Adjust for sub-pixel smooth scroll offset
    local pitch_row_top = math.floor((ry1 - grid_y + scroll_px_offset) / PITCH_ROW_H)
    local pitch_row_bot = math.floor((ry2 - grid_y + scroll_px_offset) / PITCH_ROW_H)
    local pitch_high = math.min(MAX_PITCH, math.max(MIN_PITCH, top_pitch - pitch_row_top))
    local pitch_low  = math.max(MIN_PITCH, top_pitch - pitch_row_bot)

    local beat_start = (rx1 - grid_x) / zoom_x + scroll_x
    local beat_end   = (rx2 - grid_x) / zoom_x + scroll_x

    local results = {}
    local notes = island_store.GetNotes()
    if not notes then return results end

    for i, note in ipairs(notes) do
        local np = note.pitch
        local ns = note.start_beat
        local nd = note.duration or 1
        if np >= pitch_low and np <= pitch_high
           and ns <= beat_end and (ns + nd) >= beat_start then
            table.insert(results, i)
        end
    end

    return results
end

return m
