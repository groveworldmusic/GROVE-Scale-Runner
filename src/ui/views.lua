-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
local config = require("config")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local midi_store = require("state.midi")
local ui_store = require("state.ui")
local island_store = require("state.island")
local persist = require("state.persist")
local theme = require("ui.theme")
local components = require("ui.components")
local helpers = require("ui.helpers")
local midi = require("core.midi")
local compact = require("ui.compact")
local layout = require("ui.layout")
local progression = require("core.progression")
local sequencer = require("core.sequencer")
local piano_roll = require("ui.piano-roll")
local snap = require("core.snap")
local timeline = require("ui.timeline")
local velocity = require("ui.velocity")
local preset_browser = require("ui.preset-browser")
local midi_island = require("ui.midi-island")
local api_guard = require("core.api-guard")

local views = {}

-- Cached dropdown options (built once, scales don't change at runtime)
local SCALE_OPTIONS = (function() local t = {} for _, v in ipairs(config.SCALES) do t[#t + 1] = v.name end return t end)()
local OCTAVE_OPTIONS = {"C0", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"}









-- Shared right-click quick config menu (used by both views)
local function ShowQuickConfigMenu()
    local si_qc = api_guard.ClampIndex(config.state.scale_index, 1, #config.SCALES)
    local ci_qc = api_guard.ClampIndex(config.state.chord_mode_index, 1, #config.CHORD_MODES)
    local m = "ROOT: " .. config.NOTE_NAMES[api_guard.ClampIndex(config.state.root_index, 1, 12)] .. "|<SCALE: " .. helpers.AbbreviateScale(config.SCALES[si_qc].name) .. "|OCTAVE: C" .. math.floor(config.state.octave) .. "|CHORD: " .. config.CHORD_MODES[ci_qc].name .. "|VELOCITY: " .. (midi_store.GetUseVelocity() and "ON" or "OFF") .. "|Dock in Transport Bar"
    gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
    local choice = gfx.showmenu(m)
    if choice == 1 then
        config.state.root_index = (config.state.root_index % 12) + 1
        persist.Save("root_index", config.state.root_index)
    elseif choice == 2 then
        config.state.scale_index = (config.state.scale_index % #config.SCALES) + 1
        persist.Save("scale_index", config.state.scale_index)
    elseif choice == 3 then
        config.state.octave = math.floor((config.state.octave + 1) % 9)
        persist.Save("octave", config.state.octave)
    elseif choice == 4 then
        config.state.chord_mode_index = (config.state.chord_mode_index % #config.CHORD_MODES) + 1
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

function views.DrawHeader()
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
    local ri_h = api_guard.ClampIndex(config.state.root_index, 1, 12)
    local si_h = api_guard.ClampIndex(config.state.scale_index, 1, #config.SCALES)
    local ci_h = api_guard.ClampIndex(config.state.chord_mode_index, 1, #config.CHORD_MODES)
    local scale_abbr = helpers.AbbreviateScale(config.SCALES[si_h].name)
    local state_str = "  ·  " .. config.NOTE_NAMES[ri_h] .. " " .. scale_abbr .. " · " .. config.CHORD_MODES[ci_h].name .. " · C" .. math.floor(config.state.octave)
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

function views.DrawIslands()
    local y_start = layout.UY(2196)
    local island_h = layout.US(11750)
    local std_island_w = layout.US(5316)
    local std_btn_w = layout.US(4400)
    local std_btn_h = layout.US(1980)
    local title_font_size = layout.US(1250)
    local sub_font_size = layout.US(1193)
    local btn_font_size = layout.US(1100)
    
    ---------------------------------------------------------------------------
    -- Island 1: Scale & Piano
    ---------------------------------------------------------------------------
    local i1_x, i1_w = layout.UX(0), layout.US(22591)
    components.DrawIsland(i1_x, y_start, i1_w, island_h, "SCALE", title_font_size)
    local piano_x, piano_y = layout.UX(798), layout.UY(2981)
    local piano_w, piano_h = layout.US(21056), layout.US(7875)
    components.DrawPianoKeyboard(piano_x, piano_y, piano_w, piano_h, layout.US(1400))
    
    local row_h = layout.US(1548)
    local row_y = layout.UY(11700)
    local modo_lbl_x = layout.UX(1000)
    
    -- MODO label (misma posición)
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", title_font_size) 
    local mw, mh = gfx.measurestr("MODO")
    gfx.x, gfx.y = modo_lbl_x, row_y + (row_h - mh)/2
    gfx.drawstr("MODO")
    
    -- MODO dropdown (más cerca del label, altura reducida)
    local modo_drop_x = modo_lbl_x + mw + layout.US(400)
    local modo_drop_w = layout.US(7000)
    local si_is = api_guard.ClampIndex(config.state.scale_index, 1, #config.SCALES)
    local modo_val = helpers.AbbreviateScale(config.SCALES[si_is].name)
    local choice = components.DrawDropdown(modo_drop_x, row_y, modo_drop_w, row_h, nil, modo_val, 
                                          SCALE_OPTIONS, si_is, btn_font_size)
    if choice then config.state.scale_index = choice; persist.Save("scale_index", choice) end
    
    -- Grid label + dropdown (entre MODO y NOTE display)
    local note_x = layout.UX(18826)
    local grid_lbl_x = modo_drop_x + modo_drop_w + layout.US(1026)
    
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", title_font_size)
    local gw, gh = gfx.measurestr("GRID")
    gfx.x, gfx.y = grid_lbl_x, row_y + (row_h - gh)/2
    gfx.drawstr("GRID")
    
    local grid_drop_x = grid_lbl_x + gw + layout.US(400)
    local grid_drop_w = note_x - grid_drop_x - layout.US(400)
    local grid_choice = components.DrawDropdown(grid_drop_x, row_y, grid_drop_w, row_h,
        nil, config.SUBDIVISION_LABELS[config.state.subdivision_index],
        config.SUBDIVISION_LABELS, config.state.subdivision_index, btn_font_size)
    if grid_choice then config.state.subdivision_index = grid_choice end
    
    -- NOTE display (sin label, misma posición)
    components.DrawNoteDisplay(note_x, row_y, layout.US(2800), row_h, midi_store.GetLastNotePlayed())
    
    ---------------------------------------------------------------------------
    -- Island 2: Octava (144px height, content fits inside)
    ---------------------------------------------------------------------------
    local i2_x = layout.UX(23066)
    local short_island_h = layout.US(8708)
    local short_btn_h = layout.US(1700)
    components.DrawIsland(i2_x, y_start, std_island_w, short_island_h, nil, nil)
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", sub_font_size)
    local oct_tw, oct_th = gfx.measurestr("OCTAVA")
    gfx.x, gfx.y = i2_x + (std_island_w - oct_tw)/2, y_start
    gfx.drawstr("OCTAVA")
    local btn_x = i2_x + (std_island_w - std_btn_w)/2
    local oct_open_up = y_start > gfx.h / 2
    local oct_content_h = short_btn_h * 4 + layout.US(171) * 3
    local oct_content_y = y_start + math.floor((short_island_h - oct_content_h) / 2) + layout.US(398)
    local oct_gap = layout.US(171)
    local oct_choice = components.DrawDropdown(btn_x, oct_content_y, std_btn_w, short_btn_h,
        nil, "C"..math.floor(config.state.octave), OCTAVE_OPTIONS, config.state.octave + 1, btn_font_size, oct_open_up)  -- Issue 9
    if oct_choice then config.state.octave = math.floor(oct_choice - 1); persist.Save("octave", config.state.octave) end
    if components.DrawButton(btn_x, oct_content_y + short_btn_h + oct_gap, std_btn_w, short_btn_h,
                             "C5", config.state.octave == 5, btn_font_size) then config.state.octave = 5; persist.Save("octave", 5) end
    if components.DrawButton(btn_x, oct_content_y + (short_btn_h + oct_gap) * 2, std_btn_w, short_btn_h,
                             "C4", config.state.octave == 4, btn_font_size) then config.state.octave = 4; persist.Save("octave", 4) end
    if components.DrawButton(btn_x, oct_content_y + (short_btn_h + oct_gap) * 3, std_btn_w, short_btn_h,
                             "C3", config.state.octave == 3, btn_font_size) then config.state.octave = 3; persist.Save("octave", 3) end

    ---------------------------------------------------------------------------
    -- Island 3: Chord (144px height, content fits inside)
    ---------------------------------------------------------------------------
    local i3_x = layout.UX(28832)
    components.DrawIsland(i3_x, y_start, std_island_w, short_island_h, nil, nil)
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", sub_font_size)
    local ch_tw, ch_th = gfx.measurestr("CHORD")
    gfx.x, gfx.y = i3_x + (std_island_w - ch_tw)/2, y_start
    gfx.drawstr("CHORD")
    local cbtn_x = i3_x + (std_island_w - std_btn_w)/2
    if components.DrawButton(cbtn_x, oct_content_y, std_btn_w, short_btn_h,
                             "9NA", config.state.chord_mode_index == 4, btn_font_size) then config.state.chord_mode_index = 4; persist.Save("chord_mode_index", 4) end
    if components.DrawButton(cbtn_x, oct_content_y + short_btn_h + oct_gap, std_btn_w, short_btn_h,
                             "7MA", config.state.chord_mode_index == 3, btn_font_size) then config.state.chord_mode_index = 3; persist.Save("chord_mode_index", 3) end
    if components.DrawButton(cbtn_x, oct_content_y + (short_btn_h + oct_gap) * 2, std_btn_w, short_btn_h,
                             "TRI", config.state.chord_mode_index == 2, btn_font_size) then config.state.chord_mode_index = 2; persist.Save("chord_mode_index", 2) end
    if components.DrawButton(cbtn_x, oct_content_y + (short_btn_h + oct_gap) * 3, std_btn_w, short_btn_h,
                             "NOTE", config.state.chord_mode_index == 1, btn_font_size) then config.state.chord_mode_index = 1; persist.Save("chord_mode_index", 1) end

    ---------------------------------------------------------------------------
    -- Island: ISLA INVERSIONES (192×52px, below Octava + Chord, spans both)
    ---------------------------------------------------------------------------
    local inv_y = y_start + short_island_h + layout.US(512)
    local inv_w = (i3_x + std_island_w) - i2_x
    local inv_h = layout.US(2561)
    components.DrawIsland(i2_x, inv_y, inv_w, inv_h, nil, nil)

    local inv_font = btn_font_size
    local inv_item_h = layout.US(1707)  -- 30px alto común
    local inv_pad = layout.US(300)
    local inv_text_gap = layout.US(400)
    local inv_btn_gap = layout.US(171)  -- 3px entre botones
    local inv_item_y = inv_y + (inv_h - inv_item_h) / 2

    -- INV label (mismo tamaño que OCTAVA/CHORD)
    gfx.setfont(1, "Calibri", sub_font_size)
    local ilw, ilh = gfx.measurestr("INV")
    helpers.SetColor(theme.colors.text_dim)
    gfx.x, gfx.y = i2_x + inv_pad + layout.US(57), inv_item_y + (inv_item_h - ilh) / 2
    gfx.drawstr("INV")

    -- UP/DN toggle + 1st/2nd/3rd buttons (rellenan el espacio restante con margen simétrico)
    local inv_btn_area_start = i2_x + inv_pad + ilw + inv_text_gap
    local inv_btn_area_end = i2_x + inv_w - inv_pad
    local inv_btn_area_w = inv_btn_area_end - inv_btn_area_start
    local inv_btn_w = math.floor((inv_btn_area_w - inv_btn_gap * 3) / 4)

    -- Button 1: UP/DN direction toggle (always selected, shows current direction)
    local bx1 = inv_btn_area_start
    local dir_text = config.state.inversion_direction == 0 and "UP" or "DN"
    if components.DrawButton(bx1, inv_item_y, inv_btn_w, inv_item_h, dir_text, true, inv_font) then
        config.state.inversion_direction = config.state.inversion_direction == 0 and 1 or 0
    end

    -- Buttons 2-4: 1st, 2nd, 3rd inversion (click active → root; click another → select)
    local inv_labels = {"1st", "2nd", "3rd"}
    for i = 1, 3 do
        local bx = inv_btn_area_start + i * (inv_btn_w + inv_btn_gap)
        local inv_idx = i + 1  -- maps to config indices 2, 3, 4
        if components.DrawButton(bx, inv_item_y, inv_btn_w, inv_item_h,
                                 inv_labels[i], config.state.inversion_index == inv_idx, inv_font) then
            config.state.inversion_index = (config.state.inversion_index == inv_idx) and 1 or inv_idx
            persist.Save("inversion_index", config.state.inversion_index)
        end
    end

    ---------------------------------------------------------------------------
    -- Island 4: Command Vertical Stack (Alineación Exacta)
    ---------------------------------------------------------------------------
    local i4_x = layout.UX(34541)
    local b_w = std_island_w + layout.US(57)
    local b_h = layout.US(1980)
    -- Padding calculado dinámicamente para alinear el borde inferior
    local b_gap = (island_h - (b_h * 5)) / 4
    local function PressOverlay(x, y, w, h)
        helpers.SetColor({0, 0, 0, 0.15})
        gfx.rect(x, y, w, h / 2, 1)
    end
    
    -- 1. VEL Island
    local v_y = y_start
    local v_hover = gfx.mouse_x >= i4_x and gfx.mouse_x <= i4_x + b_w and gfx.mouse_y >= v_y and gfx.mouse_y <= v_y + b_h
    local vel_on = midi_store.GetUseVelocity()
    local v_bg = vel_on and theme.colors.btn_active or (v_hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(v_bg)
    components.DrawRoundedRect(i4_x, v_y, b_w, b_h, 10, true)
    if ui_store.GetMouseClick() and v_hover and not drag_store.GetIsDragging() then PressOverlay(i4_x, v_y, b_w, b_h) end
    helpers.SetColor(vel_on and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1500))
    local vw, vh = gfx.measurestr("VEL")
    gfx.x, gfx.y = i4_x + (b_w - vw)/2, v_y + (b_h - vh)/2
    gfx.drawstr("VEL")
    if v_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip(midi_store.GetUseVelocity() and "Click: disable" or "Click: enable", layout.US(700))
    end
    if ui_store.GetMouseClick() and v_hover and not drag_store.GetIsDragging() then midi_store.SetUseVelocity(not midi_store.GetUseVelocity()) end
    
    -- 2. PLAY/STOP Island
    local p_y = v_y + b_h + b_gap - layout.US(57)
    local p_hover = gfx.mouse_x >= i4_x and gfx.mouse_x <= i4_x + b_w and gfx.mouse_y >= p_y and gfx.mouse_y <= p_y + b_h
    local is_playing = seq_store.GetIsPlaying()
    local p_bg = is_playing and theme.colors.slot_playing or (p_hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(p_bg)
    components.DrawRoundedRect(i4_x, p_y, b_w, b_h, 10, true)
    if ui_store.GetMouseClick() and p_hover and not drag_store.GetIsDragging() then PressOverlay(i4_x, p_y, b_w, b_h) end
    local cx, cy = i4_x + b_w/2, p_y + b_h/2
    local s = layout.US(1000)
    if is_playing then
        helpers.SetColor({0,0,0,0.4})
        gfx.rect(cx-s/2, cy-s/2, s, s, 1)
    else
        helpers.SetColor(theme.colors.slot_playing)
        gfx.triangle(cx-s/2, cy-s/2, cx-s/2, cy+s/2, cx+s/2, cy)
    end
    if p_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Play/Stop progression", layout.US(700))
    end
    if ui_store.GetMouseClick() and p_hover and not drag_store.GetIsDragging() then
        if is_playing then sequencer.Stop() else seq_store.SetIsPlaying(true) end
    end
    
    -- 3. CLEAR + EXPORT (side by side, same row)
    local c_y = p_y + b_h + b_gap - layout.US(57)
    local split_gap = layout.US(500)  -- gap entre CLEAR y EXPORT
    local half_w = math.floor((b_w - split_gap) / 2)
    local clear_x = i4_x
    local export_x = i4_x + half_w + split_gap

    -- CLEAR icon (left half)
    local clear_hover = gfx.mouse_x >= clear_x and gfx.mouse_x <= clear_x + half_w and gfx.mouse_y >= c_y and gfx.mouse_y <= c_y + b_h
    local clear_bg = clear_hover and {0.4, 0.1, 0.1, 1} or theme.colors.island_bg
    helpers.SetColor(clear_bg)
    components.DrawRoundedRect(clear_x, c_y, half_w, b_h, 10, true)
    if ui_store.GetMouseClick() and clear_hover and not drag_store.GetIsDragging() then PressOverlay(clear_x, c_y, half_w, b_h) end
    local icon_pad = math.floor((half_w - b_h) / 2)
    if components.DrawToolIcon("clear", clear_x + icon_pad, c_y, b_h, false) then
        progression.Clear()
    end
    if clear_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Clear all slots", layout.US(700))
    end

    -- EXPORT icon (right half)
    local export_hover = gfx.mouse_x >= export_x and gfx.mouse_x <= export_x + half_w and gfx.mouse_y >= c_y and gfx.mouse_y <= c_y + b_h
    local export_bg = export_hover and theme.colors.btn_hover or theme.colors.island_bg
    helpers.SetColor(export_bg)
    components.DrawRoundedRect(export_x, c_y, half_w, b_h, 10, true)
    if ui_store.GetMouseClick() and export_hover and not drag_store.GetIsDragging() then PressOverlay(export_x, c_y, half_w, b_h) end
    if components.DrawToolIcon("export", export_x + icon_pad, c_y, b_h, false) then
        midi.ExportToMidi()
    end
    if export_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Export MIDI", layout.US(700))
    end

    -- 4. MIDI TOGGLE (replaces old EXPORT)
    local e_y = c_y + b_h + b_gap - layout.US(57)
    local e_hover = gfx.mouse_x >= i4_x and gfx.mouse_x <= i4_x + b_w and gfx.mouse_y >= e_y and gfx.mouse_y <= e_y + b_h
    local midi_expanded = midi.midi_island_expanded
    local e_bg = midi_expanded and theme.colors.btn_active or (e_hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(e_bg)
    components.DrawRoundedRect(i4_x, e_y, b_w, b_h, 10, true)
    if ui_store.GetMouseClick() and e_hover and not drag_store.GetIsDragging() then PressOverlay(i4_x, e_y, b_w, b_h) end
    helpers.SetColor(midi_expanded and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1500))
    local ew, eh = gfx.measurestr("MIDI")
    gfx.x, gfx.y = i4_x + (b_w - ew)/2, e_y + (b_h - eh)/2
    gfx.drawstr("MIDI")
    if e_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip(midi_expanded and "Collapse MIDI island" or "Expand MIDI island", layout.US(700))
    end
    if ui_store.GetMouseClick() and e_hover and not drag_store.GetIsDragging() then midi.ToggleIsland() end

    -- 5. VOLUME SLIDER
    local s_y = e_y + b_h + layout.US(398) + layout.US(57) + layout.US(57)
    local vol_h = (v_y + island_h) - s_y
    local s_hover = gfx.mouse_x >= i4_x and gfx.mouse_x <= i4_x + b_w and gfx.mouse_y >= s_y and gfx.mouse_y <= s_y + vol_h
    local volume = seq_store.GetVolume() or 100

    -- Track (mismo island_bg que los botones para que coincida visualmente)
    helpers.SetColor(theme.colors.island_bg)
    components.DrawRoundedRect(i4_x, s_y, b_w, vol_h, 10, true)

    -- Fill (barra activa con padding interno de layout.US(180))
    local fill_pad = layout.US(180)
    local fill_w = (volume / 100) * (b_w - fill_pad * 2)
    if fill_w > 0 then
        helpers.SetColor(theme.colors.btn_active)
        components.DrawRoundedRect(i4_x + fill_pad, s_y + fill_pad, fill_w, vol_h - fill_pad * 2, 10, true)
    end

    -- Label
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", layout.US(1100))
    local label = string.format("VOL %d%%", volume)
    local lw, lh = gfx.measurestr(label)
    gfx.x, gfx.y = i4_x + (b_w - lw)/2, s_y + (vol_h - lh)/2
    gfx.drawstr(label)

    -- Interaction
    if s_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Volume: " .. volume .. "%", layout.US(700))
    end
    -- Scroll wheel volume adjustment
    if s_hover and ui_store.GetUseScroll() and ui_store.GetMouseWheelDelta() ~= 0 then
        local delta = ui_store.GetMouseWheelDelta() > 0 and 5 or -5
        ui_store.SetMouseWheelDelta(0)
        seq_store.SetVolume(math.max(0, math.min(100, volume + delta)))
    end
    if ui_store.GetMouseClick() and s_hover and not drag_store.GetIsDragging() then
        ui_store.SetSliderDragging(true)
    end
    if ui_store.GetSliderDragging() then
        local ratio = (gfx.mouse_x - i4_x) / b_w
        seq_store.SetVolume(math.floor(math.max(0, math.min(100, ratio * 100))))
        if (gfx.mouse_cap & 1) == 0 then
            ui_store.SetSliderDragging(false)
        end
    end
end

function views.DecrementPageOverrideTimer()
    -- Decrement in ALL modes, not just DrawPerformanceArea (Issue 8)
    if seq_store.GetPageOverrideTimer() > 0 then seq_store.SetPageOverrideTimer(seq_store.GetPageOverrideTimer() - 1) end
end

function views.DrawPerformanceArea()
    if seq_store.GetIsPlaying() and seq_store.GetPageOverrideTimer() <= 0 then
        local target_page = math.floor((seq_store.GetCurrentStep() - 1) / 4) + 1
        if target_page > 0 and target_page <= 4 then seq_store.SetCurrentPage(target_page) end
    end
    
    local x_start, w = layout.UX(0), layout.US(39914)
    local y, h = layout.UY(14375), layout.US(13363)
    
    -- Scroll pagination logic
    local hover_area = gfx.mouse_x >= x_start and gfx.mouse_x <= x_start + w and gfx.mouse_y >= y and gfx.mouse_y <= y + h
    if hover_area and ui_store.GetMouseWheelDelta() ~= 0 then
        local dir = ui_store.GetMouseWheelDelta() > 0 and -1 or 1
        seq_store.SetCurrentPage(math.max(1, math.min(4, seq_store.GetCurrentPage() + dir)))
    end

    helpers.SetColor(theme.colors.island_bg)
    components.DrawRoundedRect(x_start, y, w, h, 15, true)
    local margin = layout.US(800)
    local avail_w = w - (margin * 2)
    local pad_w, pad_h = layout.US(5300), layout.US(4116)
    local si_pa = api_guard.ClampIndex(config.state.scale_index, 1, #config.SCALES)
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
        local sx = x_start + margin + i * (slot_w + slot_spacing)
        components.DrawProgressionSlot(start_idx + i, sx, slots_y, slot_w, slot_h)
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

-- Track progression revision to reload notes when progression changes
local _island_progression_revision = -1

-- Horizontal scrollbar thumb drag state (task 3.1)
local _sb_dragging = false
local _sb_drag_start_x = 0
local _sb_scroll_at_drag_start = 0

-- Vertical scrollbar thumb drag state
local _vsb_dragging = false
local _vsb_drag_start_y = 0
local _vsb_scroll_at_drag_start = 0

-- Extracted helpers from DrawMIDIIsland
function views.DrawKeyboardShortcutOverlay(char, tool_mode)
    -- Uses `char` passed from MainLoop via DrawFullView.
    -- Single gfx.getchar() per frame — avoids double-read crash (regression PR3).
    -- Ctrl+Z/Y/X/C/V, Delete, arrows, Shift+arrows.
    -- Unhandled keys fall through to REAPER.
    -- Escape: Cancel note drag/resize (PR2).
    local keyboard_consumed = false

    -- Handle Escape for cancel drag first (always active)
    if char == 27 and island_store.GetNoteDragActive() then
        piano_roll.CancelNoteDrag()
        keyboard_consumed = true
    end

    -- Handle piano roll keyboard shortcuts (pointer/eraser mode)
    if not keyboard_consumed and (tool_mode == "pointer" or tool_mode == "eraser") then
        local scroll_beat = island_store.GetScrollOffsetX()
        keyboard_consumed = piano_roll.HandleKeyboardShortcut(char, scroll_beat)
    end
end

function views.DrawSnapControls(presets_x, b_w, b_h, header_y)
    -- Snap Controls (PR2) — right of PRESETS
    local snap_toggle_w = math.floor(b_w * 0.65)
    local snap_res_w = math.floor(b_w * 0.50)
    local snap_trip_w = math.floor(b_w * 0.35)
    local snap_gap = 4
    local snap_x = presets_x + b_w + 8  -- right of PRESETS
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
    end
    if st_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip(snap_enabled and "Snap: ON" or "Snap: OFF", layout.US(700))
    end

    -- Snap resolution button (click to open menu)
    local sr_x = snap_x + snap_toggle_w + snap_gap
    local sr_hover = gfx.mouse_x >= sr_x and gfx.mouse_x <= sr_x + snap_res_w
                 and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    helpers.SetColor(sr_hover and theme.colors.btn_hover or theme.colors.island_bg)
    components.DrawRoundedRect(sr_x, header_y, snap_res_w, b_h, 10, true)
    helpers.SetColor(snap_enabled and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1300))
    -- Resolution label: 1=1/1, 2=1/2, 4=1/4, 8=1/8, 16=1/16, 32=1/32
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
            if not island_store.GetSnapEnabled() then
                island_store.SetSnapEnabled(true)
            end
        end
    end
    if sr_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Snap resolution: " .. snap_res_label, layout.US(700))
    end

    -- Triplet toggle button
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
    end
    if stp_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip(snap_trip and "Triplet: ON" or "Triplet: OFF", layout.US(700))
    end
end

function views.DrawToolModeRow(ch_x, b_w, b_h, header_y)
    -- Tool mode buttons (Phase 4) — left of CH
    local tool_btn_w = math.floor(b_w * 0.55)
    local tool_btn_gap = 4
    local tools_total_w = tool_btn_w * 3 + tool_btn_gap * 2
    local tool_x = ch_x - tools_total_w - 8
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

        -- Icon/label
        helpers.SetColor(t_active and theme.colors.text or theme.colors.text_dim)
        gfx.setfont(1, "Calibri", layout.US(1500))
        local tlw, tlh = gfx.measurestr(tool_labels[ti])
        gfx.x, gfx.y = tx + (tool_btn_w - tlw) / 2, header_y + (b_h - tlh) / 2
        gfx.drawstr(tool_labels[ti])

        -- Click handler
        if ui_store.GetMouseClick() and t_hover and not drag_store.GetIsDragging() then
            island_store.SetToolMode(tool_modes[ti])
            velocity.ResetDrag()
        end

        -- Tooltip
        if t_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip(tool_hints[ti], layout.US(700))
        end
    end
end

function views.DrawMIDIIsland(char)
    midi_island.Draw(char)
end

function views.DrawFullView(char)
    -- Scale es CONSTANTE: se calcula contra la altura BASE de diseño (500px)
    -- para que el contenido NO se deforme al expandir/colapsar la MIDI island.
    -- Expandir solo agrega canvas abajo para la isla, no cambia el zoom.
    local s = math.min(gfx.w / 39914, 500 / 29162) * 1.025
    local ox = (gfx.w - 39914 * s) / 2
    local oy = 600 * s - 10
    layout.SetScale(s, ox, oy)
    helpers.SetColor(theme.colors.bg)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)
    views.DrawHeader()
    views.DrawIslands()
    views.DrawPerformanceArea()
    views.DrawMIDIIsland(char)
end

-- Docked Transport Bar: compact 50px horizontal strip
function views.DrawDockedTransportBar(dock_w, dock_h)
    helpers.SetColor(theme.colors.bg)
    gfx.rect(0, 0, dock_w, dock_h, 1)

    local btn_h = 38
    local btn_y = (dock_h - btn_h) / 2
    local btn_w = 50
    local gap = 2
    local x_pos = 10

    -- [ROOT] button - cycles through root notes
    if components.DrawTransportButton(config.NOTE_NAMES[api_guard.ClampIndex(config.state.root_index, 1, 12)], x_pos, btn_y, btn_w, btn_h) then
        config.state.root_index = (config.state.root_index % 12) + 1
        persist.Save("root_index", config.state.root_index)
    end
    x_pos = x_pos + btn_w + gap

    -- [SCALE] button - cycles through scales
    local si_dt = api_guard.ClampIndex(config.state.scale_index, 1, #config.SCALES)
    local scale_abbr = helpers.AbbreviateScale(config.SCALES[si_dt].name)
    if components.DrawTransportButton(scale_abbr, x_pos, btn_y, btn_w + 20, btn_h) then
        config.state.scale_index = (config.state.scale_index % #config.SCALES) + 1
        persist.Save("scale_index", config.state.scale_index)
    end
    x_pos = x_pos + btn_w + 20 + gap

    -- [OCT−] button
    if components.DrawTransportButton("−", x_pos, btn_y, 30, btn_h) then
        config.state.octave = math.floor(math.max(0, config.state.octave - 1))
        persist.Save("octave", config.state.octave)
    end
    x_pos = x_pos + 30 + gap

    -- [OCT+] button
    if components.DrawTransportButton("+", x_pos, btn_y, 30, btn_h) then
        config.state.octave = math.floor(math.min(8, config.state.octave + 1))
        persist.Save("octave", config.state.octave)
    end
    x_pos = x_pos + 30 + gap

    -- [CHORD] button - cycles chord modes
    local ci_dt = api_guard.ClampIndex(config.state.chord_mode_index, 1, #config.CHORD_MODES)
    local chord_label = config.CHORD_MODES[ci_dt].name
    if components.DrawTransportButton(chord_label, x_pos, btn_y, btn_w, btn_h) then
        config.state.chord_mode_index = (config.state.chord_mode_index % #config.CHORD_MODES) + 1
        persist.Save("chord_mode_index", config.state.chord_mode_index)
    end
    x_pos = x_pos + btn_w + gap

    -- [VEL] button - toggle velocity
    local vel_label = midi_store.GetUseVelocity() and "VEL" or "VEL-"
    local vel_active = midi_store.GetUseVelocity()
    local vel_hover = gfx.mouse_x >= x_pos and gfx.mouse_x <= x_pos + btn_w and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
    helpers.SetColor(vel_active and theme.colors.btn_active or (vel_hover and theme.colors.btn_hover or theme.colors.btn_bg))
    components.DrawRoundedRect(x_pos, btn_y, btn_w, btn_h, 6, true)
    helpers.SetColor(vel_active and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 11)
    local vw, vh = gfx.measurestr(vel_label)
    gfx.x, gfx.y = x_pos + (btn_w - vw) / 2, btn_y + (btn_h - vh) / 2
    gfx.drawstr(vel_label)
    if ui_store.GetMouseClick() and vel_hover then
        midi_store.SetUseVelocity(not midi_store.GetUseVelocity())
    end
    x_pos = x_pos + btn_w + gap

    -- [PLAY/STOP] button
    local is_playing = seq_store.GetIsPlaying()
    local play_hover = gfx.mouse_x >= x_pos and gfx.mouse_x <= x_pos + btn_w and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
    helpers.SetColor(is_playing and theme.colors.slot_playing or (play_hover and theme.colors.btn_hover or theme.colors.btn_bg))
    components.DrawRoundedRect(x_pos, btn_y, btn_w, btn_h, 6, true)
    local cx, cy = x_pos + btn_w / 2, btn_y + btn_h / 2
    local s = 12
    if is_playing then
        helpers.SetColor({0, 0, 0, 0.6})
        gfx.rect(cx - s / 2, cy - s / 2, s, s, 1)
    else
        helpers.SetColor(theme.colors.slot_playing)
        gfx.triangle(cx - s / 2, cy - s / 2, cx - s / 2, cy + s / 2, cx + s / 2, cy)
    end
    if ui_store.GetMouseClick() and play_hover then
        if is_playing then sequencer.Stop() else seq_store.SetIsPlaying(true) end
    end
    x_pos = x_pos + btn_w + gap

    -- [CLEAR] button - clear progression
    if components.DrawTransportButton("CLR", x_pos, btn_y, btn_w, btn_h) then
        progression.Clear()
    end
    x_pos = x_pos + btn_w + gap

    -- [◄ Undock] button - undock and return to floating (Issue 6: U+25C4 better glyph support)
    if components.DrawTransportButton("◄", x_pos, btn_y, 50, btn_h) then
        gfx.dock(0)
        ui_store.SetDockedMode(false)
        ui_store.SetDockId(0)
        -- Resize back to normal window
        gfx.init("GROVE SCALE RUNNER", 720, 497, 0, config.state.view_offset_x, config.state.view_offset_y)
    end
end

return views
