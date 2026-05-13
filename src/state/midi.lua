-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
-- GROVE Scale Runner: MIDI State Store
-- Encapsulates MIDI-related state with getters/setters.
-- Extracted from config.state.* for MIDI, keyboard, and pad subsystems.
local midi_state = {
    use_velocity = false,
    last_note_played = "None",
    active_note_draw_timer = 0,
    key_states = {},
    active_notes = {},
    mouse_pad_state = { pad_hover = nil, pad_selected = nil, pad_timer = 0, active_degree = -1, midi_notes = {} },
}

local m = {}

function m.Init(defaults)
    if defaults.use_velocity ~= nil then midi_state.use_velocity = defaults.use_velocity end
    if defaults.last_note_played ~= nil then midi_state.last_note_played = defaults.last_note_played end
    if defaults.active_note_draw_timer ~= nil then midi_state.active_note_draw_timer = defaults.active_note_draw_timer end
    if defaults.key_states then midi_state.key_states = defaults.key_states end
    if defaults.active_notes then
        for k, v in pairs(defaults.active_notes) do midi_state.active_notes[k] = v end
    end
    if defaults.mouse_pad_state then
        for k, v in pairs(defaults.mouse_pad_state) do midi_state.mouse_pad_state[k] = v end
    end
end

-- Simple fields
function m.GetUseVelocity() return midi_state.use_velocity end
function m.SetUseVelocity(v) midi_state.use_velocity = v end

function m.GetLastNotePlayed() return midi_state.last_note_played end
function m.SetLastNotePlayed(v) midi_state.last_note_played = v end

function m.GetActiveNoteDrawTimer() return midi_state.active_note_draw_timer end
function m.SetActiveNoteDrawTimer(v) midi_state.active_note_draw_timer = v end

-- key_states table — full table ref for iteration, indexed access for individual entries
function m.GetKeyStates() return midi_state.key_states end
function m.GetKeyState(i) return midi_state.key_states[i] end
function m.SetKeyState(i, v) midi_state.key_states[i] = v end

-- active_notes table — indexed by MIDI note number, ref-counted
function m.GetActiveNotes() return midi_state.active_notes end
function m.GetActiveNote(i) return midi_state.active_notes[i] end
function m.SetActiveNote(i, v)
    if v == nil then
        midi_state.active_notes[i] = nil
    else
        midi_state.active_notes[i] = v
    end
end
function m.ClearActiveNotes()
    for k, _ in pairs(midi_state.active_notes) do midi_state.active_notes[k] = nil end
end

-- mouse_pad_state — returns table ref for direct field access
function m.GetMousePadState() return midi_state.mouse_pad_state end

return m
