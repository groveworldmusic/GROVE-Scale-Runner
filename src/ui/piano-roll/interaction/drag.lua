-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Piano Roll Interaction — Note Drag/Resize
-- Note drag, resize, drag arming with threshold, multi-note group move.
-- Extracted from interaction.lua (Sprint 2).

local island_store = require("state.island")
local note = require("ui.piano-roll.note")
local grid = require("ui.piano-roll.grid")
local snap = require("core.snap")

local m = {}

-- =========================================================
-- Note Drag / Resize State (module-local, alive per drag session)
-- =========================================================

--- Drag arming: on mouse down over a note, we arm a potential drag
--- but wait for the 8px threshold before actually starting the drag.
--- This lets us distinguish a click (select) from a drag (move).
local _drag_armed_idx = nil   -- note index, or nil
local _drag_armed_mx = 0
local _drag_armed_my = 0

local DRAG_THRESHOLD_PX = 8    -- Euclidean distance threshold to start drag
local RESIZE_HOTZONE_PX = 4    -- right-edge hotzone width

-- =========================================================
-- Drag Arming (threshold-based activation)
-- =========================================================

--- Arm a drag on a note after a simple click (selection) is processed.
--- The drag only activates after the mouse crosses DRAG_THRESHOLD_PX.
--- @param hit_idx number Index of the note clicked
--- @param mx number Mouse pixel x at click time
--- @param my number Mouse pixel y at click time
function m.ArmNoteDrag(hit_idx, mx, my)
    _drag_armed_idx = hit_idx
    _drag_armed_mx = mx
    _drag_armed_my = my
end

