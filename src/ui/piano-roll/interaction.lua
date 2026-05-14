-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Piano Roll Interaction
-- Mouse event handlers, lasso rendering, Ctrl+A, keyboard shortcuts, undo/redo (PR3).
-- Extracted from piano-roll.lua barrel (PR1b).
-- Depends on note (hit test) and grid (constants).

local island_store = require("state.island")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local note = require("ui.piano-roll.note")
local grid = require("ui.piano-roll.grid")
local snap = require("core.snap")

local m = {}

-- Module-level clipboard for cut/copy/paste (PR3)
local _clipboard = {}

-- =========================================================
-- Note Drag / Resize State (module-local, alive per drag session)
-- =========================================================

--- Used for multi-note group move: relative offsets preserved by
--- applying the same delta to each note's original position.
-- Removed local _drag_origins, now using island_store.GetNoteDragOrigins() (Phase 5)

--- Drag arming: on mouse down over a note, we arm a potential drag
--- but wait for the 8px threshold before actually starting the drag.
--- This lets us distinguish a click (select) from a drag (move).
local _drag_armed_idx = nil   -- note index, or nil
local _drag_armed_mx = 0
local _drag_armed_my = 0

local DRAG_THRESHOLD_PX = 8    -- Euclidean distance threshold to start drag
local RESIZE_HOTZONE_PX = 4    -- right-edge hotzone width

-- =========================================================
-- Mouse Handlers
-- =========================================================

--- Handle mouse click in piano roll area (pointer tool).
--- Click on note: select it (deselect others). Click same note again: deselect.
--- Click on empty area: deselect all.
--- If shift_held: additive toggle (no clear).
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @param shift_held boolean? Shift key held (additive mode)
--- @return boolean true if click was consumed
function m.HandleMouseClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x, shift_held)
    local notes = island_store.GetNotes()
    local idx = note.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    if idx then
        if shift_held then
            -- Shift-click: toggle selection without clearing
            island_store.ToggleNoteSelected(idx)
        else
            -- Normal click
            if island_store.IsNoteSelected(idx) then
                island_store.ClearSelection()
            else
                island_store.SetSelectedNoteIndex(idx)
            end
        end
    else
        if not shift_held then
            island_store.ClearSelection()
        end
        -- Shift-click on empty area: preserve current selection
    end
    return true
end

