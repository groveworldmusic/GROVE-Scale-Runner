-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
-- GROVE Scale Runner: Color Semantics for Degree Grade Colors
local config = require("config")
local ui_store = require("state.ui")
local theme = require("ui.theme")

local colors = {}

-- ROMAN_NUMERALS table shared with format.lua
colors.ROMAN_NUMERALS = {"I", "II", "III", "IV", "V", "VI", "VII"}

-- Resolve display color for a degree: grade color or flat blue depending on mode
function colors.DegreeColor(degree)
    if ui_store.GetColorMode() ~= "grade" then
        return theme.colors.btn_active
    end
    return (theme.colors.grade_colors or {})[((degree-1) % 7) + 1] or theme.colors.btn_active
end

return colors
