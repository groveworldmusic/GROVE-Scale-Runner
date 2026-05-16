-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Compact View Mouse Interception
-- WM_LBUTTONDOWN/WM_RBUTTONDOWN routing and zone hit-testing.
-- Exports ProcessMouseInterception (called from main.lua's MainLoop)
-- and CleanupIntercept (called from compact-init's Cleanup).
-- Uses lazy requires for compact-init, compact-menu, compact-panel
-- to avoid circular dependency at module load time.
local config = require("config")
local positioning = require("ui.positioning")
local compact_store = require("state.compact")

local m = {}

-- =========================================================
-- INTERCEPT STATE
-- =========================================================

local intercept_active_l = false  -- WM_LBUTTONDOWN registered (passthrough=true)
local intercept_active_r = false  -- WM_RBUTTONDOWN registered (passthrough=false)
local last_l_time = 0             -- last WM_LBUTTONDOWN timestamp
local last_r_time = 0             -- last WM_RBUTTONDOWN timestamp

-- =========================================================
-- ZONE HIT-TEST HELPER
-- =========================================================

-- Returns "restore", "content", or nil based on rel_x in bitmap-local coords.
-- rel_x = wx - cv_x (0 at bitmap left edge).
local function GetCompactZone(rel_x)
    local restore_btn = positioning.GetRestoreBtnX()
    local restore_right = restore_btn + 12 + 5
    if rel_x >= restore_btn and rel_x < restore_right then
        return "restore"
    elseif rel_x >= 0 and rel_x < restore_btn then
        return "content"
    end
    return nil
end

-- =========================================================
-- PROCESS MOUSE INTERCEPTION
-- =========================================================

function m.ProcessMouseInterception()
    if not compact_store.GetTransportHwnd() then
        -- Lazy require to avoid circular load-time dependency
        local compact_init = require("ui.compact-init")
        compact_store.SetTransportHwnd(compact_init.FindTransportWindow())
    end
    if not compact_store.GetTransportHwnd() then return end

    local hwnd = compact_store.GetTransportHwnd()
    local mx, my = reaper.GetMousePosition()
    local wx, wy = reaper.JS_Window_ScreenToClient(hwnd, mx, my)
    local is_on_bar = wx >= positioning.GetCvX() and wx <= positioning.GetCvX() + positioning.GetCvW() and wy >= positioning.GetCvY() and wy <= positioning.GetCvY() + positioning.GetCvH()

    -- Left-click intercept (always active, passthrough=true — transport still works)
    if not intercept_active_l then
        reaper.JS_WindowMessage_Intercept(hwnd, "WM_LBUTTONDOWN", true)
        intercept_active_l = true
    end

    -- Post-menu guard: compute early so both intercept setup and processing use it
    local now = reaper.time_precise()
    local compact_menu = require("ui.compact-menu")
    local post_menu = (now - compact_menu.GetMenuDismissTime()) < 0.2

    -- Right-click intercept (dynamic, passthrough=false — transport does NOT get the click)
    -- Issue B4: do NOT intercept right-click during post-menu guard window (200ms after menu dismissal)
    -- so the native transport context menu works when the user clicks rapidly after menu dismiss.
    if is_on_bar and not intercept_active_r and not post_menu then
        reaper.JS_WindowMessage_Intercept(hwnd, "WM_RBUTTONDOWN", false)
        intercept_active_r = true
    elseif (not is_on_bar or post_menu) and intercept_active_r then
        reaper.JS_WindowMessage_Release(hwnd, "WM_RBUTTONDOWN")
        intercept_active_r = false
    end

    -- Process left-click
    local l_peak, _, l_time = reaper.JS_WindowMessage_Peek(hwnd, "WM_LBUTTONDOWN")
    if l_peak and l_time and l_time > 0 and l_time ~= last_l_time then
        last_l_time = l_time
        if is_on_bar then
            local rel_x = wx - positioning.GetCvX()
            local zone = GetCompactZone(rel_x)
            if zone == "restore" then
                local compact_init = require("ui.compact-init")
                compact_init.SwitchViewMode()
            elseif zone == "content" and not post_menu then
                local compact_panel = require("ui.compact-panel")
                compact_panel.TogglePanel()
            end
        end
    end

    -- Process right-click (only if intercept is active, avoids stale/crossed peeks)
    if intercept_active_r then
        local r_peak, _, r_time = reaper.JS_WindowMessage_Peek(hwnd, "WM_RBUTTONDOWN")
        if r_peak and r_time and r_time > 0 and r_time ~= last_r_time then
            last_r_time = r_time
            if is_on_bar then
                local rel_x = wx - positioning.GetCvX()
                local zone = GetCompactZone(rel_x)
                if zone == "restore" then
                    local compact_init = require("ui.compact-init")
                    compact_init.SwitchViewMode()
                elseif zone == "content" and not post_menu then
                    -- Release right-click intercept BEFORE showing the menu
                    if intercept_active_r then
                        reaper.JS_WindowMessage_Release(hwnd, "WM_RBUTTONDOWN")
                        intercept_active_r = false
                    end
                    compact_menu.ShowContextMenu()
                else
                    -- Passthrough zone: right-click outside restore/content → release intercept
                    -- so REAPER handles the right-click natively (transport context menu).
                    if intercept_active_r then
                        reaper.JS_WindowMessage_Release(hwnd, "WM_RBUTTONDOWN")
                        intercept_active_r = false
                    end
                end
            end
        end
    end
end

-- =========================================================
-- CLEANUP (exported for compact-init)
-- =========================================================

function m.CleanupIntercept(hwnd)
    -- Release left-click intercept + unlink composite
    if intercept_active_l then
        if hwnd then
            reaper.JS_WindowMessage_Release(hwnd, "WM_LBUTTONDOWN")
            reaper.JS_Composite_Unlink(hwnd, compact_store.GetLiceBitmap())
        end
        intercept_active_l = false
    end

    -- Release right-click intercept
    if intercept_active_r then
        if hwnd then
            reaper.JS_WindowMessage_Release(hwnd, "WM_RBUTTONDOWN")
        end
        intercept_active_r = false
    end

    -- Reset click timestamps
    last_l_time = 0
    last_r_time = 0
end

return m
