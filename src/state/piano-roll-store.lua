-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Piano Roll State Store
-- Encapsulates piano roll island state with getters/setters.
-- Extracted from island.lua (PR 2 of critical-areas-refactor).

local config = require("config")
local api_guard = require("core.api-guard")

local m = {}
local _uuid_to_idx = {}

local TOTAL_PITCHES = 108
local MAX_UNDO = 50

local state = {
    island_active = false,
    preset_panel_visible = false,
    notes = {},
    note_count = 0,
    playback_pos = 0,
    scroll_offset_y = 58,
    scroll_offset_x = 0,
    zoom_x = 28,
    selected_indices = {},
    _last_selected_idx = nil,
    tool_mode = "pointer",
    lasso_active = false,
    lasso_start_x = 0, lasso_start_y = 0,
    lasso_end_x = 0, lasso_end_y = 0,
    velocity_panel_expanded = false,
    island_transition_in_progress = false,
    pre_toggle_dock = 0,
    pre_toggle_rect = nil,
    snap_enabled = false,
    snap_resolution = 4,
    snap_triplet = false,
    next_note_uuid = 1,
    undo_stack = {},
    redo_stack = {},
    undo_depth = 0,
    redo_depth = 0,
    note_drag_active = false,
    notes_dirty = false,
    note_drag_indices = {},
    note_drag_start_pitch = 0,
    note_drag_start_beat = 0,
    note_drag_origin_mx = 0,
    note_drag_origin_my = 0,
    note_resize_edge = nil,
    folder_scroll = 0,
}

function m.Init(defaults)
    if defaults.island_active ~= nil then state.island_active = defaults.island_active end
    if defaults.preset_panel_visible ~= nil then state.preset_panel_visible = defaults.preset_panel_visible end
    if defaults.notes then
        state.notes = defaults.notes
        state.note_count = #defaults.notes
    end
    if defaults.playback_pos ~= nil then state.playback_pos = defaults.playback_pos end
    if defaults.scroll_offset_y ~= nil then state.scroll_offset_y = defaults.scroll_offset_y end
    if defaults.scroll_offset_x ~= nil then state.scroll_offset_x = defaults.scroll_offset_x end
    if defaults.zoom_x ~= nil then state.zoom_x = defaults.zoom_x end
    if defaults.selected_note_index ~= nil then
        state.selected_indices = {[defaults.selected_note_index] = true}
        state._last_selected_idx = defaults.selected_note_index
    end
    if defaults.velocity_panel_expanded ~= nil then state.velocity_panel_expanded = defaults.velocity_panel_expanded end
end

-- Island active state
function m.GetIslandActive() return state.island_active end
function m.SetIslandActive(v) state.island_active = v end

-- Preset panel visibility (collapsible left panel)
function m.GetPresetPanelVisible() return state.preset_panel_visible end
function m.SetPresetPanelVisible(v) state.preset_panel_visible = v end

-- Notes table — returned by reference for in-place mutation
function m.GetNotes() return state.notes end
function m.SetNotes(t)
    state.notes = t or {}
    state.note_count = #state.notes
    m.ClearSelection()
    m.RebuildUUIDIndex()
end

-- Note count
function m.GetNoteCount() return state.note_count end
function m.SetNoteCount(v) state.note_count = v end

function m.SetNotesDirty(v) state.notes_dirty = v end
function m.GetNotesDirty() return state.notes_dirty end

-- Playback position (beats)
function m.GetPlaybackPos() return state.playback_pos end
function m.SetPlaybackPos(v) state.playback_pos = v end

-- Vertical scroll offset (pitch rows)
function m.GetScrollOffsetY() return state.scroll_offset_y end
function m.SetScrollOffsetY(v)
    state.scroll_offset_y = math.max(0, math.min(TOTAL_PITCHES, v))
end

-- Horizontal scroll offset (beats)
function m.GetScrollOffsetX() return state.scroll_offset_x end
function m.SetScrollOffsetX(v)
    state.scroll_offset_x = math.max(0, v)
