-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Piano Roll Undo/Redo
-- Undo/redo stack operations. Extracted from interaction.lua (PR3).

local island_store = require("state.island")
local note_store = require("state.note-store")
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
            local idx = note_store.FindNoteByUUID(uuid)
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
            local idx = note_store.FindNoteByUUID(new_note.uuid)
            if idx then table.insert(to_remove, idx) end
        end
        table.sort(to_remove, function(a, b) return a > b end)
        for _, idx in ipairs(to_remove) do
            island_store.RemoveNoteAtIndex(idx)
        end
    elseif entry.type == "velocity" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = note_store.FindNoteByUUID(uuid)
            local prev = entry.prev_state and entry.prev_state[i]
            if idx and notes[idx] and prev then
                notes[idx].velocity = prev.velocity
            end
        end
    elseif entry.type == "mute" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = note_store.FindNoteByUUID(uuid)
            local prev = entry.prev_state and entry.prev_state[i]
            if idx and notes[idx] and prev then
                notes[idx].muted = prev.muted
            end
        end
    elseif entry.type == "split" then
        -- Reverse a split: remove both halves, restore original note
        local left_uuid = entry.note_uuids and entry.note_uuids[1]
        local right_uuid = entry.note_uuids and entry.note_uuids[2]
        local left_idx = left_uuid and note_store.FindNoteByUUID(left_uuid)
        local right_idx = right_uuid and note_store.FindNoteByUUID(right_uuid)
        local orig = entry.prev_state and entry.prev_state[1]

        -- Remove right half first (higher index) to preserve indices
        if right_idx then island_store.RemoveNoteAtIndex(right_idx) end
        if left_idx then island_store.RemoveNoteAtIndex(left_idx) end

        -- Restore original note (after removals, append works regardless of position)
        if orig then
            island_store.AddNote({
                pitch = orig.pitch,
                start_beat = orig.start_beat,
                duration = orig.duration,
                velocity = orig.velocity,
                muted = orig.muted,
                uuid = orig.uuid,
            })
        end
    end

    island_store.ClearSelection()
    note_store.RebuildUUIDIndex()
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
            local idx = note_store.FindNoteByUUID(uuid)
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
            local idx = note_store.FindNoteByUUID(prev.uuid)
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
            local idx = note_store.FindNoteByUUID(uuid)
            local after = entry.new_state and entry.new_state[i]
            if idx and notes[idx] and after then
                notes[idx].velocity = after.velocity
            end
        end
    elseif entry.type == "mute" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = note_store.FindNoteByUUID(uuid)
            local after = entry.new_state and entry.new_state[i]
            if idx and notes[idx] and after then
                notes[idx].muted = after.muted
            end
        end
    elseif entry.type == "split" then
        -- Re-apply split: remove the restored original note, insert both halves
        local orig = entry.prev_state and entry.prev_state[1]
        local left = entry.new_state and entry.new_state[1]
        local right = entry.new_state and entry.new_state[2]

        if orig then
            local orig_idx = note_store.FindNoteByUUID(orig.uuid)
            if orig_idx then island_store.RemoveNoteAtIndex(orig_idx) end
        end

        if left then island_store.AddNote(left) end
        if right then island_store.AddNote(right) end
    end

    island_store.ClearSelection()
    note_store.RebuildUUIDIndex()
    note.MarkNotesDirty()
end

--- Handle undo shortcut: Ctrl+Z. Pops undo, pushes redo, restores.
function m.HandleUndo()
    local entry = note_store.PopUndo()
    if entry then
        note_store.PushRedo(entry)
        m.RestoreUndo(entry)
    end
end

--- Handle redo shortcut: Ctrl+Y. Pops redo, pushes undo, restores.
function m.HandleRedo()
    local entry = note_store.PopRedo()
    if entry then
        note_store.PushUndo(entry)
        m.RestoreRedo(entry)
    end
end

return m
