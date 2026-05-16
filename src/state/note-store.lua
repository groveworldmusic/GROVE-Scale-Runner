-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Note State Store
-- Encapsulates piano-roll note CRUD, UUID management, undo/redo stack,
-- and progression-to-notes conversion.
-- Extracted from island.lua (Analiza toda la codebase actual., Item 3).

local config = require("config")
local api_guard = require("core.api-guard")
-- NOTE: core.midi NOT required at module level — would create circular dep:
--   state.island → state.note-store → core.midi → ui.gfx-window → state.island
-- Used via lazy require in ProgressionEntryToPitch() below.

--- Reusable chord-mode detection constants
local CHORD_MODE_OFF = 1
local CHORD_MODE_TRI = 2
local CHORD_MODE_7MA = 3
local CHORD_MODE_9NA = 4

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
    local midi = require("core.midi")
    return midi.GetMidiNote(root_idx, scale_idx, degree_idx, octave_val)
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

-- =========================================================
-- Bidirectional Progression Sync Helpers (Phase 1)
-- =========================================================

--- Group notes by snap-aligned beat column.
--- Each group key is the beat column (snap-aligned start_beat).
--- @param notes table Array of {pitch, start_beat, duration, ...}
--- @param snap_resolution number Snap resolution (default 4 = quarter notes)
--- @return table {[beat_col] = {notes}}
function m.GroupNotesByBeat(notes, snap_resolution)
    snap_resolution = snap_resolution or 4
    local step = 4 / snap_resolution
    local groups = {}
    if not notes then return groups end
    for _, n in ipairs(notes) do
        local col = math.floor((n.start_beat or 0) / step + 0.5) * step
        if not groups[col] then groups[col] = {} end
        table.insert(groups[col], n)
    end
    return groups
end

--- Detect chord mode from note count in a group (simple heuristic).
--- @param note_group table Array of notes
--- @return number|nil chord_mode_index (1-4), or nil if empty
function m.DetectChordMode(note_group)
    local count = note_group and #note_group or 0
    if count == 0 then return nil end
    if count == 1 then return CHORD_MODE_OFF end
    if count <= 3 then return CHORD_MODE_TRI end
    if count == 4 then return CHORD_MODE_7MA end
    return CHORD_MODE_9NA  -- 5+
end

--- Find the nearest scale degree for a given MIDI pitch.
--- Computes circular distance from pitch class to each interval in the scale.
--- @param pitch number MIDI pitch (0-127)
--- @param root_idx number Root note index (1-12, e.g. 1=C)
--- @param scale_idx number Scale index (1-21 into config.SCALES)
--- @return number|nil Degree number (1..N) or nil if scale not found
function m.FindNearestScaleDegree(pitch, root_idx, scale_idx)
    local si = api_guard.ClampIndex(scale_idx, 1, #config.SCALES)
    local scale = config.SCALES[si]
    if not scale or not scale.intervals then return nil end

    local pitch_class = pitch % 12
    local root_class = (root_idx - 1) % 12
    local best_dist = 12
    local best_deg = 1

    for di, interval in ipairs(scale.intervals) do
        local expected = (root_class + interval) % 12
        local dist = math.abs(pitch_class - expected)
        dist = math.min(dist, 12 - dist)  -- wraparound
        if dist < best_dist then
            best_dist = dist
            best_deg = di
        end
    end

    return best_deg
end

--- Detect chord mode from a sorted array of unique degrees.
--- Matches degree offset pattern against config.CHORD_MODES.
--- @param sorted_degrees table Sorted array of unique degree numbers
--- @return number chord_mode_index (1 = Off/single note)
function m.DetectChordModeFromDegrees(sorted_degrees)
    if not sorted_degrees or #sorted_degrees == 0 then return CHORD_MODE_OFF end
    local root_deg = sorted_degrees[1]
    for ci, cm in ipairs(config.CHORD_MODES) do
        if #cm.offsets == #sorted_degrees then
            local match = true
            for oi, off in ipairs(cm.offsets) do
                if sorted_degrees[oi] ~= root_deg + off then
                    match = false; break
                end
            end
            if match then return ci end
        end
    end
    return CHORD_MODE_OFF
end

-- =========================================================
-- SyncNotesToProgression (Phase 2)
-- =========================================================

--- Sync piano-roll notes back to progression slots.
--- Groups notes by beat slot, detects degree + chord_mode + octave per group,
--- writes to sequencer_store via SetProgressionEntry.
--- Only overwrites slots that have notes — empty slots preserve existing data.
--- @param seq_store table Sequencer store (for GetProgressionEntry/SetProgressionEntry)
--- @param prefs_store table Preferences store (for GetRootIndex/GetScaleIndex/GetOctave)
--- @param beats_per_slot number Beats per slot (default 4)
--- @return number Count of slots written
function m.SyncNotesToProgression(seq_store, prefs_store, beats_per_slot)
    beats_per_slot = beats_per_slot or 4
    local notes = m.GetNotes()
    if not notes or #notes == 0 then return 0 end

    local root_idx = prefs_store.GetRootIndex()
    local scale_idx = prefs_store.GetScaleIndex()
    local scale = config.SCALES[api_guard.ClampIndex(scale_idx, 1, #config.SCALES)]
    if not scale then return 0 end

    local slots_written = 0

    for slot_i = 1, 16 do
        local beat_start = (slot_i - 1) * beats_per_slot
        local beat_end = slot_i * beats_per_slot
        local group_notes = {}

        -- Collect notes in this slot's beat range
        for _, n in ipairs(notes) do
            if n.start_beat >= beat_start and n.start_beat < beat_end then
                table.insert(group_notes, n)
            end
        end

        if #group_notes == 0 then
            -- No notes in this slot → skip (preserve existing progression data)
            goto continue
        end

        -- Find nearest degree for each note in group
        local degrees = {}
        local root_pitch_class = (root_idx - 1) % 12
        for _, gn in ipairs(group_notes) do
            local pc = gn.pitch % 12
            local rel_pc = (pc - root_pitch_class + 12) % 12
            local best_dist = 12
            local best_deg = 1
            for di, interval in ipairs(scale.intervals) do
                local dist = math.abs(rel_pc - interval)
                dist = math.min(dist, 12 - dist)  -- wraparound
                if dist < best_dist then
                    best_dist = dist
                    best_deg = di
                end
            end
            degrees[best_deg] = true  -- dedup
        end

        -- Sort unique degrees
        local sorted = {}
        for d in pairs(degrees) do table.insert(sorted, d) end
        table.sort(sorted)
        if #sorted == 0 then goto continue end

        -- Root degree = min
        local root_degree = sorted[1]

        -- Detect chord_mode from degree pattern
        local chord_mode_idx = m.DetectChordModeFromDegrees(sorted)

        -- Determine octave from lowest pitched note in group
        local min_pitch = math.huge
        for _, gn in ipairs(group_notes) do
            if gn.pitch < min_pitch then min_pitch = gn.pitch end
        end
        local slot_octave = math.max(0, math.min(8, math.floor(min_pitch / 12) - 1))

        -- Write the slot
        seq_store.SetProgressionEntry(slot_i, {
            degree = root_degree,
            root_index = root_idx,
            scale_index = scale_idx,
            octave = slot_octave,
            chord_mode_index = chord_mode_idx,
        })
        slots_written = slots_written + 1
        ::continue::
    end

    return slots_written
end

return m
