-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Views — Header
-- DrawHeader + quick config menu.
-- Extracted from views.lua (Sprint 2).

local config = require("config")
local seq_store = require("state.sequencer")
local midi_store = require("state.midi")
local ui_store = require("state.ui")
local prefs = require("state.preferences")
local theme = require("ui.theme")
local components = require("ui.components")
local helpers = require("ui.helpers")
local compact = require("ui.compact")
local layout = require("ui.layout")
local persist = require("state.persist")
local api_guard = require("core.api-guard")

local m = {}

-- Cached dropdown options (built once, scales don't change at runtime)
local SCALE_OPTIONS = (function() local t = {} for _, v in ipairs(config.SCALES) do t[#t + 1] = v.name end return t end)()
local OCTAVE_OPTIONS = {"C0", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"}

-- Shared right-click quick config menu (used by both views)
local function ShowQuickConfigMenu()
    local si_qc = api_guard.ClampIndex(prefs.GetScaleIndex(), 1, #config.SCALES)
    local ci_qc = api_guard.ClampIndex(prefs.GetChordModeIndex(), 1, #config.CHORD_MODES)
    local m = "ROOT: " .. config.NOTE_NAMES[api_guard.ClampIndex(prefs.GetRootIndex(), 1, 12)] .. "|<SCALE: " .. helpers.AbbreviateScale(config.SCALES[si_qc].name) .. "|OCTAVE: C" .. math.floor(prefs.GetOctave()) .. "|CHORD: " .. config.CHORD_MODES[ci_qc].name .. "|VELOCITY: " .. (midi_store.GetUseVelocity() and "ON" or "OFF") .. "|Dock in Transport Bar"
    gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
    local choice = gfx.showmenu(m)
    if choice == 1 then
        config.state.root_index = (prefs.GetRootIndex() % 12) + 1
        prefs.SetRootIndex(config.state.root_index)
        persist.Save("root_index", config.state.root_index)
    elseif choice == 2 then
        config.state.scale_index = (prefs.GetScaleIndex() % #config.SCALES) + 1
        prefs.SetScaleIndex(config.state.scale_index)
        persist.Save("scale_index", config.state.scale_index)
    elseif choice == 3 then
        config.state.octave = math.floor((prefs.GetOctave() + 1) % 9)
        prefs.SetOctave(config.state.octave)
        persist.Save("octave", config.state.octave)
    elseif choice == 4 then
        config.state.chord_mode_index = (prefs.GetChordModeIndex() % #config.CHORD_MODES) + 1
        prefs.SetChordModeIndex(config.state.chord_mode_index)
        persist.Save("chord_mode_index", config.state.chord_mode_index)
    elseif choice == 5 then
        midi_store.SetUseVelocity(not midi_store.GetUseVelocity())
    elseif choice == 6 then
        ui_store.SetDockId(gfx.dock(1))
        if ui_store.GetDockId() > 0 then
            ui_store.SetDockedMode(true)
        else
            ui_store.SetDockId(0)
        end
    end
end

function m.DrawHeader()
    local h = layout.US(2200)
    local left_edge = layout.UX(0)
    
    gfx.setfont(1, "Calibri", layout.US(1500)) 
    helpers.SetColor(theme.colors.text)
    local title = "GROVE SCALE RUNNER"
    local tw, th = gfx.measurestr(title)
    gfx.x, gfx.y = left_edge, (h - th) / 2
    gfx.drawstr(title)
    
    gfx.setfont(1, "Calibri", layout.US(850))
    helpers.SetColor(theme.colors.text_dim)
    local ver = "v1.0.0  © groveworldmusic"
    local vw, vh = gfx.measurestr(ver)
    local ver_x = left_edge + tw + layout.US(800)
    local ver_y = (h - th) / 2 + layout.US(420)
    gfx.x, gfx.y = ver_x, ver_y
    gfx.drawstr(ver)

    -- Compute icon positions first (used for state text boundary below)
    local icon_size = layout.US(1700)
    local icon_gap = layout.US(420)
    local right_edge = layout.UX(39914)
    local view_x = right_edge - icon_size - icon_gap
    local settings_x = view_x - icon_size - icon_gap
    local help_x = settings_x - icon_size - icon_gap

    -- State indicator on the same line right after copyright
    gfx.setfont(1, "Calibri", layout.US(900))
    local ri_h = api_guard.ClampIndex(prefs.GetRootIndex(), 1, 12)
    local si_h = api_guard.ClampIndex(prefs.GetScaleIndex(), 1, #config.SCALES)
    local ci_h = api_guard.ClampIndex(prefs.GetChordModeIndex(), 1, #config.CHORD_MODES)
    local scale_abbr = helpers.AbbreviateScale(config.SCALES[si_h].name)
    local state_str = "  ·  " .. config.NOTE_NAMES[ri_h] .. " " .. scale_abbr .. " · " .. config.CHORD_MODES[ci_h].name .. " · C" .. math.floor(prefs.GetOctave())
    local sw, sh = gfx.measurestr(state_str)
    local state_x = math.min(ver_x + vw + layout.US(250), help_x - sw - layout.US(250))
    gfx.x, gfx.y = state_x, ver_y
    gfx.drawstr(state_str)
    -- Scroll indicator
    gfx.setfont(1, "Calibri", layout.US(700))
    local scroll_indicator = ui_store.GetUseScroll() and "  ·  Scroll: ON" or "  ·  Scroll: OFF"
    local siw, sih = gfx.measurestr(scroll_indicator)
    gfx.x, gfx.y = state_x + sw + layout.US(60), ver_y + 2
    gfx.drawstr(scroll_indicator)
    
    if components.DrawToolIcon("help", help_x, (h - icon_size) / 2, icon_size) then
        ui_store.SetShowTooltips(not ui_store.GetShowTooltips())
    end
    if components.DrawToolIcon("settings", settings_x, (h - icon_size) / 2, icon_size) then
        local is_grade = ui_store.GetColorMode() == "grade"
        local toggle_label = is_grade and "Cambiar a Colores Planos" or "Cambiar a Grados a color"
        local scroll_label = (ui_store.GetUseScroll() and "✓ " or "") .. "Activar Scroll en Dropdowns"
        local compact_label = (ui_store.GetAutoStartCompact() and "✓ " or "") .. "Iniciar en Vista Mini"
        local reaper_label = (ui_store.GetAutoStartReaper() and "✓ " or "") .. "Iniciar con REAPER"
        local track_label = (ui_store.GetAutoTrackSetup() and "✓ " or "") .. "Auto armar pista al seleccionar"
        local menu = toggle_label .. "|Ajustar Posicion Vista Mini...|Resetear Posicion Vista Mini|" .. scroll_label .. "|" .. compact_label .. "|" .. reaper_label .. "|" .. track_label
        gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
        local choice = gfx.showmenu(menu)
        if choice == 1 then
            ui_store.SetColorMode(is_grade and "flat" or "grade")
            persist.Save("color_mode", ui_store.GetColorMode())
        elseif choice == 2 then
            local ret, csv = reaper.GetUserInputs("Posicion Vista Mini", 3,
                "Offset X (0=auto),Offset Y,extrawidth=200",
                config.state.view_offset_x .. "," .. config.state.view_offset_y)
            if ret then
                local nx, ny = csv:match("([^,]+),([^,]+)")
                local nx_num = tonumber(nx) or 0
                local ny_num = tonumber(ny) or 0
                if nx_num > 0 then
                    compact.SetManualPosition(nx_num, ny_num)
                else
                    compact.ResetAutoPosition()
                    config.state.view_offset_x = 0
                    config.state.view_offset_y = ny_num
                end
            end
        elseif choice == 3 then
            config.state.view_offset_x = 0
            config.state.view_offset_y = 0
            compact.ResetAutoPosition()
        elseif choice == 4 then
            ui_store.SetUseScroll(not ui_store.GetUseScroll())
            reaper.SetExtState("GROVE_Scale_Runner", "use_scroll",
                ui_store.GetUseScroll() and "1" or "0", true)
        elseif choice == 5 then
            ui_store.SetAutoStartCompact(not ui_store.GetAutoStartCompact())
            reaper.SetExtState("GROVE_Scale_Runner", "auto_start_compact",
                ui_store.GetAutoStartCompact() and "1" or "0", true)
        elseif choice == 6 then
            ui_store.SetAutoStartReaper(not ui_store.GetAutoStartReaper())
            reaper.SetExtState("GROVE_Scale_Runner", "auto_start_reaper",
                ui_store.GetAutoStartReaper() and "1" or "0", true)
        elseif choice == 7 then
            ui_store.SetAutoTrackSetup(not ui_store.GetAutoTrackSetup())
            reaper.SetExtState("GROVE_Scale_Runner", "auto_track_setup",
                ui_store.GetAutoTrackSetup() and "1" or "0", true)
        end
    end
    
    if components.DrawToolIcon("view", view_x, (h - icon_size) / 2, icon_size) then
        compact.SwitchViewMode()
    end
end

return m