--- Check if the mouse has moved past the drag threshold.
--- If so, start the drag operation.
--- Called each frame while mouse is held down.
--- @param mx number Current mouse pixel x
--- @param my number Current mouse pixel y
--- @param grid_x number Grid left edge (pixel)
--- @param grid_y number Grid top edge (pixel)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if drag was started
function m.CheckAndStartDrag(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not _drag_armed_idx then return false end

    local dx = mx - _drag_armed_mx
    local dy = my - _drag_armed_my
    if dx * dx + dy * dy >= DRAG_THRESHOLD_PX * DRAG_THRESHOLD_PX then
        m.StartNoteDrag(_drag_armed_mx, _drag_armed_my, grid_x, grid_y,
                         scroll_y, scroll_x, zoom_x, _drag_armed_idx)
        _drag_armed_idx = nil
        return true
    end
    return false
end

--- Disarm a pending drag (mouse released before threshold reached).
function m.DisarmNoteDrag()
    _drag_armed_idx = nil
end

--- Check if the mouse is within the right-edge resize hotzone of a note block.
--- @param mx number Mouse pixel x
--- @param my number Mouse pixel y
--- @param notes table Note array from island_store
--- @param hit_idx number Index of the note to check
--- @param grid_x number Grid left edge (pixel)
--- @param grid_y number Grid top edge (pixel)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if cursor is in the resize hotzone
function m.IsNoteRightEdge(mx, my, notes, hit_idx, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not notes or not notes[hit_idx] then return false end
    local n = notes[hit_idx]
    local PITCH_ROW_H = grid.PITCH_ROW_H
    local MAX_PITCH = grid.MAX_PITCH
    local MIN_PITCH = grid.MIN_PITCH
    local scroll_px_off = (scroll_y - math.floor(scroll_y)) * PITCH_ROW_H
    local top_pitch = math.max(MIN_PITCH, MAX_PITCH - math.floor(scroll_y))
    local pitch_row = math.floor((my - grid_y + scroll_px_off) / PITCH_ROW_H)
    local click_pitch = math.max(MIN_PITCH, top_pitch - pitch_row)
    if n.pitch ~= click_pitch then return false end

    local right_edge = grid_x + (n.start_beat + (n.duration or 1) - scroll_x) * zoom_x
    local note_top = grid_y + (top_pitch - n.pitch) * PITCH_ROW_H - scroll_px_off
    local note_bot = note_top + PITCH_ROW_H
    if my >= note_top and my <= note_bot then
        return mx >= right_edge - RESIZE_HOTZONE_PX and mx <= right_edge
    end
    return false
end

--- Start a note drag operation. Saves original positions of all selected notes
--- so relative offsets are preserved during multi-note drag.
--- @param mx number Mouse pixel x
--- @param my number Mouse pixel y
--- @param grid_x number Grid left edge (pixel)
--- @param grid_y number Grid top edge (pixel)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @param hit_idx number Index of the note being dragged
function m.StartNoteDrag(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x, hit_idx)
    local notes = island_store.GetNotes()
    if not notes or not notes[hit_idx] then return end

    -- Ensure hit note is selected.
    -- If clicking a non-selected note while others are selected, select only this one.
    local selected = island_store.GetSelectedIndices()
    if not selected[hit_idx] then
        island_store.SetSelectedNoteIndex(hit_idx)
        selected = island_store.GetSelectedIndices()
    end

    -- Save original positions of ALL dragged notes for relative offset preservation
    local drag_indices = {}
    local origins = {}
    for idx in pairs(selected) do
        if notes[idx] then
            drag_indices[#drag_indices + 1] = idx
            origins[idx] = {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration or 1,
            }
        end
    end
    island_store.SetNoteDragOrigins(origins)

    island_store.SetNoteDragIndices(drag_indices)
    island_store.SetNoteDragStartPitch(notes[hit_idx].pitch)
    island_store.SetNoteDragStartBeat(notes[hit_idx].start_beat)
    island_store.SetNoteDragOriginMx(mx)
    island_store.SetNoteDragOriginMy(my)
    island_store.SetNoteDragActive(true)
    island_store.SetNoteResizeEdge(nil)
end

--- Update note positions during an active drag (mouse held + moving).
--- Computes pitch and beat delta from drag origin, applies to all dragged notes.
--- @param mx number Current mouse pixel x
--- @param my number Current mouse pixel y
--- @param grid_x number Grid left edge (pixel)
--- @param grid_y number Grid top edge (pixel)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
function m.UpdateNoteDrag(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not island_store.GetNoteDragActive() then return end

    local notes = island_store.GetNotes()
    local drag_indices = island_store.GetNoteDragIndices()
    if not drag_indices or #drag_indices == 0 then return end

    local PITCH_ROW_H = grid.PITCH_ROW_H

    -- Compute deltas from drag origin (pixel space → pitch/beat space)
    local origin_mx = island_store.GetNoteDragOriginMx()
    local origin_my = island_store.GetNoteDragOriginMy()

    local delta_px_x = mx - origin_mx
    local delta_px_y = my - origin_my

    local delta_pitch = -math.floor(delta_px_y / PITCH_ROW_H + 0.5)  -- inverted Y
    local delta_beat = delta_px_x / zoom_x

    -- Apply delta to each dragged note from its ORIGINAL position
    local origins = island_store.GetNoteDragOrigins()
    for _, idx in ipairs(drag_indices) do
        local orig = origins[idx]
        if orig and notes[idx] then
            local new_pitch = math.max(grid.MIN_PITCH, math.min(grid.MAX_PITCH, orig.pitch + delta_pitch))
            local new_beat = math.max(0, orig.start_beat + delta_beat)
            notes[idx].pitch = new_pitch
            notes[idx].start_beat = new_beat
        end
    end

    note.MarkNotesDirty()
end

--- Commit note drag on mouse up. Snaps positions if snap enabled.
--- Pushes a "move" undo entry with before/after state for all dragged notes.
--- @param mx number Current mouse pixel x
--- @param my number Current mouse pixel y
--- @param grid_x number Grid left edge (pixel)
--- @param grid_y number Grid top edge (pixel)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
function m.CommitNoteDrag(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not island_store.GetNoteDragActive() then return end

    local notes = island_store.GetNotes()
    local drag_indices = island_store.GetNoteDragIndices()
    if not drag_indices or #drag_indices == 0 then
        island_store.ResetNoteDrag()
        return
    end

    -- Snap-aware commit
    local snap_enabled = island_store.GetSnapEnabled()
    local snap_res = snap_enabled and island_store.GetSnapResolution() or 0
    local snap_trip = snap_enabled and island_store.GetSnapTriplet() or false

    local PITCH_ROW_H = grid.PITCH_ROW_H
    local origin_mx = island_store.GetNoteDragOriginMx()
    local origin_my = island_store.GetNoteDragOriginMy()
    local delta_px_x = mx - origin_mx
    local delta_px_y = my - origin_my
    local delta_pitch = -math.floor(delta_px_y / PITCH_ROW_H + 0.5)
    local delta_beat = delta_px_x / zoom_x

    -- Capture undo data BEFORE applying final snap (prev_state from _drag_origins)
    local undo_uuids = {}
    local undo_prev = {}
    local undo_new = {}

    -- Final pass: apply delta + snap
    local origins = island_store.GetNoteDragOrigins()
    for _, idx in ipairs(drag_indices) do
        local orig = origins[idx]
        if orig and notes[idx] then
            -- Capture prev state
            table.insert(undo_uuids, notes[idx].uuid)
            table.insert(undo_prev, {
                pitch = orig.pitch,
                start_beat = orig.start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
            })

            local new_pitch = math.max(grid.MIN_PITCH, math.min(grid.MAX_PITCH, orig.pitch + delta_pitch))
            local new_beat = math.max(0, orig.start_beat + delta_beat)
            if snap_res > 0 then
                new_beat = snap.SnapBeat(new_beat, snap_res, snap_trip)
            end
            notes[idx].pitch = new_pitch
            notes[idx].start_beat = new_beat

            -- Capture new state after snap
            table.insert(undo_new, {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
            })
        end
    end

    -- Push undo entry if anything was moved
    if #undo_uuids > 0 then
        local any_changed = false
        for i, uuid in ipairs(undo_uuids) do
            local p = undo_prev[i]
            local n = undo_new[i]
            if p.pitch ~= n.pitch or p.start_beat ~= n.start_beat then
                any_changed = true
                break
            end
        end
        if any_changed then
            island_store.PushUndo({
                type = "move",
                note_uuids = undo_uuids,
                prev_state = undo_prev,
                new_state = undo_new,
            })
        end
    end

    _drag_origins = {}
    island_store.ResetNoteDrag()
    note.MarkNotesDirty()
end

--- Cancel active note drag — restores ALL dragged notes to their original positions.
--- Called on Escape key press.
function m.CancelNoteDrag()
    if not island_store.GetNoteDragActive() then return end

    local notes = island_store.GetNotes()
    local drag_indices = island_store.GetNoteDragIndices()

    local origins = island_store.GetNoteDragOrigins()
    if drag_indices then
        for _, idx in ipairs(drag_indices) do
            local orig = origins[idx]
            if orig and notes[idx] then
                notes[idx].pitch = orig.pitch
                notes[idx].start_beat = orig.start_beat
            end
        end
    end

    _drag_origins = {}
    island_store.ResetNoteDrag()
    note.MarkNotesDirty()
end

--- Start a note resize (right-edge drag).
--- @param mx number Mouse pixel x
--- @param my number Mouse pixel y
--- @param grid_x number Grid left edge (pixel)
--- @param grid_y number Grid top edge (pixel)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @param hit_idx number Index of the note to resize
function m.StartNoteResize(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x, hit_idx)
    local notes = island_store.GetNotes()
    if not notes or not notes[hit_idx] then return end

    -- Save original position for this single note
    local origins = {}
    origins[hit_idx] = {
        pitch = notes[hit_idx].pitch,
        start_beat = notes[hit_idx].start_beat,
        duration = notes[hit_idx].duration or 1,
    }
    island_store.SetNoteDragOrigins(origins)

    island_store.SetNoteDragIndices({hit_idx})
    island_store.SetNoteDragStartPitch(notes[hit_idx].pitch)
    island_store.SetNoteDragStartBeat(notes[hit_idx].start_beat)
    island_store.SetNoteDragOriginMx(mx)
    island_store.SetNoteDragOriginMy(my)
    island_store.SetNoteDragActive(true)
    island_store.SetNoteResizeEdge("right")
end

--- Update note duration during an active resize.
--- @param mx number Current mouse pixel x
--- @param my number Current mouse pixel y (unused for resize)
--- @param grid_x number Grid left edge (pixel)
--- @param grid_y number Grid top edge (pixel) (unused)
--- @param scroll_y number Vertical scroll offset (unused)
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
function m.UpdateNoteResize(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not island_store.GetNoteDragActive() then return end
    if island_store.GetNoteResizeEdge() ~= "right" then return end

    local notes = island_store.GetNotes()
    local drag_indices = island_store.GetNoteDragIndices()
    if not drag_indices or #drag_indices == 0 then return end

    local idx = drag_indices[1]  -- single note resize
    local origins = island_store.GetNoteDragOrigins()
    local orig = origins[idx]
    if not orig or not notes[idx] then return end

    local origin_mx = island_store.GetNoteDragOriginMx()
    local delta_px = mx - origin_mx
    local delta_duration = delta_px / zoom_x

    local snap_res = island_store.GetSnapEnabled() and island_store.GetSnapResolution() or 0
    local snap_trip = island_store.GetSnapEnabled() and island_store.GetSnapTriplet() or false

    local new_duration = math.max(1 / 64, orig.duration + delta_duration)
    if snap_res > 0 then
        local snap_step = 4 / (snap_trip and snap_res * 1.5 or snap_res)
        if snap_step > 0 then
            new_duration = math.max(snap_step, math.floor(new_duration / snap_step + 0.5) * snap_step)
        end
    end

    notes[idx].duration = new_duration
    note.MarkNotesDirty()
end

--- Commit note resize on mouse up. Final snap + clamp.
--- Pushes a "resize" undo entry.
--- @param mx number Current mouse pixel x
--- @param my number Current mouse pixel y (unused)
--- @param grid_x number Grid left edge (pixel)
--- @param grid_y number Grid top edge (pixel) (unused)
--- @param scroll_y number Vertical scroll offset (unused)
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
function m.CommitNoteResize(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not island_store.GetNoteDragActive() then return end
    if island_store.GetNoteResizeEdge() ~= "right" then
        island_store.ResetNoteDrag()
        return
    end

    local notes = island_store.GetNotes()
    local drag_indices = island_store.GetNoteDragIndices()
    if not drag_indices or #drag_indices == 0 then
        island_store.ResetNoteDrag()
        return
    end

    local idx = drag_indices[1]
    local origins = island_store.GetNoteDragOrigins()
    local orig = origins[idx]
    if not orig or not notes[idx] then
        island_store.ResetNoteDrag()
        return
    end

    local origin_mx = island_store.GetNoteDragOriginMx()
    local delta_px = mx - origin_mx
    local delta_duration = delta_px / zoom_x

    local snap_res = island_store.GetSnapEnabled() and island_store.GetSnapResolution() or 0
    local snap_trip = island_store.GetSnapEnabled() and island_store.GetSnapTriplet() or false

    local new_duration = math.max(1 / 64, orig.duration + delta_duration)
    if snap_res > 0 then
        new_duration = snap.SnapBeat(new_duration, snap_res, snap_trip)
    end
    -- Minimum 1 subdivision
    local min_dur = 1 / math.max(1, snap_res or 4)
    new_duration = math.max(min_dur, new_duration)

    -- Push undo entry: resize
    if notes[idx].duration ~= new_duration then
        island_store.PushUndo({
            type = "resize",
            note_uuids = {notes[idx].uuid},
            prev_state = {{duration = orig.duration}},
            new_state = {{duration = new_duration}},
        })
    end

    notes[idx].duration = new_duration

    _drag_origins = {}
    island_store.ResetNoteDrag()
    note.MarkNotesDirty()
end

return m
