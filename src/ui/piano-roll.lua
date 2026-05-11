-- GROVE FL MIDI: Piano Roll Grid + Note Blocks
-- Renders a horizontal pitch×time grid with note blocks from island store.
-- Supports virtual scrolling (vertical + horizontal), zoom, and click selection.

local config = require("config")
local island_store = require("state.island")
local seq_store = require("state.sequencer")
local ui_store = require("state.ui")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local colors = require("ui.colors")

local piano_roll = {}

-- Configuration
piano_roll.PITCH_ROW_H = 12          -- Height per pitch row in pixels
piano_roll.PITCH_LABEL_W = 40        -- Width of pitch labels on the left
piano_roll.MIN_PITCH = 36            -- C2
piano_roll.MAX_PITCH = 108           -- C8
piano_roll.TOTAL_ROWS = 73           -- 108 - 36 + 1
piano_roll.OCTAVE_BUFFER = 12        -- +1 octave buffer for virtual scroll

-- Beat grid line colors
local BEAT_STRONG = {0.4, 0.4, 0.4, 0.5}
local BEAT_WEAK = {0.3, 0.3, 0.3, 0.3}
local PITCH_ROW_WHITE = {0.25, 0.25, 0.25, 0.15}
local PITCH_ROW_BLACK = {0.2, 0.2, 0.2, 0.08}
local NOTE_DEFAULT = theme.colors.btn_active
local NOTE_SELECTED_BORDER = {1, 1, 1, 0.8}
local NOTE_MUTED = {0.4, 0.4, 0.4, 0.4}
local GRID_BG = {0.15, 0.15, 0.15, 1}

-- Pre-computed: which rows are "white key" rows (pitch mod 12 is a white key)
-- White key pitch classes: 0(C), 2(D), 4(E), 5(F), 7(G), 9(A), 11(B)
local WHITE_KEY_CLASSES = {}
for _, pc in ipairs({0, 2, 4, 5, 7, 9, 11}) do
    WHITE_KEY_CLASSES[pc] = true
end

-- Note color cache: pitch_class → color (reuse across frames)
local NOTE_COLORS = {}

--- Get a color for a given pitch class (0-11), cycling through grade_colors.
local function NoteColorForPitch(pitch)
    local pc = pitch % 12
    if not NOTE_COLORS[pc] then
        local idx = (pc % 7) + 1  -- cycle 7 grade colors over 12 pitch classes
        NOTE_COLORS[pc] = theme.colors.grade_colors[idx] or theme.colors.btn_active
    end
    return NOTE_COLORS[pc]
end

--- Get the octave name for a pitch number.
local function OctaveLabel(pitch)
    local octave = math.floor(pitch / 12) - 1
    local note_names = config.NOTE_NAMES
    return note_names[(pitch % 12) + 1] .. tostring(octave)
end

