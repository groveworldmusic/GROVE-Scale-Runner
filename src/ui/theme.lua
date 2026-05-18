-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Dynamic Theme Loader
-- Colors are loaded from themes.THEMES[prefs.GetThemeIndex()].colors at module
-- load time and on every SetThemeIndex() call. The module table reference is
-- replaced in-place so all consumers (143+ `theme.colors.*` refereces) see the
-- update next frame with zero coordination.
local m = {}

local themes = require("ui.themes")
local prefs = require("state.preferences")
local idx = prefs.GetThemeIndex()
local current = themes[idx]
if current then
    m.colors = current.colors
end

--- Switch the active theme palette by index (1..3).
--- Called from the theme dropdown in midi-island/header.lua.
--- The module table reference is replaced so all `theme.colors.*` consumers
--- see the new palette on the next GFX frame (no init/restart needed).
function m.SetThemeIndex(idx)
    local t = themes[idx]
    if not t then return end
    m.colors = t.colors
end

return m
