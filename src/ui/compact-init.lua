-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Compact View Life-cycle Orchestration
-- Central coordinator that wires together all compact sub-modules.
-- Exports the functions that compact.lua re-exports to consumers.
-- Uses top-level requires for all sub-modules (no circular deps:
-- sub-modules only require compact-init at function call time via lazy requires).
local config = require("config")
local api_guard = require("core.api-guard")
local compact_store = require("state.compact")
local midi_store = require("state.midi")
local ui_store = require("state.ui")
local island_store = require("state.island")
local seq_store = require("state.sequencer")
local prefs = require("state.preferences")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local lice = require("ui.lice")
local positioning = require("ui.positioning")
local compact_bar = require("ui.compact-bar")
local panel = require("ui.compact-panel")
local intercept = require("ui.compact-intercept")
local menu = require("ui.compact-menu")
local gfx_safe = require("ui.gfx-safe")
local persist = require("state.persist")

local m = {}

-- =========================================================
-- TRANSPORT WINDOW
-- =========================================================

function m.FindTransportWindow()
    if not api_guard.CheckAPI("JS_Window_Find") then return nil end
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
-- POSITIONING WRAPPERS
-- =========================================================

function m.ResetAutoPosition() positioning.ResetAutoPosition() end

function m.SetManualPosition(x, y)
    config.state.view_offset_x = x; config.state.view_offset_y = y
    positioning.DisableAutoPosition()
end

-- =========================================================
-- VIEW MODE SWITCHING
-- =========================================================

function m.SwitchViewMode()
    if ui_store.GetViewMode() == config.VIEW_MODES.FULL then
        -- FULL → COMPACT: close full view, end overlay
        compact_store.SetOverlayActive(false)
        -- Guard: only capture GFX state if the context is valid (gfx.w > 0).
        if gfx.w and gfx.w > 0 then
            local dock = gfx.dock(-1)
            local wx, wy = 0, 0
            local hwnd = reaper.JS_Window_Find(config.script_title, true)
            if hwnd then
                local _, left, top, right, bottom = reaper.JS_Window_GetRect(hwnd)
                wx, wy = left or 0, top or 0
            end
            compact_store.SetLastGfxState({dock=dock, x=wx, y=wy, w=gfx.w, h=gfx.h})
        end
        ui_store.SetViewMode(config.VIEW_MODES.COMPACT)
        gfx_safe.SafeGfxQuit()
        compact_store.SetTransportHwnd(m.FindTransportWindow())
    else
        -- COMPACT → FULL: open full view AND activate overlay
        if panel.IsPanelOpen() then panel.ClosePanel() end
        ui_store.SetViewMode(config.VIEW_MODES.FULL)
        compact_store.SetOverlayActive(true)
        if not compact_store.GetTransportHwnd() then
            compact_store.SetTransportHwnd(m.FindTransportWindow())
        end
        lice.EnsureLICE()
        local gs = compact_store.GetLastGfxState()
        gfx_safe.SafeGfxInit(config.script_title, gs.w, gs.h, gs.dock, gs.x, gs.y)
        gfx.setfont(1, "Calibri", 16)
    end
end

-- =========================================================
-- IS PANEL OPEN (simplified accessor)
-- =========================================================

function m.IsPanelOpen() return panel.IsPanelOpen() end

-- =========================================================
-- INIT OVERLAY
-- =========================================================

-- Initialize compact bar overlay alongside the full view (auto-start)
function m.InitOverlay()
    compact_store.SetOverlayActive(true)
    ui_store.SetViewMode(config.VIEW_MODES.FULL)  -- stay in full mode
    compact_store.SetTransportHwnd(m.FindTransportWindow())
    if not compact_store.GetTransportHwnd() then
        compact_store.SetOverlayActive(false)
        return
    end
    lice.EnsureLICE()
    -- Don't call gfx.quit() — full view stays visible
    -- Interception will start on first MainLoop call via compact_overlay_active check
end

-- =========================================================
-- HANDLE PANEL (Floating GFX window)
-- =========================================================

