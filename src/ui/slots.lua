-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Progression Slot UI (extracted from components.lua)
local config = require("config")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local ui_store = require("state.ui")
local helpers = require("ui.helpers")
local theme = require("ui.theme")
local colors = require("ui.colors")
local format = require("ui.format")
local midi = require("core.midi")
local midi_store = require("state.midi")
local progression = require("core.progression")

-- NOTE: `components` (for DrawRoundedRect) is resolved lazily inside each function
-- to avoid circular require at load time (components.lua also requires this module)

local m = {}

-- Extracted: background, glow, progress bar, flash overlay
local function DrawSlotBackground(global_idx, x, y, w, h, slot, play)
    local components = require("ui.components")
    -- Background Glow for playing slot
    if play then
        helpers.SetColor(theme.colors.slot_playing, 0.2)
        components.DrawRoundedRect(x-4, y-4, w+8, h+8, 12, true)
    end

    if slot then
        local slot_color = colors.DegreeColor(slot.degree)
        helpers.SetColor(slot_color)
        if play then helpers.SetColor(theme.colors.slot_playing, 0.4) end
        components.DrawRoundedRect(x, y, w, h, 8, true)
    else
        helpers.SetColor(theme.colors.text_dim, 0.2)
        if play then helpers.SetColor(theme.colors.slot_playing, 0.4) end
        components.DrawRoundedRect(x, y, w, h, 8, false)

        -- Empty state hint (only when not dragging)
        if not drag_store.GetIsDragging() then
            helpers.SetColor(theme.colors.text_dim, 0.15)
            gfx.setfont(1, "Calibri", math.floor(h * 0.3))
            local pw, ph = gfx.measurestr("+")
            gfx.x, gfx.y = x + (w - pw) / 2, y + (h - ph) / 2
            gfx.drawstr("+")
        end
    end

    -- Slot flash highlight on drop
    if seq_store.GetSlotFlashIdx() == global_idx and seq_store.GetSlotFlashTimer() > 0 then
        helpers.SetColor(theme.colors.slot_playing, (seq_store.GetSlotFlashTimer() / 10) * 0.5)
        components.DrawRoundedRect(x, y, w, h, 8, true)
        seq_store.SetSlotFlashTimer(seq_store.GetSlotFlashTimer() - 1)
        if seq_store.GetSlotFlashTimer() <= 0 then
            seq_store.SetSlotFlashIdx(-1)
            seq_store.SetSlotFlashTimer(0)
        end
    end

    -- PROGRESS BAR OVERLAY
    if play and (seq_store.GetProgress() or 0) > 0 then
        helpers.SetColor(theme.colors.slot_playing, 0.4)
        local prog_w = math.floor(w * seq_store.GetProgress())
        components.DrawRoundedRect(x, y, prog_w, h, 8, true)
    end

    -- SUBDIVISION DOTS at slot bottom (show fill state always, active sub during play)
    local sub_idx = config.state.subdivision_index or 1
    local subdivision = config.SUBDIVISION_MODES[sub_idx] or 1
    if slot and subdivision > 1 then
        local active_sub = play and (seq_store.GetCurrentSubStep() or 0) or -1
        local circle_r = math.max(2, math.min(4, math.floor(h * 0.035)))
        local spacing = circle_r * 3.5
        local rows = subdivision > 8 and 2 or 1
        local per_row = subdivision / rows
        local total_w = per_row * spacing
        local start_x = x + (w - total_w) / 2 + circle_r
        local circle_y_base = y + h - circle_r * 3.5
        for i = 0, subdivision - 1 do
            local row = math.floor(i / per_row)
            local col = i % per_row
            local cx = start_x + col * spacing
            local cy = circle_y_base - row * (circle_r * 3)
            if i == active_sub then
                helpers.SetColor(theme.colors.page_active)
            elseif slot.subs and slot.subs[i + 1] then
                helpers.SetColor(theme.colors.text)  -- filled (has sub-entry)
            elseif not slot.subs and i == 0 then
                helpers.SetColor(theme.colors.text)  -- legacy: first dot is always filled
            else
                helpers.SetColor(theme.colors.page_inactive)  -- empty
            end
            gfx.circle(cx, cy, circle_r, 1, 1)
        end
    end
end

