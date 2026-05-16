-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Piano Roll Interaction — BARREL
-- Re-exports all interaction submodules: handlers, drag, shortcuts, clipboard, undo.
-- Extracted into submodules (Sprint 2).

local handlers = require("ui.piano-roll.interaction.handlers")
local drag = require("ui.piano-roll.interaction.drag")
local shortcuts = require("ui.piano-roll.interaction.shortcuts")
local undo = require("ui.piano-roll.undo")
local clipboard = require("ui.piano-roll.clipboard")
local knife = require("ui.piano-roll.knife")

local m = {}

-- =========================================================
-- Re-export handlers.lua
-- =========================================================

m.HandlePaintClick = handlers.HandlePaintClick
m.HandlePaintRightClick = handlers.HandlePaintRightClick
m.DrawLassoRect = handlers.DrawLassoRect
m.CtrlA = handlers.CtrlA

-- =========================================================
-- Re-export knife.lua
-- =========================================================

m.HandleKnifeClick = knife.HandleKnifeClick

-- =========================================================
-- Re-export drag.lua
-- =========================================================

m.ArmNoteDrag = drag.ArmNoteDrag
m.CheckAndStartDrag = drag.CheckAndStartDrag
m.DisarmNoteDrag = drag.DisarmNoteDrag
m.IsNoteRightEdge = drag.IsNoteRightEdge
m.IsNoteLeftEdge = drag.IsNoteLeftEdge
m.StartNoteDrag = drag.StartNoteDrag
m.UpdateNoteDrag = drag.UpdateNoteDrag
m.CommitNoteDrag = drag.CommitNoteDrag
m.CancelNoteDrag = drag.CancelNoteDrag
m.StartNoteResize = drag.StartNoteResize
m.UpdateNoteResize = drag.UpdateNoteResize
m.CommitNoteResize = drag.CommitNoteResize
m.StartRightDragSweep = drag.StartRightDragSweep
m.UpdateRightDragSweep = drag.UpdateRightDragSweep
m.CommitRightDragSweep = drag.CommitRightDragSweep
m.CancelRightDragSweep = drag.CancelRightDragSweep
m.GetRightDragSweepActive = drag.GetRightDragSweepActive
m.DrawRightDragSweepRect = drag.DrawRightDragSweepRect

-- =========================================================
-- Re-export shortcuts.lua
-- =========================================================

m.HandleKeyboardShortcut = shortcuts.HandleKeyboardShortcut
m.HandleDeleteSelected = shortcuts.HandleDeleteSelected
m.HandleNudge = shortcuts.HandleNudge

-- =========================================================
-- Re-export undo.lua
-- =========================================================

m.RestoreUndo = undo.RestoreUndo
m.RestoreRedo = undo.RestoreRedo
m.HandleUndo = undo.HandleUndo
m.HandleRedo = undo.HandleRedo

-- =========================================================
-- Re-export clipboard.lua
-- =========================================================

m.HandleCut = clipboard.HandleCut
m.HandleCopy = clipboard.HandleCopy
m.HandlePaste = clipboard.HandlePaste

return m
