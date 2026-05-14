-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Island State Store
-- Encapsulates island piano-roll state with getters/setters.
-- Schema: island_active, preset_panel_visible, notes (flat note list),
--         playback_pos, scroll_offset_y/x, zoom_x, selected_indices, note_count.
-- Phase 4: Added tool_mode, selected_indices (replacing selected_note_index),
--          lasso state, AddNote/RemoveNoteAtIndex.
local config = require("config")
local api_guard = require("core.api-guard")
local note_store = require("state.note-store")

local m = {}
local island_state = {
    island_active = false,
    preset_panel_visible = false,
    playback_pos = 0,
    scroll_offset_y = 58,   -- C3 abajo justo encima del HSB, C#3 sobre C3, arriba C#4
    scroll_offset_x = 0,
    zoom_x = 28,        -- 16 beats (4 measures) fit even with presets panel open (220px)
    selected_indices = {},
    _last_selected_idx = nil,
    tool_mode = "pointer",
    lasso_active = false,
    lasso_start_x = 0, lasso_start_y = 0,
    lasso_end_x = 0, lasso_end_y = 0,
    current_directory = "",
    preset_root = "",
    preset_tree = {},
    preset_files = {},
    selected_preset_idx = nil,
    browser_scroll = 0,
    browser_error = nil,
    favorites = {},
    bookmarks = {},
    velocity_panel_expanded = false,
    island_transition_in_progress = false,
    pre_toggle_dock = 0,
    pre_toggle_rect = nil,
    snap_enabled = false,
    snap_resolution = 4,
    folder_scroll = 0,
    note_drag_origins = {},
}

function m.Init(defaults)
    if defaults.island_active ~= nil then island_state.island_active = defaults.island_active end
    if defaults.preset_panel_visible ~= nil then island_state.preset_panel_visible = defaults.preset_panel_visible end
    if defaults.playback_pos ~= nil then island_state.playback_pos = defaults.playback_pos end
    if defaults.scroll_offset_y ~= nil then island_state.scroll_offset_y = defaults.scroll_offset_y end
    if defaults.scroll_offset_x ~= nil then island_state.scroll_offset_x = defaults.scroll_offset_x end
    if defaults.zoom_x ~= nil then island_state.zoom_x = defaults.zoom_x end
    -- Phase 4: map legacy selected_note_index to selected_indices
    if defaults.selected_note_index ~= nil then
        island_state.selected_indices = {[defaults.selected_note_index] = true}
        island_state._last_selected_idx = defaults.selected_note_index
    end
    if defaults.current_directory ~= nil then island_state.current_directory = defaults.current_directory end
    if defaults.preset_root ~= nil then island_state.preset_root = defaults.preset_root end
    if defaults.velocity_panel_expanded ~= nil then island_state.velocity_panel_expanded = defaults.velocity_panel_expanded end
    -- Delegate notes + undo/redo init to note-store
    note_store.Init(defaults)
end

-- Island active state
function m.GetIslandActive() return island_state.island_active end
function m.SetIslandActive(v) island_state.island_active = v end

-- Preset panel visibility (collapsible left panel)
function m.GetPresetPanelVisible() return island_state.preset_panel_visible end
function m.SetPresetPanelVisible(v) island_state.preset_panel_visible = v end

-- Notes table — delegated to note-store
function m.GetNotes() return note_store.GetNotes() end
function m.SetNotes(t)
    note_store.SetNotes(t)
    island_state.note_count = note_store.GetNoteCount()
    m.ClearSelection()  -- old indices are invalid when notes are replaced
end

-- Note count — delegated to note-store
function m.GetNoteCount() return note_store.GetNoteCount() end
function m.SetNoteCount(v) note_store.SetNoteCount(v); island_state.note_count = v end

-- Playback position (beats)
function m.GetPlaybackPos() return island_state.playback_pos end
function m.SetPlaybackPos(v) island_state.playback_pos = v end

-- Vertical scroll offset (pitch rows) — safe upper bound; final clamp
-- by visible viewport happens in ComputeVisibleRanges (piano-roll.lua).
local TOTAL_PITCHES = 108  -- C0 (pitch 12) to B8 (pitch 119)
function m.GetScrollOffsetY() return island_state.scroll_offset_y end
function m.SetScrollOffsetY(v)
    island_state.scroll_offset_y = math.max(0, math.min(TOTAL_PITCHES, v))
end

-- Horizontal scroll offset (beats) — clamped to non-negative
function m.GetScrollOffsetX() return island_state.scroll_offset_x end
function m.SetScrollOffsetX(v)
    island_state.scroll_offset_x = math.max(0, v)
end

-- Zoom level (pixels per beat) — clamped to 10..200
function m.GetZoomX() return island_state.zoom_x end
function m.SetZoomX(v)
    island_state.zoom_x = math.max(10, math.min(200, v))
end

-- =========================================================
-- Tool Mode (Phase 4)
-- =========================================================
function m.GetToolMode() return island_state.tool_mode end
function m.SetToolMode(v) island_state.tool_mode = v or "pointer" end

