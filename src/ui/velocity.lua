-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Velocity Editor
-- Per-note velocity bars rendered below the piano roll grid.
-- Supports click-and-drag to edit velocity values in real-time.

local island_store = require("state.island")
local ui_store = require("state.ui")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local layout = require("ui.layout")
local components = require("ui.components")

local velocity = {}

-- Configuration
velocity.EDITOR_H = 100                -- Increased height for better precision
velocity.COLLAPSED_H = 15              -- Comfortable height for the 'Blade'
velocity.COLLAPSE_HANDLE_H = 15        -- Easier to grab handle
velocity.VELOCITY_MIN_H = 4            -- Head height
velocity.VELOCITY_MAX_H = 80           -- Max height

-- Colors
local GRID_LINE_COLOR = {0.2, 0.2, 0.2, 0.2}
local VEL_LABEL_COLOR = {1.0, 1.0, 1.0, 0.9}
local BAR_SELECTED_BORDER = {1.0, 1.0, 1.0, 1.0}
local PIN_HEAD_COLOR = {1.0, 1.0, 1.0, 0.8}

-- Module-local drag state (alive only during a drag operation within a frame)
local drag_active = false
local drag_note_index = nil
local drag_initial_vel = nil   -- velocity of clicked note when drag started (for delta)
local drag_initial_my = nil    -- mouse Y when drag started (for delta tracking)

--- Compute a velocity bar color using red→green gradient.
--- @param velocity number 0-127
--- @return table {r, g, b, a}
local function VelocityGradient(velocity)
    local ratio = math.max(0, math.min(1, velocity / 127))
    -- Vivid Cyan (low) -> Electric Blue (mid) -> Vibrant Violet (high)
    local r = 0.15 + ratio * 0.7
    local g = 0.5 - ratio * 0.3
    local b = 1.0
    return {r, g, b, 0.6 + ratio * 0.3}
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
        color = theme.colors.island_note_muted
    else
        color = VelocityGradient(velocity_val)
    end

    local centerX = math.floor(x + w/2)
    local pinW = 2
    local headH = 5
    local headW = math.max(4, math.min(10, w - 2))

    -- Stem (Glassy Glow)
    helpers.SetColor(color, 0.3)
    gfx.rect(centerX - 1, y - h, pinW, h, 1)
    helpers.SetColor(color)
    gfx.rect(centerX, y - h, 1, h, 1)

    -- Head (Blade Pin)
    local head_y = y - h
    helpers.SetColor(selected and theme.colors.btn_active or PIN_HEAD_COLOR)
    components.DrawRoundedRect(centerX - headW/2, head_y, headW, headH, 2, true)

    -- Selected note: subtle glow/indicator
    if selected then
        helpers.SetColor(BAR_SELECTED_BORDER, 0.3)
        components.DrawRoundedRect(centerX - headW/2 - 2, head_y - 2, headW + 4, headH + 4, 3, false)
    end

    -- Value label (only if hovered or selected and enough room)
    if selected and h > 20 then
        helpers.SetColor(VEL_LABEL_COLOR)
        gfx.setfont(1, "Calibri", 10)
        local label = tostring(velocity_val)
        local lw, lh = gfx.measurestr(label)
        gfx.x, gfx.y = centerX - lw/2, y - h - lh - 2
        gfx.drawstr(label)
    end
end