end

-- Zoom level (pixels per beat) — clamped to 10..200
function m.GetZoomX() return state.zoom_x end
function m.SetZoomX(v)
    state.zoom_x = math.max(10, math.min(200, v))
end

-- Tool Mode
function m.GetToolMode() return state.tool_mode end
function m.SetToolMode(v) state.tool_mode = v or "pointer" end

-- Multi-Selection
function m.GetSelectedIndices() return state.selected_indices end
function m.SetSelectedIndices(t)
    state.selected_indices = t or {}
    local last = nil
    for k in pairs(state.selected_indices) do
        local kn = tonumber(k)
        if kn and (last == nil or kn > last) then last = kn end
    end
    state._last_selected_idx = last
end
function m.ClearSelection() state.selected_indices = {}; state._last_selected_idx = nil end
function m.IsNoteSelected(idx) return state.selected_indices[idx] == true end
function m.ToggleNoteSelected(idx)
    if state.selected_indices[idx] then
        state.selected_indices[idx] = nil
        if state._last_selected_idx == idx then
            state._last_selected_idx = next(state.selected_indices)
        end
    else
        state.selected_indices[idx] = true
        state._last_selected_idx = idx
    end
end
function m.GetPrimarySelectedIndex()
    return state._last_selected_idx
end
function m.GetSelectionCount()
    local count = 0
    for _ in pairs(state.selected_indices) do count = count + 1 end
    return count
end

-- Backward Compat Shims
function m.GetSelectedNoteIndex() return m.GetPrimarySelectedIndex() end
function m.SetSelectedNoteIndex(v)
    m.ClearSelection()
    if v ~= nil then
        state.selected_indices[v] = true
        state._last_selected_idx = v
    end
end

-- Lasso State
function m.GetLassoActive() return state.lasso_active end
function m.SetLassoActive(v) state.lasso_active = v end
function m.GetLassoStartX() return state.lasso_start_x end
function m.SetLassoStartX(v) state.lasso_start_x = v end
function m.GetLassoStartY() return state.lasso_start_y end
function m.SetLassoStartY(v) state.lasso_start_y = v end
function m.GetLassoEndX() return state.lasso_end_x end
function m.SetLassoEndX(v) state.lasso_end_x = v end
function m.GetLassoEndY() return state.lasso_end_y end
function m.SetLassoEndY(v) state.lasso_end_y = v end

-- Note CRUD
function m.AddNote(note)
    note.uuid = note.uuid or m.AllocNoteUUID()
    if note.origin == nil then note.origin = "manual" end
    table.insert(state.notes, note)
    state.note_count = #state.notes
    if note.uuid then
        _uuid_to_idx[note.uuid] = #state.notes
    end
end

function m.RemoveNoteAtIndex(idx)
    if idx < 1 or idx > #state.notes then return end
    table.remove(state.notes, idx)
    state.note_count = #state.notes
    m.RebuildUUIDIndex()
    local new_selected = {}
    for k in pairs(state.selected_indices) do
        local k_num = tonumber(k)
        if k_num and k_num < idx then
            new_selected[k_num] = true
        elseif k_num and k_num > idx then
            new_selected[k_num - 1] = true
        end
    end
    state.selected_indices = new_selected
    if state._last_selected_idx == idx then
        state._last_selected_idx = next(new_selected)
    elseif state._last_selected_idx and state._last_selected_idx > idx then
        state._last_selected_idx = state._last_selected_idx - 1
    end
end

-- Velocity panel expanded state
function m.GetVelocityPanelExpanded() return state.velocity_panel_expanded end
function m.SetVelocityPanelExpanded(v) state.velocity_panel_expanded = v end

-- Island transition resilience
function m.GetIslandTransitioning() return state.island_transition_in_progress end
function m.SetIslandTransitioning(v) state.island_transition_in_progress = v end
function m.GetPreToggleDock() return state.pre_toggle_dock end
function m.SetPreToggleDock(v) state.pre_toggle_dock = v or 0 end
function m.GetPreToggleRect() return state.pre_toggle_rect end
function m.SetPreToggleRect(t) state.pre_toggle_rect = t end

