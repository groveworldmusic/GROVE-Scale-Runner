-- GROVE FL MIDI: Piano Roll — Barrel Module
-- Re-exports grid.lua + note.lua and provides coordinator functions
-- (DrawPianoRoll, mouse handlers) that will be extracted in PR1b.
-- All original public functions remain accessible via require("ui.piano-roll").

local config = require("config")
local island_store = require("state.island")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local grid = require("ui.piano-roll.grid")
local note = require("ui.piano-roll.note")

local piano_roll = {}

-- =========================================================
-- Re-export grid constants and functions
-- (read-only after init; PITCH_ROW_H synced via SetPitchRowH)
-- =========================================================
piano_roll.PITCH_ROW_H = grid.PITCH_ROW_H
piano_roll.PITCH_LABEL_W = grid.PITCH_LABEL_W
piano_roll.MIN_PITCH = grid.MIN_PITCH
piano_roll.MAX_PITCH = grid.MAX_PITCH
piano_roll.TOTAL_ROWS = grid.TOTAL_ROWS
piano_roll.OCTAVE_BUFFER = grid.OCTAVE_BUFFER

piano_roll.ComputeVisibleRanges = grid.ComputeVisibleRanges
piano_roll.DrawPianoRollGrid = grid.DrawPianoRollGrid
piano_roll.HandleMouseWheel = grid.HandleMouseWheel
piano_roll.HandleZoomX = grid.HandleZoomX
piano_roll.HandleZoomVertical = grid.HandleZoomVertical
piano_roll.HandleMouseWheelVertical = grid.HandleMouseWheelVertical

-- =========================================================
-- Re-export note module functions
-- =========================================================
piano_roll.DrawNoteBlock = note.DrawNoteBlock
piano_roll.DrawNoteBlocks = note.DrawNoteBlocks
piano_roll.NoteBlockHitTest = note.NoteBlockHitTest
piano_roll.GetNotesInRect = note.GetNotesInRect
piano_roll.MarkNotesDirty = note.MarkNotesDirty

-- =========================================================
-- Local references for code below
-- (ensures functions that stay in the barrel call correctly
--  without requiring the piano_roll. prefix)
-- =========================================================
local ComputeVisibleRanges = grid.ComputeVisibleRanges

-- =========================================================
-- Mouse Handlers (to be extracted to interaction.lua in PR1b)
-- =========================================================

--- Handle mouse click in piano roll area (pointer tool).
--- Click on note: select it (deselect others). Click same note again: deselect.
--- Click on empty area: deselect all.
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if click was consumed
function piano_roll.HandleMouseClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local notes = island_store.GetNotes()
    local idx = piano_roll.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    if idx then
        if island_store.IsNoteSelected(idx) then
            island_store.ClearSelection()
        else
            island_store.SetSelectedNoteIndex(idx)
        end
    else
        island_store.ClearSelection()
    end
    return true
end

--- Handle right-click in piano roll area: toggle mute on ALL selected notes.
--- If the clicked note is not already selected, select it first (clear others).
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if right-click was consumed
function piano_roll.HandleRightClickMute(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local notes = island_store.GetNotes()
    local idx = piano_roll.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    if idx and notes[idx] then
        -- If clicked note is not already selected, select it exclusively
        if not island_store.IsNoteSelected(idx) then
            island_store.SetSelectedNoteIndex(idx)
        end
        -- Toggle mute for ALL selected notes
        local selected = island_store.GetSelectedIndices()
        local any_toggled = false
        for sel_idx in pairs(selected) do
            if notes[sel_idx] then
                notes[sel_idx].muted = not notes[sel_idx].muted
                any_toggled = true
            end
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
function piano_roll.HandlePencilClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local PITCH_ROW_H = piano_roll.PITCH_ROW_H
    local MIN_PITCH = piano_roll.MIN_PITCH
    local MAX_PITCH = piano_roll.MAX_PITCH

    -- Convert mouse to beat space
    local beat = (mx - grid_x) / zoom_x + scroll_x
    -- Snap to nearest half-beat
    local snapped_beat = math.floor(beat * 2 + 0.5) / 2

    -- Convert mouse to pitch (inverted Y: high pitch at top)
    local pitch_row = math.floor((my - grid_y) / PITCH_ROW_H)
    local top_pitch = math.max(MIN_PITCH, MAX_PITCH - scroll_y)
    local pitch = math.max(MIN_PITCH, math.min(MAX_PITCH, top_pitch - pitch_row))

    local new_note = {
        pitch = pitch,
        start_beat = snapped_beat,
        duration = 1,
        velocity = 100,
        muted = false,
    }
    island_store.AddNote(new_note)
    piano_roll.MarkNotesDirty()
    return true
end

--- Handle eraser click: hit-test and remove the clicked note.
--- @param mx number Mouse x (screen)
--- @param my number Mouse y (screen)
--- @param grid_x number Grid left edge (screen)
--- @param grid_y number Grid top edge (screen)
--- @param scroll_y number Vertical scroll offset
--- @param scroll_x number Horizontal scroll offset
--- @param zoom_x number Pixels per beat
--- @return boolean true if a note was removed
function piano_roll.HandleEraserClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)
    local notes = island_store.GetNotes()
    local idx = piano_roll.NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)
    if idx then
        island_store.RemoveNoteAtIndex(idx)
        piano_roll.MarkNotesDirty()
        return true
    end
    return false