-- Extracted: note name, roman numeral, slot number
--- Supports dynamic chord text when playback sub-step changes for subdivided slots.
local function DrawSlotLabel(global_idx, x, y, w, h, slot, play)
    local components = require("ui.components")
    -- Slot number (top-left corner)
    helpers.SetColor(theme.colors.text_dim, 0.3)
    gfx.setfont(1, "Calibri", math.floor(h * 0.15))
    local num_str = tostring(global_idx)
    gfx.x, gfx.y = x + 4, y + 2
    gfx.drawstr(num_str)

    if slot then
        -- Resolve the effective degree: use active sub-step during playback if subdivided
        local display_degree = slot.degree
        local display_velocity = slot.velocity
        if play and slot.subs and #slot.subs > 0 then
            local active_sub = seq_store.GetCurrentSubStep() or 0
            local sub = slot.subs[active_sub + 1]
            if sub and sub.degree then
                display_degree = sub.degree
                display_velocity = sub.velocity
            end
        end
        
        local label = format.ChordLabel({root_index=slot.root_index, scale_index=slot.scale_index, degree=display_degree, octave=slot.octave, chord_mode_index=slot.chord_mode_index})
        
        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", math.floor(h * 0.35))
        local nw, nh = gfx.measurestr(label)
        gfx.x, gfx.y = x+(w-nw)/2, y + (h/2) - nh - 4
        gfx.drawstr(label)
        
        gfx.setfont(1, "Calibri", math.floor(h * 0.25))
        local deg = format.RomanNumeral(display_degree)
        local dw = gfx.measurestr(deg)
        gfx.x, gfx.y = x+(w-dw)/2, y + (h/2) - 2
        gfx.drawstr(deg)
    end
end

