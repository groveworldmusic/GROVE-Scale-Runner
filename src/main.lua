-- @version 1.0.0
-- @author GROVE WORLD MUSIC
-- @about
--   Scale Runner: QWERTY to MIDI Controller
--   Multi-module architecture with Reaper integration

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
                -- Velocity Humanization
                local vel = 100
                if config.state.use_velocity then
                    vel = 85 + math.random(30) -- Range 85-115 for human feel
                end
                
                -- Minimal context with octave override (midi.TriggerChord only needs these 4 fields)
                local temp_ctx = {
                    octave = config.state.octave + map.oct,
                    root_index = config.state.root_index,
                    scale_index = config.state.scale_index,
                    chord_mode_index = config.state.chord_mode_index
                }
                
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

-- Handle keyboard shortcuts when GFX is not running (compact mode)
-- TODO: Merge with HandleKeyboard (remove is_intercepting guard difference)
local function HandleKeyboardCompact()
    if not is_intercepting then return end
    -- Use global VKeys state for compact mode
    for k_code, state in pairs(config.state.key_states) do
        local is_down = reaper.JS_VKeys_GetState(0):byte(k_code) ~= 0
        if is_down and not state.is_pressed then
            state.is_pressed = true
            local map = config.VKEY_MAP[k_code]
            if map then
                local vel = config.state.use_velocity and (85 + math.random(30)) or 100
                local temp_ctx = {
                    octave = config.state.octave + map.oct,
                    root_index = config.state.root_index,
                    scale_index = config.state.scale_index,
                    chord_mode_index = config.state.chord_mode_index
                }
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

local function MainLoop()
    -- Decrement note display timer
    if config.state.active_note_draw_timer > 0 then
        config.state.active_note_draw_timer = config.state.active_note_draw_timer - 1
    end
    
    -- Shared logic for ALL modes
    CheckFocus()
    sequencer.Run()
    HandleKeyboard()

    -- Compact mode (no GFX window)
    if config.state.view_mode == config.VIEW_MODES.COMPACT then
        compact.ProcessMouseInterception()
        compact.UpdateCompactView()
        compact.HandlePanel()
        HandleKeyboardCompact()
        reaper.defer(MainLoop)
        return
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
        -- Exit Cleanup
        midi.AllNotesOff()
        sequencer.Stop()
        if is_intercepting then
            InterceptMappedKeys(false)
        end
        compact.Cleanup()
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
    reaper.atexit(function()
        midi.AllNotesOff()
        sequencer.Stop()
        if is_intercepting then
            InterceptMappedKeys(false)
        end
        compact.Cleanup()
    end)

    gfx.init("GROVE SCALE RUNNER", 720, 500, 0, config.state.view_offset_x, config.state.view_offset_y)
    gfx.setfont(1, "Calibri", 16)

    -- Ensure clean state on startup
    InterceptMappedKeys(false)
    is_intercepting = false

    reaper.defer(MainLoop)
end

Init()