end

-- =========================================================
-- Lasso Selection Rect Drawing (to interaction.lua in PR1b)
-- =========================================================

--- Draw the lasso selection rectangle if lasso is active.
function piano_roll.DrawLassoRect()
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
-- Coordinator: DrawPianoRoll (to view.lua in PR1b)
-- =========================================================

--- Main piano roll entry point: draw grid, labels, and note blocks.
--- @param x number Left edge of the entire piano roll area (including label area)
--- @param y number Top edge of the piano roll area
--- @param w number Width of the entire piano roll area
--- @param h number Height of the piano roll area
function piano_roll.DrawPianoRoll(x, y, w, h)
    local scroll_y = island_store.GetScrollOffsetY()
    local scroll_x = island_store.GetScrollOffsetX()
    local zoom_x = island_store.GetZoomX()
    local LABEL_W = piano_roll.PITCH_LABEL_W

    -- Compute visible ranges ONCE per frame (shared between grid + notes, P5-05)
    local visible_rows, pitch_start, pitch_end, top_pitch, beat_start, beat_end =
        ComputeVisibleRanges(y, h, scroll_y, scroll_x, zoom_x, w)

    -- Draw grid (to the right of labels)
    local grid_x = x + LABEL_W
    local grid_w = w - LABEL_W
    if grid_w <= 0 then return end

    piano_roll.DrawPianoRollGrid(grid_x, y, grid_w, h, scroll_y, scroll_x, zoom_x,
                                  visible_rows, pitch_start, pitch_end, top_pitch)

    -- Draw note blocks (uses shared pitch/beat ranges)
    piano_roll.DrawNoteBlocks(grid_x, y, grid_w, h, scroll_y, scroll_x, zoom_x,
                               pitch_start, pitch_end, beat_start, beat_end, top_pitch)

    -- Draw vertical scrollbar indicator (right side)
    local total_rows = piano_roll.TOTAL_ROWS
    local actual_visible = math.ceil(h / piano_roll.PITCH_ROW_H)
    local max_scroll_y = total_rows - actual_visible
    local scroll_ratio_y = actual_visible / total_rows
    if scroll_ratio_y < 1 and max_scroll_y > 0 then
        local sb_x = x + w - 6
        local sb_y = y + (scroll_y / max_scroll_y) * h
        local sb_h = math.max(20, h * scroll_ratio_y)
        helpers.SetColor({0.4, 0.4, 0.4, 0.3})
        gfx.rect(sb_x, sb_y, 6, sb_h, 1)
    end

    -- Draw lasso selection rect (Phase 4)
    piano_roll.DrawLassoRect()
end

-- HACK: Sync PITCH_ROW_H on every SetPitchRowH call so both
-- barrel consumers (views.lua) and grid drawing functions see
-- the same value. Without this, the barrel copy goes stale.
piano_roll.SetPitchRowH = function(h)
    h = math.max(6, math.min(24, h))
    piano_roll.PITCH_ROW_H = h
    grid.SetPitchRowH(h)
end

return piano_roll
