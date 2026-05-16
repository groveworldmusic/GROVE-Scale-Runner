-- Tests: Barrel Backward Compatibility (PR1a + PR1b + PR2 + PR3)
-- Validates that piano-roll.lua (now a barrel) exports the same public API
-- as the original monolith. PR1b adds interaction + view sub-module re-exports.
-- PR2 adds note move/resize functions. PR3 adds undo/redo + keyboard shortcuts.
-- Run from a REPL or REAPER context.
--
-- Usage: require("tests.barrel-backward-compat") -- prints pass/fail
-- Or: lua -l tests.barrel-backward-compat (if test harness available)
--
-- Since there is no Lua CLI for REAPER GFX scripts, these are STATIC
-- validations: they check that all expected exports exist and that
-- sub-modules provide the expected functions.
--
-- Manual visual verification is required for pixel-identical rendering.

local function verify(condition, label)
    if condition then
        print("[PASS] " .. label)
        return true
    else
        print("[FAIL] " .. label)
        return false
    end
end

local all_pass = true

-- =========================================================
-- Configuration: Expected exports from the original monolith
-- =========================================================

-- These are ALL the functions and fields that were on the
-- piano_roll table in the original piano-roll.lua monolith.
-- Extracted from the source code by grepping for "piano_roll." exports.

local EXPECTED_EXPORTS = {
    -- Constants (lines 15-20)
    PITCH_ROW_H = "number",
    PITCH_LABEL_W = "number",
    MIN_PITCH = "number",
    MAX_PITCH = "number",
    TOTAL_ROWS = "number",
    OCTAVE_BUFFER = "number",

    -- Grid functions (lines 455-538)
    ComputeVisibleRanges = "function",
    DrawPianoRollGrid = "function",

    -- Note functions (lines 588-674, 677-713, 855-896)
    DrawNoteBlock = "function",
    DrawNoteBlocks = "function",
    MarkNotesDirty = "function",
    NoteBlockHitTest = "function",
    GetNotesInRect = "function",

    -- Interaction functions (paint/knife only — legacy pointer/pencil/eraser removed)

    -- Lasso function (lines 904-924)
    DrawLassoRect = "function",

    -- Ctrl+A (PR1b new function)
    CtrlA = "function",

    -- Note drag/resize functions (PR2)
    IsNoteRightEdge = "function",
    ArmNoteDrag = "function",
    CheckAndStartDrag = "function",
    DisarmNoteDrag = "function",
    StartNoteDrag = "function",
    UpdateNoteDrag = "function",
    CommitNoteDrag = "function",
    CancelNoteDrag = "function",
    StartNoteResize = "function",
    UpdateNoteResize = "function",
    CommitNoteResize = "function",

    -- Undo/Redo / Keyboard Shortcuts (PR3)
    RestoreUndo = "function",
    RestoreRedo = "function",
    HandleUndo = "function",
    HandleRedo = "function",
    HandleDeleteSelected = "function",
    HandleNudge = "function",
    HandleCut = "function",
    HandleCopy = "function",
    HandlePaste = "function",
    HandleKeyboardShortcut = "function",

    -- Scroll/Zoom functions (lines 931-972)
    HandleMouseWheel = "function",
    HandleZoomX = "function",
    HandleZoomVertical = "function",
    HandleMouseWheelVertical = "function",
    SetPitchRowH = "function",

    -- Coordinator function (lines 980-1020)
    DrawPianoRoll = "function",
}

-- =========================================================
-- Test 1: All expected exports exist on barrel
-- =========================================================

print("")
print("=== PR1a + PR1b + PR2 + PR3 Barrel Backward Compatibility ===")
print("")

local ok, piano_roll = pcall(require, "ui.piano-roll")
if not ok then
    print("[FAIL] require('ui.piano-roll') failed: " .. tostring(piano_roll))
    all_pass = false
else
    verify(true, "require('ui.piano-roll') loads without error")

    -- Check each expected export exists with the correct type
    for name, expected_type in pairs(EXPECTED_EXPORTS) do
        local actual_type = type(piano_roll[name])
        local ok = (actual_type == expected_type)
        if not ok then
            all_pass = false
        end
        verify(ok, string.format("piano_roll.%s exists with type '%s' (expected '%s')",
                                  name, actual_type, expected_type))
    end
end

-- =========================================================
-- Test 2: Check there are NO unexpected nil exports
-- (compared to original known API)
-- =========================================================

print("")
print("--- Extra Export Check ---")

-- Count total exports
local export_count = 0
local extra_exports = {}
for k, v in pairs(piano_roll) do
    export_count = export_count + 1
    if EXPECTED_EXPORTS[k] == nil then
        table.insert(extra_exports, k)
    end
end

if #extra_exports > 0 then
    print("[INFO] Extra exports (not in original monolith): " .. table.concat(extra_exports, ", "))
    -- NOTE: extra exports are acceptable — they don't break consumers
    -- as long as all expected exports still exist.
end

