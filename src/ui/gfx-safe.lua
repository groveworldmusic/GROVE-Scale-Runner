-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Safe GFX Initialization and Error Display
-- Wraps gfx.init() and gfx.quit() in pcall to prevent crashes when
-- the GFX context is unavailable (e.g. during REAPER shutdown).
-- All errors are surfaced via reaper.ShowConsoleMsg().
--
-- Usage:
--   local ok, err = SafeGfxInit("My Window", 720, 497, 0, x, y)
--   SafeGfxQuit()
--   ShowError("MyFunction", "something went wrong")

local m = {}

--- Wrapper around gfx.init() with pcall protection.
--- Accepts the same arguments as gfx.init: title, width, height, dock, x, y.
--- Returns (true) on success or (false, error_message) on failure.
--- On failure, prints the error via ShowError.
--- @param ... any  Arguments forwarded to gfx.init()
--- @return boolean ok
--- @return string|nil err
function m.SafeGfxInit(...)
    local ok, err = pcall(gfx.init, ...)
    if not ok then
        m.ShowError("SafeGfxInit", err)
    end
    return ok, err
end

--- Wrapper around gfx.quit() with pcall protection.
--- Returns (true) on success or (false, error_message) on failure.
--- On failure, prints the error via ShowError.
--- @return boolean ok
--- @return string|nil err
function m.SafeGfxQuit()
    local ok, err = pcall(gfx.quit)
    if not ok then
        m.ShowError("SafeGfxQuit", err)
    end
    return ok, err
end

--- Display an error message via reaper.ShowConsoleMsg().
--- Includes the function context and the error details so the user
--- can identify the source of the failure.
--- @param context string  Name of the function or module where the error occurred
--- @param err any  Error object (string, table, etc.)
function m.ShowError(context, err)
    reaper.ShowConsoleMsg("[GROVE Scale Runner] " .. tostring(context) .. " error: " .. tostring(err) .. "\n")
end

return m
