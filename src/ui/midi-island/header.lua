-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
local config = require("config")
local layout = require("ui.layout")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local island_store = require("state.island")
local ui_store = require("state.ui")
local drag_store = require("state.drag")
local midi = require("core.midi")
local velocity = require("ui.velocity")
local preset_browser = require("ui.preset-browser")

local m = {}

--- Draw Snap Controls (Snap, Resolution, Triplet)
local function DrawSnapControls(x, b_w, b_h, header_y)
    local snap_toggle_w = math.floor(b_w * 0.65)
    local snap_res_w = math.floor(b_w * 0.50)
    local snap_trip_w = math.floor(b_w * 0.35)
    local snap_gap = 4
    local snap_x = x
    local snap_enabled = island_store.GetSnapEnabled()
    local snap_res = island_store.GetSnapResolution()
    local snap_trip = island_store.GetSnapTriplet()

    -- Snap toggle button
    local st_hover = gfx.mouse_x >= snap_x and gfx.mouse_x <= snap_x + snap_toggle_w
                  and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    local st_bg = snap_enabled and theme.colors.btn_active or (st_hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(st_bg)
    components.DrawRoundedRect(snap_x, header_y, snap_toggle_w, b_h, 10, true)
    helpers.SetColor(snap_enabled and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1300))
    local snap_label = snap_enabled and "SNAP" or "SNP-"
    local slw, slh = gfx.measurestr(snap_label)
    gfx.x, gfx.y = snap_x + (snap_toggle_w - slw) / 2, header_y + (b_h - slh) / 2
    gfx.drawstr(snap_label)
    if ui_store.GetMouseClick() and st_hover and not drag_store.GetIsDragging() then
        island_store.SetSnapEnabled(not snap_enabled)
        ui_store.ConsumeMouseClick()
    end
    if st_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip(snap_enabled and "Snap: ON" or "Snap: OFF", layout.US(700))
    end

    -- Snap resolution button
    local sr_x = snap_x + snap_toggle_w + snap_gap
    local sr_hover = gfx.mouse_x >= sr_x and gfx.mouse_x <= sr_x + snap_res_w
                 and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    helpers.SetColor(sr_hover and theme.colors.btn_hover or theme.colors.island_bg)
    components.DrawRoundedRect(sr_x, header_y, snap_res_w, b_h, 10, true)
    helpers.SetColor(snap_enabled and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1300))
    local snap_res_label = "1/" .. tostring(snap_res)
    if snap_res <= 0 then snap_res_label = "OFF" end
    local rlw, rlh = gfx.measurestr(snap_res_label)
    gfx.x, gfx.y = sr_x + (snap_res_w - rlw) / 2, header_y + (b_h - rlh) / 2
    gfx.drawstr(snap_res_label)
    if ui_store.GetMouseClick() and sr_hover and not drag_store.GetIsDragging() then
        local res_menu = "1/1|1/2|1/4|1/8|1/16|1/32"
        gfx.x, gfx.y = sr_x, header_y + b_h
        local choice = gfx.showmenu(res_menu)
        if choice and choice > 0 then
            local res_values = {1, 2, 4, 8, 16, 32}
            island_store.SetSnapResolution(res_values[choice])
            if not island_store.GetSnapEnabled() then island_store.SetSnapEnabled(true) end
        end
        ui_store.ConsumeMouseClick()
    end
    if sr_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Snap resolution: " .. snap_res_label, layout.US(700))
    end

    -- Triplet toggle
    local stp_x = sr_x + snap_res_w + snap_gap
    local stp_hover = gfx.mouse_x >= stp_x and gfx.mouse_x <= stp_x + snap_trip_w
                  and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    local stp_bg = snap_trip and theme.colors.btn_active or (stp_hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(stp_bg)
    components.DrawRoundedRect(stp_x, header_y, snap_trip_w, b_h, 10, true)
    helpers.SetColor(snap_trip and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1300))
    local trip_label = snap_trip and "3" or "·"
    local tlw2, tlh2 = gfx.measurestr(trip_label)
    gfx.x, gfx.y = stp_x + (snap_trip_w - tlw2) / 2, header_y + (b_h - tlh2) / 2
    gfx.drawstr(trip_label)
    if ui_store.GetMouseClick() and stp_hover and not drag_store.GetIsDragging() then
        island_store.SetSnapTriplet(not snap_trip)
        ui_store.ConsumeMouseClick()
    end
    if stp_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip(snap_trip and "Triplet: ON" or "Triplet: OFF", layout.US(700))
    end

    return stp_x + snap_trip_w
end

