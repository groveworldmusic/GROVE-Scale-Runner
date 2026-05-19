-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Sequencer State Store
-- Encapsulates sequencer state with getters/setters.
-- Extracted from config.state.sequencer, config.state.progression,
-- config.state.current_page, config.state.page_override_timer, and config.state.slot_flash.
local persist = require("state.persist")
local seq_state = {
    progression = {},
    progression_revision = 0,
    is_playing = false,
    current_step = 0,
    last_measure = -1,
    midi_notes = {},
    progress = 0,
    internal_beats = 0,
    last_time = nil,
    volume = 100,
    current_page = 1,
    page_override_timer = 0,
    slot_flash = { idx = -1, timer = 0 },
    current_sub_step = 0,
    slot_hover_idx = -1,
    slot_hover_sub = 0,
}

-- Volume save debounce: slider drag calls SetVolume every frame,
-- so we defer the persist.Save by a few frames to batch writes.
local _volume_save_counter = 0
local _volume_last_saved = 100

-- Progression undo/redo stacks
local MAX_PROG_UNDO = 50
local prog_undo_stack = {}
local prog_redo_stack = {}
local prog_undo_gate = false

local m = {}

function m.Init(defaults)
    -- progression is shared by reference — in-place mutation (table.insert, etc.) affects the source
    if defaults.progression then seq_state.progression = defaults.progression end
    if defaults.sequencer then
        for k, v in pairs(defaults.sequencer) do seq_state[k] = v end
    end
    if defaults.current_page ~= nil then seq_state.current_page = defaults.current_page end
    if defaults.page_override_timer ~= nil then seq_state.page_override_timer = defaults.page_override_timer end
    if defaults.slot_flash then
        if defaults.slot_flash.idx ~= nil then seq_state.slot_flash.idx = defaults.slot_flash.idx end
        if defaults.slot_flash.timer ~= nil then seq_state.slot_flash.timer = defaults.slot_flash.timer end
    end
    -- Reset progression undo stacks and gate on init
    prog_undo_stack = {}
    prog_redo_stack = {}
    prog_undo_gate = false
end

-- Progression table — returned by reference for in-place mutation
function m.GetProgression() return seq_state.progression end
function m.SetProgression(t)
    if not prog_undo_gate then m.PushProgUndo(m.ProgSnapshot()) end
    seq_state.progression = t
    seq_state.progression_revision = seq_state.progression_revision + 1
    prog_redo_stack = {}
end

-- Indexed progression access
function m.GetProgressionLen() return #seq_state.progression end
function m.GetProgressionEntry(i) return seq_state.progression[i] end
function m.SetProgressionEntry(i, v)
    if not prog_undo_gate then m.PushProgUndo(m.ProgSnapshot()) end
    seq_state.progression[i] = v
    seq_state.progression_revision = seq_state.progression_revision + 1
    prog_redo_stack = {}
end
function m.ClearProgression()
    if not prog_undo_gate then m.PushProgUndo(m.ProgSnapshot()) end
    for i = 1, 16 do seq_state.progression[i] = nil end
    seq_state.progression_revision = seq_state.progression_revision + 1
    prog_redo_stack = {}
end

-- Progression revision counter (incremented on every mutation)
function m.GetProgressionRevision() return seq_state.progression_revision end

-- Progression undo/redo stacks
function m.GetProgUndoStack() return prog_undo_stack end
function m.GetProgRedoStack() return prog_redo_stack end
function m.SetProgUndoStack(t) prog_undo_stack = t end
function m.SetProgRedoStack(t) prog_redo_stack = t end
function m.GetProgUndoGate() return prog_undo_gate end
function m.SetProgUndoGate(v) prog_undo_gate = v end

function m.ClearProgUndoStacks()
    prog_undo_stack = {}
    prog_redo_stack = {}
end

-- Snapshot full progression[1..16] as shallow copies
function m.ProgSnapshot()
    local snap = {}
    for i = 1, 16 do
        local e = seq_state.progression[i]
        if e then
            snap[i] = {
                degree = e.degree,
                root_index = e.root_index,
                scale_index = e.scale_index,
                octave = e.octave,
                chord_mode_index = e.chord_mode_index,
                velocity = e.velocity,
                duration = e.duration,
            }
        end
    end
    return snap
end

