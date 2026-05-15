-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Piano Keyboard UI (extracted from components.lua)
local config = require("config")
local midi_store = require("state.midi")
local ui_store = require("state.ui")
local helpers = require("ui.helpers")
local theme = require("ui.theme")
local colors = require("ui.colors")
local prefs = require("state.preferences")

-- NOTE: `components` (for DrawRoundedRect) is resolved lazily inside each function
-- to avoid circular require at load time (components.lua also requires piano.lua)

local m = {}

-- Shared piano keyboard layout constants
-- Used by both the full-view GFX piano (DrawPianoKeyboard) and compact LICE piano
local PIANO_LAYOUT = {
    -- White key count per octave (C D E F G A B)
    white_keys_per_octave = 7,
    -- Black key count per octave (C# D# F# G# A#)
    black_keys_per_octave = 5,
    -- Black key width/height as fraction of white key width / total height
    black_key_width_ratio = 0.65,
    black_key_height_ratio = 0.65,
    -- Note indices within an octave that are white keys (1=C, 3=D, ..., 12=B)
    white_key_note_indices = {1, 3, 5, 6, 8, 10, 12},
    -- Black key spec: {idx=note_index, pos=position_of_white_key_to_the_left}
    black_key_specs = {
        {idx=2, pos=1},   -- C# between C (pos 1) and D
        {idx=4, pos=2},   -- D# between D (pos 2) and E
        {idx=7, pos=4},   -- F# between F (pos 4) and G
        {idx=9, pos=5},   -- G# between G (pos 5) and A
        {idx=11, pos=6},  -- A# between A (pos 6) and B
    },
    -- Octave range: C2 to C8
    start_note = 36,   -- MIDI note C2 (leftmost key)
    end_note = 108,    -- MIDI note C8 (rightmost key)
    num_keys = 73,     -- Total keys from C2 through C8 inclusive
}

-- Cached scale note tables for DrawPianoKeyboard (Issue 13)
local cached_scale_root = nil
local cached_scale_idx = nil
local cached_scale_notes = {}
local cached_note_to_degree = {}

function m.DrawPianoKeyboard(x, y, w, h, font_size)
    local components = require("ui.components")
    local white_w = math.floor(w / PIANO_LAYOUT.white_keys_per_octave)
    -- Center keys horizontally if width isn't evenly divisible by 7
    local total_keys_w = white_w * PIANO_LAYOUT.white_keys_per_octave
    local slack = w - total_keys_w
    local x_off = x + math.floor(slack / 2)

    local black_w = math.floor(white_w * PIANO_LAYOUT.black_key_width_ratio)
    local black_h = math.floor(h * PIANO_LAYOUT.black_key_height_ratio)
    local octave_w = PIANO_LAYOUT.white_keys_per_octave * white_w

    local mx, my = gfx.mouse_x, gfx.mouse_y

    -- Cached scale note sets (Issue 13 pattern, shared helper)
    if cached_scale_root ~= prefs.GetRootIndex() or cached_scale_idx ~= prefs.GetScaleIndex() then
        cached_scale_notes, cached_note_to_degree = helpers.ComputeScaleNotes(prefs.GetRootIndex(), prefs.GetScaleIndex())
        cached_scale_root = prefs.GetRootIndex()
        cached_scale_idx = prefs.GetScaleIndex()
    end
    local scale_notes = cached_scale_notes
    local note_to_degree = cached_note_to_degree

    -- Pre-compute active note pitch-class lookup (Issue 18): avoids O(N·M) inner loop
    local active_mod12 = {}
    for midi_note, _ in pairs(midi_store.GetActiveNotes()) do
        active_mod12[(midi_note % 12) + 1] = true
    end

    -- Draw White Keys first
    for i, wk in ipairs(PIANO_LAYOUT.white_key_note_indices) do
        local wx = x_off + (i-1) * white_w
        local is_root = (prefs.GetRootIndex() == wk)
        local in_scale = scale_notes[wk]

        if is_root then
            helpers.SetColor(theme.colors.btn_active)
            components.DrawRoundedRect(wx, y, white_w - 2, h, 4, true)
        else
            helpers.SetColor(theme.colors.piano_white)
            components.DrawRoundedRect(wx, y, white_w - 2, h, 4, true)
            -- Bottom edge indicator for scale notes (grade-colored)
            if in_scale then
                local deg = note_to_degree[wk]
                helpers.SetColor(colors.DegreeColor(deg), 0.7)
                gfx.rect(wx + 4, y + h - 5, white_w - 10, 3, 1)
            end
        end

        helpers.SetColor(is_root and theme.colors.text or theme.colors.text_dark)
        gfx.setfont(1, "Calibri", font_size or 12)
        local n = config.NOTE_NAMES[wk]
        local nw, nh = gfx.measurestr(n)
        gfx.x, gfx.y = wx + (white_w - nw)/2, y + h - nh - 10
        gfx.drawstr(n)

        -- Active note glow (Issue 18): O(1) lookup via pre-computed pitch-class set
        if not is_root and active_mod12[wk] then
            local deg = note_to_degree[wk]
            local glow = deg and colors.DegreeColor(deg) or {1, 1, 1, 0.3}
            helpers.SetColor(glow, 0.2)
            components.DrawRoundedRect(wx, y, white_w - 2, h, 4, true)
        end
    end

    -- Draw Black Keys on top with text
    for _, bk in ipairs(PIANO_LAYOUT.black_key_specs) do
        local bx = x_off + (bk.pos * white_w) - black_w/2
        local is_root = (prefs.GetRootIndex() == bk.idx)
        local in_scale = scale_notes[bk.idx]

        if is_root then
            helpers.SetColor(theme.colors.btn_active)
            components.DrawRoundedRect(bx, y, black_w, black_h, 3, true)
        else
            helpers.SetColor(theme.colors.piano_black)
            components.DrawRoundedRect(bx, y, black_w, black_h, 3, true)
            -- Bottom edge indicator for scale notes (grade-colored)
            if in_scale then
                local deg = note_to_degree[bk.idx]
                helpers.SetColor(colors.DegreeColor(deg), 0.7)
                gfx.rect(bx + 3, y + black_h - 4, black_w - 6, 2, 1)
            end
        end

        -- Drawing text for black keys
        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", font_size or 12)
        local n = config.NOTE_NAMES[bk.idx]
        local nw, nh = gfx.measurestr(n)
        gfx.x, gfx.y = bx + (black_w - nw)/2, y + black_h - nh - 10
        gfx.drawstr(n)

        -- Active note glow for black keys (Issue 18): O(1) lookup
        if not is_root and active_mod12[bk.idx] then
            local deg = note_to_degree[bk.idx]
            local glow = deg and colors.DegreeColor(deg) or {1, 1, 1, 0.4}
            helpers.SetColor(glow, 0.3)
            components.DrawRoundedRect(bx, y, black_w, black_h, 3, true)
        end
    end


    -- Input Handling
    if ui_store.GetMouseClick() then
        local clicked_idx = 0
        for _, bk in ipairs(PIANO_LAYOUT.black_key_specs) do
            local bx = x_off + (bk.pos * white_w) - black_w/2
            if mx >= bx and mx <= bx + black_w and my >= y and my <= y + black_h then clicked_idx = bk.idx end
        end
        if clicked_idx == 0 then
                for i, wk in ipairs(PIANO_LAYOUT.white_key_note_indices) do
                local wx = x_off + (i-1) * white_w
                if mx >= wx and mx <= wx + white_w and my >= y and my <= y + h then clicked_idx = wk end
            end
        end
        if clicked_idx > 0 then config.state.root_index = clicked_idx end
    end
end

return m
