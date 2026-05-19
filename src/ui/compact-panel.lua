-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Compact View Floating Panel
-- Floating GFX window with piano keyboard, scale/octave/chord dropdowns, VEL toggle
-- TogglePanel is called from compact-intercept on left-click on bar "content" zone.
-- ClosePanel/IsPanelOpen are called from compact-init life-cycle.
local config = require("config")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local lice = require("ui.lice")
local positioning = require("ui.positioning")

local m = {}

-- =========================================================
-- CONSTANTS
-- =========================================================

m.BAR_H = 26
m.PANEL_PW = 304  -- 294 + PANEL_PAD*2, piano divisible por 7
m.PANEL_PH = 171
m.PANEL_PIANO_H = 128
m.PANEL_CONTROLS_Y = m.PANEL_PIANO_H + 10  -- 138
m.PANEL_PAD = 5
m.FLOAT_GAP = 42

-- Cached dropdown options (shared with the panel)
m.SCALE_OPTIONS = (function()
    local t = {}
    for i, s in ipairs(config.SCALES) do t[i] = helpers.CompactAbbreviateScale(s.name) end
    return t
end)()
m.SCALE_FULL = (function() local t={}; for _, s in ipairs(config.SCALES) do t[#t+1]=s.name end return t end)()
m.OCTAVE_OPTIONS = (function()
    local t = {}
    for i = 0, 8 do t[i + 1] = "C" .. i end
    return t
end)()
m.CHORD_OPTIONS = (function()
    local t = {}
    for i, m in ipairs(config.CHORD_MODES) do t[i] = m.name end
    return t
end)()

-- =========================================================
-- PANEL STATE
-- =========================================================

m.panel_state = {
    open = false,
    inited = false,
    init_x = 0,
    init_y = 0,
    opened_bar_y = 0,
    last_mouse_cap = 0,
    hwnd = nil,
    first_frame = true,
    open_up = false,
}

-- =========================================================
-- INTERNAL
-- =========================================================

local function ClosePanel()
    if m.panel_state.inited then gfx.quit(); m.panel_state.inited = false end
    m.panel_state.open = false; m.panel_state.hwnd = nil
    m.panel_state.first_frame = true  -- Issue A5: defense-in-depth, stale click guard active on next open
end

-- =========================================================
-- TogglePanel
-- =========================================================

function m.TogglePanel()
    if m.panel_state.open then ClosePanel()
    else
        local rect = positioning.GetTransportScreenRect()
        if not rect then return end
        -- Centrar en el contenido visible de la vista compacta
        m.panel_state.init_x = math.floor(rect.bar_center_x - m.PANEL_PW / 2 - 26)

        -- Determinar si hay espacio arriba de la barra de transporte en pantalla
        local enough_above = rect.bar_screen_y >= m.PANEL_PH + m.FLOAT_GAP

        if enough_above then
            -- Panel flota arriba de la barra
            m.panel_state.init_y = math.floor(rect.bar_screen_y - m.PANEL_PH - m.FLOAT_GAP)
        else
            -- Panel debajo de la barra
            local TITLE_BAR_H = 31
            local BELOW_OFFSET = 38
            m.panel_state.init_y = math.floor(rect.bar_screen_y + m.BAR_H + m.FLOAT_GAP - BELOW_OFFSET)
        end
        m.panel_state.open_up = enough_above

        -- Guardar posición de barra para auto-reposición
        m.panel_state.opened_bar_y = rect.bar_screen_y

        if m.panel_state.init_x + m.PANEL_PW > rect.right then m.panel_state.init_x = rect.right - m.PANEL_PW - 10 end
        if m.panel_state.init_x < 0 then m.panel_state.init_x = 10 end
        m.panel_state.open = true
        m.panel_state.inited = false
        m.panel_state.hwnd = nil
        m.panel_state.first_frame = true
    end
end

-- =========================================================
-- EXPORTED HELPERS
-- =========================================================

function m.IsPanelOpen() return m.panel_state.open end
function m.ClosePanel() ClosePanel() end

return m
