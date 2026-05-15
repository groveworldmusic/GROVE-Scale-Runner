-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Piano Roll Interaction — Keyboard Shortcuts
-- Central shortcut dispatcher, delete selected, nudge.
-- Extracted from interaction.lua (Sprint 2).

local island_store = require("state.island")
local note = require("ui.piano-roll.note")
local grid = require("ui.piano-roll.grid")
local snap = require("core.snap")
local undo = require("ui.piano-roll.undo")
local clipboard = require("ui.piano-roll.clipboard")
local handlers = require("ui.piano-roll.interaction.handlers")

local m = {}

-- =========================================================
-- Delete Selected Notes
-- =========================================================

--- Handle Delete key: remove all selected notes with a single undo entry.
function m.HandleDeleteSelected()
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return end
    local selected = island_store.GetSelectedIndices()
    local to_remove = {}
    local undo_uuids = {}
    local undo_prev = {}
    for idx in pairs(selected) do
        if notes[idx] then
            table.insert(to_remove, idx)
            table.insert(undo_uuids, notes[idx].uuid)
            table.insert(undo_prev, {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
                uuid = notes[idx].uuid,
            })
        end
    end
    if #to_remove == 0 then return end

    island_store.PushUndo({
        type = "delete",
        note_uuids = undo_uuids,
        prev_state = undo_prev,
    })

    table.sort(to_remove, function(a, b) return a > b end)
    for _, idx in ipairs(to_remove) do
        island_store.RemoveNoteAtIndex(idx)
    end
    island_store.ClearSelection()
    note.MarkNotesDirty()
end

-- =========================================================
-- Nudge Selected Notes
-- =========================================================

--- Nudge selected notes by a pitch delta (semitones) and a beat delta.
--- Pushes a single "move" undo entry for all nudged notes.
--- @param delta_pitch number Change in semitones (positive = up)
--- @param delta_beat number Change in beats
function m.HandleNudge(delta_pitch, delta_beat)
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return end
    local selected = island_store.GetSelectedIndices()
    local sel_count = 0
    for _ in pairs(selected) do sel_count = sel_count + 1 end
    if sel_count == 0 then return end

    local undo_uuids = {}
    local undo_prev = {}
    local undo_new = {}

    for idx in pairs(selected) do
        if notes[idx] then
            table.insert(undo_uuids, notes[idx].uuid)
            table.insert(undo_prev, {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
            })

            notes[idx].pitch = math.max(grid.MIN_PITCH, math.min(grid.MAX_PITCH,
                (notes[idx].pitch or 60) + delta_pitch))
            notes[idx].start_beat = math.max(0, (notes[idx].start_beat or 0) + delta_beat)

            table.insert(undo_new, {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
            })
        end
    end

    if #undo_uuids > 0 then
        island_store.PushUndo({
            type = "move",
            note_uuids = undo_uuids,
            prev_state = undo_prev,
            new_state = undo_new,
        })
    end
    note.MarkNotesDirty()
end

-- =========================================================
-- Central Keyboard Shortcut Dispatcher
-- =========================================================

--- Dispatch keyboard shortcuts for the piano roll.
--- Call this from views.lua with the char from gfx.getchar().
--- Returns true if the key was consumed (handled), false to fall through.
--- @param char number Character code from gfx.getchar()
--- @param scroll_beat number Current scroll beat (for paste anchor)
--- @return boolean true if consumed
function m.HandleKeyboardShortcut(char, scroll_beat)
    -- Ctrl+Z (90 + 256 = 346)
    if char == 346 then
        undo.HandleUndo()
        return true
    end

    -- Ctrl+Y (89 + 256 = 345)
    if char == 345 then
        undo.HandleRedo()
        return true
    end

    -- Delete key (46 = VK_DELETE, 127 = ASCII DEL, 302 = 46+256 = Ctrl+Delete)
    if char == 46 or char == 127 or char == 302 then
        m.HandleDeleteSelected()
        return true
    end

    -- Ctrl+A (65 + 256 = 321) — select all / deselect all
    if char == 321 then
        handlers.CtrlA()
        return true
    end

    -- Ctrl+X (88 + 256 = 344)
    if char == 344 then
        clipboard.HandleCut()
        return true
    end

    -- Ctrl+C (67 + 256 = 323)
    if char == 323 then
        clipboard.HandleCopy()
        return true
    end

    -- Ctrl+V (86 + 256 = 342)
    if char == 342 then
        clipboard.HandlePaste(scroll_beat or 0)
        return true
    end

    -- Arrow keys (37=VK_LEFT, 38=VK_UP, 39=VK_RIGHT, 40=VK_DOWN)
    -- Shift+arrow adds 512 (Shift bit)
    if char >= 37 and char <= 40 then
        local delta_pitch, delta_beat = 0, 0
        if char == 37 then delta_beat = -1 end         -- Left: -1 snap unit
        if char == 39 then delta_beat = 1 end           -- Right: +1 snap unit
        if char == 38 then delta_pitch = 1 end          -- Up: +1 semitone
        if char == 40 then delta_pitch = -1 end         -- Down: -1 semitone

        if delta_beat ~= 0 then
            -- Snap-aware beat nudge
            local snap_res = island_store.GetSnapEnabled() and island_store.GetSnapResolution() or 0
            local snap_trip = island_store.GetSnapEnabled() and island_store.GetSnapTriplet() or false
            if snap_res > 0 then
                local step = 4 / (snap_trip and snap_res * 1.5 or snap_res)
                delta_beat = delta_beat * step
            else
                delta_beat = delta_beat * 0.25  -- default 1/16 step
            end
        end
        m.HandleNudge(delta_pitch, delta_beat)
        return true
    end

    -- Shift+arrows (37+512=549, 38+512=550, 39+512=551, 40+512=552)
    if char >= 549 and char <= 552 then
        local delta_pitch, delta_beat = 0, 0
        if char == 549 then delta_beat = -1 end       -- Shift+Left: -1 beat
        if char == 551 then delta_beat = 1 end         -- Shift+Right: +1 beat
        if char == 550 then delta_pitch = 12 end       -- Shift+Up: +12 semitones
        if char == 552 then delta_pitch = -12 end      -- Shift+Down: -12 semitones
        m.HandleNudge(delta_pitch, delta_beat)
        return true
    end

    return false  -- Not consumed: fall through to REAPER
end

return m
