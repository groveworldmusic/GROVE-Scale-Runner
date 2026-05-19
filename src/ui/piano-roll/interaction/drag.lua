-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Piano Roll Interaction — Note Drag/Resize + Right-Drag Delete Sweep
-- Note drag, resize (left/right edge), drag arming with threshold, multi-note group move.
-- Phase 5: Added IsNoteLeftEdge, left-edge resize support, right-drag delete sweep.
-- Extracted from interaction.lua (Sprint 2).

local island_store = require("state.island")
local note_store = require("state.note-store")
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
local RESIZE_HOTZONE_PX = 4    -- edge hotzone width (left and right)

-- =========================================================
-- Right-Drag Delete Sweep State
-- =========================================================
local _rds_active = false
local _rds_start_x = 0
local _rds_start_y = 0
local _rds_current_x = 0
local _rds_current_y = 0
local _rds_deleted_uuids = {}   -- Set of UUIDs already deleted (immediate)
local _rds_undo_uuids = {}      -- Accumulated undo UUIDs
local _rds_undo_prev = {}       -- Accumulated undo prev_state

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

-- =========================================================
-- Edge Hit Testing (left and right)
-- =========================================================

--- Check if the mouse is within the right-edge resize hotzone of a note block.
--- @return boolean true if cursor is in the right-edge resize hotzone
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

