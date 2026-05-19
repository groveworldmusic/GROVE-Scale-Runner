-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Piano Roll — Barrel Module
-- Re-exports grid.lua + note.lua + interaction.lua + view.lua
-- All original public functions remain accessible via require("ui.piano-roll").

local grid = require("ui.piano-roll.grid")
local note = require("ui.piano-roll.note")
local interaction = require("ui.piano-roll.interaction")
local view = require("ui.piano-roll.view")

local piano_roll = {}

-- PITCH_ROW_H is mutable at runtime; use __index metatable so
-- piano_roll.PITCH_ROW_H always reflects grid.PITCH_ROW_H live.
setmetatable(piano_roll, {
    __index = function(t, k)
        if k == "PITCH_ROW_H" then return grid.PITCH_ROW_H end
        return rawget(t, k)
    end,
})

-- =========================================================
-- Re-export grid constants and functions
-- (PITCH_ROW_H is live via __index metatable)
-- =========================================================
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
piano_roll.ApplyQuantize = note.ApplyQuantize

-- =========================================================
-- Re-export interaction module functions
-- =========================================================
piano_roll.HandlePaintClick = interaction.HandlePaintClick
piano_roll.HandlePaintRightClick = interaction.HandlePaintRightClick
piano_roll.HandleKnifeClick = interaction.HandleKnifeClick
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
piano_roll.IsNoteLeftEdge = interaction.IsNoteLeftEdge
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
piano_roll.StartRightDragSweep = interaction.StartRightDragSweep
piano_roll.UpdateRightDragSweep = interaction.UpdateRightDragSweep
piano_roll.CommitRightDragSweep = interaction.CommitRightDragSweep
piano_roll.CancelRightDragSweep = interaction.CancelRightDragSweep
piano_roll.GetRightDragSweepActive = interaction.GetRightDragSweepActive
piano_roll.DrawRightDragSweepRect = interaction.DrawRightDragSweepRect

-- =========================================================
-- Re-export view module functions
-- =========================================================
piano_roll.DrawPianoRoll = view.DrawPianoRoll

-- =========================================================
-- Re-export grid mutators
-- =========================================================
piano_roll.SetPitchRowH = grid.SetPitchRowH
piano_roll.InvalidateVisibleRangesCache = grid.InvalidateVisibleRangesCache

return piano_roll