--- Draw the piano roll grid background, pitch rows, and beat lines.
--- @param x number Left edge of the grid area (pixel)
--- @param y number Top edge of the grid area (pixel)
--- @param w number Width of the grid area (pixel)
--- @param h number Height of the grid area (pixel)
--- @param scroll_y number Vertical scroll offset in pitch rows
--- @param scroll_x number Horizontal scroll offset in beats
--- @param zoom_x number Pixels per beat
function piano_roll.DrawPianoRollGrid(x, y, w, h, scroll_y, scroll_x, zoom_x)
    local PITCH_ROW_H = piano_roll.PITCH_ROW_H
    local LABEL_W = piano_roll.PITCH_LABEL_W
    local MIN_PITCH = piano_roll.MIN_PITCH
    local TOTAL_ROWS = piano_roll.TOTAL_ROWS

    -- Background
    helpers.SetColor(GRID_BG)
    gfx.rect(x, y, w, h, 1)

    -- Calculate visible pitch range (vertical)
    local visible_rows = math.ceil(h / PITCH_ROW_H) + 2  -- +2 for partial rows at edges
    local pitch_start = MIN_PITCH + scroll_y
    local pitch_end = math.min(pitch_start + visible_rows, MIN_PITCH + TOTAL_ROWS - 1)

    -- Draw pitch row backgrounds + horizontal lines
    for row_offset = 0, pitch_end - pitch_start do
        local pitch = pitch_start + row_offset
        if pitch > MIN_PITCH + TOTAL_ROWS - 1 then break end

        local py = y + row_offset * PITCH_ROW_H
        if py > y + h then break end

        local is_white = WHITE_KEY_CLASSES[pitch % 12] == true

        -- Row background tint
        if is_white then
            helpers.SetColor(PITCH_ROW_WHITE)
            gfx.rect(x, py, w, PITCH_ROW_H, 1)
        end

        -- Horizontal line (bottom of each row)
        helpers.SetColor(PITCH_ROW_BLACK)
        gfx.line(x, py + PITCH_ROW_H, x + w, py + PITCH_ROW_H)

        -- Octave labels on the left edge (label area is drawn by caller or here)
        if is_white then
            local label_x = x - LABEL_W
            if label_x >= 0 then
                helpers.SetColor(theme.colors.text_dim)
                gfx.setfont(1, "Calibri", 9)
                local label = OctaveLabel(pitch)
                local lw, lh = gfx.measurestr(label)
                gfx.x, gfx.y = label_x + (LABEL_W - lw) / 2, py + (PITCH_ROW_H - lh) / 2
                gfx.drawstr(label)
            end
        end
    end

    -- Draw vertical beat lines
    local beat_start = math.floor(scroll_x)
    local beat_end = beat_start + math.ceil(w / zoom_x) + 1

    for beat = beat_start, beat_end do
        local bx = x + (beat - scroll_x) * zoom_x
        if bx >= x and bx <= x + w then
            local is_measure = (beat % 4) == 0
            if is_measure then
                helpers.SetColor(BEAT_STRONG)
            else
                helpers.SetColor(BEAT_WEAK)
            end
            gfx.line(bx, y, bx, y + h)
        end
    end
end

--- Draw a single note block.
--- @param note table {pitch, start_beat, duration, velocity, muted}
--- @param nx number Pixel x (already computed)
--- @param ny number Pixel y (already computed)
--- @param nw number Pixel width (already computed)
--- @param nh number Pixel height (row height)
--- @param selected boolean Whether this note is selected
function piano_roll.DrawNoteBlock(note, nx, ny, nw, nh, selected)
    if nw < 1 or nh < 1 then return end

    local color
    if note.muted then
        color = NOTE_MUTED
    else
        color = NoteColorForPitch(note.pitch)
    end

    -- Draw the note block
    helpers.SetColor(color)
    components.DrawRoundedRect(nx + 1, ny + 1, math.max(1, nw - 2), math.max(1, nh - 2), 3, true)

    -- Selected note: draw a bright border
    if selected then
        helpers.SetColor(NOTE_SELECTED_BORDER)
        gfx.roundrect(nx + 1, ny + 1, math.max(1, nw - 2), math.max(1, nh - 2), 3, 0)
    end
end

--- Render all visible note blocks from island store.
--- @param x number Left edge of the grid area
--- @param y number Top edge of the grid area
--- @param w number Width of the grid area
--- @param h number Height of the grid area
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
function piano_roll.DrawNoteBlocks(x, y, w, h, scroll_y, scroll_x, zoom_x)
    local PITCH_ROW_H = piano_roll.PITCH_ROW_H
    local MIN_PITCH = piano_roll.MIN_PITCH

    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return end

    local selected_idx = island_store.GetSelectedNoteIndex()

    -- Calculate visible ranges
    local visible_rows = math.ceil(h / PITCH_ROW_H) + 2
    local pitch_start = MIN_PITCH + scroll_y
    local pitch_end = pitch_start + visible_rows + piano_roll.OCTAVE_BUFFER

    local beat_start = scroll_x - 1  -- 1 beat buffer left
    local beat_end = scroll_x + math.ceil(w / zoom_x) + 1  -- 1 beat buffer right

    local rendered = 0

    for i, note in ipairs(notes) do
        local np = note.pitch
        local ns = note.start_beat
        local nd = note.duration or 1

        -- Only render notes within pitch range AND time range
        local in_pitch_range = np >= pitch_start and np <= pitch_end
        local in_time_range = ns <= beat_end and (ns + nd) >= beat_start

        if in_pitch_range and in_time_range then
            -- Compute pixel position
            local nx = x + (ns - scroll_x) * zoom_x
            local ny = y + (np - pitch_start) * PITCH_ROW_H
            local nw = nd * zoom_x
            local nh = PITCH_ROW_H

            piano_roll.DrawNoteBlock(note, nx, ny, nw, nh, i == selected_idx)
            rendered = rendered + 1
        end
    end
