-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Piano Roll Undo/Redo
-- Undo/redo stack operations. Extracted from interaction.lua (PR3).

local island_store = require("state.island")
local note = require("ui.piano-roll.note")

local m = {}

-- =========================================================
-- Undo/Redo Restore Functions
-- =========================================================

--- Restore note state from an undo entry (reverse the edit).
--- Reverses the operation specified by the entry type.
--- @param entry table Undo entry {type, note_uuids, prev_state, new_state}
function m.RestoreUndo(entry)
    local notes = island_store.GetNotes()
    if not entry or not entry.type then return end

    if entry.type == "move" or entry.type == "resize" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = island_store.FindNoteByUUID(uuid)
            local prev = entry.prev_state and entry.prev_state[i]
            if idx and notes[idx] and prev then
                notes[idx].pitch = prev.pitch or notes[idx].pitch
                notes[idx].start_beat = prev.start_beat or notes[idx].start_beat
                notes[idx].duration = prev.duration or notes[idx].duration
            end
        end
    elseif entry.type == "delete" then
        -- Restore deleted notes
        for _, prev in ipairs(entry.prev_state or {}) do
            local new_note = {
                pitch = prev.pitch,
                start_beat = prev.start_beat,
                duration = prev.duration,
                velocity = prev.velocity,
                muted = prev.muted,
                uuid = prev.uuid,
            }
            island_store.AddNote(new_note)
        end
    elseif entry.type == "add" then
        -- Remove added notes
        local to_remove = {}
        for _, new_note in ipairs(entry.new_state or {}) do
            local idx = island_store.FindNoteByUUID(new_note.uuid)
            if idx then table.insert(to_remove, idx) end
        end
        table.sort(to_remove, function(a, b) return a > b end)
        for _, idx in ipairs(to_remove) do
            island_store.RemoveNoteAtIndex(idx)
        end
    elseif entry.type == "velocity" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = island_store.FindNoteByUUID(uuid)
            local prev = entry.prev_state and entry.prev_state[i]
            if idx and notes[idx] and prev then
                notes[idx].velocity = prev.velocity
            end
        end
    elseif entry.type == "mute" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = island_store.FindNoteByUUID(uuid)
            local prev = entry.prev_state and entry.prev_state[i]
            if idx and notes[idx] and prev then
                notes[idx].muted = prev.muted
            end
        end
    end

    island_store.ClearSelection()
    island_store.RebuildUUIDIndex()
    note.MarkNotesDirty()
end

--- Restore note state from a redo entry (re-apply the edit).
--- Same logic as RestoreUndo but uses new_state instead of prev_state.
--- @param entry table Undo entry {type, note_uuids, prev_state, new_state}
function m.RestoreRedo(entry)
    local notes = island_store.GetNotes()
    if not entry or not entry.type then return end

    if entry.type == "move" or entry.type == "resize" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = island_store.FindNoteByUUID(uuid)
            local after = entry.new_state and entry.new_state[i]
            if idx and notes[idx] and after then
                notes[idx].pitch = after.pitch or notes[idx].pitch
                notes[idx].start_beat = after.start_beat or notes[idx].start_beat
                notes[idx].duration = after.duration or notes[idx].duration
            end
        end
    elseif entry.type == "delete" then
        -- Re-delete restored notes
        local to_remove = {}
        for _, prev in ipairs(entry.prev_state or {}) do
            local idx = island_store.FindNoteByUUID(prev.uuid)
            if idx then table.insert(to_remove, idx) end
        end
        table.sort(to_remove, function(a, b) return a > b end)
        for _, idx in ipairs(to_remove) do
            island_store.RemoveNoteAtIndex(idx)
        end
    elseif entry.type == "add" then
        -- Re-create added notes
        for _, new_note in ipairs(entry.new_state or {}) do
            island_store.AddNote({
                pitch = new_note.pitch,
                start_beat = new_note.start_beat,
                duration = new_note.duration,
                velocity = new_note.velocity,
                muted = new_note.muted,
                uuid = new_note.uuid,
            })
        end
    elseif entry.type == "velocity" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = island_store.FindNoteByUUID(uuid)
            local after = entry.new_state and entry.new_state[i]
            if idx and notes[idx] and after then
                notes[idx].velocity = after.velocity
            end
        end
    elseif entry.type == "mute" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = island_store.FindNoteByUUID(uuid)
            local after = entry.new_state and entry.new_state[i]
            if idx and notes[idx] and after then
                notes[idx].muted = after.muted
            end
        end
    end

    island_store.ClearSelection()
    island_store.RebuildUUIDIndex()
    note.MarkNotesDirty()
end

--- Handle undo shortcut: Ctrl+Z. Pops undo, pushes redo, restores.
function m.HandleUndo()
    local entry = island_store.PopUndo()
    if entry then
        island_store.PushRedo(entry)
        m.RestoreUndo(entry)
    end
end

--- Handle redo shortcut: Ctrl+Y. Pops redo, pushes undo, restores.
function m.HandleRedo()
    local entry = island_store.PopRedo()
    if entry then
        island_store.PushUndo(entry)
        m.RestoreRedo(entry)
    end
end

return m
