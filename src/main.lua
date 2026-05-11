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
--   src/ui/piano.lua
--   src/ui/pads.lua
--   src/core/slots.lua
--   src/ui/drag.lua
--   src/ui/lice.lua
--   src/ui/positioning.lua
--   src/ui/compact-bar.lua
--   src/ui/compact-panel.lua
--   src/ui/compact-intercept.lua
--   src/ui/compact-menu.lua
--   src/ui/compact-init.lua
-- @website https://github.com/GroveWorldMusic/GROVE-Scale-Runner

local info = debug.getinfo(1, 'S')
local script_path = info.source:match([[^@?(.*[\/])[^\/]-$]])
if not script_path then
    reaper.MB("Could not determine script path.", "Error", 0)
    return
end
package.path = package.path .. ";" .. script_path .. "?.lua"

local config = require("config")
local compact_store = require("state.compact")
compact_store.Init(config.state)
local drag_store = require("state.drag")
drag_store.Init(config.state)
local sequencer_store = require("state.sequencer")
sequencer_store.Init(config.state)
local midi_store = require("state.midi")
midi_store.Init(config.state)
local ui_store = require("state.ui")
ui_store.Init(config.state)
local island_store = require("state.island")
island_store.Init(config.state)
local theme = require("ui.theme")
local midi = require("core.midi")
local sequencer = require("core.sequencer")
local views = require("ui.views")
local compact = require("ui.compact")
local keyboard = require("core.keyboard")

local last_dock_state = 0

-- Toggle dock state (Ctrl+D)
local function ToggleDock()
    if ui_store.GetDockedMode() then
        -- Undock: call gfx.dock(0) to float
        gfx.dock(0)
        ui_store.SetDockedMode(false)
        ui_store.SetDockId(0)
        -- Resize back to normal window
        gfx.init("GROVE SCALE RUNNER", 720, 497, 0, config.state.view_offset_x, config.state.view_offset_y)
    else
        -- Dock: call gfx.dock(1) to dock in transport bar slot
        ui_store.SetDockId(gfx.dock(1))
        if ui_store.GetDockId() > 0 then
            ui_store.SetDockedMode(true)
        else
            ui_store.SetDockId(0)
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
            ui_store.SetDockedMode(true)
            ui_store.SetDockId(current_dock)
        else
            ui_store.SetDockedMode(false)
            ui_store.SetDockId(0)
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
    if midi_store.GetActiveNoteDrawTimer() > 0 then
        midi_store.SetActiveNoteDrawTimer(midi_store.GetActiveNoteDrawTimer() - 1)
    end

    -- Decrement page override timer in ALL modes (Issue 8)
    views.DecrementPageOverrideTimer()
    
    -- Shared logic for ALL modes
    keyboard.CheckFocus()
    sequencer.Run()
    keyboard.HandleKeyboard()

    -- Compact mode (no GFX window)
    if ui_store.GetViewMode() == config.VIEW_MODES.COMPACT then
        compact.ProcessMouseInterception()
        compact.UpdateCompactView()
        compact.HandlePanel()
        reaper.defer(MainLoop)
        return
    end

    -- Overlay mode: compact bar visible alongside full view (auto-start)
    if compact_store.GetOverlayActive() then
        compact.ProcessMouseInterception()
        compact.UpdateCompactView()
        -- Si TogglePanel se disparó (clic en la barra → panel_open = true),
        -- no podemos dibujar el panel sin conflicto de GFX. Transicionamos a
        -- compacto completo: gfx.quit() cierra la full view, luego HandlePanel
        -- en el próximo frame crea la ventana del panel (panel_open ya es true).
        if compact.IsPanelOpen() then
            compact.SwitchViewMode()  -- overlay_active=false, view_mode=COMPACT, gfx.quit()
        end
        if ui_store.GetViewMode() == config.VIEW_MODES.COMPACT then
            reaper.defer(MainLoop)
            return
        end
    end

    -- GFX mode: mouse state + GFX calls
    local mwd = gfx.mouse_wheel
    ui_store.SetMouseClick((gfx.mouse_cap & 1) == 1 and ui_store.GetLastMouseCap() == 0)
    ui_store.SetMouseWheelDelta(mwd)
    if mwd ~= 0 then gfx.mouse_wheel = 0 end

    -- ISLAND mode routing
    if ui_store.GetViewMode() == config.VIEW_MODES.ISLAND then
        views.DrawIslandView()
        ui_store.SetLastMouseCap(gfx.mouse_cap)
        local char = gfx.getchar()

        -- Ctrl+I (9) or F12 (123): toggle back to FULL
        if char == 9 or char == 123 then
            compact.ToggleIslandView()

        -- Ctrl+S (19): Save preset (P5-03)
        elseif char == 19 then
            views.IslandTriggerSave()

        -- Ctrl+O (15): Load/open preset (P5-03)
        elseif char == 15 then
            views.IslandTriggerLoad()

        -- Delete (127) or Backspace (8): Delete selected note (P5-03)
        elseif char == 127 or char == 8 then
            views.IslandDeleteNote()

        -- Arrow Up (273): Select previous note (P5-03)
        elseif char == 273 then
            views.IslandSelectAdjacentNote(-1)

        -- Arrow Down (274): Select next note (P5-03)
        elseif char == 274 then
            views.IslandSelectAdjacentNote(1)
        end

        -- Always check for close/escape regardless of other key handling
        if char == -1 or char == 27 then
            if ui_store.GetDidCleanup() then return end
            ui_store.SetDidCleanup(true)
            CleanupAll()
            gfx.quit()
            return
        end

        reaper.defer(MainLoop)
        return
    end

    CheckDockState()

    if ui_store.GetDockedMode() then
        views.DrawDockedTransportBar(gfx.w, gfx.h)
    else
        views.DrawFullView()
    end

    ui_store.SetLastMouseCap(gfx.mouse_cap)

    -- Re-check: DrawFullView may have called SwitchViewMode() or midi.ToggleIsland()
    if ui_store.GetViewMode() == config.VIEW_MODES.COMPACT then
        reaper.defer(MainLoop)
        return
    end
    if ui_store.GetViewMode() == config.VIEW_MODES.ISLAND then
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
    -- F12 toggle ISLAND view
    if char == 123 then  -- VK_F12
        compact.ToggleIslandView()
    end
    if char == -1 or char == 27 then
        if ui_store.GetDidCleanup() then return end
        ui_store.SetDidCleanup(true)
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
    ui_store.SetDidCleanup(false)
    reaper.atexit(function()
        if ui_store.GetDidCleanup() then return end
        ui_store.SetDidCleanup(true)
        CleanupAll()
    end)

    gfx.init("GROVE SCALE RUNNER", 720, 497, 0, config.state.view_offset_x, config.state.view_offset_y)
    gfx.setfont(1, "Calibri", 16)

    -- Load persisted preferences from REAPER ExtState
    local ext_compact = reaper.GetExtState("GROVE_Scale_Runner", "auto_start_compact")
    if ext_compact == "1" then ui_store.SetAutoStartCompact(true) end
    local ext_reaper = reaper.GetExtState("GROVE_Scale_Runner", "auto_start_reaper")
    if ext_reaper == "1" then ui_store.SetAutoStartReaper(true) end

    -- Ensure clean state on startup
    keyboard.InterceptMappedKeys(false)

    -- Auto-start: compact bar overlay alongside full view
    if ui_store.GetAutoStartCompact() then
        compact.InitOverlay()
    end

    -- Auto-start: register as REAPER startup script if enabled
    if ui_store.GetAutoStartReaper() then
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
