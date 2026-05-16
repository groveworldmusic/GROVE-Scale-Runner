-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Views — Docked Transport Bar
-- DrawDockedTransportBar: compact 50px horizontal strip.
-- Extracted from views.lua (Sprint 2).

local config = require("config")
local seq_store = require("state.sequencer")
local midi_store = require("state.midi")
local ui_store = require("state.ui")
local prefs = require("state.preferences")
local theme = require("ui.theme")
local components = require("ui.components")
local helpers = require("ui.helpers")
-- persist removed; prefs.SetKey marks dirty_key, TickSaveDebounce() flushes
local sequencer = require("core.sequencer")
local progression = require("core.progression")
local gfx_safe = require("ui.gfx-safe")
local api_guard = require("core.api-guard")

local m = {}

-- Docked Transport Bar: compact 50px horizontal strip
function m.DrawDockedTransportBar(dock_w, dock_h)
    helpers.SetColor(theme.colors.bg)
    gfx.rect(0, 0, dock_w, dock_h, 1)

    local btn_h = 38
    local btn_y = (dock_h - btn_h) / 2
    local btn_w = 50
    local gap = 2
    local x_pos = 10

    -- [ROOT] button - cycles through root notes
    if components.DrawTransportButton(config.NOTE_NAMES[api_guard.ClampIndex(prefs.GetRootIndex(), 1, 12)], x_pos, btn_y, btn_w, btn_h) then
        prefs.SetRootIndex((prefs.GetRootIndex() % 12) + 1)
    end
    x_pos = x_pos + btn_w + gap

    -- [SCALE] button - cycles through scales
    local si_dt = api_guard.ClampIndex(prefs.GetScaleIndex(), 1, #config.SCALES)
    local scale_abbr = helpers.AbbreviateScale(config.SCALES[si_dt].name)
    if components.DrawTransportButton(scale_abbr, x_pos, btn_y, btn_w + 20, btn_h) then
        prefs.SetScaleIndex((prefs.GetScaleIndex() % #config.SCALES) + 1)
    end
    x_pos = x_pos + btn_w + 20 + gap

    -- [OCT−] button
    if components.DrawTransportButton("−", x_pos, btn_y, 30, btn_h) then
        prefs.SetOctave(math.floor(math.max(0, prefs.GetOctave() - 1)))
    end
    x_pos = x_pos + 30 + gap

    -- [OCT+] button
    if components.DrawTransportButton("+", x_pos, btn_y, 30, btn_h) then
        prefs.SetOctave(math.floor(math.min(8, prefs.GetOctave() + 1)))
    end
    x_pos = x_pos + 30 + gap

    -- [CHORD] button - cycles chord modes
    local ci_dt = api_guard.ClampIndex(prefs.GetChordModeIndex(), 1, #config.CHORD_MODES)
    local chord_label = config.CHORD_MODES[ci_dt].name
    if components.DrawTransportButton(chord_label, x_pos, btn_y, btn_w, btn_h) then
        prefs.SetChordModeIndex((prefs.GetChordModeIndex() % #config.CHORD_MODES) + 1)
    end
    x_pos = x_pos + btn_w + gap

    -- [VEL] button - toggle velocity
    local vel_label = midi_store.GetUseVelocity() and "VEL" or "VEL-"
    local vel_active = midi_store.GetUseVelocity()
    local vel_hover = gfx.mouse_x >= x_pos and gfx.mouse_x <= x_pos + btn_w and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
    helpers.SetColor(vel_active and theme.colors.btn_active or (vel_hover and theme.colors.btn_hover or theme.colors.btn_bg))
    components.DrawRoundedRect(x_pos, btn_y, btn_w, btn_h, 6, true)
    helpers.SetColor(vel_active and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 11)
    local vw, vh = gfx.measurestr(vel_label)
    gfx.x, gfx.y = x_pos + (btn_w - vw) / 2, btn_y + (btn_h - vh) / 2
    gfx.drawstr(vel_label)
    if ui_store.GetMouseClick() and vel_hover then
        midi_store.SetUseVelocity(not midi_store.GetUseVelocity())
    end
    x_pos = x_pos + btn_w + gap

    -- [PLAY/STOP] button
    local is_playing = seq_store.GetIsPlaying()
    local play_hover = gfx.mouse_x >= x_pos and gfx.mouse_x <= x_pos + btn_w and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
    helpers.SetColor(is_playing and theme.colors.slot_playing or (play_hover and theme.colors.btn_hover or theme.colors.btn_bg))
    components.DrawRoundedRect(x_pos, btn_y, btn_w, btn_h, 6, true)
    local cx, cy = x_pos + btn_w / 2, btn_y + btn_h / 2
    local s = 12
    if is_playing then
        helpers.SetColor({0, 0, 0, 0.6})
        gfx.rect(cx - s / 2, cy - s / 2, s, s, 1)
    else
        helpers.SetColor(theme.colors.slot_playing)
        gfx.triangle(cx - s / 2, cy - s / 2, cx - s / 2, cy + s / 2, cx + s / 2, cy)
    end
    if ui_store.GetMouseClick() and play_hover then
        if is_playing then sequencer.Stop() else seq_store.SetIsPlaying(true) end
    end
    x_pos = x_pos + btn_w + gap

    -- [CLEAR] button - clear progression
    if components.DrawTransportButton("CLR", x_pos, btn_y, btn_w, btn_h) then
        progression.Clear()
    end
    x_pos = x_pos + btn_w + gap

    -- [◄ Undock] button - undock and return to floating (Issue 6: U+25C4 better glyph support)
    if components.DrawTransportButton("◄", x_pos, btn_y, 50, btn_h) then
        gfx.dock(0)
        ui_store.SetDockedMode(false)
        ui_store.SetDockId(0)
        -- Resize back to normal window
        gfx_safe.SafeGfxInit("GROVE SCALE RUNNER", 720, 497, 0, ui_store.GetViewOffsetX(), ui_store.GetViewOffsetY())
    end
end

return m
