-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Note State Store
-- Encapsulates piano-roll note CRUD, UUID management, undo/redo stack,
-- and progression-to-notes conversion.
-- Extracted from island.lua (Analiza toda la codebase actual., Item 3).

local config = require("config")
local api_guard = require("core.api-guard")

local m = {}
local _uuid_to_idx = {}
local MAX_UNDO = 50

local state = {
    notes = {},
    note_count = 0,
    next_note_uuid = 1,
    undo_stack = {},
    redo_stack = {},
    undo_depth = 0,
    redo_depth = 0,
}

function m.Init(defaults)
    if defaults.notes then
        state.notes = defaults.notes
        state.note_count = #defaults.notes
    end
    -- next_note_uuid starts at 1 or can be overridden
    if defaults.next_note_uuid ~= nil then
        state.next_note_uuid = defaults.next_note_uuid
    end
end

-- =========================================================
-- Notes
-- =========================================================

--- Get the notes array (reference — mutate in-place for perf).
--- @return table Array of {pitch, start_beat, duration, velocity, muted, uuid}
function m.GetNotes()
    return state.notes
end

--- Replace all notes. Does NOT touch selection state (caller handles that).
--- @param t table|nil New notes array
function m.SetNotes(t)
    state.notes = t or {}
    state.note_count = #state.notes
    m.RebuildUUIDIndex()
end

--- Get the current note count.
--- @return number
function m.GetNoteCount()
    return state.note_count
end

--- Set the note count directly.
--- @param v number
function m.SetNoteCount(v)
    state.note_count = v
end

-- =========================================================
-- Note CRUD
-- =========================================================

--- Append a note to the notes table.
--- Assigns UUID if not already set. Updates reverse index.
--- @param note table {pitch, start_beat, duration, velocity, muted}
function m.AddNote(note)
    note.uuid = note.uuid or m.AllocNoteUUID()
    if note.origin == nil then note.origin = "manual" end
    table.insert(state.notes, note)
    state.note_count = #state.notes
    if note.uuid then
        _uuid_to_idx[note.uuid] = #state.notes
    end
end

--- Remove a note at the given index. Shifts subsequent entries.
--- Does NOT fix selection state (caller handles that).
--- Does rebuild UUID reverse index since indices shifted.
--- @param idx number 1-based index into notes[]
function m.RemoveNoteAtIndex(idx)
    if idx < 1 or idx > #state.notes then return end
    table.remove(state.notes, idx)
    state.note_count = #state.notes
    m.RebuildUUIDIndex()
end

-- =========================================================
-- UUID Reverse Index
-- =========================================================

--- Rebuild the UUID-to-index reverse index from scratch.
function m.RebuildUUIDIndex()
    _uuid_to_idx = {}
    for i, note in ipairs(state.notes) do
        if note.uuid then
            _uuid_to_idx[note.uuid] = i
        end
    end
end

--- Allocate a new monotonic UUID for a note.
--- @return number
function m.AllocNoteUUID()
    local uuid = state.next_note_uuid
    state.next_note_uuid = state.next_note_uuid + 1
    return uuid
end

--- Find a note's array index by UUID.
--- @param uuid number
--- @return number|nil
function m.FindNoteByUUID(uuid)
    return _uuid_to_idx[uuid]
end

-- =========================================================
-- Undo/Redo Stack
-- =========================================================

--- Push an undo entry. Automatically clears redo stack.
--- FIFO eviction when stack exceeds 50 entries.
--- @param entry table {type, note_uuids, prev_state, new_state}
function m.PushUndo(entry)
    entry.timestamp = os.clock()
    table.insert(state.undo_stack, entry)
    state.undo_depth = #state.undo_stack
    if state.undo_depth > MAX_UNDO then
        table.remove(state.undo_stack, 1)
        state.undo_depth = MAX_UNDO
    end
    state.redo_stack = {}
    state.redo_depth = 0
end

--- Pop the most recent undo entry.
--- @return table|nil
function m.PopUndo()
    if #state.undo_stack == 0 then return nil end
    local entry = table.remove(state.undo_stack)
    state.undo_depth = #state.undo_stack
    return entry
end

--- Push a redo entry.
--- @param entry table
function m.PushRedo(entry)
    entry.timestamp = os.clock()
    table.insert(state.redo_stack, entry)
    state.redo_depth = #state.redo_stack
    if state.redo_depth > MAX_UNDO then
        table.remove(state.redo_stack, 1)
        state.redo_depth = MAX_UNDO
    end
end

--- Pop the most recent redo entry.
--- @return table|nil
function m.PopRedo()
    if #state.redo_stack == 0 then return nil end
    local entry = table.remove(state.redo_stack)
    state.redo_depth = #state.redo_stack
    return entry
end

