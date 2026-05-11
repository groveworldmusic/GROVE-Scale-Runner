-- GROVE FL MIDI: Velocity Editor
-- Per-note velocity bars rendered below the piano roll grid.
-- Supports click-and-drag to edit velocity values in real-time.

local island_store = require("state.island")
local theme = require("ui.theme")
local helpers = require("ui.helpers")

local velocity = {}

-- Configuration
velocity.EDITOR_H = 80                 -- Height of the velocity editor area in pixels
velocity.VELOCITY_MIN_H = 2            -- Minimum bar height (even for velocity=0)
velocity.VELOCITY_MAX_H = 60           -- Maximum bar height (for velocity=127)

-- Colors
local BG_COLOR = {0.12, 0.12, 0.12, 1}
local BASELINE_COLOR = {0.35, 0.35, 0.35, 0.5}
local GRID_LINE_COLOR = {0.25, 0.25, 0.25, 0.2}
local BAR_SELECTED_BORDER = {1, 1, 1, 0.7}
local MUTED_BAR_COLOR = {0.35, 0.35, 0.35, 0.5}
local VEL_LABEL_COLOR = {0.8, 0.8, 0.8, 0.7}
local LABEL_AREA_COLOR = {0.18, 0.18, 0.18, 1}

-- Module-local drag state (alive only during a drag operation within a frame)
local drag_active = false
local drag_note_index = nil

--- Compute a velocity bar color using red→green gradient.
--- @param velocity number 0-127
--- @return table {r, g, b, a}
local function VelocityGradient(velocity)
    local ratio = math.max(0, math.min(1, velocity / 127))
    -- Red (low) -> Yellow (mid) -> Green (high)
    local r = 1.0 - ratio * 0.7
    local g = 0.3 + ratio * 0.7
    local b = 0.08
    return {r, g, b, 0.85}
end

--- Draw a single velocity bar.
--- @param x number Left pixel
--- @param y number Bottom baseline pixel
--- @param w number Width in pixels
--- @param h number Height in pixels (bar grows upward from baseline)
--- @param velocity number 0-127
--- @param selected boolean Whether this bar is selected
--- @param muted boolean Whether the note is muted
function velocity.DrawVelocityBar(x, y, w, h, velocity_val, selected, muted)
    if w < 1 or h < 1 then return end

    local color
    if muted then
        color = MUTED_BAR_COLOR
    else
        color = VelocityGradient(velocity_val)
    end

    -- Bar body (drawn upward from baseline)
    helpers.SetColor(color)
    gfx.rect(x, y - h, w, h, 1)

    -- Selected note: draw a bright border around bar
    if selected then
        helpers.SetColor(BAR_SELECTED_BORDER)
        gfx.rect(x, y - h, w, h, 0)
    end

    -- Draw velocity value label on the bar if selected
    if selected and w > 30 then
        helpers.SetColor(VEL_LABEL_COLOR)
        gfx.setfont(1, "Calibri", 9)
        local label = tostring(velocity_val)
        local lw, lh = gfx.measurestr(label)
        gfx.x, gfx.y = x + (w - lw) / 2, y - h + (h - lh) / 2
        gfx.drawstr(label)
    end
end

--- Draw the full velocity editor below the piano roll.
--- @param x number Left edge of the grid area (pixel)
--- @param y number Top edge of the velocity editor (pixel)
--- @param w number Width of the grid area (pixel)
--- @param h number Height of the velocity editor (pixel)
--- @param notes table Array of notes from island_store
--- @param scroll_x number Horizontal scroll offset in beats
--- @param zoom_x number Pixels per beat
--- @param selected_idx number|nil Currently selected note index
function velocity.DrawVelocityEditor(x, y, w, h, notes, scroll_x, zoom_x, selected_idx)
    if w <= 0 or h <= 0 then return end

    local LABEL_W = 40  -- must match piano-roll PITCH_LABEL_W
    local grid_x = x + LABEL_W
    local grid_w = w - LABEL_W
    if grid_w <= 0 then return end

    -- Background for label area
    helpers.SetColor(LABEL_AREA_COLOR)
    gfx.rect(x, y, LABEL_W, h, 1)

    -- "VEL" label
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 9)
    local lw, lh = gfx.measurestr("VEL")
    gfx.x, gfx.y = x + (LABEL_W - lw) / 2, y + (h - lh) / 2
    gfx.drawstr("VEL")

    -- Background for grid area
    helpers.SetColor(BG_COLOR)
    gfx.rect(grid_x, y, grid_w, h, 1)

    -- Vertical beat grid lines (matching piano roll)
    local beat_start = math.floor(scroll_x)
    local beat_end = beat_start + math.ceil(grid_w / zoom_x) + 1
    for beat = beat_start, beat_end do
        local bx = grid_x + (beat - scroll_x) * zoom_x
        if bx >= grid_x and bx <= grid_x + grid_w then
            helpers.SetColor(GRID_LINE_COLOR)
            gfx.line(bx, y, bx, y + h)
        end
    end

    -- Baseline (bottom line of the editor area)
    local padding_bottom = 4
    local baseline_y = y + h - padding_bottom
    helpers.SetColor(BASELINE_COLOR)
    gfx.line(grid_x, baseline_y, grid_x + grid_w, baseline_y)

    -- Draw bars for each visible note
    if not notes or #notes == 0 then return end

    -- Calculate visible beat range (bars only for visible notes)
    local beat_vis_start = scroll_x - 1
    local beat_vis_end = scroll_x + math.ceil(grid_w / zoom_x) + 1

    local bar_area_bottom = baseline_y
    local bar_area_height = h - padding_bottom * 2

    for i, note in ipairs(notes) do
        -- Only render bars for notes within visible time range
        local ns = note.start_beat
        local nd = note.duration or 1
        if ns <= beat_vis_end and (ns + nd) >= beat_vis_start then
            local nx = grid_x + (ns - scroll_x) * zoom_x
            local nw = nd * zoom_x
            local nvel = note.velocity or 100
            local is_selected = (i == selected_idx)

            -- Bar height proportional to velocity
            local bar_h = velocity.VELOCITY_MIN_H + (nvel / 127) * (velocity.VELOCITY_MAX_H - velocity.VELOCITY_MIN_H)
            bar_h = math.min(bar_h, bar_area_height)

            velocity.DrawVelocityBar(nx, bar_area_bottom, nw, bar_h, nvel, is_selected, note.muted)
        end
    end
