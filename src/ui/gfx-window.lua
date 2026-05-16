-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: GFX Window Management
-- Handles MIDI island expand/collapse toggle, ShowIsland, and window sizing.
-- Extracted from core/midi.lua (PR: midi-island-critical-fixes).

local config = require("config")
local compact_store = require("state.compact")
local island_store = require("state.island")
local ui_store = require("state.ui")
local persist = require("state.persist")

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
    local dock = gfx.dock(-1)
    local gs = compact_store.GetLastGfxState()
    local hwnd = gfx.hwnd

    -- Save current window dimensions before gfx.quit()
    if gfx.w and gfx.w > 0 then ui_store.SetLastWindowW(gfx.w); persist.Save("window_w", gfx.w) end
    if gfx.h and gfx.h > 0 then ui_store.SetLastWindowH(gfx.h); persist.Save("window_h", gfx.h) end

    if hwnd then
        local l, t, r, b = reaper.JS_Window_GetRect(hwnd)
        gs.x, gs.y = l, t
        config.state.view_offset_x = l
        config.state.view_offset_y = t
        persist.Save("view_offset_x", l)
        persist.Save("view_offset_y", t)

        island_store.SetPreToggleDock(dock)
        island_store.SetPreToggleRect({x = l, y = t})
    end

    island_store.SetIslandTransitioning(true)
    local new_h = island_store.GetMidiIslandExpanded() and EXPANDED_H or COLLAPSED_H
    gfx.quit()
    gfx.init(config.script_title, ui_store.GetLastWindowW(), new_h, dock, config.state.view_offset_x, config.state.view_offset_y)
    gfx.setfont(1, "Calibri", 16)
    island_store.SetIslandTransitioning(false)
end

--- Show or hide the MIDI island (no-op if already in the requested state).
--- @param show boolean true = expand, false = collapse
function m.ShowIsland(show)
    if island_store.GetMidiIslandExpanded() == show then return end
    m.ToggleIsland()
end

return m