-- =========================================================
-- Multi-Selection (Phase 4: replaces single selected_note_index)
-- =========================================================
function m.GetSelectedIndices() return island_state.selected_indices end
function m.SetSelectedIndices(t)
    island_state.selected_indices = t or {}
    -- Track the largest index as last-selected (lasso and bulk operations)
    local last = nil
    for k in pairs(island_state.selected_indices) do
        local kn = tonumber(k)
        if kn and (last == nil or kn > last) then last = kn end
    end
    island_state._last_selected_idx = last
end
function m.ClearSelection() island_state.selected_indices = {}; island_state._last_selected_idx = nil end
function m.IsNoteSelected(idx) return island_state.selected_indices[idx] == true end
function m.ToggleNoteSelected(idx)
    if island_state.selected_indices[idx] then
        island_state.selected_indices[idx] = nil
        if island_state._last_selected_idx == idx then
            island_state._last_selected_idx = next(island_state.selected_indices)
        end
    else
        island_state.selected_indices[idx] = true
        island_state._last_selected_idx = idx
    end
end
function m.GetPrimarySelectedIndex()
    -- Returns the last-selected index, or nil if nothing selected
    return island_state._last_selected_idx
end
function m.GetSelectionCount()
    local count = 0
    for _ in pairs(island_state.selected_indices) do count = count + 1 end
    return count
end

-- =========================================================
-- Backward Compat Shims (Phase 4)
-- GetSelectedNoteIndex() / SetSelectedNoteIndex() preserve
-- the original API for velocity.lua and info bar consumers.
-- =========================================================
function m.GetSelectedNoteIndex() return m.GetPrimarySelectedIndex() end
function m.SetSelectedNoteIndex(v)
    m.ClearSelection()
    if v ~= nil then
        island_state.selected_indices[v] = true
        island_state._last_selected_idx = v
    end
end

-- =========================================================
-- Lasso State (Phase 4)
-- =========================================================
function m.GetLassoActive() return island_state.lasso_active end
function m.SetLassoActive(v) island_state.lasso_active = v end
function m.GetLassoStartX() return island_state.lasso_start_x end
function m.SetLassoStartX(v) island_state.lasso_start_x = v end
function m.GetLassoStartY() return island_state.lasso_start_y end
function m.SetLassoStartY(v) island_state.lasso_start_y = v end
function m.GetLassoEndX() return island_state.lasso_end_x end
function m.SetLassoEndX(v) island_state.lasso_end_x = v end
function m.GetLassoEndY() return island_state.lasso_end_y end
function m.SetLassoEndY(v) island_state.lasso_end_y = v end

-- =========================================================
-- Note CRUD (Phase 4)
-- =========================================================
--- Add a note — delegated to note-store.
--- @param note table {pitch, start_beat, duration, velocity, muted}
function m.AddNote(note)
    note_store.AddNote(note)
    island_state.note_count = note_store.GetNoteCount()
end

--- Remove a note at the given index. Delegates to note-store for
--- note removal, then fixes up selected_indices (kept in island).
--- @param idx number 1-based index into notes[]
function m.RemoveNoteAtIndex(idx)
    local prev_count = note_store.GetNoteCount()
    if idx < 1 or idx > prev_count then return end
    note_store.RemoveNoteAtIndex(idx)
    island_state.note_count = note_store.GetNoteCount()
    -- Fix up selected_indices: decrement keys > idx, drop key == idx
    local new_selected = {}
    for k in pairs(island_state.selected_indices) do
        local k_num = tonumber(k)
        if k_num and k_num < idx then
            new_selected[k_num] = true
        elseif k_num and k_num > idx then
            new_selected[k_num - 1] = true
        end
    end
    island_state.selected_indices = new_selected
    -- Fix up _last_selected_idx
    if island_state._last_selected_idx == idx then
        island_state._last_selected_idx = next(new_selected)
    elseif island_state._last_selected_idx and island_state._last_selected_idx > idx then
        island_state._last_selected_idx = island_state._last_selected_idx - 1
    end
end

-- Preset browser state
function m.GetCurrentDirectory() return island_state.current_directory end
function m.SetCurrentDirectory(v) island_state.current_directory = v or "" end
function m.GetPresetRoot() return island_state.preset_root end
function m.SetPresetRoot(v) island_state.preset_root = v or "" end
function m.GetPresetTree() return island_state.preset_tree end
function m.SetPresetTree(t) island_state.preset_tree = t or {} end
function m.GetPresetFiles() return island_state.preset_files end
function m.SetPresetFiles(t) island_state.preset_files = t or {} end
function m.GetSelectedPresetIdx() return island_state.selected_preset_idx end
function m.SetSelectedPresetIdx(v) island_state.selected_preset_idx = v end
function m.GetBrowserScroll() return island_state.browser_scroll end
function m.SetBrowserScroll(v) island_state.browser_scroll = math.max(0, v or 0) end
function m.GetFolderScroll() return island_state.folder_scroll end
function m.SetFolderScroll(v) island_state.folder_scroll = math.max(0, v or 0) end
function m.GetBrowserError() return island_state.browser_error end
function m.SetBrowserError(v) island_state.browser_error = v end
function m.GetFavorites() return island_state.favorites end
function m.SetFavorites(t) island_state.favorites = t or {} end
function m.GetBookmarks() return island_state.bookmarks end
function m.SetBookmarks(t) island_state.bookmarks = t or {} end

