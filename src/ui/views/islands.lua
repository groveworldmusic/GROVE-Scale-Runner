-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Views — Islands
-- DrawIslands: Scale & Piano, Octava, Chord, Inversiones, Command Vertical Stack.
-- Extracted from views.lua (Sprint 2).

local config = require("config")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local midi_store = require("state.midi")
local ui_store = require("state.ui")
local island_store = require("state.island")
local prefs = require("state.preferences")
local theme = require("ui.theme")
local components = require("ui.components")
local helpers = require("ui.helpers")
local layout = require("ui.layout")
-- persist removed; prefs.SetKey marks dirty_key, TickSaveDebounce() flushes
local sequencer = require("core.sequencer")
local midi = require("core.midi")
local gfx_window = require("ui.gfx-window")
local progression = require("core.progression")
local api_guard = require("core.api-guard")

local m = {}

-- Cached dropdown options (built once, scales don't change at runtime)
local SCALE_OPTIONS = (function() local t = {} for _, v in ipairs(config.SCALES) do t[#t + 1] = v.name end return t end)()
local CHORD_OPTIONS = (function() local t = {} for _, v in ipairs(config.CHORD_MODES) do t[#t + 1] = v.name end return t end)()
local OCTAVE_OPTIONS = {"C0", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"}

-- Module-scoped helpers (avoid closure allocation every frame, S3)
local function PressOverlay(x, y, w, h)
    helpers.SetColor({0, 0, 0, 0.15})
    gfx.rect(x, y, w, h / 2, 1)
end

--- Side-by-side half-width calculation
local function SplitWidths(total, gap)
    local avail = total - gap
    local left = math.floor(avail / 2)
    return left, avail - left
end

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
    if choice then prefs.SetScaleIndex(choice) end
    
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
    local si_clamped = api_guard.ClampIndex(prefs.GetSubdivisionIndex(), 1, #config.SUBDIVISION_LABELS)
    local grid_choice = components.DrawDropdown(grid_drop_x, row_y, grid_drop_w, row_h,
        nil, config.SUBDIVISION_LABELS[si_clamped],
        config.SUBDIVISION_LABELS, si_clamped, btn_font_size)
    if grid_choice then prefs.SetSubdivisionIndex(grid_choice) end
    
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
    local oct_content_h = short_btn_h * 4 + layout.US(171) * 3
    local oct_content_y = y_start + math.floor((short_island_h - oct_content_h) / 2) + layout.US(398)
    local oct_gap = layout.US(171)
    local oct_choice = components.DrawDropdown(btn_x, oct_content_y, std_btn_w, short_btn_h,
        nil, "C"..math.floor(prefs.GetOctave()), OCTAVE_OPTIONS,
        api_guard.ClampIndex(prefs.GetOctave() + 1, 1, #OCTAVE_OPTIONS), btn_font_size)  -- W7: guard against corrupted ExtState
    if oct_choice then local oct = math.floor(oct_choice - 1); prefs.SetOctave(oct) end
    if components.DrawButton(btn_x, oct_content_y + short_btn_h + oct_gap, std_btn_w, short_btn_h,
                             "C5", prefs.GetOctave() == 5, btn_font_size) then prefs.SetOctave(5) end
    if components.DrawButton(btn_x, oct_content_y + (short_btn_h + oct_gap) * 2, std_btn_w, short_btn_h,
                             "C4", prefs.GetOctave() == 4, btn_font_size) then prefs.SetOctave(4) end
    if components.DrawButton(btn_x, oct_content_y + (short_btn_h + oct_gap) * 3, std_btn_w, short_btn_h,
                             "C3", prefs.GetOctave() == 3, btn_font_size) then prefs.SetOctave(3) end

    ---------------------------------------------------------------------------
    -- Island 3: Chord (dropdown + TRI/7MA/9NA quick buttons, like octave island)
    ---------------------------------------------------------------------------
    local i3_x = layout.UX(28832)
    components.DrawIsland(i3_x, y_start, std_island_w, short_island_h, nil, nil)
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", sub_font_size)
    local ch_tw, ch_th = gfx.measurestr("CHORD")
    gfx.x, gfx.y = i3_x + (std_island_w - ch_tw)/2, y_start
    gfx.drawstr("CHORD")
    local cbtn_x = i3_x + (std_island_w - std_btn_w)/2
    local chord_cmi = api_guard.ClampIndex(prefs.GetChordModeIndex(), 1, #config.CHORD_MODES)
    local chord_choice = components.DrawDropdown(cbtn_x, oct_content_y, std_btn_w, short_btn_h,
        nil, config.CHORD_MODES[chord_cmi].name, CHORD_OPTIONS, chord_cmi, btn_font_size)
    if chord_choice then
        prefs.SetChordModeIndex(chord_choice)
    end
    -- Order from bottom to top: Tri, 7ma, 9na (Item 11 fix: position 3 = bottom = Tri, position 1 = top = 9na)
    if components.DrawButton(cbtn_x, oct_content_y + (short_btn_h + oct_gap) * 3, std_btn_w, short_btn_h,
                             "TRI", prefs.GetChordModeIndex() == 2, btn_font_size) then
        local new_val = prefs.GetChordModeIndex() == 2 and 1 or 2
        prefs.SetChordModeIndex(new_val)
    end
    if components.DrawButton(cbtn_x, oct_content_y + (short_btn_h + oct_gap) * 2, std_btn_w, short_btn_h,
                             "7MA", prefs.GetChordModeIndex() == 3, btn_font_size) then
        local new_val = prefs.GetChordModeIndex() == 3 and 1 or 3
        prefs.SetChordModeIndex(new_val)
    end
    if components.DrawButton(cbtn_x, oct_content_y + short_btn_h + oct_gap, std_btn_w, short_btn_h,
                             "9NA", prefs.GetChordModeIndex() == 4, btn_font_size) then
        local new_val = prefs.GetChordModeIndex() == 4 and 1 or 4
        prefs.SetChordModeIndex(new_val)
    end

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
        local new_dir = prefs.GetInversionDirection() == 0 and 1 or 0
        prefs.SetInversionDirection(new_dir)
    end

    -- Buttons 2-4: 1st, 2nd, 3rd inversion (click active → root; click another → select)
    local inv_labels = {"1st", "2nd", "3rd"}
    for i = 1, 3 do
        local bx = inv_btn_area_start + i * (inv_btn_w + inv_btn_gap)
        local inv_idx = i + 1  -- maps to config indices 2, 3, 4
        if components.DrawButton(bx, inv_item_y, inv_btn_w, inv_item_h,
                                 inv_labels[i], prefs.GetInversionIndex() == inv_idx, inv_font) then
            local new_inv = (prefs.GetInversionIndex() == inv_idx) and 1 or inv_idx
            prefs.SetInversionIndex(new_inv)
        end
    end

    ---------------------------------------------------------------------------
    -- Island 4: Command Vertical Stack
    ---------------------------------------------------------------------------
    local i4_x = layout.UX(34541)
    local b_w = std_island_w + layout.US(57)
    local b_h = layout.US(1980)
    -- NOTA: NO hay DrawIsland() contenedor — cada botón tiene su propio fondo
    -- Padding calculado dinámicamente para alinear el borde inferior
    local b_gap = (island_h - (b_h * 5)) / 4  -- provisional; vol_h clamping may shift MIDI row (C2)
    local half_gap = layout.US(400)
    
    -- Row tracking
    local r0_y = y_start
    
    -- =========================================================
    -- Row 1: VEL | SUST
    -- =========================================================
    do
        local l, r = SplitWidths(b_w, half_gap)
        local vel_x, sust_x = i4_x, i4_x + l + half_gap
        
        -- VEL (left)
        local v_hover = gfx.mouse_x >= vel_x and gfx.mouse_x <= vel_x + l and gfx.mouse_y >= r0_y and gfx.mouse_y <= r0_y + b_h
        local vel_on = midi_store.GetUseVelocity()
        local v_bg = vel_on and theme.colors.btn_active or (v_hover and theme.colors.btn_hover or theme.colors.island_bg)
        helpers.SetColor(v_bg)
        components.DrawRoundedRect(vel_x, r0_y, l, b_h, 10, true)
        if ui_store.GetMouseClick() and v_hover and not drag_store.GetIsDragging() then PressOverlay(vel_x, r0_y, l, b_h) end
        helpers.SetColor(vel_on and theme.colors.text or theme.colors.text_dim)
        gfx.setfont(1, "Calibri", layout.US(1500))
        local vw, vh = gfx.measurestr("VEL")
        gfx.x, gfx.y = vel_x + (l - vw)/2, r0_y + (b_h - vh)/2
        gfx.drawstr("VEL")
        if v_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip(midi_store.GetUseVelocity() and "Velocity: ON — click off" or "Velocity: OFF — click on", layout.US(700))
        end
        if ui_store.GetMouseClick() and v_hover and not drag_store.GetIsDragging() then midi_store.SetUseVelocity(not midi_store.GetUseVelocity()) end
        
        -- SUST (right) — smaller text
        local sust_held = midi.GetSustain()
        local sust_hover = gfx.mouse_x >= sust_x and gfx.mouse_x <= sust_x + r and gfx.mouse_y >= r0_y and gfx.mouse_y <= r0_y + b_h
        local sust_bg = sust_held and theme.colors.btn_active or (sust_hover and theme.colors.btn_hover or theme.colors.island_bg)
        helpers.SetColor(sust_bg)
        components.DrawRoundedRect(sust_x, r0_y, r, b_h, 10, true)
        if ui_store.GetMouseClick() and sust_hover and not drag_store.GetIsDragging() then PressOverlay(sust_x, r0_y, r, b_h) end
        helpers.SetColor(sust_held and theme.colors.text or theme.colors.text_dim)
        gfx.setfont(1, "Calibri", layout.US(1500))
        local suw, suh = gfx.measurestr("SUS")
        gfx.x, gfx.y = sust_x + (r - suw)/2, r0_y + (b_h - suh)/2
        gfx.drawstr("SUS")
        if sust_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip(sust_held and "Sustain: ON — click to release" or "Sustain: OFF — click to hold", layout.US(700))
        end
        if ui_store.GetMouseClick() and sust_hover and not drag_store.GetIsDragging() then midi.SetSustain(not sust_held) end
    end
    
    -- =========================================================
    -- Row 2: MOD | PLAY
    -- =========================================================
    local r1_y = r0_y + b_h + b_gap - layout.US(57)
    do
        local l, r = SplitWidths(b_w, half_gap)
        local mod_x, play_x = i4_x, i4_x + l + half_gap
        
        -- MOD (left) — smaller text
        local cc_mod_val = midi.GetModulation()
        local cc_hover = gfx.mouse_x >= mod_x and gfx.mouse_x <= mod_x + l and gfx.mouse_y >= r1_y and gfx.mouse_y <= r1_y + b_h
        local cc_bg = cc_mod_val > 0 and theme.colors.btn_active or (cc_hover and theme.colors.btn_hover or theme.colors.island_bg)
        helpers.SetColor(cc_bg)
        components.DrawRoundedRect(mod_x, r1_y, l, b_h, 10, true)
        if ui_store.GetMouseClick() and cc_hover and not drag_store.GetIsDragging() then PressOverlay(mod_x, r1_y, l, b_h) end
        helpers.SetColor(cc_mod_val > 0 and theme.colors.text or theme.colors.text_dim)
        gfx.setfont(1, "Calibri", layout.US(1200))
        local ccw, cch = gfx.measurestr("MOD")
        gfx.x, gfx.y = mod_x + (l - ccw)/2, r1_y + (b_h - cch)/2
        gfx.drawstr("MOD")
        if cc_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip(cc_mod_val > 0 and "Modulation: ON — click off" or "Modulation: OFF — click on", layout.US(700))
        end
        if ui_store.GetMouseClick() and cc_hover and not drag_store.GetIsDragging() then midi.ToggleModulation() end
        
        -- PLAY/STOP — Unicode glyphs (same approach as tool icons)
        local is_playing = seq_store.GetIsPlaying()
        local p_hover = gfx.mouse_x >= play_x and gfx.mouse_x <= play_x + r and gfx.mouse_y >= r1_y and gfx.mouse_y <= r1_y + b_h
        local p_bg = is_playing and theme.colors.slot_playing or (p_hover and theme.colors.btn_hover or theme.colors.island_bg)
        helpers.SetColor(p_bg)
        components.DrawRoundedRect(play_x, r1_y, r, b_h, 10, true)
        if ui_store.GetMouseClick() and p_hover and not drag_store.GetIsDragging() then PressOverlay(play_x, r1_y, r, b_h) end
        local play_icon = is_playing and "\226\150\160" or "\226\150\182"  -- ■ U+25A0 or ▶ U+25B6
        local p_col = is_playing and theme.colors.text or theme.colors.slot_playing
        helpers.SetColor(p_col)
        gfx.setfont(1, "Calibri", math.floor(b_h * 0.9))
        local pw, ph = gfx.measurestr(play_icon)
        gfx.x, gfx.y = play_x + (r - pw) / 2 + 1, r1_y + (b_h - ph) / 2 - 1
        gfx.drawstr(play_icon)
        if p_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip("Play/Stop progression", layout.US(700))
        end
        if ui_store.GetMouseClick() and p_hover and not drag_store.GetIsDragging() then
            if is_playing then sequencer.Stop() else seq_store.SetIsPlaying(true) end
        end
    end
    
    -- =========================================================
    -- Row 3: CLEAR | EXPORT
    -- =========================================================
    local r2_y = r1_y + b_h + b_gap - layout.US(57)
    do
        local l, r = SplitWidths(b_w, layout.US(500))
        local clear_x, export_x = i4_x, i4_x + l + layout.US(500)
        
        -- CLEAR (left half) — full-width container + icon centered
        local clear_hover = gfx.mouse_x >= clear_x and gfx.mouse_x <= clear_x + l and gfx.mouse_y >= r2_y and gfx.mouse_y <= r2_y + b_h
        local clear_bg = clear_hover and {0.4, 0.1, 0.1, 1} or theme.colors.island_bg
        helpers.SetColor(clear_bg)
        components.DrawRoundedRect(clear_x, r2_y, l, b_h, 10, true)
        if ui_store.GetMouseClick() and clear_hover and not drag_store.GetIsDragging() then PressOverlay(clear_x, r2_y, l, b_h) end
        local icon_pad = math.floor((l - b_h) / 2)
        if components.DrawToolIcon("clear", clear_x + icon_pad, r2_y, b_h, false) then
            progression.Clear()
        end
        if clear_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip("Clear all slots", layout.US(700))
        end
        
        -- EXPORT (right half) — full-width container + icon centered
        local export_hover = gfx.mouse_x >= export_x and gfx.mouse_x <= export_x + r and gfx.mouse_y >= r2_y and gfx.mouse_y <= r2_y + b_h
        local export_bg = export_hover and theme.colors.btn_hover or theme.colors.island_bg
        helpers.SetColor(export_bg)
        components.DrawRoundedRect(export_x, r2_y, r, b_h, 10, true)
        if ui_store.GetMouseClick() and export_hover and not drag_store.GetIsDragging() then PressOverlay(export_x, r2_y, r, b_h) end
        local export_icon_pad = math.floor((r - b_h) / 2)
        if components.DrawToolIcon("export", export_x + export_icon_pad, r2_y, b_h, false) then
            midi.ExportToMidi()
        end
        if export_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip("Export MIDI", layout.US(700))
        end
    end
    
    -- =========================================================
    -- Row 4: VOLUME SLIDER (auto-sized for 7px gaps both sides)
    -- =========================================================
    local r3_y = r2_y + b_h + b_gap - layout.US(57)
    local vol_gap = layout.US(398)  -- 7px gap
    local vol_h = (y_start + island_h - 2 * vol_gap - b_h) - r3_y
    vol_h = math.max(b_h * 0.5, math.min(b_h * 1.5, vol_h))  -- clamp between 0.5x and 1.5x button height
    do
        local slide_w = b_w
        local slide_x = i4_x
        local slide_h = vol_h + 4
        local volume = seq_store.GetVolume() or 100
        local s_hover = gfx.mouse_x >= slide_x and gfx.mouse_x <= slide_x + slide_w and gfx.mouse_y >= r3_y and gfx.mouse_y <= r3_y + slide_h

        helpers.SetColor(theme.colors.island_bg)
        components.DrawRoundedRect(slide_x, r3_y, slide_w, slide_h, 10, true)

        local fill_pad = layout.US(180)
        local fill_w = (volume / 100) * (slide_w - fill_pad * 2)
        if fill_w > 0 then
            helpers.SetColor(theme.colors.btn_active)
            components.DrawRoundedRect(slide_x + fill_pad, r3_y + fill_pad, fill_w, slide_h - fill_pad * 2, 10, true)
        end

        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", layout.US(1100))
        local label = string.format("VOL %d%%", volume)
        local lw, lh = gfx.measurestr(label)
        gfx.x, gfx.y = slide_x + (slide_w - lw)/2, r3_y + (slide_h - lh)/2
        gfx.drawstr(label)
        
        if s_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip("Volume: " .. volume .. "%", layout.US(700))
        end
        if s_hover and ui_store.GetUseScroll() then
            local wheel = ui_store.ConsumeMouseWheelDelta()  -- S1: use established consume pattern
            if wheel ~= 0 then
                local delta = wheel > 0 and 5 or -5
                seq_store.SetVolume(math.max(0, math.min(100, volume + delta)))
            end
        end
        if ui_store.GetMouseClick() and s_hover and not drag_store.GetIsDragging() then
            ui_store.SetSliderDragging(true)
        end
        if ui_store.GetSliderDragging() then
            local ratio = (gfx.mouse_x - slide_x) / slide_w
            seq_store.SetVolume(math.floor(math.max(0, math.min(100, ratio * 100))))
            if (gfx.mouse_cap & 1) == 0 then
                ui_store.SetSliderDragging(false)
            end
        end
    end
    
    -- =========================================================
    -- Row 5: MIDI toggle (full width, exactly 7px below volume slider)
    -- =========================================================
    do
        local r4_y = r3_y + (vol_h + 4) + vol_gap + layout.US(114)  -- ~9px below slider bottom (7+2 extra)
        local full_w = b_w
        
        local midi_expanded = island_store.GetMidiIslandExpanded()
        local m_hover = gfx.mouse_x >= i4_x and gfx.mouse_x <= i4_x + full_w and gfx.mouse_y >= r4_y and gfx.mouse_y <= r4_y + b_h
        local m_bg = midi_expanded and theme.colors.btn_active or (m_hover and theme.colors.btn_hover or theme.colors.island_bg)
        helpers.SetColor(m_bg)
        components.DrawRoundedRect(i4_x, r4_y, full_w, b_h, 10, true)
        if ui_store.GetMouseClick() and m_hover and not drag_store.GetIsDragging() then PressOverlay(i4_x, r4_y, full_w, b_h) end
        helpers.SetColor(midi_expanded and theme.colors.text or theme.colors.text_dim)
        gfx.setfont(1, "Calibri", layout.US(1500))
        local ew, eh = gfx.measurestr("MIDI")
        gfx.x, gfx.y = i4_x + (full_w - ew)/2, r4_y + (b_h - eh)/2
        gfx.drawstr("MIDI")
        if m_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip(midi_expanded and "Collapse MIDI island" or "Expand MIDI island", layout.US(700))
        end
        if ui_store.GetMouseClick() and m_hover and not drag_store.GetIsDragging() then gfx_window.ToggleIsland() end
    end
end

return m
