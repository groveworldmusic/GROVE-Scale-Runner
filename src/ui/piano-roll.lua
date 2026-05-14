-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Piano Roll â€” Barrel Module
-- Re-exports grid.lua + note.lua + interaction.lua + view.lua
-- All original public functions remain accessible via require("ui.piano-roll").

local grid = require("ui.piano-roll.grid")
local note = require("ui.piano-roll.note")
local interaction = require("ui.piano-roll.interaction")
local view = require("ui.piano-roll.view")

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
-- Re-export interaction module functions
-- =========================================================
piano_roll.HandleMouseClick = interaction.HandleMouseClick
piano_roll.HandleRightClickMute = interaction.HandleRightClickMute
piano_roll.HandlePencilClick = interaction.HandlePencilClick
piano_roll.HandleEraserClick = interaction.HandleEraserClick
piano_roll.DrawLassoRect = interaction.DrawLassoRect
piano_roll.CtrlA = interaction.CtrlA

-- =========================================================
-- Undo/Redo / Keyboard Shortcuts (PR3)
-- =========================================================
piano_roll.RestoreUndo = interaction.RestoreUndo
piano_roll.RestoreRedo = interaction.RestoreRedo
piano_roll.HandleUndo = interaction.HandleUndo
piano_roll.HandleRedo = interaction.HandleRedo
piano_roll.HandleDeleteSelected = interaction.HandleDeleteSelected
piano_roll.HandleNudge = interaction.HandleNudge
piano_roll.HandleCut = interaction.HandleCut
piano_roll.HandleCopy = interaction.HandleCopy
piano_roll.HandlePaste = interaction.HandlePaste
piano_roll.HandleKeyboardShortcut = interaction.HandleKeyboardShortcut

-- =========================================================
-- Note Drag / Resize (PR2)
-- =========================================================
piano_roll.IsNoteRightEdge = interaction.IsNoteRightEdge
piano_roll.ArmNoteDrag = interaction.ArmNoteDrag
piano_roll.CheckAndStartDrag = interaction.CheckAndStartDrag
piano_roll.DisarmNoteDrag = interaction.DisarmNoteDrag
piano_roll.StartNoteDrag = interaction.StartNoteDrag
piano_roll.UpdateNoteDrag = interaction.UpdateNoteDrag
piano_roll.CommitNoteDrag = interaction.CommitNoteDrag
piano_roll.CancelNoteDrag = interaction.CancelNoteDrag
piano_roll.StartNoteResize = interaction.StartNoteResize
piano_roll.UpdateNoteResize = interaction.UpdateNoteResize
piano_roll.CommitNoteResize = interaction.CommitNoteResize

-- =========================================================
-- Re-export view module functions
-- =========================================================
piano_roll.DrawPianoRoll = view.DrawPianoRoll

-- HACK: Sync PITCH_ROW_H on every SetPitchRowH call so both
-- barrel consumers (views.lua) and grid drawing functions see
-- the same value. Without this, the barrel copy goes stale.
piano_roll.SetPitchRowH = function(h)
    h = math.max(6, math.min(24, h))
    piano_roll.PITCH_ROW_H = h
    grid.SetPitchRowH(h)
end

return piano_roll
