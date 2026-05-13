-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
-- GROVE Scale Runner: Shared UI Helpers
local config = require("config")
local ui_store = require("state.ui")
local theme = require("ui.theme")
local api_guard = require("core.api-guard")
local helpers = {}

-- Set GFX color from {r,g,b,a} table with optional alpha multiplier
function helpers.SetColor(c, alpha_mult)
    gfx.set(c[1], c[2], c[3], (c[4] or 1) * (alpha_mult or 1))
end

-- Draw a tooltip at mouse position with optional font_size (default 11)
function helpers.DrawTooltip(text, font_size)
    if not ui_store.GetShowTooltips() then return end
    local fs = font_size or 11
    gfx.setfont(1, "Calibri", fs)
    local tw, th = gfx.measurestr(text)
    local tx = gfx.mouse_x + 14
    local ty = gfx.mouse_y - th - 6
    if tx + tw > gfx.w then tx = gfx.mouse_x - tw - 14 end
    if ty < 0 then ty = gfx.mouse_y + 14 end
    if ty + th + 6 > gfx.h then ty = gfx.mouse_y - th - 6 end
    helpers.SetColor({0, 0, 0, 0.75})
    -- Filled rounded rect via circles + rect (avoids dependency on components)
    local r = 4
    gfx.circle(tx - 4 + r, ty - 2 + r, r, 1, 1)
    gfx.circle(tx - 4 + tw + 8 - r, ty - 2 + r, r, 1, 1)
    gfx.circle(tx - 4 + r, ty - 2 + th + 4 - r, r, 1, 1)
    gfx.circle(tx - 4 + tw + 8 - r, ty - 2 + th + 4 - r, r, 1, 1)
    gfx.rect(tx - 4 + r, ty - 2, math.max(0, tw + 8 - r * 2) + 1, th + 4 + 1, 1)
    gfx.rect(tx - 4, ty - 2 + r, tw + 8 + 1, math.max(0, th + 4 - r * 2) + 1, 1)
    helpers.SetColor(theme.colors.text)
    gfx.x, gfx.y = tx, ty
    gfx.drawstr(text)
end

-- Medium abbreviations for full-view dropdowns
local FULL_ABBREV = {
    ["Major"] = "Major",
    ["Major Bebop"] = "Maj Bebop",
    ["Major Pentatonic"] = "Maj Penta",
    ["Minor Harmonic"] = "Min Harmo",
    ["Minor Hungarian"] = "Min Hunga",
    ["Minor Melodic"] = "Min Melod",
    ["Minor Natural (Aeolian)"] = "Min Natur",
    ["Minor Neopolitan"] = "Min Neopo",
    ["Minor Pentatonic"] = "Min Penta",
    ["Arabic"] = "Arabic",
    ["Blues"] = "Blues",
    ["Diminished"] = "Diminishe",
    ["Dominant Bebop"] = "Dom Bebop",
    ["Dorian"] = "Dorian",
    ["Enigmatic"] = "Enigmatic",
    ["Japanese Insen"] = "Jap Insen",
    ["Locrian"] = "Locrian",
    ["Lydian"] = "Lydian",
    ["Mixolydian"] = "Mixolydia",
    ["Neopolitan"] = "Neopolita",
    ["Phrygian"] = "Phrygian",
}

-- Ultra-short abbreviations for compact view (2+2 for two-word, first 5 for single-word)
local COMPACT_ABBREV = {
    ["Major"] = "Major",
    ["Major Bebop"] = "Ma Be",
    ["Major Pentatonic"] = "Ma Pe",
    ["Minor Harmonic"] = "Mi Ha",
    ["Minor Hungarian"] = "Mi Hu",
    ["Minor Melodic"] = "Mi Me",
    ["Minor Natural (Aeolian)"] = "Mi Na",
    ["Minor Neopolitan"] = "Mi Ne",
    ["Minor Pentatonic"] = "Mi Pe",
    ["Arabic"] = "Arabi",
    ["Blues"] = "Blues",
    ["Diminished"] = "Dimin",
    ["Dominant Bebop"] = "Do Be",
    ["Dorian"] = "Doria",
    ["Enigmatic"] = "Enigm",
    ["Japanese Insen"] = "Ja In",
    ["Locrian"] = "Locri",
    ["Lydian"] = "Lydia",
    ["Mixolydian"] = "Mixol",
    ["Neopolitan"] = "Neopo",
    ["Phrygian"] = "Phryg",
}

--- Compute scale note sets from root and scale indices.
--- Returns (scale_notes, note_to_degree) where scale_notes[note_idx] = true
--- and note_to_degree[note_idx] = degree for each scale interval.
--- Follows the Issue 13 caching pattern for reuse across caches.
function helpers.ComputeScaleNotes(root_idx, scale_idx)
    local scale_notes = {}
    local note_to_degree = {}
    local si = api_guard.ClampIndex(scale_idx, 1, #config.SCALES)
    local intervals = config.SCALES[si].intervals
    for degree, interval in ipairs(intervals) do
        local note_idx = ((root_idx - 1 + interval) % 12) + 1
        scale_notes[note_idx] = true
        note_to_degree[note_idx] = degree
    end
    return scale_notes, note_to_degree
end

function helpers.AbbreviateScale(name)
    return FULL_ABBREV[name] or name
end

function helpers.CompactAbbreviateScale(name)
    return COMPACT_ABBREV[name] or name
end

return helpers
