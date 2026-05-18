-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Path Utilities
-- Provides sanitization functions for preset file names and paths to prevent directory traversal attacks.

local m = {}

--- Sanitize a preset name to prevent directory traversal and illegal characters.
-- Removes any path separators, dot sequences, and non-alphanumeric characters
-- except underscore, hyphen, and space. Trims leading/trailing whitespace.
-- @param name string|nil The raw preset name from user input
-- @return string Sanitized name (may be empty)
function m.SanitizePresetName(name)
    if name == nil then return "" end
    -- Trim whitespace
    name = name:match("^%s*(.-)%s*$") or ""
    -- Remove path separators and any character not alphanumeric, underscore, hyphen, or space
    name = name:gsub("[^%w_%-%s]", "")
    -- Remove any remaining dot sequences (e.g., "..") – already stripped by above as non-word
    return name
end

--- Concatenate path segments using `/` as canonical separator.
-- Converts any `\` to `/` for cross-platform consistency.
-- @param ... string Path segments to join
-- @return string Joined path
function m.PathJoin(...)
    local segments = {...}
    if #segments == 0 then return "" end
    local result = table.concat(segments, "/")
    return result:gsub("\\", "/")
end

return m