--- Draw Tool Mode Row (Pointer, Pencil, Eraser)
local function DrawToolModeRow(x, b_w, b_h, header_y)
    local tool_btn_w = math.floor(b_w * 0.55)
    local tool_btn_gap = 4
    local tool_x = x
    local tool_labels = {"→", "✎", "✕"}
    local tool_hints = {"Pointer (select)", "Pencil (draw notes)", "Eraser (delete notes)"}
    local cur_tool = island_store.GetToolMode()
    local tool_modes = {"pointer", "pencil", "eraser"}

    for ti = 1, 3 do
        local t_active = cur_tool == tool_modes[ti]
        local tx = tool_x + (ti - 1) * (tool_btn_w + tool_btn_gap)
        local t_hover = gfx.mouse_x >= tx and gfx.mouse_x <= tx + tool_btn_w and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
        local t_bg = t_active and theme.colors.btn_active or (t_hover and theme.colors.btn_hover or theme.colors.island_bg)
        helpers.SetColor(t_bg)
        components.DrawRoundedRect(tx, header_y, tool_btn_w, b_h, 10, true)
        helpers.SetColor(t_active and theme.colors.text or theme.colors.text_dim)
        gfx.setfont(1, "Calibri", layout.US(1500))
        local tlw, tlh = gfx.measurestr(tool_labels[ti])
        gfx.x, gfx.y = tx + (tool_btn_w - tlw) / 2, header_y + (b_h - tlh) / 2
        gfx.drawstr(tool_labels[ti])

        if ui_store.GetMouseClick() and t_hover and not drag_store.GetIsDragging() then
            island_store.SetToolMode(tool_modes[ti])
            velocity.ResetDrag()
            ui_store.ConsumeMouseClick()
        end
        if t_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip(tool_hints[ti], layout.US(700))
        end
    end
    return tool_x + (tool_btn_w * 3 + tool_btn_gap * 2)
end

function m.DrawHeader(content_w)
    local btn_y_v = 27738 + 428
    local b_w = layout.US(5347)
    local b_h = layout.US(1980)
    local header_y = layout.UY(btn_y_v)

    local main_gap = 6
    local tool_btn_w = math.floor(b_w * 0.55)
    local tool_gap = 2
    local tools_w = tool_btn_w * 3 + tool_gap * 2
    
    local snap_toggle_w = math.floor(b_w * 0.65)
    local snap_res_w = math.floor(b_w * 0.50)
    local snap_trip_w = math.floor(b_w * 0.35)
    local snap_gap = 4
    local snap_w = snap_toggle_w + snap_gap + snap_res_w + snap_gap + snap_trip_w

    local action_btn_w = math.floor(b_w * 0.55)
    local action_gap = 4
    local actions_w = action_btn_w * 3 + action_gap * 2

    local total_header_w = tools_w + main_gap + b_w + main_gap + b_w + main_gap + actions_w + main_gap + snap_w
    local cur_x = layout.UX(0) + math.floor((content_w - total_header_w) / 2)

    -- 1. Tools
    cur_x = DrawToolModeRow(cur_x, b_w, b_h, header_y) + main_gap

    -- 2. MIDI CH
    local ch = midi.GetMidiChannel()
    local ch_hover = gfx.mouse_x >= cur_x and gfx.mouse_x <= cur_x + b_w and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    helpers.SetColor(ch_hover and theme.colors.btn_hover or theme.colors.island_bg)
    components.DrawRoundedRect(cur_x, header_y, b_w, b_h, 10, true)
    if ui_store.GetMouseClick() and ch_hover and not drag_store.GetIsDragging() then
        ui_store.ConsumeMouseClick()
        local menu = ""
        for i = 1, 16 do menu = menu .. (i == ch and "!" or "") .. tostring(i) .. "|" end
        gfx.x, gfx.y = cur_x, header_y + b_h
        local choice = gfx.showmenu(menu:sub(1, -2))
        if choice and choice > 0 then midi.SetMidiChannel(choice) end
    end
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1500))
    local ch_label = "CH " .. tostring(ch)
    local ch_lw, ch_lh = gfx.measurestr(ch_label)
    gfx.x, gfx.y = cur_x + (b_w - ch_lw)/2, header_y + (b_h - ch_lh)/2
    gfx.drawstr(ch_label)
    if ch_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("MIDI Channel: " .. ch, layout.US(700))
    end
    cur_x = cur_x + b_w + main_gap

    -- 3. PRESETS Toggle
    local ps_hover = gfx.mouse_x >= cur_x and gfx.mouse_x <= cur_x + b_w and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    local ps_active = island_store.GetPresetPanelVisible()
    helpers.SetColor(ps_hover and theme.colors.btn_hover or (ps_active and theme.colors.btn_active or theme.colors.island_bg))
    components.DrawRoundedRect(cur_x, header_y, b_w, b_h, 10, true)
    if ui_store.GetMouseClick() and ps_hover and not drag_store.GetIsDragging() then
        ui_store.ConsumeMouseClick()
        island_store.SetPresetPanelVisible(not ps_active)
    end
    helpers.SetColor(ps_active and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1500))
    local ps_label = "PANEL"
    local ps_lw, ps_lh = gfx.measurestr(ps_label)
    gfx.x, gfx.y = cur_x + (b_w - ps_lw)/2, header_y + (b_h - ps_lh)/2
    gfx.drawstr(ps_label)
    if ps_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip(ps_active and "Hide preset panel" or "Show preset panel", layout.US(700))
    end
    cur_x = cur_x + b_w + main_gap

    -- 4. PRESET ACTIONS
    cur_x = cur_x + preset_browser.DrawActionButtons(cur_x, header_y, action_btn_w, b_h) + main_gap

    -- 5. SNAP
    cur_x = DrawSnapControls(cur_x, b_w, b_h, header_y)
end

return m
