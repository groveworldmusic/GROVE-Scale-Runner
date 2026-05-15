-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Compact View Context Menu
-- Right-click context menu with scale/octave/chord selection, tools, and position adjustment.
-- Uses lazy requires for compact-init and compact-panel to avoid circular load-time deps.
local config = require("config")
local ui_store = require("state.ui")
local components = require("ui.components")
local midi = require("core.midi")
local persist = require("state.persist")
local prefs = require("state.preferences")

local m = {}

-- =========================================================
-- MENU STATE
-- =========================================================

local menu_dismiss_time = 0  -- reaper.time_precise() when the context menu was last dismissed

function m.GetMenuDismissTime() return menu_dismiss_time end
function m.SetMenuDismissTime(val) menu_dismiss_time = val end
function m.ResetMenuDismissTime() menu_dismiss_time = 0 end

-- =========================================================
-- ShowContextMenu
-- =========================================================

function m.ShowContextMenu()
    local is_full = ui_store.GetViewMode() == config.VIEW_MODES.FULL

    -- CRITICAL: Only create a temp GFX window in compact mode (no GFX context exists).
    -- In full/overlay mode, the full view's GFX is already open — creating a temp
    -- window with gfx.init would DESTROY the full view's GFX context (per REAPER API).
    if is_full then
        gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
    else
        gfx.init("", 0, 0)
        local mx, my = reaper.GetMousePosition()
        gfx.x, gfx.y = gfx.screentoclient(mx, my)
    end

    local menu = "#Scale Runner|"
    menu = menu .. (is_full and "Cambiar a Vista Compacta" or "Cambiar a Vista Completa") .. "|"
    menu = menu .. ">Tonalidad|"
    for i, n in ipairs(config.NOTE_NAMES) do menu = menu .. (prefs.GetRootIndex() == i and "!" or "") .. n .. "|" end
    menu = menu .. "<|>Escala|"
    for i, s in ipairs(config.SCALES) do menu = menu .. (prefs.GetScaleIndex() == i and "!" or "") .. s.name .. "|" end
    menu = menu .. "<|>Octava|"
    for i=0, 8 do menu = menu .. (prefs.GetOctave() == i and "!" or "") .. "C" .. i .. "|" end
    menu = menu .. "<|>Acorde|"
    for i, mo in ipairs(config.CHORD_MODES) do menu = menu .. (prefs.GetChordModeIndex() == i and "!" or "") .. mo.name .. "|" end
    menu = menu .. "<|>Herramientas|"
    menu = menu .. "Exportar Progresion MIDI|Panic (Notas Off)||"
    menu = menu .. ">Posicion|Ajustar Offset X/Y...|Resetear Verticalmente|<"

    local ret = gfx.showmenu(menu)

    -- Only quit temp window (never destroy the full view's GFX context)
    if not is_full then gfx.quit() end

    -- Record timestamp so the next left-click doesn't also toggle the panel
    menu_dismiss_time = reaper.time_precise()

    local OFFSET_TONE = 2
    local OFFSET_SCALE = OFFSET_TONE + #config.NOTE_NAMES
    local OFFSET_OCT = OFFSET_SCALE + #config.SCALES
    local OFFSET_CHORD = OFFSET_OCT + 9
    local OFFSET_TOOLS = OFFSET_CHORD + #config.CHORD_MODES

    if ret == 1 then
        -- Toggle view mode (ClosePanel + SwitchViewMode)
        local compact_panel = require("ui.compact-panel")
        if compact_panel.IsPanelOpen() then compact_panel.ClosePanel() end
        local compact_init = require("ui.compact-init")
        compact_init.SwitchViewMode()
    elseif ret >= OFFSET_TONE and ret < OFFSET_SCALE then
        config.state.root_index = ret - OFFSET_TONE + 1
        persist.Save("root_index", config.state.root_index)
    elseif ret >= OFFSET_SCALE and ret < OFFSET_OCT then
        config.state.scale_index = ret - OFFSET_SCALE + 1
        persist.Save("scale_index", config.state.scale_index)
    elseif ret >= OFFSET_OCT and ret < OFFSET_CHORD then
        config.state.octave = math.floor(ret - OFFSET_OCT)
        persist.Save("octave", config.state.octave)
    elseif ret >= OFFSET_CHORD and ret < OFFSET_TOOLS then
        config.state.chord_mode_index = ret - OFFSET_CHORD + 1
        persist.Save("chord_mode_index", config.state.chord_mode_index)
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
            if nx_num > 0 then
                local compact_init = require("ui.compact-init")
                compact_init.SetManualPosition(nx_num, ny_num)
            else
                local compact_init = require("ui.compact-init")
                compact_init.ResetAutoPosition()
                config.state.view_offset_y = ny_num
            end
        end
    elseif ret == OFFSET_TOOLS + 4 then
        config.state.view_offset_y = 0
        local compact_init = require("ui.compact-init")
        compact_init.ResetAutoPosition()
    end
end

return m