-- Extracted: hover, tooltips, right-click delete, drag-start, drag-drop swap/new
function m.HandleSlotInteraction(global_idx, x, y, w, h, slot, hover)
    local components = require("ui.components")
    if not hover then return end

    helpers.SetColor({1,1,1,0.1})
    components.DrawRoundedRect(x, y, w, h, 8, true)

    -- Drag target highlight: match dragged item's grade color
    if drag_store.GetIsDragging() then
        local drag_deg = drag_store.GetSourceDegree()
        if drag_deg == -1 and drag_store.GetSourceSlotIdx() ~= -1 then
            local src = seq_store.GetProgressionEntry(drag_store.GetSourceSlotIdx())
            if src then drag_deg = src.degree end
        end
        local highlight = colors.DegreeColor(drag_deg)
        helpers.SetColor(highlight, 0.3)
        components.DrawRoundedRect(x, y, w, h, 8, true)
    end

    -- RIGHT CLICK TO DELETE (on fresh click-down only)
    if (gfx.mouse_cap & 2) == 2 and (ui_store.GetLastMouseCap() & 2) == 0 then
        progression.Remove(global_idx)
    end

    -- CLICK + DRAG: track pending, start drag only after 8px threshold
    if (gfx.mouse_cap & 1) == 1 and not drag_store.GetIsDragging() and not ui_store.GetSliderDragging() and slot then
        if not drag_store.GetPendingSlotIdx() then
            drag_store.SetPendingSlotIdx(global_idx)
            drag_store.SetStartX(gfx.mouse_x)
            drag_store.SetStartY(gfx.mouse_y)
        elseif drag_store.GetPendingSlotIdx() == global_idx then
            local dx = gfx.mouse_x - drag_store.GetStartX()
            local dy = gfx.mouse_y - drag_store.GetStartY()
            if math.sqrt(dx*dx + dy*dy) >= 8 then
                drag_store.SetIsDragging(true)
                drag_store.SetSourceSlotIdx(global_idx)
                drag_store.SetPendingSlotIdx(nil)
            end
        end
    end

    -- Clear pending if mouse released without drag
    if (gfx.mouse_cap & 1) == 0 and drag_store.GetPendingSlotIdx() == global_idx then
        -- LEFT CLICK TO PLAY NOTE (no drag happened)
        if slot then
            local inv = config.state.inversion_index
            local click_degree = slot.degree
            if slot.subs and #slot.subs > 0 then
                click_degree = slot.subs[1].degree
            end
            midi.TriggerChord(click_degree, true, slot, nil, inv)
            midi.TriggerChord(click_degree, false, slot, nil, inv)
        end
        drag_store.SetPendingSlotIdx(nil)
    end

    -- Drop Logic (Left Release after drag)
    if drag_store.GetIsDragging() and (gfx.mouse_cap & 1) == 0 then
        if drag_store.GetSourceSlotIdx() ~= -1 and drag_store.GetSourceSlotIdx() ~= global_idx then
            -- SWAP instead of overwrite
            progression.Swap(drag_store.GetSourceSlotIdx(), global_idx)
        elseif drag_store.GetSourceDegree() ~= -1 then
            -- NEW FROM PAD — capture velocity with humanization if enabled
            local entry_velocity
            if midi_store.GetUseVelocity() then
                entry_velocity = 85 + math.random(30)
            else
                entry_velocity = nil  -- falls back to 100 in materializer
            end
            
            local sub_idx = config.state.subdivision_index or 1
            local subdivision = config.SUBDIVISION_MODES[sub_idx] or 1
            
            if subdivision > 1 then
                -- SUBDIVIDED SLOT: append to subs[] array
                local existing = seq_store.GetProgressionEntry(global_idx)
                local entry
                
                if existing and existing.subs and #existing.subs > 0 then
                    -- Append to existing subs array (up to subdivision count)
                    entry = existing
                    if #entry.subs < subdivision then
                        table.insert(entry.subs, {
                            degree = drag_store.GetSourceDegree(),
                            velocity = entry_velocity,
                        })
                        seq_store.SetProgressionEntry(global_idx, entry)
                    end
                else
                    -- Create new subdivided entry (convert legacy if needed)
                    if existing and not existing.subs then
                        existing.subs = {{
                            degree = existing.degree,
                            velocity = existing.velocity,
                        }}
                        entry = existing
                    else
                        entry = {
                            degree = drag_store.GetSourceDegree(),
                            root_index = config.state.root_index,
                            scale_index = config.state.scale_index,
                            octave = config.state.octave,
                            chord_mode_index = config.state.chord_mode_index,
                            velocity = entry_velocity,
                            duration = 4,
                            subs = {},
                        }
                    end
                    table.insert(entry.subs, {
                        degree = drag_store.GetSourceDegree(),
                        velocity = entry_velocity,
                    })
                    progression.Add(global_idx, entry)
                end
            else
                progression.Add(global_idx, { 
                    degree = drag_store.GetSourceDegree(), 
                    root_index = config.state.root_index, 
                    scale_index = config.state.scale_index, 
                    octave = config.state.octave, 
                    chord_mode_index = config.state.chord_mode_index,
                    velocity = entry_velocity,
                    duration = 4,
                })
            end
        end
        
        -- Cleanup immediately so DrawDragPreview doesn't see stale state
        drag_store.SetIsDragging(false)
        drag_store.SetSourceDegree(-1)
        drag_store.SetSourceSlotIdx(-1)
        drag_store.SetPendingDegree(nil)
    end

    if not drag_store.GetIsDragging() then
        if slot then
            local label = format.ChordLabel({root_index=slot.root_index, scale_index=slot.scale_index, degree=slot.degree, octave=slot.octave, chord_mode_index=slot.chord_mode_index})
            helpers.DrawTooltip("Slot " .. global_idx .. ": " .. label, 11)
        else
            helpers.DrawTooltip("Slot " .. global_idx .. " — Empty", 11)
        end
    end
end

function m.DrawProgressionSlot(global_idx, x, y, w, h)
    local components = require("ui.components")
    local slot = seq_store.GetProgressionEntry(global_idx)
    local play = seq_store.GetIsPlaying() and seq_store.GetCurrentStep() == global_idx
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    
    DrawSlotBackground(global_idx, x, y, w, h, slot, play)
    DrawSlotLabel(global_idx, x, y, w, h, slot, play)
    m.HandleSlotInteraction(global_idx, x, y, w, h, slot, hover)

    -- Cleanup: clear pending_slot_idx if mouse released outside slot bounce zone
    if (gfx.mouse_cap & 1) == 0 and not drag_store.GetIsDragging() and not hover then
        drag_store.SetPendingSlotIdx(nil)
    end
end

return m
