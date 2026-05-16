-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Views — Performance Area
-- DrawPerformanceArea, DecrementPageOverrideTimer.
-- Extracted from views.lua (Sprint 2).

local config = require("config")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local ui_store = require("state.ui")
local prefs = require("state.preferences")
local theme = require("ui.theme")
local components = require("ui.components")
local helpers = require("ui.helpers")
local layout = require("ui.layout")
local api_guard = require("core.api-guard")

local m = {}

function m.DecrementPageOverrideTimer()
    -- Decrement in ALL modes, not just DrawPerformanceArea (Issue 8)
    if seq_store.GetPageOverrideTimer() > 0 then seq_store.SetPageOverrideTimer(seq_store.GetPageOverrideTimer() - 1) end
end

function m.DrawPerformanceArea()
    if seq_store.GetIsPlaying() and seq_store.GetPageOverrideTimer() <= 0 then
        local target_page = math.floor((seq_store.GetCurrentStep() - 1) / 4) + 1
        if target_page > 0 and target_page <= 4 then seq_store.SetCurrentPage(target_page) end
    end
    
    local x_start, w = layout.UX(0), layout.US(39914)
    local y, h = layout.UY(14375), layout.US(13363)
    
    -- Scroll pagination logic
    local hover_area = gfx.mouse_x >= x_start and gfx.mouse_x <= x_start + w and gfx.mouse_y >= y and gfx.mouse_y <= y + h
    if hover_area and ui_store.GetUseScroll() then
        local raw = ui_store.ConsumeMouseWheelDelta()
        if raw ~= 0 then
            local dir = raw > 0 and -1 or 1
            seq_store.SetCurrentPage(math.max(1, math.min(4, seq_store.GetCurrentPage() + dir)))
        end
    end

    helpers.SetColor(theme.colors.island_bg)
    components.DrawRoundedRect(x_start, y, w, h, 15, true)
    local margin = layout.US(800)
    local avail_w = w - (margin * 2)
    local pad_w, pad_h = layout.US(5300), layout.US(4116)
    local si_pa = api_guard.ClampIndex(prefs.GetScaleIndex(), 1, #config.SCALES)
    local num_intervals = #config.SCALES[si_pa].intervals
    local num_pads = 7  -- always draw 7 slots; extra ones beyond num_intervals draw grayed out
    local pad_spacing = (avail_w - (pad_w * num_pads)) / (num_pads - 1)
    for i = 1, num_pads do
        local px = x_start + margin + (i - 1) * (pad_w + pad_spacing)
        local py = layout.UY(15197)
        components.DrawScalePad(px, py, pad_w, pad_h, i, layout.US(1500), layout.US(1100), num_intervals)
    end
    local slot_w, slot_h = layout.US(9350), layout.US(6760)
    local slot_spacing = (avail_w - (slot_w * 4)) / 3
    local slots_y = layout.UY(19730)
    local start_idx = (seq_store.GetCurrentPage() - 1) * 4 + 1
    for i = 0, 3 do
        local sx = math.floor(x_start + margin + i * (slot_w + slot_spacing))
        components.DrawProgressionSlot(start_idx + i, sx, slots_y, slot_w, slot_h)
    end
    -- DEBUG: set to true to show slot edge diagnostic lines
    local SLOT_EDGE_DEBUG = false
    if SLOT_EDGE_DEBUG then
        gfx.set(0, 1, 0, 1)  -- green: right edge
        for i = 0, 3 do
            local sx = math.floor(x_start + margin + i * (slot_w + slot_spacing))
            gfx.rect(sx + slot_w - 1, slots_y, 1, slot_h, 1)
        end
        gfx.set(1, 0, 0, 1)  -- red: left edge
        for i = 0, 3 do
            local sx = math.floor(x_start + margin + i * (slot_w + slot_spacing))
            gfx.rect(sx, slots_y, 1, slot_h, 1)
        end
    end
    local page_center_x = x_start + w/2
    local page_y = layout.UY(27192)
    components.DrawPaginator(page_center_x, page_y, 4)
    
    local btn_size = layout.US(1000)
    local btn_offset = layout.US(3200)
    
    gfx.setfont(1, "Calibri", btn_size)
    local lt, lh = gfx.measurestr("<")
    local rt, rh = gfx.measurestr(">")
    
    -- Prev button
    local prev_cx = page_center_x - btn_offset
    local prev_hover = gfx.mouse_x >= prev_cx - btn_size/2 and gfx.mouse_x <= prev_cx + btn_size/2 and gfx.mouse_y >= page_y - lh/2 and gfx.mouse_y <= page_y + lh/2
    local can_prev = seq_store.GetCurrentPage() > 1
    if not can_prev then
        local disabled_color = {theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], 0.3}
        helpers.SetColor(disabled_color)
    else
        helpers.SetColor(prev_hover and theme.colors.text or theme.colors.text_dim)
    end
    gfx.x, gfx.y = prev_cx - lt/2, page_y - lh/2
    gfx.drawstr("<")
    if prev_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Previous page", layout.US(700))
    end
    if ui_store.GetMouseClick() and prev_hover and can_prev then
        seq_store.SetCurrentPage(seq_store.GetCurrentPage() - 1)
        seq_store.SetPageOverrideTimer(30)
    end
    
    -- Next button
    local next_cx = page_center_x + btn_offset
    local next_hover = gfx.mouse_x >= next_cx - btn_size/2 and gfx.mouse_x <= next_cx + btn_size/2 and gfx.mouse_y >= page_y - rh/2 and gfx.mouse_y <= page_y + rh/2
    local can_next = seq_store.GetCurrentPage() < 4
    if not can_next then
        local disabled_color = {theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], 0.3}
        helpers.SetColor(disabled_color)
    else
        helpers.SetColor(next_hover and theme.colors.text or theme.colors.text_dim)
    end
    gfx.x, gfx.y = next_cx - rt/2, page_y - rh/2
    gfx.drawstr(">")
    if next_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Next page", layout.US(700))
    end
    if ui_store.GetMouseClick() and next_hover and can_next then
        seq_store.SetCurrentPage(seq_store.GetCurrentPage() + 1)
        seq_store.SetPageOverrideTimer(30)
    end
    
    helpers.SetColor(theme.colors.text_dim, 0.7)
    gfx.setfont(1, "Calibri", layout.US(900))
    local page_text = "Page " .. seq_store.GetCurrentPage() .. "/4"
    local pw, ph = gfx.measurestr(page_text)
    gfx.x, gfx.y = x_start + w - pw - layout.US(700), layout.UY(27192) - ph/2
    gfx.drawstr(page_text)
    
    -- Render Dragging Feedback on top
    components.DrawDragPreview(slot_w, slot_h)
end

return m