-- Velocity panel expanded state
function m.GetVelocityPanelExpanded() return island_state.velocity_panel_expanded end
function m.SetVelocityPanelExpanded(v) island_state.velocity_panel_expanded = v end

-- =========================================================
-- ToggleIsland Resilience (PR1b)
-- =========================================================
function m.GetIslandTransitioning() return island_state.island_transition_in_progress end
function m.SetIslandTransitioning(v) island_state.island_transition_in_progress = v end
function m.GetPreToggleDock() return island_state.pre_toggle_dock end
function m.SetPreToggleDock(v) island_state.pre_toggle_dock = v or 0 end
function m.GetPreToggleRect() return island_state.pre_toggle_rect end
function m.SetPreToggleRect(t) island_state.pre_toggle_rect = t end

-- =========================================================
-- Snap State (PR2)
-- =========================================================
function m.GetSnapEnabled() return island_state.snap_enabled end
function m.SetSnapEnabled(v) island_state.snap_enabled = v end
function m.GetSnapResolution() return island_state.snap_resolution end
function m.SetSnapResolution(v) island_state.snap_resolution = v or 4 end
function m.GetSnapTriplet() return island_state.snap_triplet end
function m.SetSnapTriplet(v) island_state.snap_triplet = v end

-- =========================================================
-- Note Drag State (PR2)
-- =========================================================
function m.GetNoteDragActive() return island_state.note_drag_active end
function m.SetNoteDragActive(v) island_state.note_drag_active = v end
function m.GetNoteDragIndices() return island_state.note_drag_indices end
function m.SetNoteDragIndices(t) island_state.note_drag_indices = t or {} end
function m.GetNoteDragStartPitch() return island_state.note_drag_start_pitch end
function m.SetNoteDragStartPitch(v) island_state.note_drag_start_pitch = v or 0 end
function m.GetNoteDragStartBeat() return island_state.note_drag_start_beat end
function m.SetNoteDragStartBeat(v) island_state.note_drag_start_beat = v or 0 end
function m.GetNoteDragOriginMx() return island_state.note_drag_origin_mx end
function m.SetNoteDragOriginMx(v) island_state.note_drag_origin_mx = v or 0 end
function m.GetNoteDragOriginMy() return island_state.note_drag_origin_my end
function m.SetNoteDragOriginMy(v) island_state.note_drag_origin_my = v or 0 end
function m.GetNoteResizeEdge() return island_state.note_resize_edge end
function m.SetNoteResizeEdge(v) island_state.note_resize_edge = v end
function m.GetNoteDragOrigins() return island_state.note_drag_origins end
function m.SetNoteDragOrigins(t) island_state.note_drag_origins = t or {} end
--- Reset all note drag state to defaults.
function m.ResetNoteDrag()
    island_state.note_drag_active = false
    island_state.note_drag_indices = {}
    island_state.note_drag_start_pitch = 0
    island_state.note_drag_start_beat = 0
    island_state.note_drag_origin_mx = 0
    island_state.note_drag_origin_my = 0
    island_state.note_resize_edge = nil
    island_state.note_drag_origins = {}
end

function m.ClearBrowserState()
    island_state.current_directory = ""
    island_state.preset_tree = {}
    island_state.preset_files = {}
    island_state.selected_preset_idx = nil
    island_state.browser_scroll = 0
    island_state.browser_error = nil
end

-- =========================================================
-- UUID Reverse Index — Delegated to note-store
-- =========================================================
function m.RebuildUUIDIndex() note_store.RebuildUUIDIndex() end
function m.AllocNoteUUID() return note_store.AllocNoteUUID() end
function m.FindNoteByUUID(uuid) return note_store.FindNoteByUUID(uuid) end

-- =========================================================
-- Undo/Redo Stack — Delegated to note-store
-- =========================================================
function m.PushUndo(entry) note_store.PushUndo(entry) end
function m.PopUndo() return note_store.PopUndo() end
function m.PushRedo(entry) note_store.PushRedo(entry) end
function m.PopRedo() return note_store.PopRedo() end
function m.ClearUndoStacks() note_store.ClearUndoStacks() end
function m.GetUndoDepth() return note_store.GetUndoDepth() end
function m.GetRedoDepth() return note_store.GetRedoDepth() end

-- =========================================================
-- Progression→Notes Conversion — Delegated to note-store
-- =========================================================
function m.ProgressionToNotes(progression, beats_per_slot, velocity)
    return note_store.ProgressionToNotes(progression, beats_per_slot, velocity)
end
function m.LoadNotesFromProgression(seq_store)
    note_store.LoadNotesFromProgression(seq_store)
    island_state.note_count = note_store.GetNoteCount()
end
function m.GetVisibleNotes(notes, pitch_start, pitch_end, beat_start, beat_end)
    return note_store.GetVisibleNotes(notes, pitch_start, pitch_end, beat_start, beat_end)
end

return m