function m.HandlePanel()
    if not panel.panel_state.open then
        if panel.panel_state.inited then
            gfx_safe.SafeGfxQuit()
            panel.panel_state.inited = false
            panel.panel_state.hwnd = nil
        end
        return
    end

    -- First call: init GFX window
    if not panel.panel_state.inited then
        gfx_safe.SafeGfxInit("GROVE Scale Runner (Compact)", panel.PANEL_PW, panel.PANEL_PH, 0,
            panel.panel_state.init_x, panel.panel_state.init_y)
        panel.panel_state.inited = true
        -- Find window handle for later use (e.g. closing via system X)
        panel.panel_state.hwnd = reaper.JS_Window_Find("GROVE Scale Runner (Compact)", true)
        -- No early return — fall through to gfx.getchar + draw so no frame is empty
    end

    -- Find window handle if not yet found
    if not panel.panel_state.hwnd then
        panel.panel_state.hwnd = reaper.JS_Window_Find("GROVE Scale Runner (Compact)", true)
    end

    local char = gfx.getchar()
    if char == -1 or char == 27 then
        gfx.mouse_wheel = 0
        panel.ClosePanel()
        return
    end

    -- Auto-reposition: si la barra de transporte se movio significativamente
    local rect = positioning.GetTransportScreenRect()
    if rect and math.abs(rect.bar_screen_y - panel.panel_state.opened_bar_y) > 50 then
        panel.panel_state.init_x = math.floor(rect.bar_center_x - panel.PANEL_PW / 2 - 26)
        local enough = rect.bar_screen_y >= panel.PANEL_PH + panel.FLOAT_GAP
        if enough then
            panel.panel_state.init_y = math.floor(rect.bar_screen_y - panel.PANEL_PH - panel.FLOAT_GAP)
        else
            local BELOW_OFFSET_AUTO = 38
            panel.panel_state.init_y = math.floor(rect.bar_screen_y + panel.BAR_H + panel.FLOAT_GAP - BELOW_OFFSET_AUTO)
        end
        panel.panel_state.open_up = enough
        panel.panel_state.opened_bar_y = rect.bar_screen_y

        -- Cerrar ventana actual; se recreara en el proximo frame con nueva posicion
        gfx_safe.SafeGfxQuit()
        panel.panel_state.inited = false
        panel.panel_state.hwnd = nil
        panel.panel_state.first_frame = true
        gfx.mouse_wheel = 0
        return
    end

    -- Fresh click detection (skip first frame to discard stale click that opened the panel)
    ui_store.SetMouseClick(not panel.panel_state.first_frame and (gfx.mouse_cap & 1) == 1 and panel.panel_state.last_mouse_cap == 0)
    panel.panel_state.first_frame = false
    panel.panel_state.last_mouse_cap = gfx.mouse_cap
    ui_store.SetMouseWheelDelta(gfx.mouse_wheel)
    gfx.mouse_wheel = 0

    -- Background
    helpers.SetColor(theme.colors.island_bg)
    gfx.rect(0, 0, panel.PANEL_PW, panel.PANEL_PH, 1)

    -- Piano (5px padding all around)
    components.DrawPianoKeyboard(panel.PANEL_PAD, panel.PANEL_PAD,
        panel.PANEL_PW - panel.PANEL_PAD * 2, panel.PANEL_PIANO_H - panel.PANEL_PAD, 16)

    -- Controls row
    local cy = panel.PANEL_CONTROLS_Y
    local ch = 28
    local piano_w = panel.PANEL_PW - panel.PANEL_PAD * 2
    local white_w = math.floor(piano_w / 7)
    local slack = piano_w - white_w * 7
    local piano_key_left = panel.PANEL_PAD + math.floor(slack / 2)
    local ctrl_gap = 6
    local scale_w = 85
    local octave_w = 60
    local chord_w = 60
    local vel_w = 71

    local open_up = panel.panel_state.open_up

    -- Scale dropdown
    local si = api_guard.ClampIndex(prefs.GetScaleIndex(), 1, #config.SCALES)
    local r = components.DrawDropdown(piano_key_left, cy, scale_w, ch, nil,
        helpers.CompactAbbreviateScale(config.SCALES[si].name),
        panel.SCALE_FULL, si, 16, open_up)
    if r then config.state.scale_index = r; persist.Save("scale_index", r) end

    -- Octave dropdown
    r = components.DrawDropdown(piano_key_left + scale_w + ctrl_gap, cy, octave_w, ch, nil,
        "C" .. math.floor(prefs.GetOctave()),
        panel.OCTAVE_OPTIONS, prefs.GetOctave() + 1, 16, open_up)
    if r then local ov = math.floor(r - 1); config.state.octave = ov; persist.Save("octave", ov) end

    -- Chord dropdown
    local ci = api_guard.ClampIndex(prefs.GetChordModeIndex(), 1, #config.CHORD_MODES)
    r = components.DrawDropdown(piano_key_left + scale_w + ctrl_gap + octave_w + ctrl_gap, cy, chord_w, ch, nil,
        config.CHORD_MODES[ci].name,
        panel.CHORD_OPTIONS, ci, 16, open_up)
    if r then config.state.chord_mode_index = r; persist.Save("chord_mode_index", r) end

    -- VEL toggle
    local vx = piano_key_left + scale_w + ctrl_gap + octave_w + ctrl_gap + chord_w + ctrl_gap
    local v_hover = gfx.mouse_x >= vx and gfx.mouse_x <= vx + vel_w and
                    gfx.mouse_y >= cy and gfx.mouse_y <= cy + ch
    helpers.SetColor(midi_store.GetUseVelocity() and theme.colors.btn_active or
                     (v_hover and theme.colors.btn_hover or theme.colors.bg))
    components.DrawRoundedRect(vx, cy, vel_w, ch, 6, true)
    helpers.SetColor(midi_store.GetUseVelocity() and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 16)
    local tw, th = gfx.measurestr("VEL")
    gfx.x, gfx.y = vx + (vel_w - tw) / 2, cy + (ch - th) / 2
    gfx.drawstr("VEL")
    if ui_store.GetMouseClick() and v_hover then midi_store.SetUseVelocity(not midi_store.GetUseVelocity()) end
end

-- =========================================================
-- UPDATE COMPACT VIEW (JS_Composite render)
-- =========================================================

function m.UpdateCompactView()
    if not compact_store.GetTransportHwnd() then compact_store.SetTransportHwnd(m.FindTransportWindow()) end
    if not compact_store.GetTransportHwnd() then return end

    lice.EnsureLICE()
    positioning.UpdatePositioning(config.state)

    -- Content width = left padding + all columns + gap to button + button + right margin
    local content_w = 6 + 16 + 34 + 16 + 24 + 4 + 12 + 5

    reaper.JS_LICE_Resize(compact_store.GetLiceBitmap(), positioning.GetCvW(), positioning.GetCvH())
    lice.DrawRoundedRectFill(compact_store.GetLiceBitmap(), 0, 0, content_w, positioning.GetCvH(), theme.colors.bar_bg, true, 8)
    compact_bar.CompactBar({cv_x=0, cv_y=0, cv_w=positioning.GetCvW(), cv_h=26, restore_btn_x=positioning.GetRestoreBtnX(), current_mode=ui_store.GetViewMode()})

    reaper.JS_Composite(compact_store.GetTransportHwnd(), positioning.GetCvX(), positioning.GetCvY(), content_w, positioning.GetCvH(), compact_store.GetLiceBitmap(), 0, 0, content_w, positioning.GetCvH(), true)
    reaper.JS_Window_InvalidateRect(compact_store.GetTransportHwnd(), positioning.GetCvX(), positioning.GetCvY(), positioning.GetCvX() + positioning.GetCvW(), positioning.GetCvY() + positioning.GetCvH(), false)
end

-- =========================================================
-- CLEANUP
-- =========================================================

function m.Cleanup()
    if panel.IsPanelOpen() then panel.ClosePanel() end
    -- Cache hwnd before it could go nil
    local hwnd = compact_store.GetTransportHwnd()
    compact_store.SetTransportHwnd(nil)

    -- Release intercepts and reset timestamps
    intercept.CleanupIntercept(hwnd)
    menu.ResetMenuDismissTime()

    -- Destroy LICE resources
    if compact_store.GetLiceBitmap() then reaper.JS_LICE_DestroyBitmap(compact_store.GetLiceBitmap()); compact_store.SetLiceBitmap(nil) end
    if compact_store.GetLiceFont() then reaper.JS_LICE_DestroyFont(compact_store.GetLiceFont()); compact_store.SetLiceFont(nil) end
    if compact_store.GetGdiFont() then reaper.JS_GDI_DeleteObject(compact_store.GetGdiFont()); compact_store.SetGdiFont(nil) end
end

return m
