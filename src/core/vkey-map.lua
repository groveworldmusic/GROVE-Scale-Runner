-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Configurable VKey-to-Degree/Octave Map
-- Module-level closure with persist.Save for serialization.
-- Single source of truth for key-to-degree/octave mapping.
local config = require("config")
local persist = require("state.persist")

local m = {}

-- Internal state
local _map = {}        -- Deep copy of config.VKEY_MAP
local _modified = false

-- Make a deep copy of the VKEY_MAP table
local function deep_copy(src)
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = { deg = v.deg, oct = v.oct }
    end
    return copy
end

-- Serialize internal _map to a Lua table string
-- Format: {[0x31]={deg=1,oct=1},[0x32]={deg=2,oct=1},...}
-- Deterministic via sorted VK codes.
function m.Serialize()
    local parts = {}
    table.insert(parts, "{")
    local first = true
    local sorted = {}
    for k in pairs(_map) do table.insert(sorted, k) end
    table.sort(sorted)
    for _, k in ipairs(sorted) do
        local v = _map[k]
        if not first then table.insert(parts, ",") end
        table.insert(parts, string.format("[0x%X]={deg=%d,oct=%d}", k, v.deg, v.oct))
        first = false
    end
    table.insert(parts, "}")
    return table.concat(parts)
end

-- Deserialize a Lua table string into _map.
-- Uses load("return " .. str)() pattern per spec.
-- Protected with pcall to gracefully handle malformed persisted data.
function m.Deserialize(str)
    if not str or #str == 0 then return end
    local ok, result = pcall(load, "return " .. str)
    if ok and result then
        local loaded = result()
        if type(loaded) == "table" then
            _map = {}
            for k, v in pairs(loaded) do
                _map[k] = { deg = v.deg, oct = v.oct }
            end
            _modified = true
        end
    end
end

-- Initialize from config.state (called after persist.Load in main.lua).
-- Starts as deep copy of config.VKEY_MAP, then overlays persisted data if available.
function m.Init(config_state)
    _map = deep_copy(config.VKEY_MAP)
    _modified = false
    if config_state and config_state.vkey_map_raw and #config_state.vkey_map_raw > 0 then
        m.Deserialize(config_state.vkey_map_raw)
    end
end

-- Returns reference to the internal map (not a copy — performance-critical hot path).
-- keyboard.lua reads this per-frame in HandleKeyboard.
function m.GetVkeyMap()
    return _map
end

-- Set a single VK entry to new deg/oct.
-- Returns the conflicting VK code if another key already maps to this deg+oct, or nil.
-- The caller should decide how to handle the conflict (e.g. via reaper.MB dialog).
function m.SetEntry(vk_code, deg, oct)
    -- Check for conflict: another key already maps to this deg+oct
    local conflict_key = nil
    for k, v in pairs(_map) do
        if k ~= vk_code and v.deg == deg and v.oct == oct then
            conflict_key = k
            break
        end
    end

    _map[vk_code] = { deg = deg, oct = oct }
    _modified = true

    -- Persist immediately (not debounced — user-initiated critical state)
    persist.Save("vkey_map_raw", m.Serialize())

    return conflict_key
end

-- Restore all 28 keys to config.VKEY_MAP defaults and clear the persisted override.
function m.ResetToDefaults()
    _map = deep_copy(config.VKEY_MAP)
    _modified = false
    persist.Save("vkey_map_raw", "")
end

-- Returns whether the map deviates from defaults (for UI hinting).
function m.IsModified()
    return _modified
end

-- Returns the 7 physical key chars for a given row (0-3) with their VK codes.
-- Used by the remap modal to render the grid.
local ROW_DATA = {
    { label = "1-7", key_chars = {"1","2","3","4","5","6","7"}, vks = {0x31,0x32,0x33,0x34,0x35,0x36,0x37} },
    { label = "Q-U", key_chars = {"Q","W","E","R","T","Y","U"}, vks = {0x51,0x57,0x45,0x52,0x54,0x59,0x55} },
    { label = "A-J", key_chars = {"A","S","D","F","G","H","J"}, vks = {0x41,0x53,0x44,0x46,0x47,0x48,0x4A} },
    { label = "Z-M", key_chars = {"Z","X","C","V","B","N","M"}, vks = {0x5A,0x58,0x43,0x56,0x42,0x4E,0x4D} },
}

function m.GetRowData()
    return ROW_DATA
end

return m
