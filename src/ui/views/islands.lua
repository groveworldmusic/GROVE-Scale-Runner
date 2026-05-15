-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Views — Islands
-- DrawIslands: Scale & Piano, Octava, Chord, Inversiones, Command Vertical Stack.
-- Extracted from views.lua (Sprint 2).

local config = require("config")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local midi_store = require("state.midi")
local ui_store = require("state.ui")
local prefs = require("state.preferences")
local theme = require("ui.theme")
local components = require("ui.components")
local helpers = require("ui.helpers")
local layout = require("ui.layout")
local persist = require("state.persist")
local sequencer = require("core.sequencer")
local midi = require("core.midi")
local progression = require("core.progression")
local api_guard = require("core.api-guard")

local m = {}

-- Cached dropdown options (built once, scales don't change at runtime)
local SCALE_OPTIONS = (function() local t = {} for _, v in ipairs(config.SCALES) do t[#t + 1] = v.name end return t end)()
local OCTAVE_OPTIONS = {"C0", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"}

function m.DrawIslands()
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
    local si_is = api_guard.ClampIndex(prefs.GetScaleIndex(), 1, #config.SCALES)
    local modo_val = helpers.AbbreviateScale(config.SCALES[si_is].name)
    local choice = components.DrawDropdown(modo_drop_x, row_y, modo_drop_w, row_h, nil, modo_val, 
                                          SCALE_OPTIONS, si_is, btn_font_size)
    if choice then config.state.scale_index = choice; prefs.SetScaleIndex(choice); persist.Save("scale_index", choice) end
    
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
        nil, config.SUBDIVISION_LABELS[prefs.GetSubdivisionIndex()],
        config.SUBDIVISION_LABELS, prefs.GetSubdivisionIndex(), btn_font_size)
    if grid_choice then config.state.subdivision_index = grid_choice; prefs.SetSubdivisionIndex(grid_choice); persist.Save("subdivision_index", grid_choice) end
    
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
        nil, "C"..math.floor(prefs.GetOctave()), OCTAVE_OPTIONS, prefs.GetOctave() + 1, btn_font_size, oct_open_up)  -- Issue 9
    if oct_choice then config.state.octave = math.floor(oct_choice - 1); prefs.SetOctave(config.state.octave); persist.Save("octave", config.state.octave) end
    if components.DrawButton(btn_x, oct_content_y + short_btn_h + oct_gap, std_btn_w, short_btn_h,
                             "C5", prefs.GetOctave() == 5, btn_font_size) then config.state.octave = 5; prefs.SetOctave(5); persist.Save("octave", 5) end
    if components.DrawButton(btn_x, oct_content_y + (short_btn_h + oct_gap) * 2, std_btn_w, short_btn_h,
                             "C4", prefs.GetOctave() == 4, btn_font_size) then config.state.octave = 4; prefs.SetOctave(4); persist.Save("octave", 4) end
    if components.DrawButton(btn_x, oct_content_y + (short_btn_h + oct_gap) * 3, std_btn_w, short_btn_h,
                             "C3", prefs.GetOctave() == 3, btn_font_size) then config.state.octave = 3; prefs.SetOctave(3); persist.Save("octave", 3) end

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
                             "9NA", prefs.GetChordModeIndex() == 4, btn_font_size) then config.state.chord_mode_index = 4; prefs.SetChordModeIndex(4); persist.Save("chord_mode_index", 4) end
    if components.DrawButton(cbtn_x, oct_content_y + short_btn_h + oct_gap, std_btn_w, short_btn_h,
                             "7MA", prefs.GetChordModeIndex() == 3, btn_font_size) then config.state.chord_mode_index = 3; prefs.SetChordModeIndex(3); persist.Save("chord_mode_index", 3) end
    if components.DrawButton(cbtn_x, oct_content_y + (short_btn_h + oct_gap) * 2, std_btn_w, short_btn_h,
                             "TRI", prefs.GetChordModeIndex() == 2, btn_font_size) then config.state.chord_mode_index = 2; prefs.SetChordModeIndex(2); persist.Save("chord_mode_index", 2) end
    if components.DrawButton(cbtn_x, oct_content_y + (short_btn_h + oct_gap) * 3, std_btn_w, short_btn_h,
                             "NOTE", prefs.GetChordModeIndex() == 1, btn_font_size) then config.state.chord_mode_index = 1; prefs.SetChordModeIndex(1); persist.Save("chord_mode_index", 1) end

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
    local dir_text = prefs.GetInversionDirection() == 0 and "UP" or "DN"
    if components.DrawButton(bx1, inv_item_y, inv_btn_w, inv_item_h, dir_text, true, inv_font) then
        config.state.inversion_direction = prefs.GetInversionDirection() == 0 and 1 or 0
        prefs.SetInversionDirection(config.state.inversion_direction)
        persist.Save("inversion_direction", config.state.inversion_direction)
    end

    -- Buttons 2-4: 1st, 2nd, 3rd inversion (click active → root; click another → select)
    local inv_labels = {"1st", "2nd", "3rd"}
    for i = 1, 3 do
        local bx = inv_btn_area_start + i * (inv_btn_w + inv_btn_gap)
        local inv_idx = i + 1  -- maps to config indices 2, 3, 4
        if components.DrawButton(bx, inv_item_y, inv_btn_w, inv_item_h,
                                 inv_labels[i], prefs.GetInversionIndex() == inv_idx, inv_font) then
            config.state.inversion_index = (prefs.GetInversionIndex() == inv_idx) and 1 or inv_idx
            prefs.SetInversionIndex(config.state.inversion_index)
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

return m
