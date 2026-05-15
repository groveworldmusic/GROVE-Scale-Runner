-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Views — BARREL
-- Re-exports view submodules: header, islands, performance, docked.
-- Extracted into submodules (Sprint 2).

local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local layout = require("ui.layout")
local midi_island = require("ui.midi-island")
local drag_store = require("state.drag")
local ui_store = require("state.ui")
local island_store = require("state.island")

-- View submodules
local header = require("ui.views.header")
local islands = require("ui.views.islands")
local performance = require("ui.views.performance")
local docked = require("ui.views.docked")

local piano_roll = require("ui.piano-roll")
local velocity = require("ui.velocity")

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
    m.DrawMIDIIsland(char)
end

-- =========================================================
-- MIDI Island (delegates to midi-island orchestrator)
-- =========================================================

function m.DrawMIDIIsland(char)
    midi_island.Draw(char)
end

-- =========================================================
-- Keyboard Shortcut Overlay (preserved for backward compat)
-- =========================================================

--- Draw keyboard shortcut overlay.
--- Uses `char` passed from MainLoop via DrawFullView.
--- Single gfx.getchar() per frame — avoids double-read crash (regression PR3).
-- Ctrl+Z/Y/X/C/V, Delete, arrows, Shift+arrows.
-- Unhandled keys fall through to REAPER.
-- Escape: Cancel note drag/resize (PR2).
function m.DrawKeyboardShortcutOverlay(char, tool_mode)
    local keyboard_consumed = false

    -- Handle Escape for cancel drag first (always active)
    if char == 27 and island_store.GetNoteDragActive() then
        piano_roll.CancelNoteDrag()
        keyboard_consumed = true
    end

    -- Handle piano roll keyboard shortcuts (pointer/eraser mode)
    if not keyboard_consumed and (tool_mode == "pointer" or tool_mode == "eraser") then
        local scroll_beat = island_store.GetScrollOffsetX()
        keyboard_consumed = piano_roll.HandleKeyboardShortcut(char, scroll_beat)
    end
end

-- =========================================================
-- Snap Controls (preserved for backward compat)
-- =========================================================

