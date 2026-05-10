local config = require("config")
local theme = require("ui.theme")
local components = require("ui.components")
local helpers = require("ui.helpers")
local midi = require("core.midi")
local compact = require("ui.compact")

local views = {}

-- Cached dropdown options (built once, scales don't change at runtime)
local SCALE_OPTIONS = (function() local t = {} for _, v in ipairs(config.SCALES) do t[#t + 1] = v.name end return t end)()
local OCTAVE_OPTIONS = {"C0", "C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"}

-- Uniform Scale Factor & Offsets.
-- Set ONLY via SetScale() at the start of DrawFullView.
-- Do NOT assign _S/_OX/_OY directly — use SetScale().
-- Underscore prefix = internal, do not touch from outside this module.
local _S, _OX, _OY = 0, 0, 0

local function UX(v) return math.floor(v * _S + _OX) end
local function UY(v) return math.floor(v * _S + _OY) end
local function US(v) return math.floor(v * _S) end

-- Set the scale context for the current frame.
-- Must be called before any UX/UY/US call. Only DrawFullView calls this.
local function SetScale(s, ox, oy) _S, _OX, _OY = s, ox, oy end

-- Toggle the MIDI island expanded/collapsed state.
-- Resizes window via gfx.quit()+gfx.init(). Docked mode is not supported.
local function ToggleMIDIIsland()
    if config.state.docked_mode then return end
    config.state.midi_island_expanded = not config.state.midi_island_expanded
    config.state.midi_island_toggled = true
    local dock = gfx.dock(-1)
    -- Capturar posición actual de la ventana antes de gfx.quit()
    local gs = config.state.last_gfx_state
    local hwnd = gfx.hwnd
    if hwnd then
        local l, t, r, b = reaper.JS_Window_GetRect(hwnd)
        gs.x, gs.y = l, t
    end
    local new_h = config.state.midi_island_expanded and 793 or 497
    gfx.quit()
    gfx.init(config.script_title, 720, new_h, dock, gs.x, gs.y)
    gfx.setfont(1, "Calibri", 16)
end





-- Shared right-click quick config menu (used by both views)
local function ShowQuickConfigMenu()
    local m = "ROOT: " .. config.NOTE_NAMES[config.state.root_index] .. "|<SCALE: " .. helpers.AbbreviateScale(config.SCALES[config.state.scale_index].name) .. "|OCTAVE: C" .. math.floor(config.state.octave) .. "|CHORD: " .. config.CHORD_MODES[config.state.chord_mode_index].name .. "|VELOCITY: " .. (config.state.use_velocity and "ON" or "OFF") .. "|Dock in Transport Bar"
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
        config.state.use_velocity = not config.state.use_velocity
    elseif choice == 6 then
        config.state.dock_id = gfx.dock(1)
        if config.state.dock_id > 0 then
            config.state.docked_mode = true
        else
            config.state.dock_id = 0
        end
    end
end

function views.DrawHeader()
    local h = US(2200)
    local left_edge = UX(0)
    
    gfx.setfont(1, "Calibri", US(1500)) 
    helpers.SetColor(theme.colors.text)
    local title = "GROVE SCALE RUNNER"
    local tw, th = gfx.measurestr(title)
    gfx.x, gfx.y = left_edge, (h - th) / 2
    gfx.drawstr(title)
    
    gfx.setfont(1, "Calibri", US(850))
    helpers.SetColor(theme.colors.text_dim)
    local ver = "v1.0.0  © groveworldmusic"
    local vw, vh = gfx.measurestr(ver)
    local ver_x = left_edge + tw + US(800)
    local ver_y = (h - th) / 2 + US(420)
    gfx.x, gfx.y = ver_x, ver_y
    gfx.drawstr(ver)

    -- Compute icon positions first (used for state text boundary below)
    local icon_size = US(1700)
    local icon_gap = US(420)
    local right_edge = UX(39914)
    local view_x = right_edge - icon_size - icon_gap
    local settings_x = view_x - icon_size - icon_gap
    local help_x = settings_x - icon_size - icon_gap

    -- State indicator on the same line right after copyright
    gfx.setfont(1, "Calibri", US(900))
    local scale_abbr = helpers.AbbreviateScale(config.SCALES[config.state.scale_index].name)
    local state_str = "  ·  " .. config.NOTE_NAMES[config.state.root_index] .. " " .. scale_abbr .. " · " .. config.CHORD_MODES[config.state.chord_mode_index].name .. " · C" .. math.floor(config.state.octave)
    local sw, sh = gfx.measurestr(state_str)
    local state_x = math.min(ver_x + vw + US(250), help_x - sw - US(250))
    gfx.x, gfx.y = state_x, ver_y
    gfx.drawstr(state_str)
    -- Scroll indicator
    gfx.setfont(1, "Calibri", US(700))
    local scroll_indicator = config.state.use_scroll and "  ·  Scroll: ON" or "  ·  Scroll: OFF"
    local siw, sih = gfx.measurestr(scroll_indicator)
    gfx.x, gfx.y = state_x + sw + US(60), ver_y + 2
    gfx.drawstr(scroll_indicator)
    
    if components.DrawToolIcon("help", help_x, (h - icon_size) / 2, icon_size) then
        config.state.show_tooltips = not config.state.show_tooltips
    end
    if components.DrawToolIcon("settings", settings_x, (h - icon_size) / 2, icon_size) then
        local is_grade = config.state.color_mode == "grade"
        local toggle_label = is_grade and "Cambiar a Colores Planos" or "Cambiar a Grados a color"
        local scroll_label = (config.state.use_scroll and "✓ " or "") .. "Activar Scroll en Dropdowns"
        local compact_label = (config.state.auto_start_compact and "✓ " or "") .. "Iniciar en Vista Mini"
        local reaper_label = (config.state.auto_start_reaper and "✓ " or "") .. "Iniciar con REAPER"
        local menu = toggle_label .. "|Ajustar Posicion Vista Mini...|Resetear Posicion Vista Mini|" .. scroll_label .. "|" .. compact_label .. "|" .. reaper_label
        gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
        local choice = gfx.showmenu(menu)
        if choice == 1 then
            config.state.color_mode = is_grade and "flat" or "grade"
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
            config.state.use_scroll = not config.state.use_scroll
        elseif choice == 5 then
            config.state.auto_start_compact = not config.state.auto_start_compact
            reaper.SetExtState("GROVE_Scale_Runner", "auto_start_compact",
                config.state.auto_start_compact and "1" or "0", true)
        elseif choice == 6 then
            config.state.auto_start_reaper = not config.state.auto_start_reaper
            reaper.SetExtState("GROVE_Scale_Runner", "auto_start_reaper",
                config.state.auto_start_reaper and "1" or "0", true)
        end
    end
    
    if components.DrawToolIcon("view", view_x, (h - icon_size) / 2, icon_size) then
        compact.SwitchViewMode()
    end
end

function views.DrawIslands()
    local y_start = UY(2196)
    local island_h = US(11750)
    local std_island_w = US(5316)
    local std_btn_w = US(4400)
    local std_btn_h = US(1980)
    local title_font_size = US(1250)
    local btn_font_size = US(1100)
    
    ---------------------------------------------------------------------------
    -- Island 1: Scale & Piano
    ---------------------------------------------------------------------------
    local i1_x, i1_w = UX(0), US(22591)
    components.DrawIsland(i1_x, y_start, i1_w, island_h, "SCALE", title_font_size)
    local piano_x, piano_y = UX(798), UY(2981)
    local piano_w, piano_h = US(21056), US(7875)
    components.DrawPianoKeyboard(piano_x, piano_y, piano_w, piano_h, US(1400))
    
    local drop_h = US(1677)
    local drop_y = UY(11653)
    local modo_lbl_x = UX(1000)
    local drop_x = UX(4800)
    local drop_w = US(7187)
    
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
    
    local note_x, note_y = UX(17450), UY(11707)
    local note_w, note_h = US(4042), US(1548)
    local note_lbl_x = UX(14000)
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", title_font_size)
    local nw, nh = gfx.measurestr("NOTE")
    gfx.x, gfx.y = note_lbl_x, note_y + (note_h - nh)/2
    gfx.drawstr("NOTE")
    components.DrawNoteDisplay(note_x, note_y, note_w, note_h, config.state.last_note_played)
    
    ---------------------------------------------------------------------------
    -- Island 2: Octava
    ---------------------------------------------------------------------------
    local i2_x = UX(23066)
    components.DrawIsland(i2_x, y_start, std_island_w, island_h, "OCTAVA", title_font_size)
    local btn_x = i2_x + (std_island_w - std_btn_w)/2
    local oct_open_up = y_start > gfx.h / 2
    local oct_choice = components.DrawDropdown(btn_x, UY(4545), std_btn_w, std_btn_h, nil, "C"..math.floor(config.state.octave), OCTAVE_OPTIONS, config.state.octave + 1, btn_font_size, oct_open_up)  -- Issue 9
    if oct_choice then config.state.octave = math.floor(oct_choice - 1) end
    if components.DrawButton(btn_x, UY(6823), std_btn_w, std_btn_h, "C5", config.state.octave == 5, btn_font_size) then config.state.octave = 5 end
    if components.DrawButton(btn_x, UY(9075), std_btn_w, std_btn_h, "C4", config.state.octave == 4, btn_font_size) then config.state.octave = 4 end
    if components.DrawButton(btn_x, UY(11343), std_btn_w, std_btn_h, "C3", config.state.octave == 3, btn_font_size) then config.state.octave = 3 end
    
    ---------------------------------------------------------------------------
    -- Island 3: Chord
    ---------------------------------------------------------------------------
    local i3_x = UX(28832)
    components.DrawIsland(i3_x, y_start, std_island_w, island_h, "CHORD", title_font_size)
    local cbtn_x = i3_x + (std_island_w - std_btn_w)/2
    if components.DrawButton(cbtn_x, UY(4640), std_btn_w, std_btn_h, "9NA", config.state.chord_mode_index == 4, btn_font_size) then config.state.chord_mode_index = 4 end
    if components.DrawButton(cbtn_x, UY(6893), std_btn_w, std_btn_h, "7MA", config.state.chord_mode_index == 3, btn_font_size) then config.state.chord_mode_index = 3 end
    if components.DrawButton(cbtn_x, UY(9122), std_btn_w, std_btn_h, "TRI", config.state.chord_mode_index == 2, btn_font_size) then config.state.chord_mode_index = 2 end
    if components.DrawButton(cbtn_x, UY(11365), std_btn_w, std_btn_h, "NOTE", config.state.chord_mode_index == 1, btn_font_size) then config.state.chord_mode_index = 1 end
    
    ---------------------------------------------------------------------------
    -- Island 4: Command Vertical Stack (Alineación Exacta)
    ---------------------------------------------------------------------------
    local i4_x = UX(34598)
    local b_w = std_island_w
    local b_h = US(1980)
    -- Padding calculado dinámicamente para alinear el borde inferior
    local b_gap = (island_h - (b_h * 5)) / 4
    local function PressOverlay(x, y, w, h)
        helpers.SetColor({0, 0, 0, 0.15})
        gfx.rect(x, y, w, h / 2, 1)
    end
    
    -- 1. VEL Island
    local v_y = y_start
    local v_hover = gfx.mouse_x >= i4_x and gfx.mouse_x <= i4_x + b_w and gfx.mouse_y >= v_y and gfx.mouse_y <= v_y + b_h
    local vel_on = config.state.use_velocity
    local v_bg = vel_on and theme.colors.btn_active or (v_hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(v_bg)
    components.DrawRoundedRect(i4_x, v_y, b_w, b_h, 10, true)
    if config.state.mouse_click and v_hover and not config.state.drag.is_dragging then PressOverlay(i4_x, v_y, b_w, b_h) end
    helpers.SetColor(vel_on and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", US(1500))
    local vw, vh = gfx.measurestr("VEL")
    gfx.x, gfx.y = i4_x + (b_w - vw)/2, v_y + (b_h - vh)/2
    gfx.drawstr("VEL")
    if v_hover and not config.state.drag.is_dragging then
        helpers.DrawTooltip(config.state.use_velocity and "Click: disable" or "Click: enable", US(700))
    end
    if config.state.mouse_click and v_hover and not config.state.drag.is_dragging then config.state.use_velocity = not config.state.use_velocity end
    
    -- 2. PLAY/STOP Island
    local p_y = v_y + b_h + b_gap
    local p_hover = gfx.mouse_x >= i4_x and gfx.mouse_x <= i4_x + b_w and gfx.mouse_y >= p_y and gfx.mouse_y <= p_y + b_h
    local is_playing = config.state.sequencer.is_playing
    local p_bg = is_playing and theme.colors.slot_playing or (p_hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(p_bg)
    components.DrawRoundedRect(i4_x, p_y, b_w, b_h, 10, true)
    if config.state.mouse_click and p_hover and not config.state.drag.is_dragging then PressOverlay(i4_x, p_y, b_w, b_h) end
    local cx, cy = i4_x + b_w/2, p_y + b_h/2
    local s = US(1000)
    if is_playing then
        helpers.SetColor({0,0,0,0.4})
        gfx.rect(cx-s/2, cy-s/2, s, s, 1)
    else
        helpers.SetColor(theme.colors.slot_playing)
        gfx.triangle(cx-s/2, cy-s/2, cx-s/2, cy+s/2, cx+s/2, cy)
    end
    if p_hover and not config.state.drag.is_dragging then
        helpers.DrawTooltip("Play/Stop progression", US(700))
    end
    if config.state.mouse_click and p_hover and not config.state.drag.is_dragging then config.state.sequencer.is_playing = not is_playing end
    
    -- 3. CLEAR + EXPORT (side by side, same row)
    local c_y = p_y + b_h + b_gap
    local split_gap = US(500)  -- gap entre CLEAR y EXPORT
    local half_w = math.floor((b_w - split_gap) / 2)
    local clear_x = i4_x
    local export_x = i4_x + half_w + split_gap

    -- CLEAR icon (left half)
    local clear_hover = gfx.mouse_x >= clear_x and gfx.mouse_x <= clear_x + half_w and gfx.mouse_y >= c_y and gfx.mouse_y <= c_y + b_h
    local clear_bg = clear_hover and {0.4, 0.1, 0.1, 1} or theme.colors.island_bg
    helpers.SetColor(clear_bg)
    components.DrawRoundedRect(clear_x, c_y, half_w, b_h, 10, true)
    if config.state.mouse_click and clear_hover and not config.state.drag.is_dragging then PressOverlay(clear_x, c_y, half_w, b_h) end
    local icon_pad = math.floor((half_w - b_h) / 2)
    if components.DrawToolIcon("clear", clear_x + icon_pad, c_y, b_h, false) then
        for i=1, 16 do config.state.progression[i] = nil end
    end
    if clear_hover and not config.state.drag.is_dragging then
        helpers.DrawTooltip("Clear all slots", US(700))
    end

    -- EXPORT icon (right half)
    local export_hover = gfx.mouse_x >= export_x and gfx.mouse_x <= export_x + half_w and gfx.mouse_y >= c_y and gfx.mouse_y <= c_y + b_h
    local export_bg = export_hover and theme.colors.btn_hover or theme.colors.island_bg
    helpers.SetColor(export_bg)
    components.DrawRoundedRect(export_x, c_y, half_w, b_h, 10, true)
    if config.state.mouse_click and export_hover and not config.state.drag.is_dragging then PressOverlay(export_x, c_y, half_w, b_h) end
    if components.DrawToolIcon("export", export_x + icon_pad, c_y, b_h, false) then
        midi.ExportToMidi()
    end
    if export_hover and not config.state.drag.is_dragging then
        helpers.DrawTooltip("Export MIDI", US(700))
    end

    -- 4. MIDI TOGGLE (replaces old EXPORT)
    local e_y = c_y + b_h + b_gap
    local e_hover = gfx.mouse_x >= i4_x and gfx.mouse_x <= i4_x + b_w and gfx.mouse_y >= e_y and gfx.mouse_y <= e_y + b_h
    local midi_expanded = config.state.midi_island_expanded
    local e_bg = midi_expanded and theme.colors.btn_active or (e_hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(e_bg)
    components.DrawRoundedRect(i4_x, e_y, b_w, b_h, 10, true)
    if config.state.mouse_click and e_hover and not config.state.drag.is_dragging then PressOverlay(i4_x, e_y, b_w, b_h) end
    helpers.SetColor(midi_expanded and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", US(1500))
    local ew, eh = gfx.measurestr("MIDI")
    gfx.x, gfx.y = i4_x + (b_w - ew)/2, e_y + (b_h - eh)/2
    gfx.drawstr("MIDI")
    if e_hover and not config.state.drag.is_dragging then
        helpers.DrawTooltip(midi_expanded and "Collapse MIDI island" or "Expand MIDI island", US(700))
    end
    if config.state.mouse_click and e_hover and not config.state.drag.is_dragging then ToggleMIDIIsland() end

    -- 5. VOLUME SLIDER
    local s_y = e_y + b_h + b_gap
    local s_hover = gfx.mouse_x >= i4_x and gfx.mouse_x <= i4_x + b_w and gfx.mouse_y >= s_y and gfx.mouse_y <= s_y + b_h
    local volume = config.state.sequencer.volume or 100

    -- Track (mismo island_bg que los botones para que coincida visualmente)
    helpers.SetColor(theme.colors.island_bg)
    components.DrawRoundedRect(i4_x, s_y, b_w, b_h, 10, true)

    -- Fill (barra activa con padding interno de US(180))
    local fill_pad = US(180)
    local fill_w = (volume / 100) * (b_w - fill_pad * 2)
    if fill_w > 0 then
        helpers.SetColor(theme.colors.btn_active)
        components.DrawRoundedRect(i4_x + fill_pad, s_y + fill_pad, fill_w, b_h - fill_pad * 2, 10, true)
    end

    -- Label
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", US(1100))
    local label = string.format("VOL %d%%", volume)
    local lw, lh = gfx.measurestr(label)
    gfx.x, gfx.y = i4_x + (b_w - lw)/2, s_y + (b_h - lh)/2
    gfx.drawstr(label)

    -- Interaction
    if s_hover and not config.state.drag.is_dragging then
        helpers.DrawTooltip("Volume: " .. volume .. "%", US(700))
    end
    -- Scroll wheel volume adjustment
    if s_hover and config.state.use_scroll and config.state.mouse_wheel_delta ~= 0 then
        local delta = config.state.mouse_wheel_delta > 0 and 5 or -5
        config.state.mouse_wheel_delta = 0
        config.state.sequencer.volume = math.max(0, math.min(100, volume + delta))
    end
    if config.state.mouse_click and s_hover and not config.state.drag.is_dragging then
        config.state.slider_dragging = true
    end
    if config.state.slider_dragging then
        local ratio = (gfx.mouse_x - i4_x) / b_w
        config.state.sequencer.volume = math.floor(math.max(0, math.min(100, ratio * 100)))
        if (gfx.mouse_cap & 1) == 0 then
            config.state.slider_dragging = false
        end
    end
end

function views.DecrementPageOverrideTimer()
    -- Decrement in ALL modes, not just DrawPerformanceArea (Issue 8)
    if config.state.page_override_timer > 0 then config.state.page_override_timer = config.state.page_override_timer - 1 end
end

function views.DrawPerformanceArea()
    if config.state.sequencer.is_playing and config.state.page_override_timer <= 0 then
        local target_page = math.floor((config.state.sequencer.current_step - 1) / 4) + 1
        if target_page > 0 and target_page <= 4 then config.state.current_page = target_page end
    end
    
    local x_start, w = UX(0), US(39914)
    local y, h = UY(14375), US(13363)
    
    -- Scroll pagination logic
    local hover_area = gfx.mouse_x >= x_start and gfx.mouse_x <= x_start + w and gfx.mouse_y >= y and gfx.mouse_y <= y + h
    if hover_area and config.state.mouse_wheel_delta ~= 0 then
        local dir = config.state.mouse_wheel_delta > 0 and -1 or 1
        config.state.current_page = math.max(1, math.min(4, config.state.current_page + dir))
    end

    helpers.SetColor(theme.colors.island_bg)
    components.DrawRoundedRect(x_start, y, w, h, 15, true)
    local margin = US(800)
    local avail_w = w - (margin * 2)
    local pad_w, pad_h = US(5300), US(4116)
    local num_intervals = #config.SCALES[config.state.scale_index].intervals
    local num_pads = 7  -- always draw 7 slots; extra ones beyond num_intervals draw grayed out
    local pad_spacing = (avail_w - (pad_w * num_pads)) / (num_pads - 1)
    for i = 1, num_pads do
        local px = x_start + margin + (i - 1) * (pad_w + pad_spacing)
        local py = UY(15197)
        components.DrawScalePad(px, py, pad_w, pad_h, i, US(1500), US(1100), num_intervals)
    end
    local slot_w, slot_h = US(9350), US(6760)
    local slot_spacing = (avail_w - (slot_w * 4)) / 3
    local slots_y = UY(19730)
    local start_idx = (config.state.current_page - 1) * 4 + 1
    for i = 0, 3 do
        local sx = x_start + margin + i * (slot_w + slot_spacing)
        components.DrawProgressionSlot(start_idx + i, sx, slots_y, slot_w, slot_h)
    end
    local page_center_x = x_start + w/2
    local page_y = UY(27192)
    components.DrawPaginator(page_center_x, page_y, 4)
    
    local btn_size = US(1000)
    local btn_offset = US(3200)
    
    gfx.setfont(1, "Calibri", btn_size)
    local lt, lh = gfx.measurestr("<")
    local rt, rh = gfx.measurestr(">")
    
    -- Prev button
    local prev_cx = page_center_x - btn_offset
    local prev_hover = gfx.mouse_x >= prev_cx - btn_size/2 and gfx.mouse_x <= prev_cx + btn_size/2 and gfx.mouse_y >= page_y - lh/2 and gfx.mouse_y <= page_y + lh/2
    local can_prev = config.state.current_page > 1
    if not can_prev then
        local disabled_color = {theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], 0.3}
        helpers.SetColor(disabled_color)
    else
        helpers.SetColor(prev_hover and theme.colors.text or theme.colors.text_dim)
    end
    gfx.x, gfx.y = prev_cx - lt/2, page_y - lh/2
    gfx.drawstr("<")
    if prev_hover and not config.state.drag.is_dragging then
        helpers.DrawTooltip("Previous page", US(700))
    end
    if config.state.mouse_click and prev_hover and can_prev then
        config.state.current_page = config.state.current_page - 1
        config.state.page_override_timer = 30
    end
    
    -- Next button
    local next_cx = page_center_x + btn_offset
    local next_hover = gfx.mouse_x >= next_cx - btn_size/2 and gfx.mouse_x <= next_cx + btn_size/2 and gfx.mouse_y >= page_y - rh/2 and gfx.mouse_y <= page_y + rh/2
    local can_next = config.state.current_page < 4
    if not can_next then
        local disabled_color = {theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], 0.3}
        helpers.SetColor(disabled_color)
    else
        helpers.SetColor(next_hover and theme.colors.text or theme.colors.text_dim)
    end
    gfx.x, gfx.y = next_cx - rt/2, page_y - rh/2
    gfx.drawstr(">")
    if next_hover and not config.state.drag.is_dragging then
        helpers.DrawTooltip("Next page", US(700))
    end
    if config.state.mouse_click and next_hover and can_next then
        config.state.current_page = config.state.current_page + 1
        config.state.page_override_timer = 30
    end
    
    helpers.SetColor(theme.colors.text_dim, 0.7)
    gfx.setfont(1, "Calibri", US(900))
    local page_text = "Page " .. config.state.current_page .. "/4"
    local pw, ph = gfx.measurestr(page_text)
    gfx.x, gfx.y = x_start + w - pw - US(700), UY(27192) - ph/2
    gfx.drawstr(page_text)
    
    -- Render Dragging Feedback on top
    components.DrawDragPreview(slot_w, slot_h)
end

function views.DrawMIDIIsland()
    if not config.state.midi_island_expanded then return end

    -- MIDI CH button centrado entre performance area y MIDI island
    -- Gap total = VEL height (1980) + b_gap (~1389) = ~3369 virtual
    -- perf_end = fin visual del área de performance (14375 + 13363)
    local perf_end = 27738
    local vel_h_v = 1980
    local gap_v = math.floor((15455 - 1980 * 5) / 4 + 1422)  -- b_gap en virtual; +1422 (~25px) para 49px de gap perf area→MIDI island
    local total_gap = vel_h_v + gap_v
    local top_pad = 428  -- padding arriba del botón (~7px); bottom pad queda ~942 (~16.6px)
    local btn_y_v = perf_end + top_pad                       -- ~29856
    local b_w = US(5347)  -- ~94px
    local content_w = US(39914)
    local btn_x = UX(0) + math.floor((content_w - b_w) / 2)  -- centrado
    local btn_y = UY(btn_y_v)
    local btn_h = US(vel_h_v)

    -- MIDI CH button (mismo tamaño y estilo que VEL)
    local ch = config.state.midi_channel
    local hover = gfx.mouse_x >= btn_x and gfx.mouse_x <= btn_x + b_w and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
    helpers.SetColor(hover and theme.colors.btn_hover or theme.colors.island_bg)
    components.DrawRoundedRect(btn_x, btn_y, b_w, btn_h, 10, true)
    if config.state.mouse_click and hover and not config.state.drag.is_dragging then
        local menu = ""
        for i = 1, 16 do
            menu = menu .. (i == ch and "!" or "") .. tostring(i) .. "|"
        end
        gfx.x, gfx.y = btn_x, btn_y + btn_h
        local choice = gfx.showmenu(menu:sub(1, -2))
        if choice and choice > 0 then config.state.midi_channel = choice end
    end
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", US(1500))
    local label = "CH " .. tostring(ch)
    local lw, lh = gfx.measurestr(label)
    gfx.x, gfx.y = btn_x + (b_w - lw)/2, btn_y + (btn_h - lh)/2
    gfx.drawstr(label)
    if hover and not config.state.drag.is_dragging then
        helpers.DrawTooltip("MIDI Channel: " .. ch, US(700))
    end

    -- Island background debajo del gap
    local island_y_v = btn_y_v + btn_h + gap_v - top_pad  -- ~32531
    local y = UY(island_y_v)
    local w = US(39914)
    local h = US(14000)

    helpers.SetColor(theme.colors.island_bg)
    components.DrawRoundedRect(UX(0), y, w, h, 15, true)
end

function views.DrawFullView()
    -- Scale es CONSTANTE: se calcula contra la altura BASE de diseño (500px)
    -- para que el contenido NO se deforme al expandir/colapsar la MIDI island.
    -- Expandir solo agrega canvas abajo para la isla, no cambia el zoom.
    local s = math.min(gfx.w / 39914, 500 / 29162) * 1.025
    local ox = (gfx.w - 39914 * s) / 2
    local oy = 600 * s - 10
    SetScale(s, ox, oy)
    helpers.SetColor(theme.colors.bg)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)
    views.DrawHeader()
    views.DrawIslands()
    views.DrawPerformanceArea()
    views.DrawMIDIIsland()
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
    local vel_label = config.state.use_velocity and "VEL" or "VEL-"
    local vel_active = config.state.use_velocity
    local vel_hover = gfx.mouse_x >= x_pos and gfx.mouse_x <= x_pos + btn_w and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
    helpers.SetColor(vel_active and theme.colors.btn_active or (vel_hover and theme.colors.btn_hover or theme.colors.btn_bg))
    components.DrawRoundedRect(x_pos, btn_y, btn_w, btn_h, 6, true)
    helpers.SetColor(vel_active and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 11)
    local vw, vh = gfx.measurestr(vel_label)
    gfx.x, gfx.y = x_pos + (btn_w - vw) / 2, btn_y + (btn_h - vh) / 2
    gfx.drawstr(vel_label)
    if config.state.mouse_click and vel_hover then
        config.state.use_velocity = not config.state.use_velocity
    end
    x_pos = x_pos + btn_w + gap

    -- [PLAY/STOP] button
    local is_playing = config.state.sequencer.is_playing
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
    if config.state.mouse_click and play_hover then
        config.state.sequencer.is_playing = not is_playing
    end
    x_pos = x_pos + btn_w + gap

    -- [CLEAR] button - clear progression
    if components.DrawTransportButton("CLR", x_pos, btn_y, btn_w, btn_h) then
        for i = 1, 16 do config.state.progression[i] = nil end
    end
    x_pos = x_pos + btn_w + gap

    -- [◄ Undock] button - undock and return to floating (Issue 6: U+25C4 better glyph support)
    if components.DrawTransportButton("◄", x_pos, btn_y, 50, btn_h) then
        gfx.dock(0)
        config.state.docked_mode = false
        config.state.dock_id = 0
        -- Resize back to normal window
        gfx.init("GROVE SCALE RUNNER", 720, 497, 0, config.state.view_offset_x, config.state.view_offset_y)
    end
end

return views
