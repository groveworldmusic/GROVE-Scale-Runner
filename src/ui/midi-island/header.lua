-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
local config = require("config")
local layout = require("ui.layout")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local island_store = require("state.island")
local ui_store = require("state.ui")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local midi = require("core.midi")
local velocity = require("ui.velocity")
local prefs = require("state.preferences")
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
        local snap_trip = island_store.GetSnapTriplet()
        local res_menu = "1/1|1/2|1/4|1/8|1/16|1/32||Triplet: " .. (snap_trip and "ON" or "OFF")
        gfx.x, gfx.y = sr_x, header_y + b_h
        local choice = gfx.showmenu(res_menu)
        if choice and choice > 0 then
            if choice <= 6 then
                local res_values = {1, 2, 4, 8, 16, 32}
                island_store.SetSnapResolution(res_values[choice])
                if not island_store.GetSnapEnabled() then island_store.SetSnapEnabled(true) end
            elseif choice == 8 then
                island_store.SetSnapTriplet(not snap_trip)
            end
        end
        ui_store.ConsumeMouseClick()
    end
    if sr_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Snap resolution: " .. snap_res_label, layout.US(700))
    end

    return sr_x + snap_res_w
end

--- Draw Tool Mode Row (Paint, Knife) — Phase 5
local function DrawToolModeRow(x, b_w, b_h, header_y)
    local tool_btn_w = math.floor(b_w * 0.55)
    local tool_btn_gap = 4
    local tool_x = x
    local tool_labels = {"✎", "✂"}
    local tool_hints = {"Paint (draw/delete notes)", "Knife (split notes)"}
    local cur_tool = island_store.GetToolMode()
    local tool_modes = {"paint", "knife"}

    for ti = 1, 2 do
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
    return tool_x + (tool_btn_w * 2 + tool_btn_gap)
end