-- Snap State
function m.GetSnapEnabled() return state.snap_enabled end
function m.SetSnapEnabled(v) state.snap_enabled = v end
function m.GetSnapResolution() return state.snap_resolution end
function m.SetSnapResolution(v) state.snap_resolution = v or 4 end
function m.GetSnapTriplet() return state.snap_triplet end
function m.SetSnapTriplet(v) state.snap_triplet = v end

-- Note Drag State
function m.GetNoteDragActive() return state.note_drag_active end
function m.SetNoteDragActive(v) state.note_drag_active = v end
function m.GetNoteDragIndices() return state.note_drag_indices end
function m.SetNoteDragIndices(t) state.note_drag_indices = t or {} end
function m.GetNoteDragStartPitch() return state.note_drag_start_pitch end
function m.SetNoteDragStartPitch(v) state.note_drag_start_pitch = v or 0 end
function m.GetNoteDragStartBeat() return state.note_drag_start_beat end
function m.SetNoteDragStartBeat(v) state.note_drag_start_beat = v or 0 end
function m.GetNoteDragOriginMx() return state.note_drag_origin_mx end
function m.SetNoteDragOriginMx(v) state.note_drag_origin_mx = v or 0 end
function m.GetNoteDragOriginMy() return state.note_drag_origin_my end
function m.SetNoteDragOriginMy(v) state.note_drag_origin_my = v or 0 end
function m.GetNoteResizeEdge() return state.note_resize_edge end
function m.SetNoteResizeEdge(v) state.note_resize_edge = v end
function m.ResetNoteDrag()
    state.note_drag_active = false
    state.note_drag_indices = {}
    state.note_drag_start_pitch = 0
    state.note_drag_start_beat = 0
    state.note_drag_origin_mx = 0
    state.note_drag_origin_my = 0
    state.note_resize_edge = nil
end

-- Folder scroll (for preset browser folder navigation)
function m.GetFolderScroll() return state.folder_scroll end
function m.SetFolderScroll(v) state.folder_scroll = math.max(0, v or 0) end

-- UUID Reverse Index
function m.RebuildUUIDIndex()
    _uuid_to_idx = {}
    local notes = state.notes
    for i, note in ipairs(notes) do
        if note.uuid then
            _uuid_to_idx[note.uuid] = i
        end
    end
end

function m.AllocNoteUUID()
    local uuid = state.next_note_uuid
    state.next_note_uuid = state.next_note_uuid + 1
    return uuid
end

function m.FindNoteByUUID(uuid)
    return _uuid_to_idx[uuid]
end

-- Undo/Redo Stack Functions
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

function m.PopUndo()
    if #state.undo_stack == 0 then return nil end
    local entry = table.remove(state.undo_stack)
    state.undo_depth = #state.undo_stack
    return entry
end

function m.PushRedo(entry)
    entry.timestamp = os.clock()
    table.insert(state.redo_stack, entry)
    state.redo_depth = #state.redo_stack
    if state.redo_depth > MAX_UNDO then
        table.remove(state.redo_stack, 1)
        state.redo_depth = MAX_UNDO
    end
end

function m.PopRedo()
    if #state.redo_stack == 0 then return nil end
    local entry = table.remove(state.redo_stack)
    state.redo_depth = #state.redo_stack
    return entry
end

function m.ClearUndoStacks()
    state.undo_stack = {}
    state.redo_stack = {}
    state.undo_depth = 0
    state.redo_depth = 0
end

function m.GetUndoDepth() return state.undo_depth end
function m.GetRedoDepth() return state.redo_depth end

-- Progression→Notes Conversion
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

function m.LoadNotesFromProgression(seq_store)
    local progression = seq_store.GetProgression()
    local notes = m.ProgressionToNotes(progression, 4, 100)
    m.SetNotes(notes)
end

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
