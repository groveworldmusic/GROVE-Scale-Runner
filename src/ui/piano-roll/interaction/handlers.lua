-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Piano Roll Interaction — Mouse Handlers
-- Mouse click handlers, lasso rect drawing, Ctrl+A.
-- Phase 5: Unified paint tool replaces pointer/pencil/eraser.
--   HandlePaintClick: left-click creates note on empty cell, selects on hit
--   HandlePaintRightClick: right-click deletes note

local island_store = require("state.island")
local note_store = require("state.note-store")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local note = require("ui.piano-roll.note")
local grid = require("ui.piano-roll.grid")
local snap = require("core.snap")

local m = {}

-- =========================================================
-- Paint Tool Handlers (Phase 5)
-- =========================================================

--- Handle paint tool left-click: create note on empty cell, select on hit.
--- When clicking on a note: selects it (single exclusive or shift-additive).
--- When clicking on empty cell: creates a new note at snapped beat/pitch.
--- Ctrl held on empty cell: starts lasso (not handled here — dispatched in input.lua).
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @param ctrl boolean Whether Ctrl is held
--- @param shift boolean Whether Shift is held
--- @return boolean true if click was consumed
function m.HandlePaintClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x, ctrl, shift)
    local notes = island_store.GetNotes()
    local idx = note.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)

    if idx then
        -- Click on note body: select/deselect
        if shift then
            island_store.ToggleNoteSelected(idx)
        else
            if island_store.IsNoteSelected(idx) then
                island_store.ClearSelection()
            else
                island_store.SetSelectedNoteIndex(idx)
            end
        end
        return true
    end

    -- Click on empty cell (and Ctrl NOT held — Ctrl+lasso is handled in input.lua)
    if not ctrl then
        local PITCH_ROW_H = grid.PITCH_ROW_H
        local MIN_PITCH = grid.MIN_PITCH
        local MAX_PITCH = grid.MAX_PITCH

        -- Convert mouse to beat space
        local beat = (mx - grid_x) / zoom_x + scroll_x
        local snap_enabled = island_store.GetSnapEnabled()
        local snap_res = snap_enabled and island_store.GetSnapResolution() or 0
        local snap_trip = snap_enabled and island_store.GetSnapTriplet() or false
        local snapped_beat = beat
        if snap_res > 0 then
            snapped_beat = snap.SnapBeat(beat, snap_res, snap_trip)
        end

        -- Convert mouse to pitch (inverted Y)
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
        note_store.PushUndo({
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
        island_store.SetNotesState(island_store.NOTES_STATE_EDITED)
        return true
    end

    return false
end

--- Handle paint tool right-click: delete note on hit.
--- Stationary right-click on a note body deletes it with undo.
--- Stationary right-click on empty cell does nothing (context menu future).
--- Right-drag delete sweep is handled separately in drag.lua (CommitRightDragSweep).
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if a note was deleted
function m.HandlePaintRightClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local notes = island_store.GetNotes()
    local idx = note.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    if idx and notes[idx] then
        local removed = notes[idx]
        note_store.PushUndo({
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
        island_store.SetNotesState(island_store.NOTES_STATE_EDITED)
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

    local sel = island_store.GetSelectedIndices()
    local all_selected = true
    for i = 1, #notes do
        if not sel[i] then
            all_selected = false
            break
        end
    end

    if all_selected then
        island_store.ClearSelection()
    else
        local new_sel = {}
        for i = 1, #notes do
            new_sel[i] = true
        end
        island_store.SetSelectedIndices(new_sel)
    end
end

return m
