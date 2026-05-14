-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Formatting helpers for note names, chord labels, and roman numerals
local config = require("config")
local midi = require("core.midi")
local colors = require("ui.colors")
local api_guard = require("core.api-guard")

local format = {}

-- ctx: {root_index, scale_index, degree, octave}
-- Returns the note name (e.g. "C", "D#", "F")
function format.NoteName(ctx)
    local note_num = midi.GetMidiNote(ctx.root_index, ctx.scale_index, ctx.degree, ctx.octave)
    return config.NOTE_NAMES[(note_num % 12) + 1]
end

-- ctx: {root_index, scale_index, degree, octave, chord_mode_index}
-- Returns note name only if chord_mode_index == 1 (Off/Note mode),
-- otherwise returns "Note ChordType" (e.g. "C Maj", "D# Tri")
function format.ChordLabel(ctx)
    local nn = format.NoteName(ctx)
    local ci = api_guard.ClampIndex(ctx.chord_mode_index, 1, #config.CHORD_MODES)
    if ci <= 1 then return nn end
    local mode_name = config.CHORD_MODES[ci].name
    return nn .. " " .. mode_name:sub(1,1):upper() .. mode_name:sub(2):lower()
end

-- Returns roman numeral string for degree (1-7) or "?" for out of range
function format.RomanNumeral(degree)
    return colors.ROMAN_NUMERALS[degree] or "?"
end

return format