end

--- Hit test: find which note index is under a mouse position in the velocity editor.
--- @param mx number Mouse pixel x
--- @param my number Mouse pixel y
--- @param notes table Array of notes
--- @param grid_x number Grid left edge (after label area)
--- @param ed_y number Editor area top
--- @param ed_h number Editor area height
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return number|nil Index of hit note, or nil
function velocity.VelocityHitTest(mx, my, notes, grid_x, ed_y, ed_h, scroll_x, zoom_x)
    if not notes or #notes == 0 then return nil end
    if zoom_x <= 0 then return nil end

    -- Convert mouse X to beat position
    local beat = (mx - grid_x) / zoom_x + scroll_x

    -- Check each note (reverse order for topmost priority)
    for i = #notes, 1, -1 do
        local note = notes[i]
        local ns = note.start_beat
        local nd = note.duration or 1
        if beat >= ns and beat <= ns + nd then
            return i
        end
    end

    return nil
end

--- Handle click and drag in the velocity editor area.
--- Called each frame from DrawIslandView mouse handling.
--- @param mx number Mouse pixel x
--- @param my number Mouse pixel y
--- @param grid_x number Grid left edge
--- @param ed_y number Editor area top
--- @param ed_h number Editor area height
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @param click boolean Whether a fresh left-click occurred this frame
--- @param mouse_down boolean Whether left mouse button is currently held
--- @return boolean true if event was consumed
function velocity.HandleVelocityMouse(mx, my, grid_x, ed_y, ed_h, scroll_x, zoom_x, click, mouse_down)
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return false end

    -- Start drag on fresh click
    if click and mouse_down then
        local idx = velocity.VelocityHitTest(mx, my, notes, grid_x, ed_y, ed_h, scroll_x, zoom_x)
        if idx then
            island_store.SetSelectedNoteIndex(idx)
            drag_active = true
            drag_note_index = idx
            -- Update velocity immediately on click
            local padding = 4
            local bar_area_bot = ed_y + ed_h - padding
            local bar_area_top = ed_y + padding
            local bar_area_h = math.max(1, bar_area_bot - bar_area_top)
            local ratio = (bar_area_bot - my) / bar_area_h
            local new_vel = math.max(0, math.min(127, math.floor(ratio * 127 + 0.5)))
            notes[idx].velocity = new_vel
            return true
        end
    end

    -- Continue drag while button is held
    if drag_active and mouse_down and drag_note_index then
        local idx = drag_note_index
        if idx >= 1 and idx <= #notes then
            local padding = 4
            local bar_area_bot = ed_y + ed_h - padding
            local bar_area_top = ed_y + padding
            local bar_area_h = math.max(1, bar_area_bot - bar_area_top)
            local ratio = (bar_area_bot - my) / bar_area_h
            local new_vel = math.max(0, math.min(127, math.floor(ratio * 127 + 0.5)))
            notes[idx].velocity = new_vel
        end
        return true
    end

    -- Release drag
    if drag_active and not mouse_down then
        drag_active = false
        drag_note_index = nil
    end

    return false
end

--- Reset drag state (call on mode switch)
function velocity.ResetDrag()
    drag_active = false
    drag_note_index = nil
end

return velocity
