-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Knife Tool — Note Split Algorithm
-- Splits a note into two halves at the clicked beat position.
-- Left half keeps the original note identity; right half gets new UUID + split flag.
-- Supports undo/redo via "split" entry type.

local island_store = require("state.island")
local note_store = require("state.note-store")
local note = require("ui.piano-roll.note")
local coord = require("ui.piano-roll.coord")
local midi = require("core.midi")

local m = {}

--- Handle knife tool click: split a note at the clicked beat.
--- @param mx number Mouse pixel x (screen)
--- @param my number Mouse pixel y (screen)
--- @param grid_x number Grid left edge (screen pixel)
--- @param grid_y number Grid top edge (screen pixel)
--- @param scroll_y number Vertical scroll offset (pitch rows)
--- @param scroll_x number Horizontal scroll offset (beats)
--- @param zoom_x number Pixels per beat
--- @return boolean true if a note was split
function m.HandleKnifeClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local notes = note_store.GetNotes()
    if not notes or #notes == 0 then return false end

    -- Hit-test: find note at click position
    local idx = note.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    if not idx or not notes[idx] then return false end

    local orig = notes[idx]

    -- Convert click X to beat position
    local click_beat = coord.XToBeat(mx, scroll_x, zoom_x, grid_x)
    local start_beat = orig.start_beat
    local duration = orig.duration or 1

    -- Guard: split point must be strictly inside the note body
    -- Minimum 1 snap unit from each edge (use 1/16 snap unit = 0.25 beats as minimum)
    local MIN_SNAP = 0.25
    if click_beat <= start_beat + MIN_SNAP or click_beat >= start_beat + duration - MIN_SNAP then
        return false
    end

    -- Calculate split beat (quantized to MIN_SNAP grid for clean visual result)
    local split_beat = math.floor(click_beat / MIN_SNAP + 0.5) * MIN_SNAP
    -- Re-clamp after quantization
    if split_beat <= start_beat + MIN_SNAP or split_beat >= start_beat + duration - MIN_SNAP then
        return false
    end

    local left_duration = split_beat - start_beat
    local right_duration = duration - left_duration

    -- Create left half (mutate the original note in place)
    local orig_velocity = orig.velocity or 100
    local left_note = {
        pitch = orig.pitch,
        start_beat = start_beat,
        duration = left_duration,
        velocity = orig_velocity,
        muted = orig.muted,
        uuid = orig.uuid,  -- keep original UUID for identity
    }

    -- Create right half (new note)
    local right_note = {
        pitch = orig.pitch,
        start_beat = split_beat,
        duration = right_duration,
        velocity = orig_velocity,
        muted = orig.muted,
        uuid = note_store.AllocNoteUUID(),
        split = true,  -- visual gap marker
    }

    -- Save the original note for undo before mutating
    local orig_snapshot = {
        pitch = orig.pitch,
        start_beat = start_beat,
        duration = duration,
        velocity = orig_velocity,
        muted = orig.muted,
        uuid = orig.uuid,
    }

    -- Send MIDI note-off for the original note's pitch (prevent stuck note)
    -- The split replaces one sustained note with two, and the MIDI note-on
    -- was for the original. Send note-off so the note doesn't hang.
    midi.SendMidi(orig.pitch, false, 0, true)

    -- Replace original note with left_note and insert right_note after
    notes[idx] = left_note
    table.insert(notes, idx + 1, right_note)

    -- Fix up selection: the split replaces the selected note — clear selection
    -- so the user doesn't have a stale selection pointing at changed indices.
    note_store.ClearSelection()

    -- Push undo entry
    note_store.PushUndo({
        type = "split",
        note_uuids = {left_note.uuid, right_note.uuid, orig_snapshot.uuid},
        prev_state = {orig_snapshot},
        new_state = {left_note, right_note},
    })

    note_store.SetNotesState(note_store.NOTES_STATE_EDITED)
    note_store.RebuildUUIDIndex()

    return true
end

return m
