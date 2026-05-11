local config = require("config")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local midi_store = require("state.midi")
local ui_store = require("state.ui")
local island_store = require("state.island")
local theme = require("ui.theme")
local components = require("ui.components")
local helpers = require("ui.helpers")
local midi = require("core.midi")
local compact = require("ui.compact")
local layout = require("ui.layout")
local progression = require("core.progression")
local piano_roll = require("ui.piano-roll")
local timeline = require("ui.timeline")
local velocity = require("ui.velocity")
local preset_browser = require("ui.preset-browser")

local views = {}

-- Cached dropdown options (built once, scales don't change at runtime)
local SCALE_OPTIONS = (function() local t = {} for _, v in ipairs(config.SCALES) do t[#t + 1] = v.name end return t end)()
local OCTAVE_OPTIONS = {"C0", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"}









-- Shared right-click quick config menu (used by both views)
local function ShowQuickConfigMenu()
    local m = "ROOT: " .. config.NOTE_NAMES[config.state.root_index] .. "|<SCALE: " .. helpers.AbbreviateScale(config.SCALES[config.state.scale_index].name) .. "|OCTAVE: C" .. math.floor(config.state.octave) .. "|CHORD: " .. config.CHORD_MODES[config.state.chord_mode_index].name .. "|VELOCITY: " .. (midi_store.GetUseVelocity() and "ON" or "OFF") .. "|Dock in Transport Bar"
    gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
    local choice = gfx.showmenu(m)
    if choice == 1 then
        config.state.root_index = (config.state.root_index % 12) + 1
    elseif choice == 2 then
        config.state.scale_index = (config.state.scale_index % #config.SCALES) + 1
    elseif choice == 3 then
        config.state.octave = math.floor((config.state.octave + 1) % 9)
    elseif choice == 4 then
        config.state.chord_mode_index = (config.state.chord_mode_index % #config.CHORD_MODES) + 1
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
    local island_x = right_edge - icon_size - icon_gap
    local view_x = island_x - icon_size - icon_gap
    local settings_x = view_x - icon_size - icon_gap
    local help_x = settings_x - icon_size - icon_gap

    -- State indicator on the same line right after copyright
    gfx.setfont(1, "Calibri", layout.US(900))
    local scale_abbr = helpers.AbbreviateScale(config.SCALES[config.state.scale_index].name)
    local state_str = "  ·  " .. config.NOTE_NAMES[config.state.root_index] .. " " .. scale_abbr .. " · " .. config.CHORD_MODES[config.state.chord_mode_index].name .. " · C" .. math.floor(config.state.octave)
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
        local menu = toggle_label .. "|Ajustar Posicion Vista Mini...|Resetear Posicion Vista Mini|" .. scroll_label .. "|" .. compact_label .. "|" .. reaper_label
        gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
        local choice = gfx.showmenu(menu)
        if choice == 1 then
            ui_store.SetColorMode(is_grade and "flat" or "grade")
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
        end
    end
    
    if components.DrawToolIcon("view", view_x, (h - icon_size) / 2, icon_size) then
        compact.SwitchViewMode()
    end
    if components.DrawToolIcon("island", island_x, (h - icon_size) / 2, icon_size) then
        compact.ToggleIslandView()
    end
end

function views.DrawIslands()
    local y_start = layout.UY(2196)
    local island_h = layout.US(11750)
    local std_island_w = layout.US(5316)
    local std_btn_w = layout.US(4400)
    local std_btn_h = layout.US(1980)
    local title_font_size = layout.US(1250)
    local btn_font_size = layout.US(1100)
    
    ---------------------------------------------------------------------------
    -- Island 1: Scale & Piano
    ---------------------------------------------------------------------------
    local i1_x, i1_w = layout.UX(0), layout.US(22591)
    components.DrawIsland(i1_x, y_start, i1_w, island_h, "SCALE", title_font_size)
    local piano_x, piano_y = layout.UX(798), layout.UY(2981)
    local piano_w, piano_h = layout.US(21056), layout.US(7875)
    components.DrawPianoKeyboard(piano_x, piano_y, piano_w, piano_h, layout.US(1400))
    
    local drop_h = layout.US(1677)
    local drop_y = layout.UY(11653)
    local modo_lbl_x = layout.UX(1000)
    local drop_x = layout.UX(4800)
    local drop_w = layout.US(7187)
    
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", title_font_size) 
    local mw, mh = gfx.measurestr("MODO")
    gfx.x, gfx.y = modo_lbl_x, drop_y + (drop_h - mh)/2
    gfx.drawstr("MODO")
    
    -- Using the smart abbreviation strategy
    local modo_val = helpers.AbbreviateScale(config.SCALES[config.state.scale_index].name)
    local choice = components.DrawDropdown(drop_x, drop_y, drop_w, drop_h, nil, modo_val, 
                                          SCALE_OPTIONS, config.state.scale_index, btn_font_size)
    if choice then config.state.scale_index = choice end
    
    local note_x, note_y = layout.UX(17450), layout.UY(11707)
    local note_w, note_h = layout.US(4042), layout.US(1548)
    local note_lbl_x = layout.UX(14000)
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", title_font_size)
    local nw, nh = gfx.measurestr("NOTE")
    gfx.x, gfx.y = note_lbl_x, note_y + (note_h - nh)/2
    gfx.drawstr("NOTE")
    components.DrawNoteDisplay(note_x, note_y, note_w, note_h, midi_store.GetLastNotePlayed())
    
    ---------------------------------------------------------------------------
    -- Island 2: Octava
    ---------------------------------------------------------------------------
    local i2_x = layout.UX(23066)
    components.DrawIsland(i2_x, y_start, std_island_w, island_h, "OCTAVA", title_font_size)
    local btn_x = i2_x + (std_island_w - std_btn_w)/2
    local oct_open_up = y_start > gfx.h / 2
    local oct_choice = components.DrawDropdown(btn_x, layout.UY(4545), std_btn_w, std_btn_h, nil, "C"..math.floor(config.state.octave), OCTAVE_OPTIONS, config.state.octave + 1, btn_font_size, oct_open_up)  -- Issue 9
    if oct_choice then config.state.octave = math.floor(oct_choice - 1) end
    if components.DrawButton(btn_x, layout.UY(6823), std_btn_w, std_btn_h, "C5", config.state.octave == 5, btn_font_size) then config.state.octave = 5 end
    if components.DrawButton(btn_x, layout.UY(9075), std_btn_w, std_btn_h, "C4", config.state.octave == 4, btn_font_size) then config.state.octave = 4 end
    if components.DrawButton(btn_x, layout.UY(11343), std_btn_w, std_btn_h, "C3", config.state.octave == 3, btn_font_size) then config.state.octave = 3 end
    
    ---------------------------------------------------------------------------
    -- Island 3: Chord
    ---------------------------------------------------------------------------
    local i3_x = layout.UX(28832)
    components.DrawIsland(i3_x, y_start, std_island_w, island_h, "CHORD", title_font_size)
    local cbtn_x = i3_x + (std_island_w - std_btn_w)/2
    if components.DrawButton(cbtn_x, layout.UY(4640), std_btn_w, std_btn_h, "9NA", config.state.chord_mode_index == 4, btn_font_size) then config.state.chord_mode_index = 4 end
    if components.DrawButton(cbtn_x, layout.UY(6893), std_btn_w, std_btn_h, "7MA", config.state.chord_mode_index == 3, btn_font_size) then config.state.chord_mode_index = 3 end
    if components.DrawButton(cbtn_x, layout.UY(9122), std_btn_w, std_btn_h, "TRI", config.state.chord_mode_index == 2, btn_font_size) then config.state.chord_mode_index = 2 end
    if components.DrawButton(cbtn_x, layout.UY(11365), std_btn_w, std_btn_h, "NOTE", config.state.chord_mode_index == 1, btn_font_size) then config.state.chord_mode_index = 1 end
    
    ---------------------------------------------------------------------------
    -- Island 4: Command Vertical Stack (Alineación Exacta)
    ---------------------------------------------------------------------------
    local i4_x = layout.UX(34598)
    local b_w = std_island_w
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
    local p_y = v_y + b_h + b_gap
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
    if ui_store.GetMouseClick() and p_hover and not drag_store.GetIsDragging() then seq_store.SetIsPlaying(not is_playing) end
    
    -- 3. CLEAR + EXPORT (side by side, same row)
    local c_y = p_y + b_h + b_gap
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
    local e_y = c_y + b_h + b_gap
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
    local s_y = e_y + b_h + b_gap
    local s_hover = gfx.mouse_x >= i4_x and gfx.mouse_x <= i4_x + b_w and gfx.mouse_y >= s_y and gfx.mouse_y <= s_y + b_h
    local volume = seq_store.GetVolume() or 100

    -- Track (mismo island_bg que los botones para que coincida visualmente)
    helpers.SetColor(theme.colors.island_bg)
    components.DrawRoundedRect(i4_x, s_y, b_w, b_h, 10, true)

    -- Fill (barra activa con padding interno de layout.US(180))
    local fill_pad = layout.US(180)
    local fill_w = (volume / 100) * (b_w - fill_pad * 2)
    if fill_w > 0 then
        helpers.SetColor(theme.colors.btn_active)
        components.DrawRoundedRect(i4_x + fill_pad, s_y + fill_pad, fill_w, b_h - fill_pad * 2, 10, true)
    end

    -- Label
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", layout.US(1100))
    local label = string.format("VOL %d%%", volume)
    local lw, lh = gfx.measurestr(label)
    gfx.x, gfx.y = i4_x + (b_w - lw)/2, s_y + (b_h - lh)/2
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
    local num_intervals = #config.SCALES[config.state.scale_index].intervals
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

function views.DrawMIDIIsland()
    if not midi.midi_island_expanded then return end

    -- MIDI CH button centrado entre performance area y MIDI island
    -- Gap total = VEL height (1980) + b_gap (~1389) = ~3369 virtual
    -- perf_end = fin visual del área de performance (14375 + 13363)
    local perf_end = 27738
    local vel_h_v = 1980
    local gap_v = math.floor((15455 - 1980 * 5) / 4 + 1422)  -- b_gap en virtual; +1422 (~25px) para 49px de gap perf area→MIDI island
    local total_gap = vel_h_v + gap_v
    local top_pad = 428  -- padding arriba del botón (~7px); bottom pad queda ~942 (~16.6px)
    local btn_y_v = perf_end + top_pad                       -- ~29856
    local b_w = layout.US(5347)  -- ~94px
    local content_w = layout.US(39914)
    local btn_x = layout.UX(0) + math.floor((content_w - b_w) / 2)  -- centrado
    local btn_y = layout.UY(btn_y_v)
    local btn_h = layout.US(vel_h_v)

    -- MIDI CH button (mismo tamaño y estilo que VEL)
    local ch = midi.midi_channel
    local hover = gfx.mouse_x >= btn_x and gfx.mouse_x <= btn_x + b_w and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
    helpers.SetColor(hover and theme.colors.btn_hover or theme.colors.island_bg)
    components.DrawRoundedRect(btn_x, btn_y, b_w, btn_h, 10, true)
    if ui_store.GetMouseClick() and hover and not drag_store.GetIsDragging() then
        local menu = ""
        for i = 1, 16 do
            menu = menu .. (i == ch and "!" or "") .. tostring(i) .. "|"
        end
        gfx.x, gfx.y = btn_x, btn_y + btn_h
        local choice = gfx.showmenu(menu:sub(1, -2))
        if choice and choice > 0 then midi.midi_channel = choice end
    end
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1500))
    local label = "CH " .. tostring(ch)
    local lw, lh = gfx.measurestr(label)
    gfx.x, gfx.y = btn_x + (b_w - lw)/2, btn_y + (btn_h - lh)/2
    gfx.drawstr(label)
    if hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("MIDI Channel: " .. ch, layout.US(700))
    end

    -- Island background debajo del gap
    local island_y_v = btn_y_v + btn_h + gap_v - top_pad  -- ~32531
    local y = layout.UY(island_y_v)
    local w = layout.US(39914)
    local h = layout.US(14000)

    helpers.SetColor(theme.colors.island_bg)
    components.DrawRoundedRect(layout.UX(0), y, w, h, 15, true)
end

function views.DrawFullView()
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
    views.DrawMIDIIsland()
end

-- Island Piano Roll View: piano roll grid + timeline ruler + preset panel
function views.DrawIslandView()
    -- Guard: minimum window size required
    if gfx.w < 800 or gfx.h < 550 then
        helpers.SetColor(theme.colors.bg)
        gfx.rect(0, 0, gfx.w, gfx.h, 1)
        gfx.setfont(1, "Calibri", 16)
        helpers.SetColor(theme.colors.text_dim)
        local msg = "Window too small — resize to at least 800×550"
        local mw, mh = gfx.measurestr(msg)
        gfx.x, gfx.y = (gfx.w - mw) / 2, (gfx.h - mh) / 2
        gfx.drawstr(msg)
        return
    end

    -- Synch playback position from sequencer
    timeline.SyncPlaybackPosition()

    helpers.SetColor(theme.colors.bg)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)

    local preset_w = island_store.GetPresetPanelVisible() and config.ISLAND_PRESET_PANEL_W or 0
    local right_x = preset_w
    local right_w = gfx.w - preset_w

    -- =========================================
    -- Preset Panel (left, collapsible)
    -- =========================================
    if preset_w > 0 then
        helpers.SetColor(theme.colors.island_bg)
        gfx.rect(0, 0, preset_w, gfx.h, 1)

        -- Collapse button (◄) at top-right of panel
        local btn_size = 18
        local btn_x = preset_w - btn_size - 4
        local btn_y = 4
        local collapse_hover = gfx.mouse_x >= btn_x and gfx.mouse_x <= btn_x + btn_size
                            and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_size
        helpers.SetColor(collapse_hover and theme.colors.btn_hover or {0.3, 0.3, 0.3, 0.5})
        components.DrawRoundedRect(btn_x, btn_y, btn_size, btn_size, 4, true)
        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", 12)
        local sym = "◄"
        local sw_, sh_ = gfx.measurestr(sym)
        gfx.x, gfx.y = btn_x + (btn_size - sw_) / 2, btn_y + (btn_size - sh_) / 2
        gfx.drawstr(sym)
        if ui_store.GetMouseClick() and collapse_hover then
            island_store.SetPresetPanelVisible(false)
        end

        -- Draw the actual preset browser content
        local browser_y = btn_y + btn_size + 6
        local browser_h = gfx.h - browser_y
        if browser_h > 20 then
            -- Init preset browser on first draw
            local root = island_store.GetPresetRoot()
            if not root or #root == 0 then
                preset_browser.Init()
            end
            preset_browser.DrawPresetBrowser(0, browser_y, preset_w, browser_h)
        end
    else
        -- Collapsed panel: draw a thin expand handle (►) on the left edge
        local handle_w = 12
        local handle_h = 60
        local handle_x = 0
        local handle_y = (gfx.h - handle_h) / 2
        local handle_hover = gfx.mouse_x >= handle_x and gfx.mouse_x <= handle_x + handle_w
                            and gfx.mouse_y >= handle_y and gfx.mouse_y <= handle_y + handle_h
        helpers.SetColor(handle_hover and theme.colors.btn_hover or {0.25, 0.25, 0.25, 0.4})
        components.DrawRoundedRect(handle_x, handle_y, handle_w, handle_h, 3, true)
        if handle_hover then
            helpers.SetColor(theme.colors.text_dim)
            gfx.setfont(1, "Calibri", 10)
            local sym2 = "►"
            local sw2_, sh2_ = gfx.measurestr(sym2)
            gfx.x, gfx.y = (handle_w - sw2_) / 2, handle_y + (handle_h - sh2_) / 2
            gfx.drawstr(sym2)
        end
        if ui_store.GetMouseClick() and handle_hover then
            island_store.SetPresetPanelVisible(true)
        end
    end

    -- =========================================
    -- Timeline Ruler (top of right area)
    -- =========================================
    local tl_h = timeline.TIMELINE_H
    local ve_h = velocity.EDITOR_H
    local pr_y = tl_h
    local pr_h = gfx.h - tl_h - ve_h

    timeline.DrawTimelineRuler(right_x, 0, right_w, tl_h, pr_h)

    -- =========================================
    -- Piano Roll Grid (below timeline)
    -- =========================================
    piano_roll.DrawPianoRoll(right_x, pr_y, right_w, pr_h)

    -- =========================================
    -- Velocity Editor (below piano roll)
    -- =========================================
    local ve_y = pr_y + pr_h
    local notes = island_store.GetNotes()
    velocity.DrawVelocityEditor(right_x, ve_y, right_w, ve_h, notes,
        island_store.GetScrollOffsetX(), island_store.GetZoomX(),
        island_store.GetSelectedNoteIndex())

    -- =========================================
    -- Mouse Event Handling
    -- =========================================
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local click = ui_store.GetMouseClick()
    local last_cap = ui_store.GetLastMouseCap()
    local right_click = (gfx.mouse_cap & 2) == 2 and (last_cap & 2) == 0
    local wheel = ui_store.ConsumeMouseWheelDelta()
    local click_consumed = false

    -- Timeline ruler click → seek
    if not click_consumed and mx >= right_x and mx < right_x + right_w
       and my >= 0 and my < tl_h then
        if click then
            local grid_x = right_x + timeline.PITCH_LABEL_W
            local beat = timeline.TimelineHitTest(mx, grid_x, island_store.GetScrollOffsetX(), island_store.GetZoomX())
            island_store.SetPlaybackPos(beat)
            click_consumed = true
        end
    end

    -- Piano roll left-click → select note
    if not click_consumed and mx >= right_x and mx < right_x + right_w
       and my >= pr_y and my < pr_y + pr_h then
        if click then
            local grid_x = right_x + piano_roll.PITCH_LABEL_W
            piano_roll.HandleMouseClick(mx, my, grid_x, pr_y,
                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(), island_store.GetZoomX())
            click_consumed = true
        end
    end

    -- Piano roll right-click → toggle mute on note block
    if not click_consumed and mx >= right_x and mx < right_x + right_w
       and my >= pr_y and my < pr_y + pr_h then
        if right_click then
            local grid_x = right_x + piano_roll.PITCH_LABEL_W
            local muted = piano_roll.HandleRightClickMute(mx, my, grid_x, pr_y,
                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(), island_store.GetZoomX())
            if muted then
                click_consumed = true
            end
        end
    end

    -- Velocity editor click-drag
    if not click_consumed and mx >= right_x and mx < right_x + right_w
       and my >= ve_y and my < ve_y + ve_h then
        local grid_x = right_x + piano_roll.PITCH_LABEL_W
        local mouse_down = (gfx.mouse_cap & 1) == 1
        local consumed = velocity.HandleVelocityMouse(mx, my, grid_x, ve_y, ve_h,
            island_store.GetScrollOffsetX(), island_store.GetZoomX(), click, mouse_down)
        if consumed then
            click_consumed = true
        end
    end

    -- Mouse wheel over right area → horizontal scroll (only when not over velocity editor)
    if wheel ~= 0 and mx >= right_x and mx < right_x + right_w then
        if my >= 0 and my < tl_h + pr_h then
            local new_scroll = piano_roll.HandleMouseWheel(wheel, island_store.GetScrollOffsetX(), island_store.GetZoomX())
            island_store.SetScrollOffsetX(new_scroll)
        end
    end

    -- Draw exit hint bottom-left (above preset panel if visible)
    gfx.setfont(1, "Calibri", 12)
    helpers.SetColor(theme.colors.text_dim)
    local hint = "F12: Exit  |  Ctrl+I: Toggle"
    local hw, hh = gfx.measurestr(hint)
    gfx.x, gfx.y = 8, gfx.h - hh - 8
    gfx.drawstr(hint)

    -- Draw info bar: note count and zoom level at bottom-right of right area
    local nc = island_store.GetNoteCount()
    local zx = island_store.GetZoomX()
    local info = string.format("Notes: %d  |  Zoom: %d px/beat", nc, zx)
    gfx.setfont(1, "Calibri", 11)
    helpers.SetColor(theme.colors.text_dim)
    local iw, ih = gfx.measurestr(info)
    gfx.x, gfx.y = right_x + right_w - iw - 8, gfx.h - ih - 8
    gfx.drawstr(info)
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
    if components.DrawTransportButton(config.NOTE_NAMES[config.state.root_index], x_pos, btn_y, btn_w, btn_h) then
        config.state.root_index = (config.state.root_index % 12) + 1
    end
    x_pos = x_pos + btn_w + gap

    -- [SCALE] button - cycles through scales
    local scale_abbr = helpers.AbbreviateScale(config.SCALES[config.state.scale_index].name)
    if components.DrawTransportButton(scale_abbr, x_pos, btn_y, btn_w + 20, btn_h) then
        config.state.scale_index = (config.state.scale_index % #config.SCALES) + 1
    end
    x_pos = x_pos + btn_w + 20 + gap

    -- [OCT−] button
    if components.DrawTransportButton("−", x_pos, btn_y, 30, btn_h) then
        config.state.octave = math.floor(math.max(0, config.state.octave - 1))
    end
    x_pos = x_pos + 30 + gap

    -- [OCT+] button
    if components.DrawTransportButton("+", x_pos, btn_y, 30, btn_h) then
        config.state.octave = math.floor(math.min(8, config.state.octave + 1))
    end
    x_pos = x_pos + 30 + gap

    -- [CHORD] button - cycles chord modes
    local chord_label = config.CHORD_MODES[config.state.chord_mode_index].name
    if components.DrawTransportButton(chord_label, x_pos, btn_y, btn_w, btn_h) then
        config.state.chord_mode_index = (config.state.chord_mode_index % #config.CHORD_MODES) + 1
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
        seq_store.SetIsPlaying(not is_playing)
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
