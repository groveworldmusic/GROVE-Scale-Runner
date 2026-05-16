-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Compact bar drawing
-- Renders the transport bar composite (key, scale, octave, chord, restore button)
-- Dependencies: config, theme, helpers, lice, positioning, state.compact
local config = require("config")
local midi_store = require("state.midi")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local lice = require("ui.lice")
local positioning = require("ui.positioning")
local compact_store = require("state.compact")
local api_guard = require("core.api-guard")
local prefs = require("state.preferences")

local m = {}

-- =========================================================
-- CONSTANTS
-- =========================================================

local BAR_H = 26
local RESTORE_BTN_SIZE = 12

-- =========================================================
-- COMPACT BAR
-- =========================================================

-- Draw the compact bar content onto the LICE bitmap.
-- ctx: {cv_x, cv_y, cv_w, restore_btn_x, current_mode}
-- Uses positioning getters (not direct upvalues) for cross-module state.
function m.CompactBar(ctx)
    local bm = compact_store.GetLiceBitmap()
    local font = compact_store.GetLiceFont()

    local ri = api_guard.ClampIndex(prefs.GetRootIndex(), 1, #config.NOTE_NAMES)
    local si = api_guard.ClampIndex(prefs.GetScaleIndex(), 1, #config.SCALES)
    local ci = api_guard.ClampIndex(prefs.GetChordModeIndex(), 1, #config.CHORD_MODES)
    local key_n = config.NOTE_NAMES[ri]
    local scale_n = helpers.CompactAbbreviateScale(config.SCALES[si].name)
    local oct_n = "C" .. math.floor(prefs.GetOctave())
    local chord_n = (ci == 1) and "Note" or config.CHORD_MODES[ci].name:sub(1, 3)

    local wk, ws, wo, wch = 16, 34, 16, 24
    local x = 6

    lice.DrawModeHint(bm, font, x, ctx.cv_y + 6, key_n, theme.colors.text)
    x = x + wk

    local disp, dc = scale_n, theme.colors.text
    if midi_store.GetActiveNoteDrawTimer() > 0 then
        local nc = midi_store.GetLastNotePlayed() or ""
        if nc ~= "None" then disp = nc:sub(1, 4); dc = theme.colors.pad_active end
    end

    lice.DrawModeHint(bm, font, x, ctx.cv_y + 6, disp, dc)
    x = x + ws
    lice.DrawModeHint(bm, font, x, ctx.cv_y + 6, oct_n, theme.colors.text_dim)
    x = x + wo
    lice.DrawModeHint(bm, font, x, ctx.cv_y + 6, chord_n, theme.colors.text_dim)
    x = x + wch

    -- Restore full-view button (4px after chord text)
    local btn_size = RESTORE_BTN_SIZE
    local btn_x = x + 4
    local btn_y = ctx.cv_y + (ctx.cv_h - btn_size) / 2
    positioning.SetRestoreBtnX(btn_x)
    lice.DrawRoundedRectFill(bm, btn_x, btn_y, btn_size, btn_size, theme.colors.text_dim, false, 2)
end

return m
