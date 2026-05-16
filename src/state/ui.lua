-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: UI State Store
-- Encapsulates UI state with getters/setters.
-- Extracted from config.state.* for UI subsystem.
-- Keys: view_mode, mouse_click, mouse_wheel_delta, show_tooltips, color_mode,
--       last_mouse_cap, slider_dragging, pad_flash{}, docked_mode, dock_id,
--       auto_start_compact, auto_start_reaper, did_cleanup, use_scroll.
local ui_state = {
    view_mode = 1,  -- VIEW_MODES.FULL
    mouse_click = false,
    mouse_wheel_delta = 0,
    show_tooltips = false,
    color_mode = "grade",
    last_mouse_cap = 0,
    slider_dragging = false,
    pad_flash = { degree = -1, timer = 0, prev_active = {} },
    docked_mode = false,
    dock_id = 0,
    auto_start_compact = false,
    auto_start_reaper = false,
    auto_track_setup = true,
    did_cleanup = false,
    use_scroll = true,
    view_offset_x = 0,
    view_offset_y = 0,
    last_window_w = 720,
    last_window_h = 497,
    last_mouse_x = 0,
    last_mouse_y = 0,
    force_next_redraw = false,
}

local m = {}

function m.Init(defaults)
    if defaults.view_mode ~= nil then ui_state.view_mode = defaults.view_mode end
    if defaults.mouse_click ~= nil then ui_state.mouse_click = defaults.mouse_click end
    if defaults.mouse_wheel_delta ~= nil then ui_state.mouse_wheel_delta = defaults.mouse_wheel_delta end
    if defaults.show_tooltips ~= nil then ui_state.show_tooltips = defaults.show_tooltips end
    if defaults.color_mode ~= nil then ui_state.color_mode = defaults.color_mode end
    if defaults.last_mouse_cap ~= nil then ui_state.last_mouse_cap = defaults.last_mouse_cap end
    if defaults.slider_dragging ~= nil then ui_state.slider_dragging = defaults.slider_dragging end
    if defaults.pad_flash then
        for k, v in pairs(defaults.pad_flash) do
            if type(v) == "table" then
                for kk, vv in pairs(v) do ui_state.pad_flash[k][kk] = vv end
            else
                ui_state.pad_flash[k] = v
            end
        end
    end
    if defaults.docked_mode ~= nil then ui_state.docked_mode = defaults.docked_mode end
    if defaults.dock_id ~= nil then ui_state.dock_id = defaults.dock_id end
    if defaults.auto_start_compact ~= nil then ui_state.auto_start_compact = defaults.auto_start_compact end
    if defaults.auto_start_reaper ~= nil then ui_state.auto_start_reaper = defaults.auto_start_reaper end
    if defaults.auto_track_setup ~= nil then ui_state.auto_track_setup = defaults.auto_track_setup end
    if defaults.did_cleanup ~= nil then ui_state.did_cleanup = defaults.did_cleanup end
    if defaults.use_scroll ~= nil then ui_state.use_scroll = defaults.use_scroll end
    if defaults.view_offset_x ~= nil then ui_state.view_offset_x = defaults.view_offset_x end
    if defaults.view_offset_y ~= nil then ui_state.view_offset_y = defaults.view_offset_y end
    if defaults.last_window_w ~= nil then ui_state.last_window_w = defaults.last_window_w end
    if defaults.last_window_h ~= nil then ui_state.last_window_h = defaults.last_window_h end
end

-- Simple fields
function m.GetViewMode() return ui_state.view_mode end
function m.SetViewMode(v) ui_state.view_mode = v end

function m.GetMouseClick() return ui_state.mouse_click end
function m.SetMouseClick(v) ui_state.mouse_click = v end
-- ConsumeMouseClick: event bus pattern — returns current value and clears it
function m.ConsumeMouseClick()
    local v = ui_state.mouse_click
    ui_state.mouse_click = false
    return v
end

function m.GetMouseWheelDelta() return ui_state.mouse_wheel_delta end
function m.SetMouseWheelDelta(v) ui_state.mouse_wheel_delta = v end
-- ConsumeMouseWheelDelta: returns current value and zeros it
function m.ConsumeMouseWheelDelta()
    local v = ui_state.mouse_wheel_delta
    ui_state.mouse_wheel_delta = 0
    return v
end

function m.GetShowTooltips() return ui_state.show_tooltips end
function m.SetShowTooltips(v) ui_state.show_tooltips = v end

function m.GetColorMode() return ui_state.color_mode end
function m.SetColorMode(v) ui_state.color_mode = v end

function m.GetLastMouseCap() return ui_state.last_mouse_cap end
function m.SetLastMouseCap(v) ui_state.last_mouse_cap = v end

function m.GetSliderDragging() return ui_state.slider_dragging end
function m.SetSliderDragging(v) ui_state.slider_dragging = v end

-- pad_flash sub-table: degree, timer, prev_active{}
function m.GetPadFlashDegree() return ui_state.pad_flash.degree end
function m.SetPadFlashDegree(v) ui_state.pad_flash.degree = v end
function m.GetPadFlashTimer() return ui_state.pad_flash.timer end
function m.SetPadFlashTimer(v) ui_state.pad_flash.timer = v end
function m.GetPadFlashPrevActive() return ui_state.pad_flash.prev_active end
function m.ClearPadFlash()
    ui_state.pad_flash.degree = -1
    ui_state.pad_flash.timer = 0
end

function m.GetDockedMode() return ui_state.docked_mode end
function m.SetDockedMode(v) ui_state.docked_mode = v end

function m.GetDockId() return ui_state.dock_id end
function m.SetDockId(v) ui_state.dock_id = v end

function m.GetAutoStartCompact() return ui_state.auto_start_compact end
function m.SetAutoStartCompact(v) ui_state.auto_start_compact = v end

function m.GetAutoStartReaper() return ui_state.auto_start_reaper end
function m.SetAutoStartReaper(v) ui_state.auto_start_reaper = v end

function m.GetAutoTrackSetup() return ui_state.auto_track_setup end
function m.SetAutoTrackSetup(v) ui_state.auto_track_setup = v end

function m.GetDidCleanup() return ui_state.did_cleanup end
function m.SetDidCleanup(v) ui_state.did_cleanup = v end

function m.GetUseScroll() return ui_state.use_scroll end
function m.SetUseScroll(v) ui_state.use_scroll = v end

-- View offset (window positioning)
function m.GetViewOffsetX() return ui_state.view_offset_x end
function m.SetViewOffsetX(v) ui_state.view_offset_x = v end
function m.GetViewOffsetY() return ui_state.view_offset_y end
function m.SetViewOffsetY(v) ui_state.view_offset_y = v end

-- Last window dimensions (for ISLAND mode restoration)
function m.GetLastWindowW() return ui_state.last_window_w end
function m.SetLastWindowW(v) ui_state.last_window_w = v end
function m.GetLastWindowH() return ui_state.last_window_h end
function m.SetLastWindowH(v) ui_state.last_window_h = v end

function m.GetLastMouseX() return ui_state.last_mouse_x end
function m.SetLastMouseX(v) ui_state.last_mouse_x = v end

function m.GetLastMouseY() return ui_state.last_mouse_y end
function m.SetLastMouseY(v) ui_state.last_mouse_y = v end

function m.GetForceNextRedraw() return ui_state.force_next_redraw end
function m.SetForceNextRedraw(v) ui_state.force_next_redraw = v end

return m
