-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Keyboard Handling — VKeys intercept, focus detection, key dispatch
local config = require("config")
local midi = require("core.midi")
local midi_store = require("state.midi")
local sequencer = require("core.sequencer")
local api_guard = require("core.api-guard")
local prefs = require("state.preferences")
local ui_store = require("state.ui")

local keyboard = {}

-- Module-level closures (encapsulated state)
local is_intercepting = false
local last_focus_check = 0
local temp_ctx = {}  -- Reusable context table for key press handling (Issue 12)

-- Validate required APIs once at module init level (not per-frame)
local HAS_VKEYS_GET_STATE = api_guard.CheckAPI("JS_VKeys_GetState")
local HAS_VKEYS_INTERCEPT = api_guard.CheckAPI("JS_VKeys_Intercept")

function keyboard.HandleKeyboard()
    if not is_intercepting then return end
    if not HAS_VKEYS_GET_STATE then return end

    local vk_state = reaper.JS_VKeys_GetState(0)
    if not vk_state then return end

    for k_code, state in pairs(midi_store.GetKeyStates()) do
        local is_down = vk_state:byte(k_code) ~= 0
        if is_down and not state.is_pressed then
            state.is_pressed = true
            local map = config.VKEY_MAP[k_code]
            if map then
                -- Velocity Humanization (Issue 21)
                local vel = midi_store.GetUseVelocity() and (85 + math.random(30)) or 100
                
                -- Reusable context with octave override (Issue 12)
                -- Read from preferences_store for debounced persistence (Phase 4 migration)
                temp_ctx.octave = prefs.GetOctave() + map.oct
                temp_ctx.root_index = prefs.GetRootIndex()
                temp_ctx.scale_index = prefs.GetScaleIndex()
                temp_ctx.chord_mode_index = prefs.GetChordModeIndex()
                state.midi_notes = midi.TriggerChord(map.deg, true, temp_ctx, vel, prefs.GetInversionIndex())
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

function keyboard.InterceptMappedKeys(state)
    -- Only intercept the specific keys the script uses, not ALL keys.
    -- This allows the VKB and Reaper shortcuts to work normally for unmapped keys.
    if not HAS_VKEYS_INTERCEPT then return end
    local action = state and 1 or -1
    for k_code, _ in pairs(config.VKEY_MAP) do
        reaper.JS_VKeys_Intercept(k_code, action)
    end
end

function keyboard.IsPluginOrScriptFocused()
    local hwnd = reaper.JS_Window_GetFocus()
    if not hwnd then return false end
    
    -- Our own script window has focus (only valid in FULL mode; gfx.hwnd is stale after COMPACT gfx.quit())
    if ui_store.GetViewMode() == config.VIEW_MODES.FULL and hwnd == gfx.hwnd then return true end
    
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

function keyboard.CheckFocus()
    local now = reaper.time_precise()
    if now - last_focus_check > 0.1 then  -- ~6 frames at 60fps; halved from 0.2s to reduce stuck-note window on alt-tab
        last_focus_check = now
        
        local should_intercept = keyboard.IsPluginOrScriptFocused()
        
        if should_intercept and not is_intercepting then
            keyboard.InterceptMappedKeys(true)
            is_intercepting = true
        elseif not should_intercept and is_intercepting then
            keyboard.InterceptMappedKeys(false)
            is_intercepting = false
            -- Stop sequencer FIRST, then silence MIDI notes (Issue 22):
            -- Stop() sends per-note note-offs and resets playback state.
            sequencer.Stop()
            midi.AllNotesOff(true)  -- Issue B2: force=true so note-offs bypass sustain/ref-count gate on focus loss
        end
    end
end

-- Cleanup: release key intercept if active (for main.lua's CleanupAll)
function keyboard.Cleanup()
    if is_intercepting then
        keyboard.InterceptMappedKeys(false)
    end
end

return keyboard
