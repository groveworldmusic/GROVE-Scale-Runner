-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Drag Preview UI (extracted from components.lua)
local config = require("config")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local helpers = require("ui.helpers")
local theme = require("ui.theme")
local colors = require("ui.colors")
local format = require("ui.format")
local prefs = require("state.preferences")

-- NOTE: `components` (for DrawRoundedRect) is resolved lazily inside each function
-- to avoid circular require at load time (components.lua also requires this module)

local m = {}

function m.DrawDragPreview(w, h)
    local components = require("ui.components")
    if (gfx.mouse_cap & 1) == 0 and drag_store.GetIsDragging() then
        drag_store.Reset()
    end
    if not drag_store.GetIsDragging() then return end

    -- Scale the original pad/slot size to a compact preview maintaining aspect ratio
    local scale = gfx.w / 39914
    local max_preview_w = math.min(100, math.floor(6000 * scale))
    local max_preview_h = math.min(80, math.floor(5000 * scale))
    local cw, ch
    if w / h > max_preview_w / max_preview_h then
        cw = max_preview_w
        ch = math.floor(h * max_preview_w / w)
    else
        ch = max_preview_h
        cw = math.floor(w * max_preview_h / h)
    end
    local x, y = gfx.mouse_x - cw/2, gfx.mouse_y - ch/2

    -- Preview background: match grade color of dragged item
    local preview_color = theme.colors.btn_active
    if drag_store.GetSourceDegree() ~= -1 then
        preview_color = colors.DegreeColor(drag_store.GetSourceDegree())
    elseif drag_store.GetSourceSlotIdx() ~= -1 then
        local src_slot = seq_store.GetProgressionEntry(drag_store.GetSourceSlotIdx())
        if src_slot then
            preview_color = colors.DegreeColor(src_slot.degree)
        end
    end
    helpers.SetColor(preview_color, 0.8)
    components.DrawRoundedRect(x, y, cw, ch, 8, true)

    helpers.SetColor(theme.colors.text)

    if drag_store.GetSourceDegree() ~= -1 then
        -- Dragging from a pad: show actual note name + roman numeral
        local degree = drag_store.GetSourceDegree()
        local label = format.ChordLabel({root_index=prefs.GetRootIndex(), scale_index=prefs.GetScaleIndex(), degree=degree, octave=prefs.GetOctave(), chord_mode_index=prefs.GetChordModeIndex()})
        local roman = format.RomanNumeral(degree)

        local main_font = math.max(math.floor(ch * 0.35), 8)
        local sub_font = math.max(math.floor(ch * 0.25), 7)

        gfx.setfont(1, "Calibri", main_font)
        local lw, lh = gfx.measurestr(label)
        gfx.x, gfx.y = x + (cw - lw) / 2, y + (ch / 2) - lh - 2
        gfx.drawstr(label)

        gfx.setfont(1, "Calibri", sub_font)
        local rw = gfx.measurestr(roman)
        gfx.x, gfx.y = x + (cw - rw) / 2, y + (ch / 2) + 4
        gfx.drawstr(roman)

    elseif drag_store.GetSourceSlotIdx() ~= -1 then
        -- Dragging from a slot: show actual slot content
        local slot = seq_store.GetProgressionEntry(drag_store.GetSourceSlotIdx())
        if slot then
            local label = format.ChordLabel({root_index=slot.root_index, scale_index=slot.scale_index, degree=slot.degree, octave=slot.octave, chord_mode_index=slot.chord_mode_index})
            local roman = format.RomanNumeral(slot.degree)

            local main_font = math.max(math.floor(ch * 0.35), 8)
            local sub_font = math.max(math.floor(ch * 0.25), 7)

            gfx.setfont(1, "Calibri", main_font)
            local lw, lh = gfx.measurestr(label)
            gfx.x, gfx.y = x + (cw - lw) / 2, y + (ch / 2) - lh - 2
            gfx.drawstr(label)

            gfx.setfont(1, "Calibri", sub_font)
            local rw = gfx.measurestr(roman)
            gfx.x, gfx.y = x + (cw - rw) / 2, y + (ch / 2) + 4
            gfx.drawstr(roman)
        else
            local main_font = math.max(math.floor(ch * 0.35), 8)
            gfx.setfont(1, "Calibri", main_font)
            local label = "↕ REORDER"
            local lw, lh = gfx.measurestr(label)
            gfx.x, gfx.y = x + (cw - lw) / 2, y + (ch - lh) / 2
            gfx.drawstr(label)
        end
    end

end

return m
