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
--   src/ui/theme.lua
--   src/ui/helpers.lua
--   src/ui/components.lua
--   src/ui/views.lua
--   src/ui/compact.lua
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

local last_focus_check = 0
local is_intercepting = false
local last_dock_state = 0
local temp_ctx = {}  -- Reusable context table for key press handling (Issue 12)

-- Toggle dock state (Ctrl+D)
local function ToggleDock()
    if config.state.docked_mode then
        -- Undock: call gfx.dock(0) to float
        gfx.dock(0)
        config.state.docked_mode = false
        config.state.dock_id = 0
        -- Resize back to normal window
        gfx.init("GROVE SCALE RUNNER", 720, 500, 0, config.state.view_offset_x, config.state.view_offset_y)
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

local function HandleKeyboard()
    if not is_intercepting then return end
    
    for k_code, state in pairs(config.state.key_states) do
        local is_down = reaper.JS_VKeys_GetState(0):byte(k_code) ~= 0
        if is_down and not state.is_pressed then
            state.is_pressed = true
            local map = config.VKEY_MAP[k_code]
            if map then
                -- Velocity Humanization (Issue 21)
                local vel = config.state.use_velocity and (85 + math.random(30)) or 100
                
                -- Reusable context with octave override (Issue 12)
                temp_ctx.octave = config.state.octave + map.oct
                temp_ctx.root_index = config.state.root_index
                temp_ctx.scale_index = config.state.scale_index
                temp_ctx.chord_mode_index = config.state.chord_mode_index
                state.midi_notes = midi.TriggerChord(map.deg, true, temp_ctx, vel)
            end
        elseif not is_down and state.is_pressed then
            state.is_pressed = false
            for _, n in ipairs(state.midi_notes) do
                midi.SendMidi(n, false)
            end
            state.midi_notes = {}
        end
    end
end



local function InterceptMappedKeys(state)
    -- Only intercept the specific keys the script uses, not ALL keys.
    -- This allows the VKB and Reaper shortcuts to work normally for unmapped keys.
    local action = state and 1 or -1
    for k_code, _ in pairs(config.VKEY_MAP) do
        reaper.JS_VKeys_Intercept(k_code, action)
    end
end

local function IsPluginOrScriptFocused()
    local hwnd = reaper.JS_Window_GetFocus()
    if not hwnd then return false end
    
    -- Our own script window has focus
    if hwnd == gfx.hwnd then return true end
    
    -- GetFocusedFX2() retval bitmask:
    --   bit 1 (& 1): track FX is focused
    --   bit 2 (& 2): take FX is focused  
    --   bit 4 (& 4): window is open but NOT actively focused
    -- We want to intercept ONLY when a plugin is ACTIVELY focused (bits 1/2 set, bit 4 NOT set)
    local retval = reaper.GetFocusedFX2()
    local plugin_type = retval & 3  -- track FX or take FX
    local is_unfocused = retval & 4 -- window open but not focused
    
    if plugin_type ~= 0 and is_unfocused == 0 then
        return true -- A plugin window is actively focused
    end
    
    return false
end

local function CheckFocus()
    local now = reaper.time_precise()
    if now - last_focus_check > 0.2 then  -- ~3 frames at 60fps, matches REAPER's typical defer cycle
        last_focus_check = now
        
        local should_intercept = IsPluginOrScriptFocused()
        
        if should_intercept and not is_intercepting then
            InterceptMappedKeys(true)
            is_intercepting = true
        elseif not should_intercept and is_intercepting then
            InterceptMappedKeys(false)
            is_intercepting = false
            midi.AllNotesOff()
        end
    end
end

local function CleanupAll()
    midi.AllNotesOff()
    sequencer.Stop()
    if is_intercepting then
        InterceptMappedKeys(false)
    end
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
    CheckFocus()
    sequencer.Run()
    HandleKeyboard()

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

    -- Re-check: DrawFullView may have called SwitchViewMode()
    if config.state.view_mode == config.VIEW_MODES.COMPACT then
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

    gfx.init("GROVE SCALE RUNNER", 720, 500, 0, config.state.view_offset_x, config.state.view_offset_y)
    gfx.setfont(1, "Calibri", 16)

    -- Load persisted preferences from REAPER ExtState
    local ext_compact = reaper.GetExtState("GROVE_Scale_Runner", "auto_start_compact")
    if ext_compact == "1" then config.state.auto_start_compact = true end
    local ext_reaper = reaper.GetExtState("GROVE_Scale_Runner", "auto_start_reaper")
    if ext_reaper == "1" then config.state.auto_start_reaper = true end

    -- Ensure clean state on startup
    InterceptMappedKeys(false)
    is_intercepting = false

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
