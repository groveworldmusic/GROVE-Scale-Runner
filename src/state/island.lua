-- GROVE FL MIDI: Island State Store
-- Encapsulates island piano-roll state with getters/setters.
-- Schema: island_active, preset_panel_visible, notes (flat note list),
--         playback_pos, scroll_offset_y/x, zoom_x, selected_indices, note_count.
-- Phase 4: Added tool_mode, selected_indices (replacing selected_note_index),
--          lasso state, AddNote/RemoveNoteAtIndex.
local config = require("config")

local MAX_UNDO = 50
local _uuid_to_idx = {}  -- Reverse index: note.uuid → array index

local island_state = {
    island_active = false,
    preset_panel_visible = true,
    notes = {},
    playback_pos = 0,
    scroll_offset_y = 36,  -- default: scroll position
    scroll_offset_x = 0,
    zoom_x = 40,
    tool_mode = "pointer",               -- "pointer"|"pencil"|"eraser"
    selected_indices = {},               -- {[idx]=true} replaces selected_note_index
    note_count = 0,

    -- Lasso state (Phase 4)
    lasso_active = false,
    lasso_start_x = 0,
    lasso_start_y = 0,
    lasso_end_x = 0,
    lasso_end_y = 0,

    -- Preset browser state
    current_directory = "",
    preset_root = "",
    preset_tree = {},
    preset_files = {},
    selected_preset_idx = nil,
    browser_scroll = 0,
    browser_error = nil,
    favorites = {},
    bookmarks = {},
    velocity_panel_expanded = true,

    -- ToggleIsland resilience (PR1b)
    island_transition_in_progress = false,
    pre_toggle_dock = 0,
    pre_toggle_rect = nil,

    -- Snap state (PR2)
    snap_enabled = true,
    snap_resolution = 4,         -- subdivisions per whole note: 1/2/4/8/16/32
    snap_triplet = false,

    -- Note drag/resize state (PR2)
    note_drag_active = false,
    note_drag_indices = {},
    note_drag_start_pitch = 0,
    note_drag_start_beat = 0,
    note_drag_origin_mx = 0,
    note_drag_origin_my = 0,
    note_resize_edge = nil,      -- "left" or "right"

    -- Undo/redo state (PR3)
    undo_stack = {},
    redo_stack = {},
    next_note_uuid = 1,
    undo_depth = 0,
    redo_depth = 0,
}

local m = {}

function m.Init(defaults)
    if defaults.island_active ~= nil then island_state.island_active = defaults.island_active end
    if defaults.preset_panel_visible ~= nil then island_state.preset_panel_visible = defaults.preset_panel_visible end
    if defaults.notes then
        -- notes are shared by reference
        island_state.notes = defaults.notes
        island_state.note_count = #defaults.notes
    end
    if defaults.playback_pos ~= nil then island_state.playback_pos = defaults.playback_pos end
    if defaults.scroll_offset_y ~= nil then island_state.scroll_offset_y = defaults.scroll_offset_y end
    if defaults.scroll_offset_x ~= nil then island_state.scroll_offset_x = defaults.scroll_offset_x end
    if defaults.zoom_x ~= nil then island_state.zoom_x = defaults.zoom_x end
    -- Phase 4: map legacy selected_note_index to selected_indices
    if defaults.selected_note_index ~= nil then
        island_state.selected_indices = {[defaults.selected_note_index] = true}
    end
    if defaults.current_directory ~= nil then island_state.current_directory = defaults.current_directory end
    if defaults.preset_root ~= nil then island_state.preset_root = defaults.preset_root end
    if defaults.velocity_panel_expanded ~= nil then island_state.velocity_panel_expanded = defaults.velocity_panel_expanded end
end

-- Island active state
function m.GetIslandActive() return island_state.island_active end
function m.SetIslandActive(v) island_state.island_active = v end

