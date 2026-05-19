-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Views — BARREL
-- Re-exports view submodules: header, islands, performance, docked.
-- Extracted into submodules (Sprint 2).

local theme = require("ui.theme")
local helpers = require("ui.helpers")
local layout = require("ui.layout")
local midi_island = require("ui.midi-island")

-- View submodules
local header = require("ui.views.header")
local islands = require("ui.views.islands")
local performance = require("ui.views.performance")
local docked = require("ui.views.docked")

local m = {}

-- =========================================================
-- Re-export header.lua
-- =========================================================

m.DrawHeader = header.DrawHeader

-- =========================================================
-- Re-export islands.lua
-- =========================================================

m.DrawIslands = islands.DrawIslands

-- =========================================================
-- Re-export performance.lua
-- =========================================================

m.DrawPerformanceArea = performance.DrawPerformanceArea
m.DecrementPageOverrideTimer = performance.DecrementPageOverrideTimer

-- =========================================================
-- Re-export docked.lua
-- =========================================================

m.DrawDockedTransportBar = docked.DrawDockedTransportBar

-- =========================================================
-- Orchestrator: DrawFullView
-- =========================================================

function m.DrawFullView(char)
    -- Scale es CONSTANTE: se calcula contra la altura BASE de diseño (500px)
    -- para que el contenido NO se deforme al expandir/colapsar la MIDI island.
    -- Expandir solo agrega canvas abajo para la isla, no cambia el zoom.
    local s = math.min(gfx.w / 39914, 500 / 29162) * 1.025
    local ox = (gfx.w - 39914 * s) / 2
    local oy = 600 * s - 10
    layout.SetScale(s, ox, oy)
    helpers.SetColor(theme.colors.bg)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)
    m.DrawHeader()
    m.DrawIslands()
    m.DrawPerformanceArea()
    return m.DrawMIDIIsland(char)  -- returns esc_consumed for remap modal
end

-- =========================================================
-- MIDI Island (delegates to midi-island orchestrator)
-- =========================================================

function m.DrawMIDIIsland(char)
    return midi_island.Draw(char)  -- returns esc_consumed for remap modal
end

return m