--- Draw the full velocity editor below the piano roll.
--- When collapsed: shows a centered "▶ VELOCITY" bar — click anywhere to expand.
--- When expanded: shows velocity bars, grid, and a bottom handle to collapse.
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

    local expanded = island_store.GetVelocityPanelExpanded()
    local LABEL_W = 48  -- must match piano-roll PITCH_LABEL_W
    local grid_x = x + LABEL_W
    local grid_w = w - LABEL_W
    if grid_w <= 0 then return end

    -- Velocity editor background (Restored rounding at the bottom as requested)
    helpers.SetColor(theme.colors.island_velocity_bg)
    local has_presets = island_store.GetPresetPanelVisible()
    components.DrawRoundedRectEx(x, y, w, h, 10, {bl=not has_presets, br=true, tl=not has_presets, tr=false})
    
    -- Sub-border/Glass highlight
    helpers.SetColor({1, 1, 1, 0.05})
    gfx.line(x, y, x + w, y)

    if not expanded then 
        -- ===== COLLAPSED: The Clean Blade =====
        -- Centered hint, very clean
        helpers.SetColor(theme.colors.text, 0.4)
        local fs = layout.US(800)
        gfx.setfont(1, "Calibri", fs)
        local label = "V E L O C I T Y"
        local lw, lh = gfx.measurestr(label)
        gfx.x, gfx.y = x + (w - lw) / 2, y + (h - lh) / 2
        gfx.drawstr(label)

        -- Interaction area hint on hover (Rounded base)
        if gfx.mouse_y >= y and gfx.mouse_y <= y + h then
            helpers.SetColor({1, 1, 1, 0.08})
            components.DrawRoundedRectEx(x, y, w, h, 10, {bl=not has_presets, br=true, tl=not has_presets, tr=false})
        end
        return 
    end

    -- ===== EXPANDED: velocity bars + grid + bottom collapse handle =====

    -- Left Label Strip (Clean)

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

    -- Reserve room for collapsible handle at the bottom
    local handle_h = velocity.COLLAPSE_HANDLE_H
    local content_h = h - handle_h

    -- Draw bars for each visible note
    local beat_vis_start = scroll_x - 1
    local beat_vis_end = scroll_x + math.ceil(grid_w / zoom_x) + 1

    local pad_bot = 4
    local bar_area_bottom = y + content_h - pad_bot
    local bar_area_height = content_h - pad_bot * 2

    if notes and #notes > 0 then
        -- 1. PRE-CULL: Only process notes within visible range for grouping and layout
        local visible_indices = {}
        for i, note in ipairs(notes) do
            local ns = note.start_beat
            local nd = note.duration or 1
            if ns <= beat_vis_end and (ns + nd) >= beat_vis_start then
                visible_indices[#visible_indices + 1] = i
            end
        end

        -- 2. GROUP ONLY VISIBLE NOTES (task 3.2)
        local offset_map = {}
        local beat_groups = {}
        for _, i in ipairs(visible_indices) do
            local note = notes[i]
            local beat = note.start_beat or 0
            if not beat_groups[beat] then beat_groups[beat] = {} end
            beat_groups[beat][#beat_groups[beat] + 1] = i
        end
        for _, indices in pairs(beat_groups) do
            local count = #indices
            if count > 1 then
                for j, idx in ipairs(indices) do
                    offset_map[idx] = (j - 1) * 3 - (count - 1) * 1.5
                end
            else
                offset_map[indices[1]] = 0
            end
        end

        for _, i in ipairs(visible_indices) do
            local note = notes[i]
            -- Only render bars for notes within visible time range
            local ns = note.start_beat
            local nd = note.duration or 1
            -- Already checked ns/nd in pre-cull
                local nx = grid_x + (ns - scroll_x) * zoom_x + (offset_map[i] or 0)
                local nw = nd * zoom_x
                local nvel = note.velocity or 100
                local is_selected = island_store.IsNoteSelected(i)

                -- Bar height proportional to velocity
                local bar_h = velocity.VELOCITY_MIN_H + (nvel / 127) * (velocity.VELOCITY_MAX_H - velocity.VELOCITY_MIN_H)
                bar_h = math.min(bar_h, bar_area_height)

                velocity.DrawVelocityBar(nx, bar_area_bottom, nw, bar_h, nvel, is_selected, note.muted)
        end
    end

    -- Collapse handle at bottom (Glass style with rounded base)
    local handle_y = y + h - handle_h
    helpers.SetColor({1, 1, 1, 0.05})
    if gfx.mouse_y >= handle_y and gfx.mouse_y <= handle_y + handle_h and gfx.mouse_x >= x and gfx.mouse_x <= x + w then
        helpers.SetColor({1, 1, 1, 0.1}) -- Brighter on hover
    end
    components.DrawRoundedRectEx(x, handle_y, w, handle_h, 10, {bl=not has_presets, br=true, tl=false, tr=false})

    -- Glow line separator
    helpers.SetColor(theme.colors.btn_active, 0.3)
    gfx.line(x, handle_y, x + w, handle_y)

    -- Centered handle indicator
    helpers.SetColor({1, 1, 1, 0.4})
    local hw, hh = 40, 2
    gfx.rect(x + (w - hw)/2, handle_y + (handle_h - hh)/2, hw, hh, 1)
end

--- Check if mouse is over the velocity collapse handle.
function velocity.IsOverCollapseHandle(mx, my, x, y, w, h)
    local handle_h = velocity.COLLAPSE_HANDLE_H
    return mx >= x and mx <= x + w and my >= y + h - handle_h and my <= y + h
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

--- Helper: apply velocity to a set of notes (bulk-aware).
--- When multiple notes are selected, applies a relative delta to all selected notes.
--- When only the clicked note is selected, applies the value directly.
--- @param notes table Notes array
--- @param idx number Primary clicked note index
--- @param new_vel number Computed velocity from mouse position
--- @param drag_initial_vel number|nil Velocity at drag start (for delta)
local function ApplyVelocity(notes, idx, new_vel)
    local selected = island_store.GetSelectedIndices()
    local sel_count = 0
    for _ in pairs(selected) do sel_count = sel_count + 1 end

    if sel_count > 1 and drag_initial_vel ~= nil then
        -- Bulk: apply delta relative to initial click
        local delta = new_vel - drag_initial_vel
        for sel_idx in pairs(selected) do
            if notes[sel_idx] then
                local base = notes[sel_idx].velocity or 100
                notes[sel_idx].velocity = math.max(0, math.min(127, base + delta))
            end
        end
    else
        -- Single note: apply directly
        notes[idx].velocity = new_vel
    end
end

--- Handle click and drag in the velocity editor area.
--- Called each frame from DrawMIDIIsland mouse handling.
--- Collapsed: click anywhere to expand.
--- Expanded: click bottom handle to collapse, or drag bars to edit velocity.
--- When multiple notes are selected, drag applies a relative delta to ALL selected notes.
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
    local expanded = island_store.GetVelocityPanelExpanded()

    if not expanded then
        -- COLLAPSED: any click in the velocity area toggles expand
        if click and mouse_down and my >= ed_y and my <= ed_y + ed_h then
            island_store.SetVelocityPanelExpanded(true)
            return true
        end
        return false
    end

    -- EXPANDED: check collapse handle at bottom first
    local handle_h = velocity.COLLAPSE_HANDLE_H
    if click and mouse_down and my >= ed_y + ed_h - handle_h and my <= ed_y + ed_h then
        island_store.SetVelocityPanelExpanded(false)
        return true
    end

    if not notes or #notes == 0 then return false end

    -- Start drag on fresh click
    if click and mouse_down then
        local idx = velocity.VelocityHitTest(mx, my, notes, grid_x, ed_y, ed_h, scroll_x, zoom_x)
        if idx then
            -- Store initial state for delta tracking
            drag_initial_vel = notes[idx].velocity or 100
            drag_initial_my = my
            drag_active = true
            drag_note_index = idx
            -- Preserve multi-selection: only change selection if clicked note is NOT already selected
            local selected = island_store.GetSelectedIndices()
            if not selected[idx] then
                island_store.ClearSelection()
                selected[idx] = true
            end
            -- Update velocity immediately on click
            local padding = 4
            local bar_area_bot = ed_y + ed_h - padding
            local bar_area_top = ed_y + padding
            local bar_area_h = math.max(1, bar_area_bot - bar_area_top)
            local ratio = (bar_area_bot - my) / bar_area_h
            local new_vel = math.max(0, math.min(127, math.floor(ratio * 127 + 0.5)))
            ApplyVelocity(notes, idx, new_vel)
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
            ApplyVelocity(notes, idx, new_vel)
        end
        return true
    end

    -- Release drag: push undo entry for velocity change
    if drag_active and not mouse_down then
        local notes = island_store.GetNotes()
        local selected = island_store.GetSelectedIndices()
        if notes and drag_note_index and notes[drag_note_index] then
            local undo_uuids = {}
            local undo_prev = {}
            local undo_new = {}
            local sel_count = 0
            for _ in pairs(selected) do sel_count = sel_count + 1 end
            if sel_count > 1 and drag_initial_vel ~= nil then
                -- Bulk: capture all selected notes
                local delta = (notes[drag_note_index].velocity or 100) - drag_initial_vel
                for sel_idx in pairs(selected) do
                    if notes[sel_idx] then
                        table.insert(undo_uuids, notes[sel_idx].uuid)
                        table.insert(undo_prev, {velocity = math.max(0, math.min(127, (notes[sel_idx].velocity or 100) - delta))})
                        table.insert(undo_new, {velocity = notes[sel_idx].velocity})
                    end
                end
            else
                -- Single note
                table.insert(undo_uuids, notes[drag_note_index].uuid)
                table.insert(undo_prev, {velocity = drag_initial_vel})
                table.insert(undo_new, {velocity = notes[drag_note_index].velocity})
            end
            if #undo_uuids > 0 then
                island_store.PushUndo({
                    type = "velocity",
                    note_uuids = undo_uuids,
                    prev_state = undo_prev,
                    new_state = undo_new,
                })
            end
        end
        drag_active = false
        drag_note_index = nil
        drag_initial_vel = nil
        drag_initial_my = nil
    end

    return false
end

--- Reset drag state (call on mode switch)
function velocity.ResetDrag()
    drag_active = false
    drag_note_index = nil
    drag_initial_vel = nil
    drag_initial_my = nil
end

--- Check if a velocity drag is currently active.
function velocity.IsDragging()
    return drag_active
end

return velocity
