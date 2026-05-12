-- GROVE FL MIDI: Piano Roll Grid + Note Blocks
-- Renders a horizontal pitch×time grid with note blocks from island store.
-- Supports virtual scrolling (vertical + horizontal), zoom, and click selection.

local config = require("config")
local island_store = require("state.island")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")

local piano_roll = {}

-- Configuration
piano_roll.PITCH_ROW_H = 12          -- Height per pitch row in pixels
piano_roll.PITCH_LABEL_W = 40        -- Width of pitch labels on the left
piano_roll.MIN_PITCH = 12            -- C0
piano_roll.MAX_PITCH = 119           -- B8 (octava 8 completa)
piano_roll.TOTAL_ROWS = 108          -- 119 - 12 + 1 (C0 a B8)
piano_roll.OCTAVE_BUFFER = 12        -- +1 octave buffer for virtual scroll

-- Beat grid line colors (replaced by theme.colors.grid_* — kept inline for pitch rows/key strip)
local PITCH_ROW_WHITE = {0.3, 0.3, 0.3, 0.35}
local PITCH_ROW_BLACK = {0.12, 0.12, 0.12, 0.5}
local KEY_WHITE_FILL = {0.55, 0.55, 0.55, 0.7}
local KEY_BLACK_FILL = {0.06, 0.06, 0.06, 0.9}
local NOTE_SELECTED_BORDER = {1, 1, 1, 0.8}
local NOTE_MUTED = {0.4, 0.4, 0.4, 0.4}
local NOTE_MUTED_OPAQUE = {0.4, 0.4, 0.4, 1.0}  -- Used for gradient render (spec: full alpha)

-- Frame-cache: avoid recomputing visible ranges when scroll/zoom unchanged
local _cache = {
    scroll_y = nil, scroll_x = nil, zoom_x = nil, w = nil, h = nil,
    pitch_start = 0, pitch_end = 0, beat_start = 0, beat_end = 0,
    visible_rows = 0, top_pitch = 0,
}

--- Compute visible pitch and beat ranges for the current viewport.
--- Inverted Y: high pitch at TOP (low y), low pitch at BOTTOM (high y).
--- Results are cached and reused when scroll/zoom/dimensions haven't changed.
local function ComputeVisibleRanges(y, h, scroll_y, scroll_x, zoom_x, w)
    local PITCH_ROW_H = piano_roll.PITCH_ROW_H
    local MIN_PITCH = piano_roll.MIN_PITCH
    local MAX_PITCH = piano_roll.MAX_PITCH
    local TOTAL_ROWS = piano_roll.TOTAL_ROWS

    -- Invalidate cache when parameters change
    if _cache.scroll_y == scroll_y and _cache.scroll_x == scroll_x
       and _cache.zoom_x == zoom_x and _cache.w == w and _cache.h == h then
        return _cache.visible_rows, _cache.pitch_start, _cache.pitch_end,
               _cache.top_pitch, _cache.beat_start, _cache.beat_end
    end

    local visible_rows = math.ceil(h / PITCH_ROW_H) + 2
    -- scroll_y = rows from top (MAX_PITCH); increases → see lower pitches
    local max_scroll = TOTAL_ROWS - visible_rows
    local clamped_scroll = math.max(0, math.min(max_scroll, scroll_y or 0))
    -- Top pitch: highest pitch shown at the very top of the grid
    local top_pitch = math.max(MIN_PITCH, MAX_PITCH - clamped_scroll)
    -- Pitch range including buffer for virtual scrolling
    local pitch_start = math.max(MIN_PITCH, top_pitch - visible_rows - piano_roll.OCTAVE_BUFFER)
    local pitch_end = math.min(MAX_PITCH, top_pitch + piano_roll.OCTAVE_BUFFER)
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

--- Note block color: white keys get a lighter shade, black keys a darker shade.
--- Matches piano keyboard visual convention (white vs black keys).
local WHITE_KEY_PCS = {[0]=true, [2]=true, [4]=true, [5]=true, [7]=true, [9]=true, [11]=true}
local NOTE_WHITE = {0.55, 0.72, 0.88, 0.92}  -- light blue-gray for white keys
local NOTE_BLACK = {0.22, 0.38, 0.55, 0.92}  -- deeper blue for black keys
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

--- Pre-computed set of white key pitch classes (O(1) lookup, Issue 18 pattern).
--- Used to determine row background tint without modulo + table scan per row.
local WHITE_KEY_SET = {}
for _, pc in ipairs({0, 2, 4, 5, 7, 9, 11}) do
    WHITE_KEY_SET[pc] = true
