-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: GFX Window Management
-- Handles MIDI island expand/collapse toggle, ShowIsland, and window sizing.
-- Extracted from core/midi.lua (PR: midi-island-critical-fixes).

local config = require("config")
local api_guard = require("core.api-guard")
local compact_store = require("state.compact")
local island_store = require("state.island")
local ui_store = require("state.ui")
local persist = require("state.persist")

-- Soft-check: JS_Window_GetLong/SetLong may not exist in older versions.
-- JS_Window_GetRoot is NOT required — gfx.hwnd targets the window directly.
-- If missing, falls back to MainLoop debounced gfx.quit()+gfx.init().
local HAS_WS_SIZEBOX_TOGGLE = api_guard.CheckAPI("JS_Window_GetLong")
    and api_guard.CheckAPI("JS_Window_SetLong")

local COLLAPSED_H = 497
local EXPANDED_H = 793

local m = {}

--- Toggle the MIDI island expanded/collapsed state.
--- Resizes window via gfx.quit()+gfx.init(). Docked mode is not supported.
--- Saves pre-toggle state to island_store for resilience (PR1b).
function m.ToggleIsland()
    if ui_store.GetDockedMode() then return end
    local expanded = island_store.GetMidiIslandExpanded()
    island_store.SetMidiIslandExpanded(not expanded)
    island_store.SetMidiIslandToggled(true)
    local gs = compact_store.GetLastGfxState()
    local hwnd = gfx.hwnd

    if hwnd then
        -- JS_Window_GetRect returns (bool, left, top, right, bottom) — discard bool with _
        local _, l, t, r, b = reaper.JS_Window_GetRect(hwnd)
        gs.x, gs.y = l, t
        ui_store.SetViewOffsetX(l)
        ui_store.SetViewOffsetY(t)
        persist.Save("view_offset_x", l)
        persist.Save("view_offset_y", t)

        island_store.SetPreToggleDock(gfx.dock(-1) & 1)  -- mask to bit 0; bits 8-15 encode docker index
        island_store.SetPreToggleRect({x = l, y = t})
    end

    island_store.SetIslandTransitioning(true)
    local new_h = island_store.GetMidiIslandExpanded() and EXPANDED_H or COLLAPSED_H
    gfx.quit()
    local uid = config.script_title .. reaper.time_precise()
    gfx.init(uid, 720, new_h, 0, ui_store.GetViewOffsetX(), ui_store.GetViewOffsetY())
    gfx.setfont(1, "Calibri", 16)
    if reaper.JS_Window_SetTitle then
        reaper.JS_Window_SetTitle(gfx.hwnd, config.script_title)
    end

    -- Toggle WS_SIZEBOX resize border based on island state.
    -- Uses JS_Window_GetLong/SetLong on gfx.hwnd directly (no GetRoot needed).
    -- WS_SIZEBOX = 0x40000 enables resizable border.
    -- Guarded by HAS_WS_SIZEBOX_TOGGLE — graceful degradation if APIs not available.
    if HAS_WS_SIZEBOX_TOGGLE then
        local new_hwnd = gfx.hwnd
        if new_hwnd then
            local style = reaper.JS_Window_GetLong(new_hwnd, "STYLE")
            if island_store.GetMidiIslandExpanded() then
                reaper.JS_Window_SetLong(new_hwnd, "STYLE", style & ~0x40000)
            else
                reaper.JS_Window_SetLong(new_hwnd, "STYLE", style | 0x40000)
            end
        end
    end

    island_store.SetIslandTransitioning(false)
end

--- Show or hide the MIDI island (no-op if already in the requested state).
--- @param show boolean true = expand, false = collapse
function m.ShowIsland(show)
    if island_store.GetMidiIslandExpanded() == show then return end
    m.ToggleIsland()
end

return m