--- Check if the mouse is within the left-edge resize hotzone of a note block.
--- 4px hotzone on the left side of the note block.
--- @return boolean true if cursor is in the left-edge resize hotzone
function m.IsNoteLeftEdge(mx, my, notes, hit_idx, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
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

    local left_edge = grid_x + (n.start_beat - scroll_x) * zoom_x
    local note_top = grid_y + (top_pitch - n.pitch) * PITCH_ROW_H - scroll_px_off
    local note_bot = note_top + PITCH_ROW_H
    if my >= note_top and my <= note_bot then
        return mx >= left_edge and mx <= left_edge + RESIZE_HOTZONE_PX
    end
    return false
end

-- =========================================================
-- Note Drag (multi-note group move)
-- =========================================================

--- Start a note drag operation. Saves original positions of all selected notes
--- so relative offsets are preserved during multi-note drag.
function m.StartNoteDrag(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x, hit_idx)
    local notes = island_store.GetNotes()
    if not notes or not notes[hit_idx] then return end

    local selected = island_store.GetSelectedIndices()
    if not selected[hit_idx] then
        island_store.SetSelectedNoteIndex(hit_idx)
        selected = island_store.GetSelectedIndices()
    end

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
function m.UpdateNoteDrag(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not island_store.GetNoteDragActive() then return end

    local notes = island_store.GetNotes()
    local drag_indices = island_store.GetNoteDragIndices()
    if not drag_indices or #drag_indices == 0 then return end

    local PITCH_ROW_H = grid.PITCH_ROW_H
    local origin_mx = island_store.GetNoteDragOriginMx()
    local origin_my = island_store.GetNoteDragOriginMy()
    local delta_px_x = mx - origin_mx
    local delta_px_y = my - origin_my
    local delta_pitch = -math.floor(delta_px_y / PITCH_ROW_H + 0.5)
    local delta_beat = delta_px_x / zoom_x

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

    island_store.SetNotesState(island_store.NOTES_STATE_EDITED)
end

--- Commit note drag on mouse up. Snaps positions if snap enabled.
--- Pushes a "move" undo entry with before/after state for all dragged notes.
function m.CommitNoteDrag(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not island_store.GetNoteDragActive() then return end

    local notes = island_store.GetNotes()
    local drag_indices = island_store.GetNoteDragIndices()
    if not drag_indices or #drag_indices == 0 then
        island_store.ResetNoteDrag()
        return
    end

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

    local undo_uuids = {}
    local undo_prev = {}
    local undo_new = {}

    local origins = island_store.GetNoteDragOrigins()
    for _, idx in ipairs(drag_indices) do
        local orig = origins[idx]
        if orig and notes[idx] then
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

            table.insert(undo_new, {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
            })
        end
    end

    if #undo_uuids > 0 then
        local any_changed = false
        for i, _ in ipairs(undo_uuids) do
            local p = undo_prev[i]
            local n = undo_new[i]
            if p.pitch ~= n.pitch or p.start_beat ~= n.start_beat then
                any_changed = true
                break
            end
        end
        if any_changed then
            note_store.PushUndo({
                type = "move",
                note_uuids = undo_uuids,
                prev_state = undo_prev,
                new_state = undo_new,
            })
        end
    end

    island_store.ResetNoteDrag()
    island_store.SetNotesState(island_store.NOTES_STATE_EDITED)
end

--- Cancel active note drag — restores ALL dragged notes to their original positions.
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

    island_store.ResetNoteDrag()
    island_store.SetNotesState(island_store.NOTES_STATE_EDITED)
end

-- =========================================================
-- Note Resize (Left and Right Edge)
-- =========================================================

--- Start a note resize (left or right edge drag).
--- For right-edge: duration changes, start_beat stays fixed.
--- For left-edge: start_beat changes (duration shrinks/expands), end_beat stays fixed.
--- @param edge string "left" or "right"
function m.StartNoteResize(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x, hit_idx, edge)
    local notes = island_store.GetNotes()
    if not notes or not notes[hit_idx] then return end

    edge = edge or "right"

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
    island_store.SetNoteResizeEdge(edge)
end

--- Update note duration/start_beat during an active resize.
function m.UpdateNoteResize(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not island_store.GetNoteDragActive() then return end
    local edge = island_store.GetNoteResizeEdge()
    if edge ~= "right" and edge ~= "left" then return end

    local notes = island_store.GetNotes()
    local drag_indices = island_store.GetNoteDragIndices()
    if not drag_indices or #drag_indices == 0 then return end

    local idx = drag_indices[1]
    local origins = island_store.GetNoteDragOrigins()
    local orig = origins[idx]
    if not orig or not notes[idx] then return end

    local origin_mx = island_store.GetNoteDragOriginMx()
    local delta_px = mx - origin_mx
    local delta_dur = delta_px / zoom_x

    local snap_enabled = island_store.GetSnapEnabled()
    local snap_res = snap_enabled and island_store.GetSnapResolution() or 0
    local snap_trip = snap_enabled and island_store.GetSnapTriplet() or false

    local MIN_DURATION = 1 / math.max(1, snap_res or 4)

    if edge == "right" then
        -- Right edge: duration changes, start_beat stays fixed
        local new_duration = math.max(MIN_DURATION, orig.duration + delta_dur)
        if snap_res > 0 then
            local snap_step = 4 / (snap_trip and snap_res * 1.5 or snap_res)
            if snap_step > 0 then
                new_duration = math.max(snap_step, math.floor(new_duration / snap_step + 0.5) * snap_step)
            end
        end
        notes[idx].duration = new_duration

    elseif edge == "left" then
        -- Left edge: start_beat changes, end_beat stays fixed
        local end_beat = orig.start_beat + orig.duration
        local new_start = math.max(0, orig.start_beat + delta_dur)
        if snap_res > 0 then
            new_start = snap.SnapBeat(new_start, snap_res, snap_trip)
        end
        -- Clamp so duration doesn't go below minimum
        local max_start = end_beat - MIN_DURATION
        new_start = math.min(max_start, new_start)
        local new_duration = end_beat - new_start
        notes[idx].start_beat = new_start
        notes[idx].duration = math.max(MIN_DURATION, new_duration)
    end

    island_store.SetNotesState(island_store.NOTES_STATE_EDITED)
end

--- Commit note resize on mouse up. Final snap + clamp. Pushes undo entry.
function m.CommitNoteResize(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not island_store.GetNoteDragActive() then return end
    local edge = island_store.GetNoteResizeEdge()
    if edge ~= "right" and edge ~= "left" then
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
    local delta_dur = delta_px / zoom_x

    local snap_enabled = island_store.GetSnapEnabled()
    local snap_res = snap_enabled and island_store.GetSnapResolution() or 0
    local snap_trip = snap_enabled and island_store.GetSnapTriplet() or false
    local MIN_DURATION = 1 / math.max(1, snap_res or 4)

    local old_start = orig.start_beat
    local old_duration = orig.duration
    local new_start = old_start
    local new_duration = old_duration

    if edge == "right" then
        new_duration = math.max(MIN_DURATION, old_duration + delta_dur)
        if snap_res > 0 then
            new_duration = snap.SnapBeat(new_duration, snap_res, snap_trip)
        end
        new_duration = math.max(MIN_DURATION, new_duration)

        if notes[idx].duration ~= new_duration then
            note_store.PushUndo({
                type = "resize",
                note_uuids = {notes[idx].uuid},
                prev_state = {{duration = old_duration}},
                new_state = {{duration = new_duration}},
            })
        end
        notes[idx].duration = new_duration

    elseif edge == "left" then
        local end_beat = old_start + old_duration
        new_start = math.max(0, old_start + delta_dur)
        if snap_res > 0 then
            new_start = snap.SnapBeat(new_start, snap_res, snap_trip)
        end
        local max_start = end_beat - MIN_DURATION
        new_start = math.min(max_start, new_start)
        new_duration = end_beat - new_start

        if notes[idx].start_beat ~= new_start or notes[idx].duration ~= new_duration then
            note_store.PushUndo({
                type = "resize",
                note_uuids = {notes[idx].uuid},
                prev_state = {{start_beat = old_start, duration = old_duration}},
                new_state = {{start_beat = new_start, duration = new_duration}},
            })
        end
        notes[idx].start_beat = new_start
        notes[idx].duration = math.max(MIN_DURATION, new_duration)
    end

    island_store.ResetNoteDrag()
    island_store.SetNotesState(island_store.NOTES_STATE_EDITED)
end

-- =========================================================
-- Right-Drag Delete Sweep
-- =========================================================

--- Start a right-drag delete sweep (tracking start position).
--- Called when right mouse button is pressed in the grid area.
function m.StartRightDragSweep(mx, my)
    _rds_active = true
    _rds_start_x = mx
    _rds_start_y = my
    _rds_current_x = mx
    _rds_current_y = my
    _rds_deleted_uuids = {}
    _rds_undo_uuids = {}
    _rds_undo_prev = {}
end

--- Update the right-drag sweep and delete notes immediately as the drag rect expands.
--- Notes are removed on-the-fly so the user sees instant feedback.
--- Deleted UUIDs are tracked to avoid double-deletion within the same sweep.
--- @param mx number Current mouse pixel x
--- @param my number Current mouse pixel y
--- @param grid_x number Grid left edge in pixels
--- @param grid_y number Grid top edge in pixels
--- @param scroll_y number Vertical scroll offset in pitches
--- @param scroll_x number Horizontal scroll offset in beats
--- @param zoom_x number Pixels per beat
function m.UpdateRightDragSweep(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not _rds_active then return end
    _rds_current_x = mx
    _rds_current_y = my

    -- Find notes in the current drag rect
    local rx1 = math.min(_rds_start_x, _rds_current_x)
    local ry1 = math.min(_rds_start_y, _rds_current_y)
    local rx2 = math.max(_rds_start_x, _rds_current_x)
    local ry2 = math.max(_rds_start_y, _rds_current_y)

    if math.abs(rx2 - rx1) < 3 and math.abs(ry2 - ry1) < 3 then return end

    local indices = note.GetNotesInRect(rx1, ry1, rx2, ry2, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if #indices == 0 then return end

    local notes = island_store.GetNotes()
    local to_remove = {}

    for _, idx in ipairs(indices) do
        local n = notes[idx]
        if n and n.uuid and not _rds_deleted_uuids[n.uuid] then
            _rds_deleted_uuids[n.uuid] = true
            table.insert(_rds_undo_uuids, n.uuid)
            table.insert(_rds_undo_prev, {
                pitch = n.pitch,
                start_beat = n.start_beat,
                duration = n.duration,
                velocity = n.velocity,
                muted = n.muted,
                uuid = n.uuid,
            })
            table.insert(to_remove, idx)
        end
    end

    if #to_remove == 0 then return end

    -- Remove in reverse order to preserve indices
    table.sort(to_remove, function(a, b) return a > b end)
    for _, idx in ipairs(to_remove) do
        island_store.RemoveNoteAtIndex(idx)
    end

    island_store.SetNotesState(island_store.NOTES_STATE_EDITED)
end

--- Commit right-drag delete sweep: push accumulated undo entry and clean up.
--- Notes are already deleted immediately during UpdateRightDragSweep.
--- This just finalizes the undo entry and resets sweep state.
--- @return boolean true if any notes were deleted during the sweep
function m.CommitRightDragSweep(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    if not _rds_active then return false end
    _rds_active = false

    local had_deletions = #_rds_undo_uuids > 0

    -- Check for undragged rect notes (notes under the final rect that weren't
    -- caught by incremental updates — shouldn't happen but belt and suspenders)
    local rx1 = math.min(_rds_start_x, _rds_current_x)
    local ry1 = math.min(_rds_start_y, _rds_current_y)
    local rx2 = math.max(_rds_start_x, _rds_current_x)
    local ry2 = math.max(_rds_start_y, _rds_current_y)

    if not had_deletions and math.abs(rx2 - rx1) >= 3 and math.abs(ry2 - ry1) >= 3 then
        -- No incremental deletions happened — try final rect sweep as fallback
        local indices = note.GetNotesInRect(rx1, ry1, rx2, ry2, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
        local notes = island_store.GetNotes()
        local to_remove = {}
        for _, idx in ipairs(indices) do
            local n = notes[idx]
            if n and n.uuid and not _rds_deleted_uuids[n.uuid] then
                _rds_deleted_uuids[n.uuid] = true
                table.insert(_rds_undo_uuids, n.uuid)
                table.insert(_rds_undo_prev, {
                    pitch = n.pitch, start_beat = n.start_beat, duration = n.duration,
                    velocity = n.velocity, muted = n.muted, uuid = n.uuid,
                })
                table.insert(to_remove, idx)
            end
        end
        if #to_remove > 0 then
            table.sort(to_remove, function(a, b) return a > b end)
            for _, idx in ipairs(to_remove) do
                island_store.RemoveNoteAtIndex(idx)
            end
            had_deletions = true
        end
    end

    -- Push accumulated undo entry
    if had_deletions then
        note_store.PushUndo({
            type = "delete",
            note_uuids = _rds_undo_uuids,
            prev_state = _rds_undo_prev,
        })
    end

    -- Reset sweep state
    _rds_deleted_uuids = {}
    _rds_undo_uuids = {}
    _rds_undo_prev = {}

    if had_deletions then
        island_store.SetNotesState(island_store.NOTES_STATE_EDITED)
    end
    return had_deletions
end

--- Cancel right-drag sweep (e.g., if mouse leaves grid area or right button released outside).
--- Clears tracking state without pushing undo.
function m.CancelRightDragSweep()
    _rds_active = false
    _rds_deleted_uuids = {}
    _rds_undo_uuids = {}
    _rds_undo_prev = {}
end

--- Check if a right-drag delete sweep is currently active.
--- @return boolean
function m.GetRightDragSweepActive()
    return _rds_active
end

--- Draw the right-drag sweep rectangle if active.
--- Uses a red-tinted semi-transparent fill to distinguish from lasso.
function m.DrawRightDragSweepRect()
    if not _rds_active then return end

    local rx, ry = math.min(_rds_start_x, _rds_current_x), math.min(_rds_start_y, _rds_current_y)
    local rw = math.abs(_rds_current_x - _rds_start_x)
    local rh = math.abs(_rds_current_y - _rds_start_y)

    if rw < 1 or rh < 1 then return end

    -- Fill: red tint
    local helpers = require("ui.helpers")
    helpers.SetColor({0.8, 0.2, 0.2, 0.15})
    gfx.rect(rx, ry, rw, rh, 1)
    -- Border: red
    helpers.SetColor({0.9, 0.3, 0.3, 0.6})
    gfx.rect(rx, ry, rw, rh, 0)
end

return m