function m.DrawSnapControls(presets_x, b_w, b_h, header_y)
    -- Snap Controls (PR2) — right of PRESETS
    local snap_toggle_w = math.floor(b_w * 0.65)
    local snap_res_w = math.floor(b_w * 0.50)
    local snap_trip_w = math.floor(b_w * 0.35)
    local snap_gap = 4
    local snap_x = presets_x + b_w + 8  -- right of PRESETS
    local snap_enabled = island_store.GetSnapEnabled()
    local snap_res = island_store.GetSnapResolution()
    local snap_trip = island_store.GetSnapTriplet()

    -- Snap toggle button
    local st_hover = gfx.mouse_x >= snap_x and gfx.mouse_x <= snap_x + snap_toggle_w
                  and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    local st_bg = snap_enabled and theme.colors.btn_active or (st_hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(st_bg)
    components.DrawRoundedRect(snap_x, header_y, snap_toggle_w, b_h, 10, true)
    helpers.SetColor(snap_enabled and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1300))
    local snap_label = snap_enabled and "SNAP" or "SNP-"
    local slw, slh = gfx.measurestr(snap_label)
    gfx.x, gfx.y = snap_x + (snap_toggle_w - slw) / 2, header_y + (b_h - slh) / 2
    gfx.drawstr(snap_label)
    if ui_store.GetMouseClick() and st_hover and not drag_store.GetIsDragging() then
        island_store.SetSnapEnabled(not snap_enabled)
    end
    if st_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip(snap_enabled and "Snap: ON" or "Snap: OFF", layout.US(700))
    end

    -- Snap resolution button (click to open menu)
    local sr_x = snap_x + snap_toggle_w + snap_gap
    local sr_hover = gfx.mouse_x >= sr_x and gfx.mouse_x <= sr_x + snap_res_w
                 and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    helpers.SetColor(sr_hover and theme.colors.btn_hover or theme.colors.island_bg)
    components.DrawRoundedRect(sr_x, header_y, snap_res_w, b_h, 10, true)
    helpers.SetColor(snap_enabled and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1300))
    -- Resolution label: 1=1/1, 2=1/2, 4=1/4, 8=1/8, 16=1/16, 32=1/32
    local snap_res_label = "1/" .. tostring(snap_res)
    if snap_res <= 0 then snap_res_label = "OFF" end
    local rlw, rlh = gfx.measurestr(snap_res_label)
    gfx.x, gfx.y = sr_x + (snap_res_w - rlw) / 2, header_y + (b_h - rlh) / 2
    gfx.drawstr(snap_res_label)
    if ui_store.GetMouseClick() and sr_hover and not drag_store.GetIsDragging() then
        local res_menu = "1/1|1/2|1/4|1/8|1/16|1/32"
        gfx.x, gfx.y = sr_x, header_y + b_h
        local choice = gfx.showmenu(res_menu)
        if choice and choice > 0 then
            local res_values = {1, 2, 4, 8, 16, 32}
            island_store.SetSnapResolution(res_values[choice])
            if not island_store.GetSnapEnabled() then
                island_store.SetSnapEnabled(true)
            end
        end
    end
    if sr_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip("Snap resolution: " .. snap_res_label, layout.US(700))
    end

    -- Triplet toggle button
    local stp_x = sr_x + snap_res_w + snap_gap
    local stp_hover = gfx.mouse_x >= stp_x and gfx.mouse_x <= stp_x + snap_trip_w
                  and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
    local stp_bg = snap_trip and theme.colors.btn_active or (stp_hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(stp_bg)
    components.DrawRoundedRect(stp_x, header_y, snap_trip_w, b_h, 10, true)
    helpers.SetColor(snap_trip and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", layout.US(1300))
    local trip_label = snap_trip and "3" or "·"
    local tlw2, tlh2 = gfx.measurestr(trip_label)
    gfx.x, gfx.y = stp_x + (snap_trip_w - tlw2) / 2, header_y + (b_h - tlh2) / 2
    gfx.drawstr(trip_label)
    if ui_store.GetMouseClick() and stp_hover and not drag_store.GetIsDragging() then
        island_store.SetSnapTriplet(not snap_trip)
    end
    if stp_hover and not drag_store.GetIsDragging() then
        helpers.DrawTooltip(snap_trip and "Triplet: ON" or "Triplet: OFF", layout.US(700))
    end
end

-- =========================================================
-- Tool Mode Row (preserved for backward compat)
-- =========================================================

function m.DrawToolModeRow(ch_x, b_w, b_h, header_y)
    -- Tool mode buttons (Phase 4) — left of CH
    local tool_btn_w = math.floor(b_w * 0.55)
    local tool_btn_gap = 4
    local tools_total_w = tool_btn_w * 3 + tool_btn_gap * 2
    local tool_x = ch_x - tools_total_w - 8
    local tool_labels = {"→", "✎", "✕"}
    local tool_hints = {"Pointer (select)", "Pencil (draw notes)", "Eraser (delete notes)"}
    local cur_tool = island_store.GetToolMode()
    local tool_modes = {"pointer", "pencil", "eraser"}

    for ti = 1, 3 do
        local t_active = cur_tool == tool_modes[ti]
        local tx = tool_x + (ti - 1) * (tool_btn_w + tool_btn_gap)
        local t_hover = gfx.mouse_x >= tx and gfx.mouse_x <= tx + tool_btn_w and gfx.mouse_y >= header_y and gfx.mouse_y <= header_y + b_h
        local t_bg = t_active and theme.colors.btn_active or (t_hover and theme.colors.btn_hover or theme.colors.island_bg)
        helpers.SetColor(t_bg)
        components.DrawRoundedRect(tx, header_y, tool_btn_w, b_h, 10, true)

        -- Icon/label
        helpers.SetColor(t_active and theme.colors.text or theme.colors.text_dim)
        gfx.setfont(1, "Calibri", layout.US(1500))
        local tlw, tlh = gfx.measurestr(tool_labels[ti])
        gfx.x, gfx.y = tx + (tool_btn_w - tlw) / 2, header_y + (b_h - tlh) / 2
        gfx.drawstr(tool_labels[ti])

        -- Click handler
        if ui_store.GetMouseClick() and t_hover and not drag_store.GetIsDragging() then
            island_store.SetToolMode(tool_modes[ti])
            velocity.ResetDrag()
        end

        -- Tooltip
        if t_hover and not drag_store.GetIsDragging() then
            helpers.DrawTooltip(tool_hints[ti], layout.US(700))
        end
    end
end

return m