end

--- Hit test: find which note index is at a given mouse position.
--- @param mx number Mouse pixel x (relative to grid)
--- @param my number Mouse pixel y (relative to grid)
--- @param notes table Array of notes from island_store
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @param grid_x number Grid left edge pixel
--- @param grid_y number Grid top edge pixel
--- @return number|nil Index of clicked note, or nil
function piano_roll.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    local PITCH_ROW_H = piano_roll.PITCH_ROW_H
    local MIN_PITCH = piano_roll.MIN_PITCH

    if not notes then return nil end

    -- Convert mouse position to beat/pitch space
    local beat = (mx - grid_x) / zoom_x + scroll_x
    local pitch_row = math.floor((my - grid_y) / PITCH_ROW_H)
    local click_pitch = MIN_PITCH + scroll_y + pitch_row

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

--- Handle mouse wheel in piano roll area.
--- @param delta number Mouse wheel delta
--- @param scroll_x number Current horizontal scroll (beats)
--- @param zoom_x number Pixels per beat
--- @return number New horizontal scroll
function piano_roll.HandleMouseWheel(delta, scroll_x, zoom_x)
    local scroll_speed = 4 / (zoom_x / 40)  -- base 4 beats at 40px/beat
    local new_scroll = scroll_x + delta * scroll_speed
    return math.max(0, new_scroll)
end

--- Main piano roll entry point: draw grid, labels, and note blocks.
--- @param x number Left edge of the entire piano roll area (including label area)
--- @param y number Top edge of the piano roll area
--- @param w number Width of the entire piano roll area
--- @param h number Height of the piano roll area
function piano_roll.DrawPianoRoll(x, y, w, h)
    local scroll_y = island_store.GetScrollOffsetY()
    local scroll_x = island_store.GetScrollOffsetX()
    local zoom_x = island_store.GetZoomX()
    local LABEL_W = piano_roll.PITCH_LABEL_W

    -- Draw pitch label background on the left
    helpers.SetColor(theme.colors.island_bg)
    gfx.rect(x, y, LABEL_W, h, 1)

    -- Draw grid (to the right of labels)
    local grid_x = x + LABEL_W
    local grid_w = w - LABEL_W
    if grid_w <= 0 then return end

    piano_roll.DrawPianoRollGrid(grid_x, y, grid_w, h, scroll_y, scroll_x, zoom_x)

    -- Draw note blocks
    piano_roll.DrawNoteBlocks(grid_x, y, grid_w, h, scroll_y, scroll_x, zoom_x)

    -- Draw vertical scrollbar indicator (right side)
    local total_rows = piano_roll.TOTAL_ROWS
    local visible_rows = math.ceil(h / piano_roll.PITCH_ROW_H)
    local scroll_ratio = visible_rows / total_rows
    if scroll_ratio < 1 then
        local sb_x = x + w - 6
        local sb_y = y + (scroll_y / (total_rows - visible_rows)) * h
        local sb_h = math.max(20, h * scroll_ratio)
        helpers.SetColor({0.4, 0.4, 0.4, 0.3})
        gfx.rect(sb_x, sb_y, 6, sb_h, 1)
    end
end

return piano_roll
