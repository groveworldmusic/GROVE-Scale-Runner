-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Piano Roll Interaction — Mouse Handlers
-- Mouse click handlers, lasso rect drawing, Ctrl+A.
-- Extracted from interaction.lua (Sprint 2).

local island_store = require("state.island")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local note = require("ui.piano-roll.note")
local grid = require("ui.piano-roll.grid")
local snap = require("core.snap")

local m = {}

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

return m