end

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
function piano_roll.DrawPianoRollGrid(x, y, w, h, scroll_y, scroll_x, zoom_x,
                                       visible_rows, pitch_start, pitch_end, top_pitch)
    local PITCH_ROW_H = piano_roll.PITCH_ROW_H
    local LABEL_W = piano_roll.PITCH_LABEL_W
    local MIN_PITCH = piano_roll.MIN_PITCH

    -- Draw pitch row backgrounds + horizontal lines (high→low = top→bottom)
    for row_offset = 0, visible_rows do
        local pitch = top_pitch - row_offset  -- descending: high pitch at top
        if pitch < MIN_PITCH then break end

        local py = y + row_offset * PITCH_ROW_H
        if py > y + h then break end

        local is_white = WHITE_KEY_SET[pitch % 12] == true

        -- Row background tint
        if is_white then
            helpers.SetColor(PITCH_ROW_WHITE)
            gfx.rect(x, py, w, PITCH_ROW_H, 1)
        end

        -- Horizontal line (bottom of each row)
        helpers.SetColor(PITCH_ROW_BLACK)
        gfx.line(x, py + PITCH_ROW_H, x + w, py + PITCH_ROW_H)

        -- Key strip on the left edge (white/black key colors + pitch label)
        local label_x = x - LABEL_W
        if label_x >= 0 then
            -- Key background fill
            if is_white then
                helpers.SetColor(KEY_WHITE_FILL)
            else
                helpers.SetColor(KEY_BLACK_FILL)
            end
            gfx.rect(label_x, py, LABEL_W, PITCH_ROW_H, 1)
            -- Pitch label (brighter on white keys, dimmer on black keys)
            if is_white then
                helpers.SetColor(theme.colors.text)
            else
                helpers.SetColor(theme.colors.text_dim)
            end
            gfx.setfont(1, "Calibri", 10)
            local label = OctaveLabel(pitch)
            local lw, lh = gfx.measurestr(label)
            gfx.x, gfx.y = label_x + (LABEL_W - lw) / 2, py + (PITCH_ROW_H - lh) / 2
            gfx.drawstr(label)
            -- Key right edge separator
            helpers.SetColor({0.15, 0.15, 0.15, 0.6})
            gfx.line(label_x + LABEL_W, py, label_x + LABEL_W, py + PITCH_ROW_H)
        end
    end

    -- Draw vertical beat lines (4-tier hierarchy: measure, beat, 1/8, 1/16)
    -- Colors reference theme.colors.grid_* for DAW-style opacity levels
    local beat_start = math.max(0, math.floor(scroll_x))
    local beat_end = beat_start + math.ceil(w / zoom_x) + 1

    -- Measure lines (every 4 beats, alpha 0.60, double line for bold)
    helpers.SetColor(theme.colors.grid_measure)
    local first_measure = math.ceil(beat_start / 4) * 4
    for beat = first_measure, beat_end, 4 do
        local bx = x + (beat - scroll_x) * zoom_x
        if bx >= x and bx <= x + w then
            gfx.line(bx, y, bx, y + h)
            gfx.line(bx + 1, y, bx + 1, y + h)  -- second pass for bold
        end
    end

    -- Beat lines (integer beats that are not measures, alpha 0.35)
    helpers.SetColor(theme.colors.grid_beat)
    for beat = beat_start, beat_end do
        if (beat % 4) ~= 0 then
            local bx = x + (beat - scroll_x) * zoom_x
            if bx >= x and bx <= x + w then
                gfx.line(bx, y, bx, y + h)
            end
        end
    end

    -- Subdivision lines (4-tier: 1/8 at alpha 0.15, 1/16 at alpha 0.08 when subdivision >= 4)
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
                            -- Distinguish 1/8 (s%2==0) from 1/16 (others)
                            helpers.SetColor((s % 2) == 0 and theme.colors.grid_sub_1_8 or theme.colors.grid_sub_1_16)
                        else
                            -- Subdivision < 4: all sub-beats at 1/8 tier
                            helpers.SetColor(theme.colors.grid_sub_1_8)
                        end
                        gfx.line(bx, y, bx, y + h)
                    end
                end
            end
        end
    end
end

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
        -- Muted: flat fill at full alpha, NOTE_MUTED_RGB, no gradient
        helpers.SetColor(NOTE_MUTED_OPAQUE)
        components.DrawRoundedRect(nx + 1, ny + 1, math.max(1, nw - 2), math.max(1, nh - 2), 3, true)
        return
    end

    local base_color = NoteColorForPitch(pitch)
    local vel_alpha = 0.35 + (velocity / 127) * 0.65
    local strips = math.max(1, math.floor(nh / 4))

    for i = 0, strips - 1 do
        local t = i / strips
        local darken = 1 - t * 0.3  -- top=1.0, bottom≈0.7
        -- Distribute strip heights evenly using floor division
        local sy = ny + math.floor(i * nh / strips)
        local ey = ny + math.floor((i + 1) * nh / strips)
        local sh = ey - sy

        helpers.SetColor({
            base_color[1] * darken,
            base_color[2] * darken,
            base_color[3] * darken,
            vel_alpha,
        })
        components.DrawRoundedRect(nx + 1, sy + 1, math.max(1, nw - 2), math.max(1, sh - 2), 3, true)
    end