-- Preset panel visibility (collapsible left panel)
function m.GetPresetPanelVisible() return island_state.preset_panel_visible end
function m.SetPresetPanelVisible(v) island_state.preset_panel_visible = v end

-- Notes table — returned by reference for in-place mutation
-- Each entry: {pitch, start_beat, duration, velocity, muted, uuid}
function m.GetNotes() return island_state.notes end
function m.SetNotes(t)
    island_state.notes = t or {}
    island_state.note_count = #island_state.notes
    m.ClearSelection()  -- old indices are invalid when notes are replaced
    m.RebuildUUIDIndex()
end

-- Note count — updated automatically by SetNotes, can also be set directly
function m.GetNoteCount() return island_state.note_count end
function m.SetNoteCount(v) island_state.note_count = v end

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
function m.SetSelectedIndices(t) island_state.selected_indices = t or {} end
function m.ClearSelection() island_state.selected_indices = {} end
function m.IsNoteSelected(idx) return island_state.selected_indices[idx] == true end
function m.ToggleNoteSelected(idx)
    if island_state.selected_indices[idx] then
        island_state.selected_indices[idx] = nil
    else
        island_state.selected_indices[idx] = true
    end
end
function m.GetPrimarySelectedIndex()
    -- Returns the first key in selected_indices, or nil
    return next(island_state.selected_indices)
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
    if v ~= nil then island_state.selected_indices[v] = true end
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
--- Append a note to the notes table. Sets origin = "manual" automatically.
--- Assigns UUID if not already set. Updates reverse index.
--- @param note table {pitch, start_beat, duration, velocity, muted}
function m.AddNote(note)
    note.uuid = note.uuid or m.AllocNoteUUID()
    if note.origin == nil then note.origin = "manual" end
    table.insert(island_state.notes, note)
    island_state.note_count = #island_state.notes
    if note.uuid then
        _uuid_to_idx[note.uuid] = #island_state.notes
    end
end

--- Remove a note at the given index. Shifts subsequent entries and
--- fixes up selected_indices so indices after the removed entry are adjusted.
--- Also rebuilds UUID reverse index.
--- @param idx number 1-based index into notes[]
function m.RemoveNoteAtIndex(idx)
    if idx < 1 or idx > #island_state.notes then return end
    table.remove(island_state.notes, idx)
    island_state.note_count = #island_state.notes
    -- Rebuild UUID index since indices shifted
    m.RebuildUUIDIndex()
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
--- Reset all note drag state to defaults.
function m.ResetNoteDrag()
    island_state.note_drag_active = false
    island_state.note_drag_indices = {}
    island_state.note_drag_start_pitch = 0
    island_state.note_drag_start_beat = 0
    island_state.note_drag_origin_mx = 0
    island_state.note_drag_origin_my = 0
    island_state.note_resize_edge = nil
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
-- UUID Reverse Index (PR3)
-- =========================================================

--- Rebuild the UUID-to-index reverse index from scratch.
--- Call after any operation that adds/removes/reorders notes.
function m.RebuildUUIDIndex()
    _uuid_to_idx = {}
    local notes = island_state.notes
    for i, note in ipairs(notes) do
        if note.uuid then
            _uuid_to_idx[note.uuid] = i
        end
    end
end

--- Allocate a new monotonic UUID for a note.
--- @return number
function m.AllocNoteUUID()
    local uuid = island_state.next_note_uuid
    island_state.next_note_uuid = island_state.next_note_uuid + 1
    return uuid
end

--- Find a note's array index by UUID.
--- @param uuid number
--- @return number|nil Note index, or nil if not found
function m.FindNoteByUUID(uuid)
    return _uuid_to_idx[uuid]
end

-- =========================================================
-- Undo/Redo Stack Functions (PR3)
-- =========================================================