-- Push to undo (FIFO, evict oldest at MAX_PROG_UNDO+1)
function m.PushProgUndo(snapshot)
    table.insert(prog_undo_stack, snapshot)
    if #prog_undo_stack > MAX_PROG_UNDO then
        table.remove(prog_undo_stack, 1)
    end
end

function m.PopProgUndo()
    return table.remove(prog_undo_stack)
end

-- Push to redo (FIFO, evict oldest at MAX_PROG_UNDO+1)
function m.PushProgRedo(snapshot)
    table.insert(prog_redo_stack, snapshot)
    if #prog_redo_stack > MAX_PROG_UNDO then
        table.remove(prog_redo_stack, 1)
    end
end

function m.PopProgRedo()
    return table.remove(prog_redo_stack)
end

-- Undo: push current state to redo, pop undo snapshot and restore
function m.HandleProgUndo()
    if #prog_undo_stack == 0 then return end
    prog_undo_gate = true
    m.PushProgRedo(m.ProgSnapshot())
    local snap = m.PopProgUndo()
    if snap then
        seq_state.progression = snap
        seq_state.progression_revision = seq_state.progression_revision + 1
    end
    prog_undo_gate = false
end

-- Redo: push current state to undo, pop redo snapshot and restore
function m.HandleProgRedo()
    if #prog_redo_stack == 0 then return end
    prog_undo_gate = true
    m.PushProgUndo(m.ProgSnapshot())
    local snap = m.PopProgRedo()
    if snap then
        seq_state.progression = snap
        seq_state.progression_revision = seq_state.progression_revision + 1
    end
    prog_undo_gate = false
end

-- Sequencer fields (was config.state.sequencer.*)
function m.GetIsPlaying() return seq_state.is_playing end
function m.SetIsPlaying(v) seq_state.is_playing = v end
function m.GetCurrentStep() return seq_state.current_step end
function m.SetCurrentStep(v) seq_state.current_step = v end
function m.GetLastMeasure() return seq_state.last_measure end
function m.SetLastMeasure(v) seq_state.last_measure = v end
function m.GetMidiNotes() return seq_state.midi_notes end
function m.SetMidiNotes(v) seq_state.midi_notes = v end
function m.GetProgress() return seq_state.progress end
function m.SetProgress(v) seq_state.progress = v end
function m.GetInternalBeats() return seq_state.internal_beats end
function m.SetInternalBeats(v) seq_state.internal_beats = v end
function m.GetLastTime() return seq_state.last_time end
function m.SetLastTime(v) seq_state.last_time = v end
function m.GetVolume() return seq_state.volume end
function m.SetVolume(v)
    if seq_state.volume ~= v then
        seq_state.volume = v
        _volume_save_counter = 3  -- defer persist ~3 frames
    end
end
function m.TickVolumeSave()
    if _volume_save_counter > 0 then
        _volume_save_counter = _volume_save_counter - 1
        if _volume_save_counter == 0 and seq_state.volume ~= _volume_last_saved then
            persist.Save("volume", seq_state.volume)
            _volume_last_saved = seq_state.volume
        end
    end
end

-- Page state
function m.GetCurrentPage() return seq_state.current_page end
function m.SetCurrentPage(v) seq_state.current_page = v end
function m.GetPageOverrideTimer() return seq_state.page_override_timer end
function m.SetPageOverrideTimer(v) seq_state.page_override_timer = v end

-- Slot flash sub-table (named keys: idx, timer)
function m.GetSlotFlashIdx() return seq_state.slot_flash.idx end
function m.SetSlotFlashIdx(v) seq_state.slot_flash.idx = v end
function m.GetSlotFlashTimer() return seq_state.slot_flash.timer end
function m.SetSlotFlashTimer(v) seq_state.slot_flash.timer = v end

-- Sub-step tracking for subdivision playback
function m.GetCurrentSubStep() return seq_state.current_sub_step end
function m.SetCurrentSubStep(v) seq_state.current_sub_step = v end

-- Slot hover sub preview (mouse wheel cycling through subdivided slot subs)
function m.GetSlotHoverIdx() return seq_state.slot_hover_idx end
function m.SetSlotHoverIdx(v) seq_state.slot_hover_idx = v end
function m.GetSlotHoverSub() return seq_state.slot_hover_sub end
function m.SetSlotHoverSub(v) seq_state.slot_hover_sub = v end

return m