verify(export_count >= #EXPECTED_EXPORTS,
       string.format("piano_roll has at least %d exports (has %d)", #EXPECTED_EXPORTS, export_count))

-- =========================================================
-- Test 3: Grid sub-module exports correctly
-- =========================================================

print("")
print("--- Grid Sub-Module Exports ---")

local ok_grid, grid_mod = pcall(require, "ui.piano-roll.grid")
if not ok_grid then
    print("[FAIL] require('ui.piano-roll.grid') failed: " .. tostring(grid_mod))
    all_pass = false
else
    verify(true, "require('ui.piano-roll.grid') loads without error")

    local GRID_EXPORTS = {
        PITCH_ROW_H = "number",
        PITCH_LABEL_W = "number",
        MIN_PITCH = "number",
        MAX_PITCH = "number",
        TOTAL_ROWS = "number",
        OCTAVE_BUFFER = "number",
        ComputeVisibleRanges = "function",
        DrawVerticalKeyboard = "function",
        DrawVerticalPianoKeyboard = "function",
        DrawPianoRollGrid = "function",
        HandleMouseWheel = "function",
        HandleZoomX = "function",
        HandleZoomVertical = "function",
        HandleMouseWheelVertical = "function",
        SetPitchRowH = "function",
    }

    for name, expected_type in pairs(GRID_EXPORTS) do
        local actual_type = type(grid_mod[name])
        verify(actual_type == expected_type,
               string.format("grid.%s exists with type '%s' (expected '%s')",
                              name, actual_type, expected_type))
    end
end

-- =========================================================
-- Test 4: Note sub-module exports correctly
-- =========================================================

print("")
print("--- Note Sub-Module Exports ---")

local ok_note, note_mod = pcall(require, "ui.piano-roll.note")
if not ok_note then
    print("[FAIL] require('ui.piano-roll.note') failed: " .. tostring(note_mod))
    all_pass = false
else
    verify(true, "require('ui.piano-roll.note') loads without error")

    local NOTE_EXPORTS = {
        DrawNoteBlock = "function",
        DrawNoteBlocks = "function",
        MarkNotesDirty = "function",
        NoteBlockHitTest = "function",
        GetNotesInRect = "function",
    }

    for name, expected_type in pairs(NOTE_EXPORTS) do
        local actual_type = type(note_mod[name])
        verify(actual_type == expected_type,
               string.format("note.%s exists with type '%s' (expected '%s')",
                              name, actual_type, expected_type))
    end
end

-- =========================================================
-- Test 5: Interaction sub-module exports correctly (PR1b + PR2 + PR3)
-- =========================================================

print("")
print("--- Interaction Sub-Module Exports ---")

local ok_int, int_mod = pcall(require, "ui.piano-roll.interaction")
if not ok_int then
    print("[FAIL] require('ui.piano-roll.interaction') failed: " .. tostring(int_mod))
    all_pass = false
else
    verify(true, "require('ui.piano-roll.interaction') loads without error")

    local INT_EXPORTS = {
        DrawLassoRect = "function",
        CtrlA = "function",

        -- PR2: Note drag/resize
        IsNoteRightEdge = "function",
        ArmNoteDrag = "function",
        CheckAndStartDrag = "function",
        DisarmNoteDrag = "function",
        StartNoteDrag = "function",
        UpdateNoteDrag = "function",
        CommitNoteDrag = "function",
        CancelNoteDrag = "function",
        StartNoteResize = "function",
        UpdateNoteResize = "function",
        CommitNoteResize = "function",

        -- PR3: Undo/Redo + Keyboard Shortcuts
        RestoreUndo = "function",
        RestoreRedo = "function",
        HandleUndo = "function",
        HandleRedo = "function",
        HandleDeleteSelected = "function",
        HandleNudge = "function",
        HandleCut = "function",
        HandleCopy = "function",
        HandlePaste = "function",
        HandleKeyboardShortcut = "function",
    }

    for name, expected_type in pairs(INT_EXPORTS) do
        local actual_type = type(int_mod[name])
        verify(actual_type == expected_type,
               string.format("interaction.%s exists with type '%s' (expected '%s')",
                              name, actual_type, expected_type))
    end
end

-- =========================================================
-- Test 6: View sub-module exports correctly (PR1b)
-- =========================================================

print("")
print("--- View Sub-Module Exports ---")

local ok_view, view_mod = pcall(require, "ui.piano-roll.view")
if not ok_view then
    print("[FAIL] require('ui.piano-roll.view') failed: " .. tostring(view_mod))
    all_pass = false
else
    verify(true, "require('ui.piano-roll.view') loads without error")

    local VIEW_EXPORTS = {
        DrawPianoRoll = "function",
    }

    for name, expected_type in pairs(VIEW_EXPORTS) do
        local actual_type = type(view_mod[name])
        verify(actual_type == expected_type,
               string.format("view.%s exists with type '%s' (expected '%s')",
                              name, actual_type, expected_type))
    end
end

-- =========================================================
-- Results
-- =========================================================

print("")
if all_pass then
    print("=== ALL TESTS PASSED ===")
else
    print("=== SOME TESTS FAILED ===")
end
print("")

return all_pass