end

--- Draw a single note block with gradient and velocity opacity.
--- @param note table {pitch, start_beat, duration, velocity, muted}
--- @param nx number Pixel x (already computed)
--- @param ny number Pixel y (already computed)
--- @param nw number Pixel width (already computed)
--- @param nh number Pixel height (row height)
--- @param selected boolean Whether this note is selected
function piano_roll.DrawNoteBlock(note, nx, ny, nw, nh, selected)
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
        gfx.setfont(1, "Calibri", 10)
        local lw, lh = gfx.measurestr(label)
        helpers.SetColor(theme.colors.text_dark)
        gfx.x, gfx.y = nx + (nw - lw) / 2, ny + (nh - lh) / 2
        gfx.drawstr(label)
    end
end

--- Track whether notes changed since last render (avoids full iteration
--- when nothing changed, P5-05).
local _last_note_count = -1
local _last_selected_idx = -1
local _last_notes_dirty = true

--- Render all visible note blocks from island store.
--- Uses pre-computed visible ranges and skips iteration when notes unchanged.
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
function piano_roll.DrawNoteBlocks(x, y, w, h, scroll_y, scroll_x, zoom_x,
                                    pitch_start, pitch_end, beat_start, beat_end, top_pitch)
    local PITCH_ROW_H = piano_roll.PITCH_ROW_H
    local MIN_PITCH = piano_roll.MIN_PITCH

    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return end

    local selected_idx = island_store.GetSelectedNoteIndex()

    -- Check if we can skip note redraw (nothing changed — P5-05)
    local note_count = #notes
    if note_count == _last_note_count and selected_idx == _last_selected_idx
       and not _last_notes_dirty then
        return
    end
    _last_note_count = note_count
    _last_selected_idx = selected_idx
    _last_notes_dirty = false

    for i, note in ipairs(notes) do
        local np = note.pitch
        local ns = note.start_beat
        local nd = note.duration or 1

        -- Only render notes within pitch range AND time range
        local in_pitch_range = np >= pitch_start and np <= pitch_end
        local in_time_range = ns <= beat_end and (ns + nd) >= beat_start

        if in_pitch_range and in_time_range then
            -- Compute pixel position (inverted Y: high pitch → top)
            local nx = x + (ns - scroll_x) * zoom_x
            local ny = y + (top_pitch - np) * PITCH_ROW_H
            local nw = nd * zoom_x
            local nh = PITCH_ROW_H

            piano_roll.DrawNoteBlock(note, nx, ny, nw, nh, i == selected_idx)
        end
    end
end

--- Mark note cache as dirty (call when notes change externally).
function piano_roll.MarkNotesDirty()
    _last_notes_dirty = true
end

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
function piano_roll.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    local PITCH_ROW_H = piano_roll.PITCH_ROW_H
    local MAX_PITCH = piano_roll.MAX_PITCH
    local MIN_PITCH = piano_roll.MIN_PITCH

    if not notes then return nil end

    -- Convert mouse position to beat/pitch space (inverted Y)
    local beat = (mx - grid_x) / zoom_x + scroll_x
    local pitch_row = math.floor((my - grid_y) / PITCH_ROW_H)
    local top_pitch = math.max(MIN_PITCH, MAX_PITCH - scroll_y)
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

--- Handle mouse click in piano roll area.
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if click was consumed
function piano_roll.HandleMouseClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local notes = island_store.GetNotes()
    local idx = piano_roll.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    if idx then
        island_store.SetSelectedNoteIndex(idx)
    else
        island_store.SetSelectedNoteIndex(nil)
    end
    return true
end

