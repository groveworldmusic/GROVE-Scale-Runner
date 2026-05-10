-- @description Scale Runner — QWERTY to MIDI Controller for REAPER
-- @version 1.0.0
-- @author GROVE WORLD MUSIC
-- @about
--   Scale Runner: QWERTY to MIDI Controller
--   Multi-module architecture with REAPER integration.
--   Maps keyboard keys to scale degrees and chord modes.
--   Includes sequencer, piano keyboard, performance pads,
--   progression slots, docked transport bar, and compact mode via JS_Composite.
-- @provides
--   [main] src/main.lua
--   src/config.lua
--   src/core/midi.lua
--   src/core/sequencer.lua
--   src/core/progression.lua
--   src/ui/theme.lua
--   src/ui/helpers.lua
--   src/ui/components.lua
--   src/ui/views.lua
--   src/ui/compact.lua
--   src/ui/colors.lua
--   src/ui/format.lua
--   src/ui/buttons.lua
--   src/ui/paginator.lua
--   src/ui/dropdown.lua
-- @website https://github.com/GroveWorldMusic/GROVE-Scale-Runner

local info = debug.getinfo(1, 'S')
local script_path = info.source:match([[^@?(.*[\/])[^\/]-$]])
if not script_path then
    reaper.MB("Could not determine script path.", "Error", 0)
    return
end
package.path = package.path .. ";" .. script_path .. "?.lua"

local config = require("config")
local theme = require("ui.theme")
local midi = require("core.midi")
local sequencer = require("core.sequencer")
local views = require("ui.views")
local compact = require("ui.compact")
local keyboard = require("core.keyboard")

local last_dock_state = 0

-- Toggle dock state (Ctrl+D)
local function ToggleDock()
    if config.state.docked_mode then
        -- Undock: call gfx.dock(0) to float
        gfx.dock(0)
        config.state.docked_mode = false
        config.state.dock_id = 0
        -- Resize back to normal window
        gfx.init("GROVE SCALE RUNNER", 720, 497, 0, config.state.view_offset_x, config.state.view_offset_y)
    else
        -- Dock: call gfx.dock(1) to dock in transport bar slot
        config.state.dock_id = gfx.dock(1)
        if config.state.dock_id > 0 then
            config.state.docked_mode = true
        else
            config.state.dock_id = 0
        end
    end
end

-- Toggle view mode (Ctrl+Shift+C) - called from HandleKeyboard
local function ToggleViewMode()
    compact.SwitchViewMode()
end

-- Check dock state changes (polling via gfx.dock(-1))
local function CheckDockState()
    local current_dock = gfx.dock(-1)
    if current_dock ~= last_dock_state then
        last_dock_state = current_dock
        if current_dock > 0 then
            config.state.docked_mode = true
            config.state.dock_id = current_dock
        else
            config.state.docked_mode = false
            config.state.dock_id = 0
        end
    end
end



local function CleanupAll()
    midi.AllNotesOff()
    sequencer.Stop()
    keyboard.Cleanup()
    compact.Cleanup()
end

