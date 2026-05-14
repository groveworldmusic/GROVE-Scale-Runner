-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Piano Roll Clipboard
-- Cut/copy/paste state and handlers. Extracted from interaction.lua (PR3).

local island_store = require("state.island")
local note = require("ui.piano-roll.note")

local m = {}

-- Module-level clipboard for cut/copy/paste
local _clipboard = {}

-- =========================================================
-- Cut/Copy/Paste Clipboard
-- =========================================================

--- Cut selected notes: store in clipboard, remove from grid, push undo.
--- @return boolean true if any notes were cut
function m.HandleCut()
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return false end
    local selected = island_store.GetSelectedIndices()

    -- Capture clipboard + undo data
    _clipboard = {}
    local to_remove = {}
    local undo_uuids = {}
    local undo_prev = {}
    for idx in pairs(selected) do
        if notes[idx] then
            local copy = {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
                uuid = notes[idx].uuid,
            }
            table.insert(_clipboard, copy)
            table.insert(to_remove, idx)
            table.insert(undo_uuids, notes[idx].uuid)
            table.insert(undo_prev, copy)
        end
    end
    if #to_remove == 0 then return false end

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
    return true
end

--- Copy selected notes to clipboard (no removal).
--- @return boolean true if any notes were copied
function m.HandleCopy()
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return false end
    local selected = island_store.GetSelectedIndices()

    _clipboard = {}
    for idx in pairs(selected) do
        if notes[idx] then
            table.insert(_clipboard, {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
            })
        end
    end
    return #_clipboard > 0
end

--- Paste clipboard notes at the current scroll position.
--- Assigns new UUIDs to all pasted notes. Pushes a single "add" undo entry.
--- @param scroll_beat number Current scroll position in beats (anchor beat)
--- @return boolean true if notes were pasted
function m.HandlePaste(scroll_beat)
    if not _clipboard or #_clipboard == 0 then return false end

    local notes = island_store.GetNotes()
    local undo_new = {}

    -- Find beat anchor: use scroll_beat or earliest clipboard start_beat
    local anchor_beat = scroll_beat or 0
    if #notes > 0 then
        -- Place pasted notes at a reasonable position
        local max_beat = 0
        for _, n in ipairs(notes) do
            local end_b = (n.start_beat or 0) + (n.duration or 1)
            if end_b > max_beat then max_beat = end_b end
        end
        anchor_beat = math.max(anchor_beat, max_beat + 1)
    end

    local min_clip_beat = nil
    for _, copy in ipairs(_clipboard) do
        if min_clip_beat == nil or copy.start_beat < min_clip_beat then
            min_clip_beat = copy.start_beat
        end
    end
    local offset = (min_clip_beat or 0)

    for _, copy in ipairs(_clipboard) do
        local new_note = {
            pitch = copy.pitch,
            start_beat = anchor_beat + (copy.start_beat - offset),
            duration = copy.duration,
            velocity = copy.velocity,
            muted = copy.muted,
        }
        island_store.AddNote(new_note)
        table.insert(undo_new, {
            pitch = new_note.pitch,
            start_beat = new_note.start_beat,
            duration = new_note.duration,
            velocity = new_note.velocity,
            muted = new_note.muted,
            uuid = new_note.uuid,
        })
    end

    island_store.PushUndo({
        type = "add",
        note_uuids = {},
        new_state = undo_new,
    })
    note.MarkNotesDirty()
    return true
end

return m