function m.DrawHeader(content_w)
    local btn_y_v = 27738 + 428
    local b_w = layout.US(5347)
    local b_h = layout.US(1980)
    local header_y = layout.UY(btn_y_v)

    local main_gap = 6
    local tool_btn_w = math.floor(b_w * 0.55)
    local tool_gap = 2
    local tools_w = tool_btn_w * 2 + tool_gap

    local ps_btn_w = math.floor(b_w * 1.2)
    local icon_btn_w = math.floor(b_w * 0.6)
    
    local snap_toggle_w = math.floor(b_w * 0.65)
    local snap_res_w = math.floor(b_w * 0.50)
    local snap_gap = 4
    local snap_w = snap_toggle_w + snap_gap + snap_res_w
    local total_header_w = tools_w + main_gap + b_w + main_gap + ps_btn_w + main_gap + icon_btn_w + main_gap + icon_btn_w + main_gap + icon_btn_w + main_gap + icon_btn_w + main_gap + snap_w
    local cur_x = layout.UX(0) + math.floor((content_w - total_header_w) / 2)
    local reload_requested = false

    -- 1. Tools (Paint / Knife)
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
    local ps_hover = gfx.mouse_x >= cur_x and gfx.mouse_x <= cur_x + ps_btn_w and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    local ps_active = island_store.GetPresetPanelVisible()
    helpers.SetColor(ps_hover and theme.colors.btn_hover or (ps_active and theme.colors.btn_active or theme.colors.island_bg))
    components.DrawRoundedRect(cur_x, header_y, ps_btn_w, b_h, 10, true)
    if ui_store.GetMouseClick() and ps_hover and not drag_store.GetIsDragging() then
        ui_store.ConsumeMouseClick()
        island_store.SetPresetPanelVisible(not ps_active)
    end
    helpers.SetColor(ps_active and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1500))
    local ps_label = "PRESETS"
    local ps_lw, ps_lh = gfx.measurestr(ps_label)
    gfx.x, gfx.y = cur_x + (ps_btn_w - ps_lw)/2, header_y + (b_h - ps_lh)/2
    gfx.drawstr(ps_label)
    if ps_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip(ps_active and "Hide preset panel" or "Show preset panel", layout.US(700))
    end
    cur_x = cur_x + ps_btn_w + main_gap

    -- 4. SAVE preset to file
    local save_hover = gfx.mouse_x >= cur_x and gfx.mouse_x <= cur_x + icon_btn_w and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    helpers.SetColor(save_hover and theme.colors.btn_hover or theme.colors.island_bg)
    components.DrawRoundedRect(cur_x, header_y, icon_btn_w, b_h, 10, true)
    if ui_store.GetMouseClick() and save_hover and not drag_store.GetIsDragging() then
        ui_store.ConsumeMouseClick()
        local ret, csv = reaper.GetUserInputs("Save Preset", 1, "Preset name:", "Untitled")
        if ret and csv and #csv > 0 then
            local dir = preset_store.GetCurrentDirectory()
            if not dir or #dir == 0 then dir = preset_store.GetPresetRoot() end
            local filename = csv:gsub("[^%w_%-%s]", ""):gsub("%.grove$", "")
            if #filename > 0 then
                preset_browser.SavePreset(dir .. "\\" .. filename .. ".grove", filename)
            end
        end
    end
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", layout.US(1500))
    local sv_label = "💾"
    local sv_lw, sv_lh = gfx.measurestr(sv_label)
    gfx.x, gfx.y = cur_x + (icon_btn_w - sv_lw) / 2, header_y + (b_h - sv_lh) / 2
    gfx.drawstr(sv_label)
    if save_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Save notes as preset file", layout.US(700))
    end
    cur_x = cur_x + icon_btn_w + main_gap

    -- 5. LOAD preset from file
    local ld_hover = gfx.mouse_x >= cur_x and gfx.mouse_x <= cur_x + icon_btn_w and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    helpers.SetColor(ld_hover and theme.colors.btn_hover or theme.colors.island_bg)
    components.DrawRoundedRect(cur_x, header_y, icon_btn_w, b_h, 10, true)
    if ui_store.GetMouseClick() and ld_hover and not drag_store.GetIsDragging() then
        ui_store.ConsumeMouseClick()
        local files = preset_store.GetPresetFiles()
        local idx = preset_store.GetSelectedPresetIdx()
        if idx and idx >= 1 and idx <= #files then
            if preset_browser.LoadPreset(files[idx].path) then
                island_store.SetNotesState(island_store.NOTES_STATE_LOADED)
                island_store.ClearSelection()
            end
        end
    end
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", layout.US(1500))
    local ld_label = "📂"
    local ld_lw, ld_lh = gfx.measurestr(ld_label)
    gfx.x, gfx.y = cur_x + (icon_btn_w - ld_lw) / 2, header_y + (b_h - ld_lh) / 2
    gfx.drawstr(ld_label)
    if ld_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Load selected preset file", layout.US(700))
    end
    cur_x = cur_x + icon_btn_w + main_gap

    -- 6. RELOAD from Progression (discards manual edits)
    local rl_hover = gfx.mouse_x >= cur_x and gfx.mouse_x <= cur_x + icon_btn_w and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    local rl_bg = rl_hover and theme.colors.btn_hover or theme.colors.island_bg
    helpers.SetColor(rl_bg)
    components.DrawRoundedRect(cur_x, header_y, icon_btn_w, b_h, 10, true)
    if ui_store.GetMouseClick() and rl_hover and not drag_store.GetIsDragging() then
        ui_store.ConsumeMouseClick()
        -- Confirmation popup before discarding edits
        local ret = reaper.MB("Reload all notes from the progression?\n\nThis will discard any manual edits you made.", "Reload from Progression", 4)
        if ret == 6 then
            reload_requested = true
        end
    end
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1500))
    local rl_label = "\226\135\187"  -- ↻ (U+21BB)
    local rl_lw, rl_lh = gfx.measurestr(rl_label)
    gfx.x, gfx.y = cur_x + (icon_btn_w - rl_lw) / 2, header_y + (b_h - rl_lh) / 2
    gfx.drawstr(rl_label)
    if rl_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Reload notes from progression (discards edits)", layout.US(700))
    end
    cur_x = cur_x + icon_btn_w + main_gap

    -- 6b. SYNC to Progression (writes notes back to progression slots)
    local sync_requested = false
    local notes_state = island_store.GetNotesState()
    local has_edits = notes_state == island_store.NOTES_STATE_EDITED
    local sync_hover = gfx.mouse_x >= cur_x and gfx.mouse_x <= cur_x + icon_btn_w and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    local sync_bg = (sync_hover and has_edits) and theme.colors.btn_hover or (has_edits and theme.colors.island_bg or theme.colors.island_bg)
    helpers.SetColor(sync_bg)
    components.DrawRoundedRect(cur_x, header_y, icon_btn_w, b_h, 10, true)
    if ui_store.GetMouseClick() and sync_hover and has_edits and not drag_store.GetIsDragging() then
        ui_store.ConsumeMouseClick()
        sync_requested = true
    end
    -- Dim label if no edits to sync
    if has_edits then
        helpers.SetColor(theme.colors.text)
    else
        helpers.SetColor(theme.colors.text_dim)
    end
    gfx.setfont(1, "Calibri", layout.US(1500))
    local sync_label = "\226\135\132"  -- ⇄ (U+21C4)
    local sync_lw, sync_lh = gfx.measurestr(sync_label)
    gfx.x, gfx.y = cur_x + (icon_btn_w - sync_lw) / 2, header_y + (b_h - sync_lh) / 2
    gfx.drawstr(sync_label)
    if sync_hover and not drag_store.GetIsDragging() then
        if has_edits then
            helpers.DrawTooltip("Sync notes to progression slots", layout.US(700))
        else
            helpers.DrawTooltip("No edits to sync", layout.US(700))
        end
    end
    cur_x = cur_x + icon_btn_w + main_gap

    -- 7. SNAP controls
    cur_x = DrawSnapControls(cur_x, b_w, b_h, header_y)

    return cur_x, reload_requested, sync_requested
end

return m