local function MainLoop()
    -- Decrement note display timer
    if config.state.active_note_draw_timer > 0 then
        config.state.active_note_draw_timer = config.state.active_note_draw_timer - 1
    end

    -- Decrement page override timer in ALL modes (Issue 8)
    views.DecrementPageOverrideTimer()
    
    -- Shared logic for ALL modes
    keyboard.CheckFocus()
    sequencer.Run()
    keyboard.HandleKeyboard()

    -- Compact mode (no GFX window)
    if config.state.view_mode == config.VIEW_MODES.COMPACT then
        compact.ProcessMouseInterception()
        compact.UpdateCompactView()
        compact.HandlePanel()
        reaper.defer(MainLoop)
        return
    end

    -- Overlay mode: compact bar visible alongside full view (auto-start)
    if config.state.compact_overlay_active then
        compact.ProcessMouseInterception()
        compact.UpdateCompactView()
        -- Si TogglePanel se disparó (clic en la barra → panel_open = true),
        -- no podemos dibujar el panel sin conflicto de GFX. Transicionamos a
        -- compacto completo: gfx.quit() cierra la full view, luego HandlePanel
        -- en el próximo frame crea la ventana del panel (panel_open ya es true).
        if compact.IsPanelOpen() then
            compact.SwitchViewMode()  -- overlay_active=false, view_mode=COMPACT, gfx.quit()
        end
        if config.state.view_mode == config.VIEW_MODES.COMPACT then
            reaper.defer(MainLoop)
            return
        end
    end

    -- GFX mode: mouse state + GFX calls
    config.state.mouse_click = (gfx.mouse_cap&1)==1 and config.state.last_mouse_cap==0
    config.state.mouse_wheel_delta = gfx.mouse_wheel
    if config.state.mouse_wheel_delta ~= 0 then gfx.mouse_wheel = 0 end

    CheckDockState()

    if config.state.docked_mode then
        views.DrawDockedTransportBar(gfx.w, gfx.h)
    else
        views.DrawFullView()
    end

    config.state.last_mouse_cap = gfx.mouse_cap

    -- Re-check: DrawFullView may have called SwitchViewMode() or midi.ToggleIsland()
    if config.state.view_mode == config.VIEW_MODES.COMPACT then
        reaper.defer(MainLoop)
        return
    end
    if midi.midi_island_toggled then
        midi.midi_island_toggled = false
        reaper.defer(MainLoop)
        return
    end

    local char = gfx.getchar()
    -- Ctrl+D toggle dock
    if char == 4 then
        ToggleDock()
    end
    if char == -1 or char == 27 then
        if config.state.did_cleanup then return end
        config.state.did_cleanup = true
        CleanupAll()
        gfx.quit()
        return
    end
    reaper.defer(MainLoop)
end

local function Init()
    if not reaper.JS_VKeys_GetState then
        reaper.MB("Por favor instala js_ReaScriptAPI via ReaPack.", "Error de Dependencia", 0)
        return
    end

    -- Register cleanup for safe exit
    config.state.did_cleanup = false
    reaper.atexit(function()
        if config.state.did_cleanup then return end
        config.state.did_cleanup = true
        CleanupAll()
    end)

    gfx.init("GROVE SCALE RUNNER", 720, 497, 0, config.state.view_offset_x, config.state.view_offset_y)
    gfx.setfont(1, "Calibri", 16)

    -- Load persisted preferences from REAPER ExtState
    local ext_compact = reaper.GetExtState("GROVE_Scale_Runner", "auto_start_compact")
    if ext_compact == "1" then config.state.auto_start_compact = true end
    local ext_reaper = reaper.GetExtState("GROVE_Scale_Runner", "auto_start_reaper")
    if ext_reaper == "1" then config.state.auto_start_reaper = true end

    -- Ensure clean state on startup
    keyboard.InterceptMappedKeys(false)

    -- Auto-start: compact bar overlay alongside full view
    if config.state.auto_start_compact then
        compact.InitOverlay()
    end

    -- Auto-start: register as REAPER startup script if enabled
    if config.state.auto_start_reaper then
        local resource_path = reaper.GetResourcePath()
        if resource_path and #resource_path > 0 then
            local startup_dir = resource_path .. "\\Scripts\\Startup\\"
            local startup_file = startup_dir .. "GROVE_Scale_Runner.lua"

            local f = io.open(startup_file, "r")
            if not f then
                -- Derive absolute path to this script
                local info = debug.getinfo(1, 'S')
                local our_path = (info.source or ""):gsub("^@", "")  -- strip @ prefix

                -- Ensure Startup directory exists
                reaper.RecursiveCreateDirectory(startup_dir, 0)

                -- Create wrapper script that dofile()s the real main.lua
                local fh = io.open(startup_file, "w")
                if fh then
                    local escaped = our_path:gsub("\\", "\\\\")
                    fh:write("-- Auto-start for GROVE Scale Runner\n")
                    fh:write("-- REAPER runs all .lua files in Scripts/Startup/ at launch\n")
                    fh:write("dofile[[" .. escaped .. "]]\n")
                    fh:close()
                end
            else
                f:close()
            end
        end
    end

    reaper.defer(MainLoop)
end

Init()
