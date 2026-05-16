-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Compact view positioning and layout math
-- Dependencies: config, state.compact (transport_hwnd via compact_store)
local config = require("config")
local compact_store = require("state.compact")
local ui_store = require("state.ui")
local api_guard = require("core.api-guard")

local m = {}

-- =========================================================
-- LOCAL STATE
-- =========================================================

local cv_x, cv_y, cv_w, cv_h = 0, 0, 0, 26
local restore_btn_x = 0
local cv_auto_x = nil
local use_auto_pos = true
local last_transport_w = nil

-- =========================================================
-- CONSTANTS
-- =========================================================

local BAR_H = 26
local CV_W = 156
local PANEL_PW = 304
local PANEL_PH = 171
local PANEL_PIANO_H = 128
local PANEL_PAD = 5
local FLOAT_GAP = 42

-- =========================================================
-- CV GETTERS
-- =========================================================

function m.GetCvX() return cv_x end
function m.GetCvY() return cv_y end
function m.GetCvW() return cv_w end
function m.GetCvH() return cv_h end

-- =========================================================
-- RESTORE BUTTON X
-- =========================================================

function m.GetRestoreBtnX() return restore_btn_x end
function m.SetRestoreBtnX(val) restore_btn_x = val end

-- =========================================================
-- AREA / PANEL HELPERS
-- =========================================================

-- Width of the visible composite content area
function m.GetMainAreaWidth()
    -- 6 (left padding) + 16 (key) + 34 (scale) + 16 (octave) + 24 (chord)
    -- + 4 (gap to restore btn) + 12 (restore btn) + 5 (right margin)
    return 117
end

-- Panel dimensions
function m.GetPanelArea()
    return {
        pw = PANEL_PW,
        ph = PANEL_PH,
        piano_h = PANEL_PIANO_H,
        controls_y = PANEL_PIANO_H + 10,
        pad = PANEL_PAD,
        float_gap = FLOAT_GAP,
    }
end

-- =========================================================
-- AUTO-POSITION STATE
-- =========================================================

function m.ResetAutoPosition()
    cv_auto_x = nil
    use_auto_pos = true
end

function m.DisableAutoPosition()
    use_auto_pos = false
    cv_auto_x = nil
end

-- =========================================================
-- FIND EMPTY AREA ON TRANSPORT WINDOW
-- =========================================================

local function FindTransportEmptyArea()
    local hwnd = compact_store.GetTransportHwnd()
    if not hwnd then return nil end
    if not api_guard.CheckAPI("JS_Window_GetClientSize") then return nil end
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
-- UPDATE POSITIONING
-- =========================================================

-- Recalculate cv_x, cv_y, cv_w, cv_h from config.state
-- state: config.state (passed as parameter to avoid require cycle)
function m.UpdatePositioning(state)
    local transport_hwnd = compact_store.GetTransportHwnd()
    if not transport_hwnd then return end

    cv_w, cv_h = CV_W, BAR_H

    local _, w_trans, h_trans = reaper.JS_Window_GetClientSize(transport_hwnd)

    -- Invalidate auto-position cache if transport window resized (Issue 10)
    if cv_auto_x ~= nil and last_transport_w and w_trans and w_trans ~= last_transport_w then
        cv_auto_x = nil
    end
    if w_trans then last_transport_w = w_trans end

    if ui_store.GetViewOffsetX() > 0 then
        cv_x = ui_store.GetViewOffsetX()
    elseif use_auto_pos then
        if cv_auto_x == nil then cv_auto_x = FindTransportEmptyArea() end
        cv_x = cv_auto_x or 5
    else
        cv_x = 5
    end

    if h_trans and h_trans > 0 then
        cv_y = math.floor((h_trans - BAR_H) / 2) + 2 + ui_store.GetViewOffsetY()
    else
        cv_y = 4
    end
end

-- =========================================================
-- TRANSPORT SCREEN RECT
-- =========================================================

-- Returns the compact bar's screen rect for panel positioning.
function m.GetTransportScreenRect()
    local hwnd = compact_store.GetTransportHwnd()
    if not hwnd then return nil end
    if not api_guard.CheckAPI("JS_Window_GetClientSize") then return nil end
    local _, w_trans, h_trans = reaper.JS_Window_GetClientSize(hwnd)
    if not w_trans then return nil end
    if not api_guard.CheckAPI("JS_Window_GetRect") then return nil end
    local _, win_left, win_top, win_right, win_bottom = reaper.JS_Window_GetRect(hwnd)

    -- Get client area origin in screen coordinates
    local client_screen_x, client_screen_y = reaper.JS_Window_ClientToScreen(hwnd, 0, 0)
    if not client_screen_x then
        client_screen_x = win_left or 0
        client_screen_y = win_top or 0
    end

    -- Compact bar screen position
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

return m
