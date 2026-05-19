-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Safe Preset Loader
-- Loads preset files in a restricted environment to prevent code execution.
-- Only allows safe operations: math, string, table (read-only). No io, os, dofile.

local m = {}

-- Creates a sandbox environment for preset execution.
local function make_env()
    local env = {}
    local ro_meta = {
        __index = function(_, key)
            if key == "math" then return math end
            if key == "string" then return string end
            if key == "table" then return table end
            return nil
        end,
        __newindex = function(_, key, value)
            error("Attempt to write to sandbox environment: " .. tostring(key))
        end
    }
    setmetatable(env, ro_meta)
    return env
end

--- Load and execute a preset file in a sandbox.
-- @param file_path string Path to the .grove preset file
-- @return (ok, result) where ok is boolean and result is the loaded table or error message
function m.LoadSandboxed(file_path)
    -- Read file content using trusted I/O
    local f, err = io.open(file_path, "r")
    if not f then
        return false, "Cannot open file: " .. (err or "unknown error")
    end
    local content = f:read("*a")
    f:close()
    if not content or #content == 0 then
        return false, "File is empty"
    end
    -- Compile the chunk with the sandbox environment
    local chunk, err = load(content, "@" .. file_path, "t", make_env())
    if not chunk then
        return false, "Syntax error: " .. tostring(err)
    end
    -- Execute in protected mode
    local ok, result = pcall(chunk)
    if not ok then
        return false, "Runtime error: " .. tostring(result)
    end
    if type(result) ~= "table" then
        return false, "Invalid preset: expected a table, got " .. type(result)
    end
    return true, result
end

return m