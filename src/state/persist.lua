-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Preference Persistence
-- Read/writes user preferences via reaper.SetExtState/GetExtState.
-- Canonical namespace: GROVE_Scale_Runner
-- Legacy namespace: GROVE_FL_MIDI (migrated on first load, never deleted)
--
-- Usage:
--   persist.Load(config.state)     -- load all persisted prefs into state
--   persist.Save("root_index", 3)  -- save a single pref to canonical ns

local CANONICAL_NS = "GROVE_Scale_Runner"
local LEGACY_NS = "GROVE_FL_MIDI"

-- Key registry: maps preference keys to their paths within config.state.
-- A string value means state[key]; a table {sub, key} means state[sub][key].
-- These must match the fields defined in config.PREF_KEYS.
local PREF_KEYS = {
    root_index        = "root_index",
    scale_index       = "scale_index",
    octave            = "octave",
    chord_mode_index  = "chord_mode_index",
    inversion_index   = "inversion_index",
    inversion_direction = "inversion_direction",
    subdivision_index  = "subdivision_index",
    volume            = { "sequencer", "volume" },
    color_mode        = "color_mode",
    auto_focus_enabled = "auto_focus_enabled",
    theme_index       = "theme_index",
    view_offset_x     = "view_offset_x",
    view_offset_y     = "view_offset_y",
    vkey_map_raw      = "vkey_map_raw",
}

local m = {}

--- Retrieve the raw ExtState value for a key from the canonical namespace.
--- Returns the value string, or nil if the key does not exist.
local function get_canonical(key)
    local val = reaper.GetExtState(CANONICAL_NS, key)
    if val ~= "" then return val end
    return nil
end

--- Retrieve the raw ExtState value for a key from the legacy namespace.
--- Returns the value string, or nil if the key does not exist.
local function get_legacy(key)
    local val = reaper.GetExtState(LEGACY_NS, key)
    if val ~= "" then return val end
    return nil
end

--- Resolve a key spec to the corresponding config.state value.
--- @param state table config.state
--- @param key_spec string|table  Path descriptor from PREF_KEYS
--- @return any  The current value at that path
local function resolve(state, key_spec)
    if type(key_spec) == "table" then
        local tbl = state[key_spec[1]]
        return tbl and tbl[key_spec[2]] or nil
    end
    return state[key_spec]
end

--- Set a value at the config.state path described by key_spec.
--- @param state table config.state
--- @param key_spec string|table  Path descriptor from PREF_KEYS
--- @param value any  Value to apply (auto-converted from ExtState string)
local function apply(state, key_spec, value)
    if type(key_spec) == "table" then
        local tbl = state[key_spec[1]]
        if tbl then tbl[key_spec[2]] = value end
    else
        state[key_spec] = value
    end
end

--- Convert an ExtState string value to the appropriate Lua type.
--- Numeric strings become numbers; everything else stays as string.
--- @param val string  Raw ExtState value
--- @return number|string
local function coerce(val)
    -- tonumber returns nil for non-numeric strings; the "or val" fallback
    -- preserves the original string (e.g. "grade", "flat").
    return tonumber(val) or val
end

--- Load all persisted preferences from ExtState into the given state table.
---
--- Reads from canonical namespace GROVE_Scale_Runner first.
--- If a key is missing in canonical, falls back to legacy GROVE_FL_MIDI
--- and silently migrates the value to canonical (writes to GROVE_Scale_Runner).
--- Legacy keys are NEVER deleted.
---
--- @param state table  config.state (or equivalent) to apply values into
function m.Load(state)
    for key, key_spec in pairs(PREF_KEYS) do
        local val = get_canonical(key)
        if val then
            -- Canonical exists — apply directly
            apply(state, key_spec, coerce(val))
        else
            -- Fall back to legacy namespace
            local legacy_val = get_legacy(key)
            if legacy_val then
                -- Migrate to canonical namespace
                reaper.SetExtState(CANONICAL_NS, key, legacy_val, true)
                apply(state, key_spec, coerce(legacy_val))
            end
            -- If neither exists, keep the hardcoded default already in state
        end
    end
end

--- Save a single preference value to the canonical ExtState namespace.
--- The value is persisted immediately (persistent=true) and survives REAPER restarts.
---
--- @param key string  One of the PREF_KEYS (e.g. "root_index", "volume")
--- @param value string|number  Value to persist
function m.Save(key, value)
    reaper.SetExtState(CANONICAL_NS, key, tostring(value), true)
end

return m