--- Push an undo entry onto the undo stack.
--- Automatically clears the redo stack (new edit invalidates redo).
--- FIFO eviction when stack exceeds MAX_UNDO (50).
--- Entry format: {type, note_uuids, prev_state, new_state, timestamp}
--- @param entry table
function m.PushUndo(entry)
    entry.timestamp = os.clock()
    table.insert(island_state.undo_stack, entry)
    island_state.undo_depth = #island_state.undo_stack
    if island_state.undo_depth > MAX_UNDO then
        table.remove(island_state.undo_stack, 1)
        island_state.undo_depth = MAX_UNDO
    end
    -- New edit → clear redo stack
    island_state.redo_stack = {}
    island_state.redo_depth = 0
end

--- Pop the most recent undo entry.
--- @return table|nil
function m.PopUndo()
    if #island_state.undo_stack == 0 then return nil end
    local entry = table.remove(island_state.undo_stack)
    island_state.undo_depth = #island_state.undo_stack
    return entry
end

--- Push a redo entry onto the redo stack.
--- @param entry table
function m.PushRedo(entry)
    entry.timestamp = os.clock()
    table.insert(island_state.redo_stack, entry)
    island_state.redo_depth = #island_state.redo_stack
    if island_state.redo_depth > MAX_UNDO then
        table.remove(island_state.redo_stack, 1)
        island_state.redo_depth = MAX_UNDO
    end
end

--- Pop the most recent redo entry.
--- @return table|nil
function m.PopRedo()
    if #island_state.redo_stack == 0 then return nil end
    local entry = table.remove(island_state.redo_stack)
    island_state.redo_depth = #island_state.redo_stack
    return entry
end

--- Clear both undo and redo stacks.
function m.ClearUndoStacks()
    island_state.undo_stack = {}
    island_state.redo_stack = {}
    island_state.undo_depth = 0
    island_state.redo_depth = 0
end

--- Get the current undo stack depth.
--- @return number
function m.GetUndoDepth() return island_state.undo_depth end

--- Get the current redo stack depth.
--- @return number
function m.GetRedoDepth() return island_state.redo_depth end

-- =========================================================
-- Progression→Notes Conversion
-- =========================================================

--- Pure function: converts a progression entry to a MIDI pitch.
--- Matches the formula from midi.GetMidiNote (core/midi.lua line 14-23)
--- without requiring the midi module directly.
--- @param root_idx number 1-12 (index into NOTE_NAMES)
--- @param scale_idx number 1-21 (index into SCALES)
--- @param degree_idx number 1-N (scale degree, wraps by scale length)
--- @param octave_val number 0-8 (MIDI octave)
--- @return number 0-127 (MIDI pitch)
local function ProgressionEntryToPitch(root_idx, scale_idx, degree_idx, octave_val)
    local root = root_idx - 1
    local scale = config.SCALES[scale_idx]
    local n_scale = #scale.intervals
    local deg0 = degree_idx - 1
    local oct_off = math.floor(deg0 / n_scale)
    local interval = scale.intervals[(deg0 % n_scale) + 1]
    local result = (octave_val + 1) * 12 + root + (oct_off * 12) + interval
    return math.max(0, math.min(127, result))
end

--- Convert a progression entry table to a list of note pitches.
--- Each entry has {degree, root_index, scale_index, octave, chord_mode_index}.
--- Each chord offset produces one pitch.
--- @param entry table Progression slot entry
--- @return table Array of MIDI pitch numbers
local function EntryToPitches(entry)
    local chord_mode = config.CHORD_MODES[entry.chord_mode_index or 1]
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
--- Each chord offset becomes a separate note entry.
---
--- @param progression table Array of progression entries (1..16, may have nils)
--- @param beats_per_slot number Beats per slot (default 4)
--- @param velocity number Default velocity (default 100)
--- @return table Array of {pitch, start_beat, duration, velocity, muted}
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
                -- SUBDIVIDED SLOT: create one note group per sub-chord
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
                -- LEGACY single-chord entry
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

--- Convenience: reads progression from sequencer_store and populates island notes.
--- Call this when entering island mode to materialise the progression as note blocks.
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