--- Handle right-click in piano roll area: toggle mute on the clicked note.
--- Right-click on a note block toggles note.muted; right-click on empty area does nothing.
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if right-click was consumed (muted toggled)
function piano_roll.HandleRightClickMute(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local notes = island_store.GetNotes()
    local idx = piano_roll.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    if idx and notes[idx] then
        notes[idx].muted = not notes[idx].muted
        island_store.SetSelectedNoteIndex(idx)
        return true
    end
    return false
end

--- Handle horizontal mouse wheel in piano roll area (timeline-style).
--- @param delta number Mouse wheel delta
--- @param scroll_x number Current horizontal scroll (beats)
--- @param zoom_x number Pixels per beat
--- @return number New horizontal scroll
function piano_roll.HandleMouseWheel(delta, scroll_x, zoom_x)
    local scroll_speed = 4 / (zoom_x / 40)  -- base 4 beats at 40px/beat
    local new_scroll = scroll_x + delta * scroll_speed
    return math.max(0, new_scroll)
end

--- Handle horizontal zoom on timeline ruler: adjust zoom_x (pixels per beat).
--- @param delta number Mouse wheel delta
--- @param zoom_x number Current zoom
--- @return number New zoom_x
function piano_roll.HandleZoomX(delta, zoom_x)
    local factor = delta > 0 and 1.15 or (1/1.15)
    return math.max(10, math.min(200, math.floor(zoom_x * factor + 0.5)))
end

--- Handle vertical zoom on piano roll: adjust pitch row height.
--- @param delta number Mouse wheel delta
--- @param row_h number Current row height
--- @return number New row height
function piano_roll.HandleZoomVertical(delta, row_h)
    local factor = delta > 0 and 1.15 or (1/1.15)
    return math.max(6, math.min(24, math.floor(row_h * factor + 0.5)))
end

--- Set pitch row height (PITCH_ROW_H is the module field so consumers see the change).
--- @param h number New height in pixels
function piano_roll.SetPitchRowH(h)
    piano_roll.PITCH_ROW_H = math.max(6, math.min(24, h))
end

--- Handle vertical mouse wheel in piano roll area: scroll pitch rows.
--- Inverted Y: delta>0 (wheel up) → lower scroll_y → show higher pitches.
--- @param delta number Mouse wheel delta
--- @param scroll_y number Current vertical scroll offset
--- @return number New vertical scroll offset
function piano_roll.HandleMouseWheelVertical(delta, scroll_y)
    -- Delta > 0 = wheel up = show higher pitches = decrease scroll_y
    local new_scroll = scroll_y - delta
    -- Clamp to valid range (0..TOTAL_ROWS - visible_min)
    local max_scroll = piano_roll.TOTAL_ROWS - 12  -- at least 12 rows visible
    return math.max(0, math.min(max_scroll, new_scroll))
end

--- Main piano roll entry point: draw grid, labels, and note blocks.
--- Computes visible ranges ONCE and shares between grid + note rendering (P5-05).
--- @param x number Left edge of the entire piano roll area (including label area)
--- @param y number Top edge of the piano roll area
--- @param w number Width of the entire piano roll area
--- @param h number Height of the piano roll area
function piano_roll.DrawPianoRoll(x, y, w, h)
    local scroll_y = island_store.GetScrollOffsetY()
    local scroll_x = island_store.GetScrollOffsetX()
    local zoom_x = island_store.GetZoomX()
    local LABEL_W = piano_roll.PITCH_LABEL_W

    -- Compute visible ranges ONCE per frame (shared between grid + notes, P5-05)
    local visible_rows, pitch_start, pitch_end, top_pitch, beat_start, beat_end =
        ComputeVisibleRanges(y, h, scroll_y, scroll_x, zoom_x, w)

    -- No label background — parent DrawMIDIIsland provides rounded bg

    -- Draw grid (to the right of labels)
    local grid_x = x + LABEL_W
    local grid_w = w - LABEL_W
    if grid_w <= 0 then return end

    piano_roll.DrawPianoRollGrid(grid_x, y, grid_w, h, scroll_y, scroll_x, zoom_x,
                                  visible_rows, pitch_start, pitch_end, top_pitch)

    -- Draw note blocks (uses shared pitch/beat ranges)
    piano_roll.DrawNoteBlocks(grid_x, y, grid_w, h, scroll_y, scroll_x, zoom_x,
                               pitch_start, pitch_end, beat_start, beat_end, top_pitch)

    -- Draw vertical scrollbar indicator (right side)
    local total_rows = piano_roll.TOTAL_ROWS
    local actual_visible = math.ceil(h / piano_roll.PITCH_ROW_H)
    local max_scroll_y = total_rows - actual_visible
    local scroll_ratio_y = actual_visible / total_rows
    if scroll_ratio_y < 1 and max_scroll_y > 0 then
        local sb_x = x + w - 6
        local sb_y = y + (scroll_y / max_scroll_y) * h
        local sb_h = math.max(20, h * scroll_ratio_y)
        helpers.SetColor({0.4, 0.4, 0.4, 0.3})
        gfx.rect(sb_x, sb_y, 6, sb_h, 1)
    end

end

return piano_roll
