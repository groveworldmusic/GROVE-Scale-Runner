-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
-- API Guard: Central module for REAPER API validation and index clamping

local m = {}

--- Check if a REAPER API function exists.
--- Uses reaper.APIExists when available, falls back to checking the function directly.
--- @param name string The API function name (e.g. "JS_VKeys_GetState")
--- @return boolean true if the API exists and is callable
function m.CheckAPI(name)
    if type(reaper.APIExists) == "function" then
        return reaper.APIExists(name)
    end
    return type(reaper[name]) == "function"
end

--- Assert that all required API functions exist.
--- Displays a message box listing all missing APIs and returns false.
--- @param checks table A table mapping API names to human-readable error messages
--- @return boolean true if all APIs exist, false otherwise
function m.AssertAPIs(checks)
    local missing = {}
    for name, msg in pairs(checks) do
        if not m.CheckAPI(name) then
            table.insert(missing, msg or name)
        end
    end
    if #missing > 0 then
        local err_msg = "Missing required APIs:\n  - " .. table.concat(missing, "\n  - ")
        reaper.MB(err_msg, "GROVE Scale Runner — Missing Dependencies", 0)
        return false
    end
    return true
end

--- Clamp an index to a valid range [min, max].
--- Logs a console message if the value was out of bounds and needed clamping.
--- @param idx number The index to clamp
--- @param min number Minimum valid value (inclusive)
--- @param max number Maximum valid value (inclusive)
--- @return number Clamped integer value within [min, max]
function m.ClampIndex(idx, min, max)
    min = min or 1
    max = max or 1
    local original = idx
    local clamped = math.max(min, math.min(max, math.floor(idx or min)))
    if original ~= clamped then
        reaper.ShowConsoleMsg("[GROVE Scale Runner] ClampIndex: "
            .. tostring(original) .. " clamped to " .. tostring(clamped)
            .. " (range " .. min .. "-" .. max .. ")\n")
    end
    return clamped
end

return m
