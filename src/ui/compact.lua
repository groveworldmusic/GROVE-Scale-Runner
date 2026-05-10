-- GROVE FL MIDI: Compact View via JS_Composite
-- Renders the transport bar composite onto REAPER's transport window
-- Left click opens floating panel (GFX window, borderless) above transport bar
-- Right click opens context menu
local config = require("config")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local midi = require("core.midi")
local components = require("ui.components")

local compact = {}

-- =========================================================
-- CONSTANTS
-- =========================================================

local BAR_H = 26
local CV_W = 156
local PANEL_PW = 304  -- 294 + PANEL_PAD*2, piano divisible por 7
local PANEL_PH = 171
local PANEL_PIANO_H = 128
local PANEL_CONTROLS_Y = PANEL_PIANO_H + 10  -- 128 + 10 = 138
local PANEL_PAD = 5
local FLOAT_GAP = 6  -- gap visual entre panel y barra de transporte
local TITLE_BAR_H = 25  -- altura estimada de la barra de título de la ventana GFX

-- Cached dropdown options (shared with the panel)
local SCALE_OPTIONS = (function()
    local t = {}
    for i, s in ipairs(config.SCALES) do t[i] = helpers.CompactAbbreviateScale(s.name) end
    return t
end)()
local SCALE_FULL = (function() local t={}; for _, s in ipairs(config.SCALES) do t[#t+1]=s.name end return t end)()
local OCTAVE_OPTIONS = (function()
    local t = {}
    for i = 0, 8 do t[i + 1] = "C" .. i end
    return t
end)()
local CHORD_OPTIONS = (function()
    local t = {}
    for i, m in ipairs(config.CHORD_MODES) do t[i] = m.name end
    return t
end)()

-- =========================================================
-- LOCAL STATE
-- =========================================================

local cv_x, cv_y, cv_w, cv_h = 0, 0, 0, BAR_H
local intercept_active = false
local cv_auto_x = nil
local use_auto_pos = true
local last_peek_time = 0
local last_transport_w = nil  -- Track transport width for auto-position invalidation (Issue 10)

-- Panel (floating GFX) state
local panel_open = false
local panel_inited = false
local panel_init_x, panel_init_y = 0, 0
local panel_last_mouse_cap = 0
local panel_hwnd = nil
local panel_first_frame = true
local panel_instance = 0
local panel_open_up = false  -- dropdown direction based on panel screen position
local RESTORE_BTN_SIZE = 12
local restore_btn_x = 0  -- x of the restore-full-view button on the compact bar
local function PanelTitle() return "Scale Runner - Panel#" .. panel_instance end

-- =========================================================
-- LICE SYSTEM
-- =========================================================

local function EnsureLICE()
    local c = config.state.compact
    if not c.lice_bitmap then
        c.lice_bitmap = reaper.JS_LICE_CreateBitmap(true, 1, 1)
    end
    if not c.lice_font then
        c.lice_font = reaper.JS_LICE_CreateFont()
        c.gdi_font = reaper.JS_GDI_CreateFont(13, 400, 0, 0, 0, 0, "Calibri")
        reaper.JS_LICE_SetFontFromGDI(c.lice_font, c.gdi_font, "")
    end
end

local function DrawLICERect(bm, x, y, w, h, color, fill, r)
    local a = 1
    local ci = reaper.ColorToNative(math.floor(color[1]*255), math.floor(color[2]*255), math.floor(color[3]*255)) | 0xFF000000
    r = r or 0
    if not fill then
        reaper.JS_LICE_RoundRect(bm, x, y, w - 1, h - 1, r, ci, a, 0, true)
        return
    end
    if r == 0 then
        reaper.JS_LICE_FillRect(bm, x, y, w, h, ci, a, 0)
        return
    end
    if h <= 2 * r then r = math.floor(h / 2 - 1) end
    if w <= 2 * r then r = math.floor(w / 2 - 1) end
    local F = reaper.JS_LICE_FillCircle
    F(bm, x + r, y + r, r, ci, a, 0, 1)
    F(bm, x + w - r - 1, y + r, r, ci, a, 0, 1)
    F(bm, x + w - r - 1, y + h - r - 1, r, ci, a, 0, 1)
    F(bm, x + r, y + h - r - 1, r, ci, a, 0, 1)
    reaper.JS_LICE_FillRect(bm, x, y + r, r, h - r * 2, ci, a, 0)
    reaper.JS_LICE_FillRect(bm, x + w - r, y + r, r, h - r * 2, ci, a, 0)
    reaper.JS_LICE_FillRect(bm, x + r, y, w - r * 2, h, ci, a, 0)
end

local function DrawLICEText(bm, x, y, text, color)
    local ci = reaper.ColorToNative(math.floor(color[1]*255), math.floor(color[2]*255), math.floor(color[3]*255)) | 0xFF000000
    reaper.JS_LICE_SetFontColor(config.state.compact.lice_font, ci)
    reaper.JS_LICE_DrawText(bm, config.state.compact.lice_font, text, #text, x, y, 1000, 100)
end

-- =========================================================
-- TRANSPORT WINDOW
-- =========================================================

function compact.FindTransportWindow()
    local hwnd = reaper.JS_Window_Find("Transport", true)
    if not hwnd then hwnd = reaper.JS_Window_Find("Transporte", false) end
    if not hwnd then hwnd = reaper.JS_Window_Find("Transport", false) end
    -- Fallback: SWS extension's GetTransportHwnd (Issue 7)
    if not hwnd then
        local getHwnd = reaper.GetTransportHwnd
        if getHwnd then
            local ok, ret = pcall(getHwnd)
            if ok and ret and ret ~= 0 then hwnd = ret end
        end
    end
    return hwnd
end

-- =========================================================
-- POSITIONING
-- =========================================================

function compact.ResetAutoPosition()
    cv_auto_x = nil; use_auto_pos = true
end

function compact.SetManualPosition(x, y)
    config.state.view_offset_x = x; config.state.view_offset_y = y
    use_auto_pos = false; cv_auto_x = nil
end

local function FindTransportEmptyArea()
    local hwnd = config.state.compact.transport_hwnd
    if not hwnd then return nil end
    local _, w_trans, h_trans = reaper.JS_Window_GetClientSize(hwnd)
    if not w_trans or w_trans < cv_w then return nil end
    local mid_y = math.floor(h_trans / 2)
    local empty_areas, seg_start = {}, nil
    for x = 0, w_trans - 1, 5 do
        local sx, sy = reaper.JS_Window_ClientToScreen(hwnd, x, mid_y)
        local _, thing = reaper.GetThingFromPoint(sx, sy)
        if thing == 'trans' then
            if not seg_start then seg_start = x end
        elseif seg_start then
            local seg_w = x - seg_start
            if seg_w >= cv_w then table.insert(empty_areas, {x = seg_start, w = seg_w}) end
            seg_start = nil
        end
    end
    if seg_start then
        local seg_w = w_trans - seg_start
        if seg_w >= cv_w then table.insert(empty_areas, {x = seg_start, w = seg_w}) end
    end
    if #empty_areas == 0 then return nil end
    return empty_areas[#empty_areas].x
end

-- =========================================================
-- GET TRANSPORT SCREEN POSITION
-- =========================================================

local function GetTransportScreenRect()
    local hwnd = config.state.compact.transport_hwnd
    if not hwnd then return nil end
    local _, w_trans, h_trans = reaper.JS_Window_GetClientSize(hwnd)
    if not w_trans then return nil end
    local _, win_left, win_top, win_right, win_bottom = reaper.JS_Window_GetRect(hwnd)
    -- Obtener el origen del área cliente en coordenadas de pantalla
    local client_screen_x, client_screen_y = reaper.JS_Window_ClientToScreen(hwnd, 0, 0)
    if not client_screen_x then
        -- Fallback: usar GetRect directamente
        client_screen_x = win_left or 0
        client_screen_y = win_top or 0
    end
    -- Posición de la vista compacta en pantalla
    local bar_screen_x = client_screen_x + cv_x
    local bar_screen_y = client_screen_y + cv_y
    return {
        left = bar_screen_x, top = bar_screen_y,
        right = win_right or (bar_screen_x + cv_w),
        bottom = win_bottom or (bar_screen_y + BAR_H),
        w = w_trans, h = h_trans,
        bar_center_x = bar_screen_x + cv_w / 2,
        bar_screen_y = bar_screen_y,
    }
end

-- =========================================================
-- BORDERLESS WINDOW STYLING
-- =========================================================

-- =========================================================
-- PANEL WINDOW
-- =========================================================

local function ClosePanel()
    if panel_inited then gfx.quit(); panel_inited = false end
    panel_open = false; panel_hwnd = nil
end

function compact.HandlePanel()
    if not panel_open then
        if panel_inited then gfx.quit(); panel_inited = false; panel_hwnd = nil end
        return
    end

    -- First call: init GFX window
    if not panel_inited then
        gfx.init(PanelTitle(), PANEL_PW, PANEL_PH, 0, panel_init_x, panel_init_y)
        panel_inited = true
        -- Find window handle for later use (e.g. closing via system X)
        panel_hwnd = reaper.JS_Window_Find(PanelTitle(), true)
        -- No early return — fall through to gfx.getchar + draw so no frame is empty
    end

    -- Find window handle if not yet found
    if not panel_hwnd then
        panel_hwnd = reaper.JS_Window_Find(PanelTitle(), true)
    end

    local char = gfx.getchar()
    if char == -1 or char == 27 then
        ClosePanel()
        return
    end

    -- Fresh click detection (skip first frame to discard stale click that opened the panel)
    config.state.mouse_click = not panel_first_frame and (gfx.mouse_cap & 1) == 1 and panel_last_mouse_cap == 0
    panel_first_frame = false
    panel_last_mouse_cap = gfx.mouse_cap

    -- Background (fill entire window, no rounded corners to avoid border artifacts)
    helpers.SetColor(theme.colors.island_bg)
    gfx.rect(0, 0, PANEL_PW, PANEL_PH, 1)

    -- Piano (5px padding all around)
    components.DrawPianoKeyboard(PANEL_PAD, PANEL_PAD, PANEL_PW - PANEL_PAD * 2, PANEL_PIANO_H - PANEL_PAD, 16)

    -- Controls row — aligned with piano KEY boundaries (match DrawPianoKeyboard centering)
    local cy = PANEL_CONTROLS_Y
    local ch = 28
    local piano_w = PANEL_PW - PANEL_PAD * 2
    local white_w = math.floor(piano_w / 7)
    local slack = piano_w - white_w * 7  -- 0
    local piano_key_left = PANEL_PAD + math.floor(slack / 2)  -- 5
    local piano_key_right = piano_key_left + white_w * 7  -- 299
    local ctrl_gap = 6
    local scale_w = 85   -- scale gets more room
    local octave_w = 60  -- octave and chord narrower
    local chord_w = 60
    local vel_w = 71     -- vel takes what remains
    -- Sum: 85+60+60+71 + 3*6 = 294 ✓

    -- Dropdown direction: open upward si el panel está arriba de la barra, downward si está abajo
    local open_up = panel_open_up

    -- Scale dropdown (wider)
    local r = components.DrawDropdown(piano_key_left, cy, scale_w, ch, nil,
        helpers.CompactAbbreviateScale(config.SCALES[config.state.scale_index].name),
        SCALE_FULL, config.state.scale_index, 16, open_up)
    if r then config.state.scale_index = r end

    -- Octave dropdown (narrower)
    r = components.DrawDropdown(piano_key_left + scale_w + ctrl_gap, cy, octave_w, ch, nil,
        "C" .. math.floor(config.state.octave), OCTAVE_OPTIONS, config.state.octave + 1, 16, open_up)
    if r then config.state.octave = math.floor(r - 1) end

    -- Chord dropdown (narrower)
    r = components.DrawDropdown(piano_key_left + scale_w + ctrl_gap + octave_w + ctrl_gap, cy, chord_w, ch, nil,
        config.CHORD_MODES[config.state.chord_mode_index].name,
        CHORD_OPTIONS, config.state.chord_mode_index, 16, open_up)
    if r then config.state.chord_mode_index = r end

    -- VEL toggle
    local vx = piano_key_left + scale_w + ctrl_gap + octave_w + ctrl_gap + chord_w + ctrl_gap
    local v_hover = gfx.mouse_x >= vx and gfx.mouse_x <= vx + vel_w and
                    gfx.mouse_y >= cy and gfx.mouse_y <= cy + ch
    helpers.SetColor(config.state.use_velocity and theme.colors.btn_active or
                     (v_hover and theme.colors.btn_hover or theme.colors.bg))
    components.DrawRoundedRect(vx, cy, vel_w, ch, 6, true)
    helpers.SetColor(config.state.use_velocity and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 16)
    local tw, th = gfx.measurestr("VEL")
    gfx.x, gfx.y = vx + (vel_w - tw) / 2, cy + (ch - th) / 2
    gfx.drawstr("VEL")
    if config.state.mouse_click and v_hover then config.state.use_velocity = not config.state.use_velocity end
end

-- =========================================================
-- CONTEXT MENU
-- =========================================================

function compact.ShowContextMenu()
    -- Save current GFX state BEFORE creating the temp context-menu window.
    -- gfx.init("", 0, 0) below replaces the GFX context; if we don't save now,
    -- SwitchViewMode later reads gfx.w/gfx.h = 0 and corrupts last_gfx_state.
    if config.state.view_mode == config.VIEW_MODES.FULL then
        local saved_dock = gfx.dock(-1)
        local sw, sh = gfx.w, gfx.h
        if sw and sw > 0 then
            config.state.last_gfx_state.dock = saved_dock
            config.state.last_gfx_state.w = sw
            config.state.last_gfx_state.h = sh
        end
    end

    local menu = "#Scale Runner|"
    menu = menu .. (config.state.view_mode == config.VIEW_MODES.COMPACT and "Cambiar a Vista Completa" or "Cambiar a Vista Compacta") .. "|"
    menu = menu .. ">Tonalidad|"
    for i, n in ipairs(config.NOTE_NAMES) do menu = menu .. (config.state.root_index == i and "!" or "") .. n .. "|" end
    menu = menu .. "<|>Escala|"
    for i, s in ipairs(config.SCALES) do menu = menu .. (config.state.scale_index == i and "!" or "") .. s.name .. "|" end
    menu = menu .. "<|>Octava|"
    for i=0, 8 do menu = menu .. (config.state.octave == i and "!" or "") .. "C" .. i .. "|" end
    menu = menu .. "<|>Acorde|"
    for i, m in ipairs(config.CHORD_MODES) do menu = menu .. (config.state.chord_mode_index == i and "!" or "") .. m.name .. "|" end
    menu = menu .. "<|>Herramientas|"
    menu = menu .. "Exportar Progresion MIDI|Panic (Notas Off)||"
    menu = menu .. ">Posicion|Ajustar Offset X/Y...|Resetear Verticalmente|<"

    gfx.init("", 0, 0)
    local mx, my = reaper.GetMousePosition()
    gfx.x, gfx.y = gfx.screentoclient(mx, my)
    local ret = gfx.showmenu(menu)
    gfx.quit()

    local OFFSET_TONE = 2
    local OFFSET_SCALE = OFFSET_TONE + #config.NOTE_NAMES
    local OFFSET_OCT = OFFSET_SCALE + #config.SCALES
    local OFFSET_CHORD = OFFSET_OCT + 9
    local OFFSET_TOOLS = OFFSET_CHORD + #config.CHORD_MODES

    if ret == 1 then
        if panel_open then ClosePanel() end
        compact.SwitchViewMode()  -- Issue 1: re-initializes GFX window properly
    elseif ret >= OFFSET_TONE and ret < OFFSET_SCALE then
        config.state.root_index = ret - OFFSET_TONE + 1
    elseif ret >= OFFSET_SCALE and ret < OFFSET_OCT then
        config.state.scale_index = ret - OFFSET_SCALE + 1
    elseif ret >= OFFSET_OCT and ret < OFFSET_CHORD then
        config.state.octave = math.floor(ret - OFFSET_OCT)
    elseif ret >= OFFSET_CHORD and ret < OFFSET_TOOLS then
        config.state.chord_mode_index = ret - OFFSET_CHORD + 1
    elseif ret == OFFSET_TOOLS + 1 then
        midi.ExportToMidi()
    elseif ret == OFFSET_TOOLS + 2 then
        midi.AllNotesOff()
    elseif ret == OFFSET_TOOLS + 3 then
        local ok, csv = reaper.GetUserInputs("Ajustar Posicion", 2, "Offset X,Offset Y",
            config.state.view_offset_x .. "," .. config.state.view_offset_y)
        if ok then
            local nx, ny = csv:match("([^,]+),([^,]+)")
            local nx_num, ny_num = tonumber(nx) or 0, tonumber(ny) or 0
            if nx_num > 0 then compact.SetManualPosition(nx_num, ny_num)
            else compact.ResetAutoPosition(); config.state.view_offset_y = ny_num end
        end
    elseif ret == OFFSET_TOOLS + 4 then
        config.state.view_offset_y = 0; cv_auto_x = nil
    end
end

-- =========================================================
-- VIEW MODE SWITCHING
-- =========================================================

function compact.SwitchViewMode()
    local c = config.state.compact
    if config.state.view_mode == config.VIEW_MODES.FULL then
        -- Guard: only capture GFX state if the context is valid (gfx.w > 0).
        -- When called from ShowContextMenu after gfx.quit(), the context is gone.
        if gfx.w and gfx.w > 0 then
            local dock = gfx.dock(-1)
            local wx, wy = 0, 0
            local hwnd = reaper.JS_Window_Find(config.script_title, true)
            if hwnd then
                local _, left, top, right, bottom = reaper.JS_Window_GetRect(hwnd)
                wx, wy = left or 0, top or 0
            end
            config.state.last_gfx_state = {dock=dock, x=wx, y=wy, w=gfx.w, h=gfx.h}
        end
        config.state.view_mode = config.VIEW_MODES.COMPACT
        gfx.quit()
        c.transport_hwnd = compact.FindTransportWindow()
    else
        if panel_open then ClosePanel() end
        config.state.view_mode = config.VIEW_MODES.FULL
        -- Keep transport interception alive so the full-view toggle button works both ways
        local gs = config.state.last_gfx_state
        gfx.init(config.script_title, gs.w, gs.h, gs.dock, gs.x, gs.y)
        gfx.setfont(1, "Calibri", 16)
    end
end

-- =========================================================
-- COMPACT BAR DRAWING
-- =========================================================

local function DrawCompactBar(bm, y_off)
    local key_n = config.NOTE_NAMES[config.state.root_index]
    local scale_n = helpers.CompactAbbreviateScale(config.SCALES[config.state.scale_index].name)
    local oct_n = "C" .. math.floor(config.state.octave)
    local chord_n = (config.state.chord_mode_index == 1) and "Note" or config.CHORD_MODES[config.state.chord_mode_index].name:sub(1, 3)
    local wk, ws, wo, wch = 16, 34, 16, 24
    local x = 6
    DrawLICEText(bm, x, y_off + 6, key_n, theme.colors.text); x = x + wk
    local disp, dc = scale_n, theme.colors.text
    if config.state.active_note_draw_timer > 0 then
        local nc = config.state.last_note_played or ""
        if nc ~= "None" then disp = nc:sub(1, 4); dc = theme.colors.pad_active end
    end
    DrawLICEText(bm, x, y_off + 6, disp, dc); x = x + ws
    DrawLICEText(bm, x, y_off + 6, oct_n, theme.colors.text_dim); x = x + wo
    DrawLICEText(bm, x, y_off + 6, chord_n, theme.colors.text_dim); x = x + wch

    -- Restore full-view button (4px after chord text, tight with the group)
    local btn_size = RESTORE_BTN_SIZE
    local btn_x = x + 4
    local btn_y = y_off + (BAR_H - btn_size) / 2
    restore_btn_x = btn_x
    local btn_color = theme.colors.text_dim
    DrawLICERect(bm, btn_x, btn_y, btn_size, btn_size, theme.colors.text_dim, false, 2)
end

-- =========================================================
-- RENDER (JS_Composite bar)
-- =========================================================

local function TogglePanel()
    if panel_open then ClosePanel()
    else
        local rect = GetTransportScreenRect()
        if not rect then return end
        -- Centrar en el contenido visible de la vista compacta (no en el composite entero)
        -- cv_w es 156 pero el contenido visible es ~103px, ajustamos 26px a la izquierda
        panel_init_x = math.floor(rect.bar_center_x - PANEL_PW / 2 - 26)

        -- Determinar si hay espacio arriba de la barra
        local space_above = rect.bar_screen_y - FLOAT_GAP
        local enough_above = space_above >= PANEL_PH + FLOAT_GAP

        if enough_above then
            -- Panel arriba de la barra (comportamiento normal)
            panel_init_y = math.floor(rect.bar_screen_y - PANEL_PH - FLOAT_GAP)
        else
            -- Panel debajo de la barra (cuando está dockeada on top)
            panel_init_y = math.floor(rect.bar_screen_y + BAR_H + FLOAT_GAP)
        end
        panel_open_up = not enough_above  -- Issue 2: open away from bar direction

        if panel_init_x + PANEL_PW > rect.right then panel_init_x = rect.right - PANEL_PW - 10 end
        if panel_init_x < 0 then panel_init_x = 10 end
        panel_open = true
        panel_inited = false
        panel_hwnd = nil
        panel_first_frame = true
        panel_instance = panel_instance + 1
    end
end

function compact.UpdateCompactView()
    local c = config.state.compact
    if not c.transport_hwnd then c.transport_hwnd = compact.FindTransportWindow() end
    if not c.transport_hwnd then return end

    EnsureLICE()

    cv_w, cv_h = CV_W, BAR_H

    local _, w_trans, h_trans = reaper.JS_Window_GetClientSize(c.transport_hwnd)

    -- Invalidate auto-position cache if transport window resized (Issue 10)
    if cv_auto_x ~= nil and last_transport_w and w_trans and w_trans ~= last_transport_w then
        cv_auto_x = nil
    end
    if w_trans then last_transport_w = w_trans end

    if config.state.view_offset_x > 0 then
        cv_x = config.state.view_offset_x
    elseif use_auto_pos then
        if cv_auto_x == nil then cv_auto_x = FindTransportEmptyArea() end
        cv_x = cv_auto_x or 5
    else
        cv_x = 5
    end

    if h_trans and h_trans > 0 then
        cv_y = math.floor((h_trans - BAR_H) / 2) + config.state.view_offset_y
    else
        cv_y = 2
    end

    -- Content width = left padding + all columns + gap to button + button + right margin
    local content_w = 6 + 16 + 34 + 16 + 24 + 4 + RESTORE_BTN_SIZE + 5

    reaper.JS_LICE_Resize(c.lice_bitmap, cv_w, cv_h)
    DrawLICERect(c.lice_bitmap, 0, 0, content_w, cv_h, theme.colors.bg, true, 8)
    DrawCompactBar(c.lice_bitmap, 0)

    reaper.JS_Composite(c.transport_hwnd, cv_x, cv_y, content_w, cv_h, c.lice_bitmap, 0, 0, content_w, cv_h, true)
    -- Invalidate full old area + new content area to clean up stale pixels
    reaper.JS_Window_InvalidateRect(c.transport_hwnd, cv_x, cv_y, cv_x + cv_w, cv_y + cv_h, false)
end

-- =========================================================
-- MOUSE INTERCEPTION
-- =========================================================

function compact.ProcessMouseInterception()
    local c = config.state.compact
    if not c.transport_hwnd then c.transport_hwnd = compact.FindTransportWindow() end
    if not c.transport_hwnd then return end

    if not intercept_active then
        reaper.JS_WindowMessage_Intercept(c.transport_hwnd, "WM_LBUTTONDOWN", false)
        reaper.JS_WindowMessage_Intercept(c.transport_hwnd, "WM_RBUTTONDOWN", false)
        intercept_active = true; c.is_active = true
    end

    -- Pre-check cursor position BEFORE removing intercepted messages.
    -- Only peek+remove when cursor is within the compact view rect so that
    -- clicks on transport controls (play/stop/record) reach REAPER normally.
    local mx, my = reaper.GetMousePosition()
    local wx, wy = reaper.JS_Window_ScreenToClient(c.transport_hwnd, mx, my)
    if not (wx >= cv_x and wx <= cv_x + cv_w and wy >= cv_y and wy <= cv_y + cv_h) then
        return
    end

    local l_peak, _, l_time = reaper.JS_WindowMessage_Peek(c.transport_hwnd, "WM_LBUTTONDOWN", true)
    local r_peak, _, r_time = reaper.JS_WindowMessage_Peek(c.transport_hwnd, "WM_RBUTTONDOWN", true)

    local timestamp = math.max(l_time or 0, r_time or 0)
    -- Process left-click FIRST (panel/switch view). Right-click (context menu) falls through.
    -- Both Peek calls already removed their messages from the queue with remove=true,
    -- so we only process one event per frame (deduped by timestamp).
    if timestamp > 0 and timestamp ~= last_peek_time then
        last_peek_time = timestamp
        if l_peak then
            -- Check if click is on the restore-full-view button
            local btn_size = RESTORE_BTN_SIZE
            local btn_x = cv_x + restore_btn_x
            local btn_y = cv_y + (BAR_H - btn_size) / 2
            if wx >= btn_x and wx <= btn_x + btn_size and wy >= btn_y and wy <= btn_y + btn_size then
                compact.SwitchViewMode()
            else
                TogglePanel()
            end
        elseif r_peak then
            compact.ShowContextMenu()
        end
    end
end

-- =========================================================
-- CLEANUP
-- =========================================================

function compact.Cleanup()
    local c = config.state.compact
    if panel_open then ClosePanel() end
    -- Cache hwnd before it could go nil; always attempt release/unlink
    local hwnd = c.transport_hwnd
    c.transport_hwnd = nil
    if intercept_active then
        if hwnd then
            reaper.JS_WindowMessage_Release(hwnd, "WM_LBUTTONDOWN")
            reaper.JS_WindowMessage_Release(hwnd, "WM_RBUTTONDOWN")
            reaper.JS_Composite_Unlink(hwnd, c.lice_bitmap)
        end
        intercept_active = false; c.is_active = false
    end
    if c.lice_bitmap then reaper.JS_LICE_DestroyBitmap(c.lice_bitmap); c.lice_bitmap = nil end
    if c.lice_font then reaper.JS_LICE_DestroyFont(c.lice_font); c.lice_font = nil end
    if c.gdi_font then reaper.JS_GDI_DeleteObject(c.gdi_font); c.gdi_font = nil end
end

return compact