--- Handle right-click in piano roll area: toggle mute on ALL selected notes.
--- If the clicked note is not already selected, select it first (clear others).
--- Pushes a "mute" undo entry (batch — all toggled notes in one entry).
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if right-click was consumed
function m.HandleRightClickMute(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local notes = island_store.GetNotes()
    local idx = note.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    if idx and notes[idx] then
        -- If clicked note is not already selected, select it exclusively
        if not island_store.IsNoteSelected(idx) then
            island_store.SetSelectedNoteIndex(idx)
        end
        -- Toggle mute for ALL selected notes
        local selected = island_store.GetSelectedIndices()
        local any_toggled = false
        local undo_uuids = {}
        local undo_prev = {}
        local undo_new = {}
        for sel_idx in pairs(selected) do
            if notes[sel_idx] then
                local old_muted = notes[sel_idx].muted
                notes[sel_idx].muted = not old_muted
                any_toggled = true
                table.insert(undo_uuids, notes[sel_idx].uuid)
                table.insert(undo_prev, {muted = old_muted})
                table.insert(undo_new, {muted = notes[sel_idx].muted})
            end
        end
        if any_toggled and #undo_uuids > 0 then
            island_store.PushUndo({
                type = "mute",
                note_uuids = undo_uuids,
                prev_state = undo_prev,
                new_state = undo_new,
            })
        end
        return any_toggled
    end
    return false
end

--- Handle pencil click: create a new note at the clicked position.
--- Converts mouse position to pitch + beat (inverted Y), snaps beat to half-beat.
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if note was created
function m.HandlePencilClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local PITCH_ROW_H = grid.PITCH_ROW_H
    local MIN_PITCH = grid.MIN_PITCH
    local MAX_PITCH = grid.MAX_PITCH

    -- Convert mouse to beat space
    local beat = (mx - grid_x) / zoom_x + scroll_x
    -- Snap to nearest grid boundary (respects snap settings)
    local snap_enabled = island_store.GetSnapEnabled()
    local snap_res = snap_enabled and island_store.GetSnapResolution() or 0
    local snap_trip = snap_enabled and island_store.GetSnapTriplet() or false
    local snapped_beat = beat
    if snap_res > 0 then
        snapped_beat = snap.SnapBeat(beat, snap_res, snap_trip)
    else
        snapped_beat = beat  -- no snap: use exact beat
    end

    -- Convert mouse to pitch (inverted Y: high pitch at top)
    -- Account for sub-pixel smooth scroll offset
    local scroll_px_off = (scroll_y - math.floor(scroll_y)) * PITCH_ROW_H
    local pitch_row = math.floor((my - grid_y + scroll_px_off) / PITCH_ROW_H)
    local top_pitch = math.max(MIN_PITCH, MAX_PITCH - math.floor(scroll_y))
    local pitch = math.max(MIN_PITCH, math.min(MAX_PITCH, top_pitch - pitch_row))

    local new_note = {
        pitch = pitch,
        start_beat = snapped_beat,
        duration = 1,
        velocity = 100,
        muted = false,
    }
    island_store.AddNote(new_note)
    -- Push undo entry for note creation
    island_store.PushUndo({
        type = "add",
        note_uuids = {new_note.uuid},
        new_state = {{
            pitch = new_note.pitch,
            start_beat = new_note.start_beat,
            duration = new_note.duration,
            velocity = new_note.velocity,
            muted = new_note.muted,
            uuid = new_note.uuid,
        }},
    })
    note.MarkNotesDirty()
    return true
end

--- Handle eraser click: hit-test and remove the clicked note.
--- Pushes a "delete" undo entry.
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if a note was removed
function m.HandleEraserClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local notes = island_store.GetNotes()
    local idx = note.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    if idx and notes[idx] then
        -- Capture note state before removal for undo
        local removed = notes[idx]
        island_store.PushUndo({
            type = "delete",
            note_uuids = {removed.uuid},
            prev_state = {{
                pitch = removed.pitch,
                start_beat = removed.start_beat,
                duration = removed.duration,
                velocity = removed.velocity,
                muted = removed.muted,
                uuid = removed.uuid,
            }},
        })
        island_store.RemoveNoteAtIndex(idx)
        note.MarkNotesDirty()
        return true
    end
    return false
end

-- =========================================================
-- Lasso Selection Rect Drawing
-- =========================================================

--- Draw the lasso selection rectangle if lasso is active.
function m.DrawLassoRect()
    if not island_store.GetLassoActive() then return end

    local x1 = island_store.GetLassoStartX()
    local y1 = island_store.GetLassoStartY()
    local x2 = island_store.GetLassoEndX()
    local y2 = island_store.GetLassoEndY()

    local rx, ry = math.min(x1, x2), math.min(y1, y2)
    local rw = math.abs(x2 - x1)
    local rh = math.abs(y2 - y1)

    if rw < 1 or rh < 1 then return end

    -- Fill
    helpers.SetColor(theme.colors.lasso_fill)
    gfx.rect(rx, ry, rw, rh, 1)
    -- Border
    helpers.SetColor(theme.colors.lasso_border)
    gfx.rect(rx, ry, rw, rh, 0)
end

-- =========================================================
-- Ctrl+A: Select All / Deselect All
-- =========================================================

--- Select all notes if not all already selected; deselect all if all are selected.
function m.CtrlA()
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return end

    -- Check if all notes are already selected
    local sel = island_store.GetSelectedIndices()
    local all_selected = true
    for i = 1, #notes do
        if not sel[i] then
            all_selected = false
            break
        end
    end

    if all_selected then
        -- Deselect all
        island_store.ClearSelection()
    else
        -- Select all
        local new_sel = {}
        for i = 1, #notes do
            new_sel[i] = true
        end
        island_store.SetSelectedIndices(new_sel)
    end
end

-- =========================================================
-- Note Drag / Resize (PR2)
-- =========================================================

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

-- =========================================================
-- Undo/Redo Restore Functions (PR3)
-- =========================================================

--- Restore note state from an undo entry (reverse the edit).
--- Reverses the operation specified by the entry type.
--- @param entry table Undo entry {type, note_uuids, prev_state, new_state}
function m.RestoreUndo(entry)
    local notes = island_store.GetNotes()
    if not entry or not entry.type then return end

    if entry.type == "move" or entry.type == "resize" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = island_store.FindNoteByUUID(uuid)
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
            local idx = island_store.FindNoteByUUID(new_note.uuid)
            if idx then table.insert(to_remove, idx) end
        end
        table.sort(to_remove, function(a, b) return a > b end)
        for _, idx in ipairs(to_remove) do
            island_store.RemoveNoteAtIndex(idx)
        end
    elseif entry.type == "velocity" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = island_store.FindNoteByUUID(uuid)
            local prev = entry.prev_state and entry.prev_state[i]
            if idx and notes[idx] and prev then
                notes[idx].velocity = prev.velocity
            end
        end
    elseif entry.type == "mute" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = island_store.FindNoteByUUID(uuid)
            local prev = entry.prev_state and entry.prev_state[i]
            if idx and notes[idx] and prev then
                notes[idx].muted = prev.muted
            end
        end
    end

    island_store.ClearSelection()
    island_store.RebuildUUIDIndex()
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
            local idx = island_store.FindNoteByUUID(uuid)
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
            local idx = island_store.FindNoteByUUID(prev.uuid)
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
            local idx = island_store.FindNoteByUUID(uuid)
            local after = entry.new_state and entry.new_state[i]
            if idx and notes[idx] and after then
                notes[idx].velocity = after.velocity
            end
        end
    elseif entry.type == "mute" then
        for i, uuid in ipairs(entry.note_uuids or {}) do
            local idx = island_store.FindNoteByUUID(uuid)
            local after = entry.new_state and entry.new_state[i]
            if idx and notes[idx] and after then
                notes[idx].muted = after.muted
            end
        end
    end

    island_store.ClearSelection()
    island_store.RebuildUUIDIndex()
    note.MarkNotesDirty()
end

-- =========================================================
-- Keyboard Shortcuts (PR3)
-- =========================================================

--- Handle undo shortcut: Ctrl+Z. Pops undo, pushes redo, restores.
function m.HandleUndo()
    local entry = island_store.PopUndo()
    if entry then
        island_store.PushRedo(entry)
        m.RestoreUndo(entry)
    end
end

--- Handle redo shortcut: Ctrl+Y. Pops redo, pushes undo, restores.
function m.HandleRedo()
    local entry = island_store.PopRedo()
    if entry then
        island_store.PushUndo(entry)
        m.RestoreRedo(entry)
    end
end

--- Handle Delete key: remove all selected notes with a single undo entry.
function m.HandleDeleteSelected()
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return end
    local selected = island_store.GetSelectedIndices()
    local to_remove = {}
    local undo_uuids = {}
    local undo_prev = {}
    for idx in pairs(selected) do
        if notes[idx] then
            table.insert(to_remove, idx)
            table.insert(undo_uuids, notes[idx].uuid)
            table.insert(undo_prev, {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
                uuid = notes[idx].uuid,
            })
        end
    end
    if #to_remove == 0 then return end

    island_store.PushUndo({
        type = "delete",
        note_uuids = undo_uuids,
        prev_state = undo_prev,
    })

    table.sort(to_remove, function(a, b) return a > b end)
    for _, idx in ipairs(to_remove) do
        island_store.RemoveNoteAtIndex(idx)
    end
    island_store.ClearSelection()
    note.MarkNotesDirty()
end

--- Nudge selected notes by a pitch delta (semitones) and a beat delta.
--- Pushes a single "move" undo entry for all nudged notes.
--- @param delta_pitch number Change in semitones (positive = up)
--- @param delta_beat number Change in beats
--- @param grid_x number Grid left edge (for edge limits)
--- @param grid_y number Grid top edge
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
function m.HandleNudge(delta_pitch, delta_beat)
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return end
    local selected = island_store.GetSelectedIndices()
    local sel_count = 0
    for _ in pairs(selected) do sel_count = sel_count + 1 end
    if sel_count == 0 then return end

    local undo_uuids = {}
    local undo_prev = {}
    local undo_new = {}

    for idx in pairs(selected) do
        if notes[idx] then
            table.insert(undo_uuids, notes[idx].uuid)
            table.insert(undo_prev, {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
            })

            notes[idx].pitch = math.max(grid.MIN_PITCH, math.min(grid.MAX_PITCH,
                (notes[idx].pitch or 60) + delta_pitch))
            notes[idx].start_beat = math.max(0, (notes[idx].start_beat or 0) + delta_beat)

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
        island_store.PushUndo({
            type = "move",
            note_uuids = undo_uuids,
            prev_state = undo_prev,
            new_state = undo_new,
        })
    end
    note.MarkNotesDirty()
end

-- =========================================================
-- Cut/Copy/Paste Clipboard (PR3)
-- =========================================================

--- Cut selected notes: store in clipboard, remove from grid, push undo.
--- @return boolean true if any notes were cut
function m.HandleCut()
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return false end
    local selected = island_store.GetSelectedIndices()

    -- Capture clipboard + undo data
    _clipboard = {}
    local to_remove = {}
    local undo_uuids = {}
    local undo_prev = {}
    for idx in pairs(selected) do
        if notes[idx] then
            local copy = {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
                uuid = notes[idx].uuid,
            }
            table.insert(_clipboard, copy)
            table.insert(to_remove, idx)
            table.insert(undo_uuids, notes[idx].uuid)
            table.insert(undo_prev, copy)
        end
    end
    if #to_remove == 0 then return false end

    island_store.PushUndo({
        type = "delete",
        note_uuids = undo_uuids,
        prev_state = undo_prev,
    })

    table.sort(to_remove, function(a, b) return a > b end)
    for _, idx in ipairs(to_remove) do
        island_store.RemoveNoteAtIndex(idx)
    end
    island_store.ClearSelection()
    note.MarkNotesDirty()
    return true
end

--- Copy selected notes to clipboard (no removal).
--- @return boolean true if any notes were copied
function m.HandleCopy()
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return false end
    local selected = island_store.GetSelectedIndices()

    _clipboard = {}
    for idx in pairs(selected) do
        if notes[idx] then
            table.insert(_clipboard, {
                pitch = notes[idx].pitch,
                start_beat = notes[idx].start_beat,
                duration = notes[idx].duration,
                velocity = notes[idx].velocity,
                muted = notes[idx].muted,
            })
        end
    end
    return #_clipboard > 0
end

--- Paste clipboard notes at the current scroll position.
--- Assigns new UUIDs to all pasted notes. Pushes a single "add" undo entry.
--- @param scroll_beat number Current scroll position in beats (anchor beat)
--- @return boolean true if notes were pasted
function m.HandlePaste(scroll_beat)
    if not _clipboard or #_clipboard == 0 then return false end

    local notes = island_store.GetNotes()
    local undo_new = {}

    -- Find beat anchor: use scroll_beat or earliest clipboard start_beat
    local anchor_beat = scroll_beat or 0
    if #notes > 0 then
        -- Place pasted notes at a reasonable position
        local max_beat = 0
        for _, n in ipairs(notes) do
            local end_b = (n.start_beat or 0) + (n.duration or 1)
            if end_b > max_beat then max_beat = end_b end
        end
        anchor_beat = math.max(anchor_beat, max_beat + 1)
    end

    local min_clip_beat = nil
    for _, copy in ipairs(_clipboard) do
        if min_clip_beat == nil or copy.start_beat < min_clip_beat then
            min_clip_beat = copy.start_beat
        end
    end
    local offset = (min_clip_beat or 0)

    for _, copy in ipairs(_clipboard) do
        local new_note = {
            pitch = copy.pitch,
            start_beat = anchor_beat + (copy.start_beat - offset),
            duration = copy.duration,
            velocity = copy.velocity,
            muted = copy.muted,
        }
        island_store.AddNote(new_note)
        table.insert(undo_new, {
            pitch = new_note.pitch,
            start_beat = new_note.start_beat,
            duration = new_note.duration,
            velocity = new_note.velocity,
            muted = new_note.muted,
            uuid = new_note.uuid,
        })
    end

    island_store.PushUndo({
        type = "add",
        note_uuids = {},
        new_state = undo_new,
    })
    note.MarkNotesDirty()
    return true
end

-- =========================================================
-- Central Keyboard Shortcut Dispatcher (PR3)
-- =========================================================

--- Dispatch keyboard shortcuts for the piano roll.
--- Call this from views.lua with the char from gfx.getchar().
--- Returns true if the key was consumed (handled), false to fall through.
--- @param char number Character code from gfx.getchar()
--- @param scroll_beat number Current scroll beat (for paste anchor)
--- @return boolean true if consumed
function m.HandleKeyboardShortcut(char, scroll_beat)
    -- Ctrl+Z (90 + 256 = 346)
    if char == 346 then
        m.HandleUndo()
        return true
    end

    -- Ctrl+Y (89 + 256 = 345)
    if char == 345 then
        m.HandleRedo()
        return true
    end

    -- Delete key (46 = VK_DELETE, 127 = ASCII DEL, 302 = 46+256 = Ctrl+Delete)
    if char == 46 or char == 127 or char == 302 then
        m.HandleDeleteSelected()
        return true
    end

    -- Ctrl+A (65 + 256 = 321) — select all / deselect all
    if char == 321 then
        m.CtrlA()
        return true
    end

    -- Ctrl+X (88 + 256 = 344)
    if char == 344 then
        m.HandleCut()
        return true
    end

    -- Ctrl+C (67 + 256 = 323)
    if char == 323 then
        m.HandleCopy()
        return true
    end

    -- Ctrl+V (86 + 256 = 342)
    if char == 342 then
        m.HandlePaste(scroll_beat or 0)
        return true
    end

    -- Arrow keys (37=VK_LEFT, 38=VK_UP, 39=VK_RIGHT, 40=VK_DOWN)
    -- Shift+arrow adds 512 (Shift bit)
    if char >= 37 and char <= 40 then
        local delta_pitch, delta_beat = 0, 0
        if char == 37 then delta_beat = -1 end         -- Left: -1 snap unit
        if char == 39 then delta_beat = 1 end           -- Right: +1 snap unit
        if char == 38 then delta_pitch = 1 end          -- Up: +1 semitone
        if char == 40 then delta_pitch = -1 end         -- Down: -1 semitone

        if delta_beat ~= 0 then
            -- Snap-aware beat nudge
            local snap_res = island_store.GetSnapEnabled() and island_store.GetSnapResolution() or 0
            local snap_trip = island_store.GetSnapEnabled() and island_store.GetSnapTriplet() or false
            if snap_res > 0 then
                local step = 4 / (snap_trip and snap_res * 1.5 or snap_res)
                delta_beat = delta_beat * step
            else
                delta_beat = delta_beat * 0.25  -- default 1/16 step
            end
        end
        m.HandleNudge(delta_pitch, delta_beat)
        return true
    end

    -- Shift+arrows (37+512=549, 38+512=550, 39+512=551, 40+512=552)
    if char >= 549 and char <= 552 then
        local delta_pitch, delta_beat = 0, 0
        if char == 549 then delta_beat = -1 end       -- Shift+Left: -1 beat
        if char == 551 then delta_beat = 1 end         -- Shift+Right: +1 beat
        if char == 550 then delta_pitch = 12 end       -- Shift+Up: +12 semitones
        if char == 552 then delta_pitch = -12 end      -- Shift+Down: -12 semitones
        m.HandleNudge(delta_pitch, delta_beat)
        return true
    end

    return false  -- Not consumed: fall through to REAPER
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
