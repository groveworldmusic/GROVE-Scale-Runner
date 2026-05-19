-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Scale Pad UI (extracted from components.lua)
local config = require("config")
local vkey_map = require("core.vkey-map")
local drag_store = require("state.drag")
local midi_store = require("state.midi")
local ui_store = require("state.ui")
local helpers = require("ui.helpers")
local theme = require("ui.theme")
local colors = require("ui.colors")
local format = require("ui.format")
local midi = require("core.midi")
local prefs = require("state.preferences")

-- NOTE: `components` (for DrawRoundedRect) is resolved lazily inside each function
-- to avoid circular require at load time (components.lua also requires pads.lua)

local m = {}

-- QWERTY key labels for degrees 1-7 (base octave)
local DEGREE_KEY_LABELS = {"Q", "W", "E", "R", "T", "Y", "U"}

function m.DrawScalePad(x, y, w, h, degree, main_font_size, sub_font_size, total_degrees)
    local components = require("ui.components")
    local disabled = total_degrees and degree > total_degrees
    local hover = not disabled and gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    local label = format.ChordLabel({root_index=prefs.GetRootIndex(), scale_index=prefs.GetScaleIndex(), degree=degree, octave=prefs.GetOctave(), chord_mode_index=prefs.GetChordModeIndex()})
    local roman = format.RomanNumeral(degree)

    local active = false
    if not disabled then
        for _, state in pairs(midi_store.GetKeyStates()) do if state.is_pressed and vkey_map.GetVkeyMap()[state.code].deg == degree then active = true break end end
        if midi_store.GetMousePadState().active_degree == degree then active = true end
    end

    -- Capture click once per frame (Issue A4): read at top, reuse in both drag and chord-play branches
    local click = ui_store.GetMouseClick()

    -- Flash trigger on pad activation
    if degree >= 1 and degree <= 7 then
        local prev = ui_store.GetPadFlashPrevActive()[degree]
        if active and not prev then
            ui_store.SetPadFlashDegree(degree)
            ui_store.SetPadFlashTimer(10)
        end
        ui_store.GetPadFlashPrevActive()[degree] = active
    end

    -- Base
    if disabled then
        helpers.SetColor({0.3, 0.3, 0.3, 0.35})
    else
        helpers.SetColor(colors.DegreeColor(degree), active and 1 or 0.9)
    end
    components.DrawRoundedRect(x, y, w, h, 10, true)

    if hover and not disabled then
        helpers.SetColor({1, 1, 1, 0.15})
        components.DrawRoundedRect(x, y, w, h, 10, true)

        -- Bug fix: only start drag after moving 8px (distinguish click from drag)
        if (gfx.mouse_cap & 1) == 1 and not drag_store.GetIsDragging() and not ui_store.GetSliderDragging() then
            if not drag_store.GetPendingDegree() and click then
                drag_store.SetPendingDegree(degree)
                drag_store.SetPendingSlotIdx(nil)  -- Issue B3: cross-clear pending_slot_idx
                drag_store.SetStartX(gfx.mouse_x)
                drag_store.SetStartY(gfx.mouse_y)
            else
                local dx = gfx.mouse_x - drag_store.GetStartX()
                local dy = gfx.mouse_y - drag_store.GetStartY()
                if math.sqrt(dx*dx + dy*dy) >= 8 then
                    drag_store.SetIsDragging(true)
                    drag_store.SetSourceDegree(drag_store.GetPendingDegree())
                    -- Only release pad-held notes when drag starts (Issue 5)
                    local mps = midi_store.GetMousePadState()
                    for _, n in ipairs(mps.midi_notes) do
                        midi.SendMidi(n, false)
                    end
                    mps.midi_notes = {}
                    mps.active_degree = -1  -- Issue A2: reset active_degree so pad can be clicked again after drag
                end
            end
        end

        if not drag_store.GetIsDragging() then
            local key_label = DEGREE_KEY_LABELS[degree]
            helpers.DrawTooltip(key_label and (roman .. " (" .. key_label .. ")") or roman, 11)
        end
    end

    -- Clear pending drag if mouse released
    if (gfx.mouse_cap & 1) == 0 and drag_store.GetPendingDegree() then
        drag_store.SetPendingDegree(nil)
    end

    if disabled then
        helpers.SetColor({0.5, 0.5, 0.5, 0.6})
    else
        helpers.SetColor(theme.colors.text)
    end
    gfx.setfont(1, "Calibri", main_font_size or 18)
    local cw, ch = gfx.measurestr(label)
    gfx.x, gfx.y = x + (w-cw)/2, y + (h/2) - ch
    gfx.drawstr(label)

    gfx.setfont(1, "Calibri", sub_font_size or 14)
    local rw = gfx.measurestr(roman)
    gfx.x, gfx.y = x + (w-rw)/2, y + (h/2) + 4
    gfx.drawstr(roman)

    -- Keyboard shortcut hint
    local key_label = DEGREE_KEY_LABELS[degree]
    if key_label and not disabled then
        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", sub_font_size or 14)
        local kw = gfx.measurestr(key_label)
        gfx.x, gfx.y = x + w - kw - 4, y + 2
        gfx.drawstr(key_label)
    end

    if not disabled and click and hover then
        local mps = midi_store.GetMousePadState()
        if mps.active_degree ~= degree then
            mps.active_degree = degree
            local vel = midi_store.GetUseVelocity() and (85 + math.random(30)) or 100
            mps.midi_notes = midi.TriggerChord(degree, true, nil, vel, prefs.GetInversionIndex())
        end
    elseif not disabled and midi_store.GetMousePadState().active_degree == degree and (gfx.mouse_cap & 1) == 0 then
        -- Only turn off mouse-pad notes, not all notes (avoids killing QWERTY-held notes)
        local mps = midi_store.GetMousePadState()
        for _, n in ipairs(mps.midi_notes) do
            midi.SendMidi(n, false)
        end
        mps.midi_notes = {}
        mps.active_degree = -1
    end

    -- Flash overlay on top of everything
    if ui_store.GetPadFlashDegree() == degree and ui_store.GetPadFlashTimer() > 0 then
        local alpha = (ui_store.GetPadFlashTimer() / 10) * 0.4
        helpers.SetColor({1, 1, 1, alpha})
        components.DrawRoundedRect(x, y, w, h, 10, true)
        ui_store.SetPadFlashTimer(ui_store.GetPadFlashTimer() - 1)
        if ui_store.GetPadFlashTimer() == 0 then
            ui_store.SetPadFlashDegree(-1)
        end
    end
end

return m