--- Clear both undo and redo stacks.
function m.ClearUndoStacks()
    state.undo_stack = {}
    state.redo_stack = {}
    state.undo_depth = 0
    state.redo_depth = 0
end

--- Get undo stack depth.
--- @return number
function m.GetUndoDepth()
    return state.undo_depth
end

--- Get redo stack depth.
--- @return number
function m.GetRedoDepth()
    return state.redo_depth
end

-- =========================================================
-- Progression → Notes Conversion
-- =========================================================

local function ProgressionEntryToPitch(root_idx, scale_idx, degree_idx, octave_val)
    local root = root_idx - 1
    local si = api_guard.ClampIndex(scale_idx, 1, #config.SCALES)
    local scale = config.SCALES[si]
    local n_scale = #scale.intervals
    local deg0 = degree_idx - 1
    local oct_off = math.floor(deg0 / n_scale)
    local interval = scale.intervals[(deg0 % n_scale) + 1]
    local result = (octave_val + 1) * 12 + root + (oct_off * 12) + interval
    return math.max(0, math.min(127, result))
end

local function EntryToPitches(entry)
    local ci = api_guard.ClampIndex(entry.chord_mode_index or 1, 1, #config.CHORD_MODES)
    local chord_mode = config.CHORD_MODES[ci]
    local pitches = {}
    for _, off in ipairs(chord_mode.offsets) do
        local pitch = ProgressionEntryToPitch(
            entry.root_index or 1,
            entry.scale_index or 1,
            entry.degree + off,
            entry.octave or 4
        )
        table.insert(pitches, pitch)
    end
    return pitches
end

--- Convert a progression table to a flat list of note entries.
--- Each slot i produces notes starting at (i-1) * beats_per_slot beats.
--- Each chord offset becomes a separate note entry with a UUID.
---
--- @param progression table Array of progression entries (1..16, may have nils)
--- @param beats_per_slot number Beats per slot (default 4)
--- @param velocity number Default velocity (default 100)
--- @return table Array of {pitch, start_beat, duration, velocity, muted, uuid}
function m.ProgressionToNotes(progression, beats_per_slot, velocity)
    beats_per_slot = beats_per_slot or 4
    velocity = velocity or 100
    local notes = {}
    if not progression then return notes end

    for i = 1, 16 do
        local entry = progression[i]
        if entry and entry.degree then
            local entry_velocity = entry.velocity or velocity
            local entry_duration = entry.duration or beats_per_slot

            if entry.subs and #entry.subs > 0 then
                local sub_duration = entry_duration / #entry.subs
                for si, sub in ipairs(entry.subs) do
                    local start_beat = (i - 1) * beats_per_slot + (si - 1) * sub_duration
                    local sub_vel = sub.velocity or entry_velocity
                    local sub_entry = {
                        degree = sub.degree,
                        root_index = entry.root_index,
                        scale_index = entry.scale_index,
                        octave = entry.octave,
                        chord_mode_index = entry.chord_mode_index,
                    }
                    local pitches = EntryToPitches(sub_entry)
                    for _, pitch in ipairs(pitches) do
                        table.insert(notes, {
                            pitch = pitch,
                            start_beat = start_beat,
                            duration = sub_duration,
                            velocity = sub_vel,
                            muted = false,
                            uuid = m.AllocNoteUUID(),
                        })
                    end
                end
            else
                local start_beat = (i - 1) * beats_per_slot
                local pitches = EntryToPitches(entry)
                for _, pitch in ipairs(pitches) do
                    table.insert(notes, {
                        pitch = pitch,
                        start_beat = start_beat,
                        duration = entry_duration,
                        velocity = entry_velocity,
                        muted = false,
                        uuid = m.AllocNoteUUID(),
                    })
                end
            end
        end
    end

    return notes
end

--- Convenience: reads progression from sequencer_store and populates notes.
--- @param seq_store table The sequencer store module
function m.LoadNotesFromProgression(seq_store)
    local progression = seq_store.GetProgression()
    local notes = m.ProgressionToNotes(progression, 4, 100)
    m.SetNotes(notes)
end

--- Filter notes by visible pitch and time range (for virtual scrolling).
--- @param notes table Full notes array
--- @param pitch_start number Minimum pitch (inclusive)
--- @param pitch_end number Maximum pitch (inclusive)
--- @param beat_start number Minimum beat (inclusive)
--- @param beat_end number Maximum beat (inclusive)
--- @return table Filtered notes (sub-set suitable for rendering)
function m.GetVisibleNotes(notes, pitch_start, pitch_end, beat_start, beat_end)
    local result = {}
    if not notes then return result end
    for _, note in ipairs(notes) do
        if note.pitch >= pitch_start and note.pitch <= pitch_end then
            local ns = note.start_beat
            local nd = note.duration or 1
            if ns + nd >= beat_start and ns <= beat_end then
                table.insert(result, note)
            end
        end
    end
    return result
end

return m
