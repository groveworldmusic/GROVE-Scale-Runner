-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Preferences State Store
-- Encapsulates user preference state with getters/setters.
-- Each Set*() also persists the value via reaper.SetExtState.
-- Extracted from config.state.* for preference subsystem.
-- Keys: root_index, scale_index, octave, chord_mode_index,
--       inversion_index, inversion_direction, subdivision_index,
--       auto_focus_enabled.
local prefs_state = {
    root_index = 1,
    scale_index = 1,
    octave = 4,
    chord_mode_index = 1,
    inversion_index = 1,
    inversion_direction = 0,
    subdivision_index = 1,
    auto_focus_enabled = true,
    scale_snap_highlight = true,
}

local persist = require("state.persist")

local m = {}

-- Debounce state for persist.Save: track which keys changed, flush only those
-- via TickSaveDebounce(). Avoids N synchronous SetExtState calls per frame.
local dirty_keys = {}

function m.Init(defaults)
    if defaults.root_index ~= nil then prefs_state.root_index = defaults.root_index end
    if defaults.scale_index ~= nil then prefs_state.scale_index = defaults.scale_index end
    if defaults.octave ~= nil then prefs_state.octave = defaults.octave end
    if defaults.chord_mode_index ~= nil then prefs_state.chord_mode_index = defaults.chord_mode_index end
    if defaults.inversion_index ~= nil then prefs_state.inversion_index = defaults.inversion_index end
    if defaults.inversion_direction ~= nil then prefs_state.inversion_direction = defaults.inversion_direction end
    if defaults.subdivision_index ~= nil then prefs_state.subdivision_index = defaults.subdivision_index end
    if defaults.auto_focus_enabled ~= nil then prefs_state.auto_focus_enabled = defaults.auto_focus_enabled end
    if defaults.scale_snap_highlight ~= nil then prefs_state.scale_snap_highlight = defaults.scale_snap_highlight end
end

--- Sync values from a state table (typically config.state after persist.Load)
--- so that persisted values from ExtState are reflected in this store.
function m.SyncFromState(state)
    if state.root_index ~= nil then prefs_state.root_index = state.root_index end
    if state.scale_index ~= nil then prefs_state.scale_index = state.scale_index end
    if state.octave ~= nil then prefs_state.octave = state.octave end
    if state.chord_mode_index ~= nil then prefs_state.chord_mode_index = state.chord_mode_index end
    if state.inversion_index ~= nil then prefs_state.inversion_index = state.inversion_index end
    if state.inversion_direction ~= nil then prefs_state.inversion_direction = state.inversion_direction end
    if state.subdivision_index ~= nil then prefs_state.subdivision_index = state.subdivision_index end
    if state.auto_focus_enabled ~= nil then prefs_state.auto_focus_enabled = state.auto_focus_enabled end
    if state.scale_snap_highlight ~= nil then prefs_state.scale_snap_highlight = state.scale_snap_highlight end
end

-- Getters
function m.GetRootIndex() return prefs_state.root_index end
function m.GetScaleIndex() return prefs_state.scale_index end
function m.GetOctave() return prefs_state.octave end
function m.GetChordModeIndex() return prefs_state.chord_mode_index end
function m.GetInversionIndex() return prefs_state.inversion_index end
function m.GetInversionDirection() return prefs_state.inversion_direction end
function m.GetSubdivisionIndex() return prefs_state.subdivision_index end
function m.GetAutoFocusEnabled() return prefs_state.auto_focus_enabled end
function m.GetScaleSnapHighlight() return prefs_state.scale_snap_highlight end

--- Flush pending saves once per frame (called from MainLoop).
--- Only saves keys that actually changed, reducing SetExtState calls.
function m.TickSaveDebounce()
    if not next(dirty_keys) then return end
    for key in pairs(dirty_keys) do
        persist.Save(key, prefs_state[key])
        dirty_keys[key] = nil
    end
end

-- Setters (debounced: mark dirty key, flush via TickSaveDebounce once per frame)
function m.SetRootIndex(v) prefs_state.root_index = v; dirty_keys["root_index"] = true end
function m.SetScaleIndex(v) prefs_state.scale_index = v; dirty_keys["scale_index"] = true end
function m.SetOctave(v) prefs_state.octave = v; dirty_keys["octave"] = true end
function m.SetChordModeIndex(v) prefs_state.chord_mode_index = v; dirty_keys["chord_mode_index"] = true end
function m.SetInversionIndex(v) prefs_state.inversion_index = v; dirty_keys["inversion_index"] = true end
function m.SetInversionDirection(v) prefs_state.inversion_direction = v; dirty_keys["inversion_direction"] = true end
function m.SetSubdivisionIndex(v) prefs_state.subdivision_index = v; dirty_keys["subdivision_index"] = true end
function m.SetAutoFocusEnabled(v) prefs_state.auto_focus_enabled = v; dirty_keys["auto_focus_enabled"] = true end
function m.SetScaleSnapHighlight(v) prefs_state.scale_snap_highlight = v; dirty_keys["scale_snap_highlight"] = true end

return m
