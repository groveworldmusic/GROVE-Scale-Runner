-- Tests: Progression Undo/Redo (PR1)
-- Tests sequencer store undo/redo stack functions, snapshot helper,
-- guard gate, FIFO eviction, and the HandleProgUndo/HandleProgRedo API.
--
-- Setup: requires seq_store only (no reaper/gfx mocks needed)
--
-- Usage: lua tests/run.lua (from project root, or via test runner)

local check = require("tests.helpers").check
local seq_store = require("state.sequencer")

io.write("=== Progression Undo/Redo Tests ===\n")

-- Helper: build a slot table
local function slot(degree, root, scale, octave, chord)
    return {
        degree = degree,
        root_index = root or 1,
        scale_index = scale or 1,
        octave = octave or 4,
        chord_mode_index = chord or 1,
    }
end

-- Helper: create a fresh state table and init the store with it.
-- CRITICAL: a new progression table each time so Init does not carry stale entries.
local function fresh_state()
    local st = {
        progression = {},
        sequencer = {
            is_playing = false, current_step = 0, last_measure = -1,
            midi_notes = {}, progress = 0, internal_beats = 0,
            last_time = nil, volume = 100,
        },
        current_page = 1, page_override_timer = 0,
        slot_flash = { idx = -1, timer = 0 },
    }
    seq_store.Init(st)
    return st
end

-- ============================================================
-- Test 1: Snapshot roundtrip — snapshot captures, restore preserves
-- ============================================================
io.write("\n-- Snapshot Roundtrip\n")

fresh_state()

-- Seed two slots
seq_store.SetProgressionEntry(1, slot(1))
seq_store.SetProgressionEntry(3, slot(3))

-- Take snapshot
local snap = seq_store.ProgSnapshot()
check(type(snap) == "table", "snapshot: returns a table")
check(snap[1] ~= nil, "snapshot: slot 1 captured")
check(snap[1].degree == 1, "snapshot: slot 1 degree = 1")
check(snap[3] ~= nil, "snapshot: slot 3 captured")
check(snap[3].degree == 3, "snapshot: slot 3 degree = 3")
check(snap[2] == nil, "snapshot: slot 2 is nil (empty)")
check(snap[4] == nil, "snapshot: slot 4 is nil (empty)")

-- Snapshot is not the same reference as progression
check(snap ~= seq_store.GetProgression(), "snapshot: different table ref from progression")
check(snap[1] ~= seq_store.GetProgressionEntry(1), "snapshot: entry is deep copy, not same ref")

-- Modify original, snapshot stays intact
seq_store.SetProgressionEntry(1, slot(99))
check(snap[1].degree == 1, "snapshot: original data preserved after mutation")

-- ============================================================
-- Test 2: Undo/Redo cycle
-- ============================================================
io.write("\n-- Undo/Redo Cycle\n")

fresh_state()

seq_store.SetProgressionEntry(1, slot(10))
seq_store.SetProgressionEntry(2, slot(20))
check(seq_store.GetProgressionEntry(1).degree == 10, "cycle: slot 1 = 10")
check(seq_store.GetProgressionEntry(2).degree == 20, "cycle: slot 2 = 20")
check(#seq_store.GetProgUndoStack() == 2, "cycle: undo stack has 2 entries after 2 mutations")

-- Change slot 1
seq_store.SetProgressionEntry(1, slot(99))
check(seq_store.GetProgressionEntry(1).degree == 99, "cycle: slot 1 changed to 99")

-- Undo: should restore slot 1 to 10
seq_store.HandleProgUndo()
check(seq_store.GetProgressionEntry(1).degree == 10, "cycle: after undo, slot 1 = 10")
check(seq_store.GetProgressionEntry(2).degree == 20, "cycle: after undo, slot 2 = 20")

-- Redo: should restore slot 1 to 99
seq_store.HandleProgRedo()
check(seq_store.GetProgressionEntry(1).degree == 99, "cycle: after redo, slot 1 = 99")
check(seq_store.GetProgressionEntry(2).degree == 20, "cycle: after redo, slot 2 = 20")

-- ============================================================
-- Test 3: FIFO eviction at 51
-- ============================================================
io.write("\n-- FIFO Eviction\n")

fresh_state()

-- Push 51 entries (overflow by 1)
for i = 1, 51 do
    seq_store.SetProgressionEntry(1, slot(100 + i))
end
check(#seq_store.GetProgUndoStack() == 50, "evict: undo stack capped at 50 after 51 pushes")
check(#seq_store.GetProgRedoStack() == 0, "evict: redo stack is empty (new edits clear redo)")

-- Verify the oldest entry was evicted by checking degrees
-- Each snapshot captures the state BEFORE mutation.
-- i=1 snaps {}, i=2 snaps {1=101}, ..., i=51 snaps {1=150}.
-- After FIFO eviction: positions 1..50 = snaps from i=2 (degree 101) thru i=51 (degree 150).
local e = seq_store.PopProgUndo()
check(e ~= nil, "evict: Pop returns entry")
check(e[1].degree == 150, "evict: newest entry degree = 150 (snap before i=51)")

-- Pop 48 more, then check the oldest remaining is from i=2 (degree 101)
for _ = 1, 48 do seq_store.PopProgUndo() end
local oldest = seq_store.PopProgUndo()
check(oldest ~= nil, "evict: Pop oldest remaining entry")
check(oldest[1].degree == 101, "evict: oldest remaining degree = 101 (snap before i=2)")
check(seq_store.PopProgUndo() == nil, "evict: stack empty after 50 pops")

-- ============================================================
-- Test 4: Empty stacks no-op
-- ============================================================
io.write("\n-- Empty Stack No-ops\n")

fresh_state()
check(#seq_store.GetProgUndoStack() == 0, "noop: undo stack empty after init")
check(#seq_store.GetProgRedoStack() == 0, "noop: redo stack empty after init")

-- These should not error or crash on empty stacks
local ok = pcall(seq_store.HandleProgUndo)
check(ok == true, "noop: HandleProgUndo on empty does not crash")
ok = pcall(seq_store.HandleProgRedo)
check(ok == true, "noop: HandleProgRedo on empty does not crash")
ok = pcall(seq_store.PopProgUndo)
check(ok == true, "noop: PopProgUndo on empty does not crash")
check(seq_store.PopProgUndo() == nil, "noop: PopProgUndo returns nil on empty")
ok = pcall(seq_store.PopProgRedo)
check(ok == true, "noop: PopProgRedo on empty does not crash")
check(seq_store.PopProgRedo() == nil, "noop: PopProgRedo returns nil on empty")

-- ============================================================
-- Test 5: Clear stacks works
-- ============================================================
io.write("\n-- Clear Stacks\n")

seq_store.SetProgressionEntry(1, slot(5))
seq_store.SetProgressionEntry(2, slot(6))
check(#seq_store.GetProgUndoStack() == 2, "clear: undo stack has 2 entries before clear")

seq_store.ClearProgUndoStacks()
check(#seq_store.GetProgUndoStack() == 0, "clear: undo stack empty after clear")
check(#seq_store.GetProgRedoStack() == 0, "clear: redo stack empty after clear")
check(seq_store.PopProgUndo() == nil, "clear: PopProgUndo returns nil after clear")
check(seq_store.PopProgRedo() == nil, "clear: PopProgRedo returns nil after clear")

-- Clear empty stacks is idempotent
ok = pcall(seq_store.ClearProgUndoStacks)
check(ok == true, "clear: ClearProgUndoStacks on empty does not crash")

-- ============================================================
-- Test 6: Gate prevents double-snapshot
-- ============================================================
io.write("\n-- Guard Gate\n")

fresh_state()

-- Open gate (default) — mutations create undo entries
seq_store.SetProgUndoGate(false)
local before = #seq_store.GetProgUndoStack()
seq_store.SetProgressionEntry(1, slot(30))
check(#seq_store.GetProgUndoStack() == before + 1, "gate open: mutation creates undo entry")

-- Close gate — mutations do NOT create undo entries
seq_store.SetProgUndoGate(true)
before = #seq_store.GetProgUndoStack()
seq_store.SetProgressionEntry(1, slot(40))
check(#seq_store.GetProgUndoStack() == before, "gate closed: mutation does not create undo entry")

-- Open gate again — mutations create undo entries again
seq_store.SetProgUndoGate(false)
before = #seq_store.GetProgUndoStack()
seq_store.SetProgressionEntry(1, slot(50))
check(#seq_store.GetProgUndoStack() == before + 1, "gate reopened: mutation creates undo entry")

-- ============================================================
-- Test 7: SetProgression undo — snapshot captures full array
-- ============================================================
io.write("\n-- SetProgression Undo\n")

fresh_state()

-- Build a multi-slot progression and set it
local prog1 = {}
prog1[1] = slot(1)
prog1[3] = slot(3)
prog1[5] = slot(5)
seq_store.SetProgression(prog1)
check(seq_store.GetProgressionEntry(1).degree == 1, "setprog: slot 1 = 1")
check(seq_store.GetProgressionEntry(5).degree == 5, "setprog: slot 5 = 5")

-- Replace with different progression
local prog2 = {}
prog2[2] = slot(2)
prog2[4] = slot(4)
seq_store.SetProgression(prog2)
check(seq_store.GetProgressionEntry(2).degree == 2, "setprog: slot 2 = 2")
check(seq_store.GetProgressionEntry(1) == nil, "setprog: slot 1 is nil")

-- Undo: should restore prog1
seq_store.HandleProgUndo()
check(seq_store.GetProgressionEntry(1).degree == 1, "setprog: after undo, slot 1 = 1")
check(seq_store.GetProgressionEntry(3).degree == 3, "setprog: after undo, slot 3 = 3")
check(seq_store.GetProgressionEntry(5).degree == 5, "setprog: after undo, slot 5 = 5")
check(seq_store.GetProgressionEntry(2) == nil, "setprog: after undo, slot 2 is nil")

-- ============================================================
-- Test 8: ClearProgression undo
-- ============================================================
io.write("\n-- ClearProgression Undo\n")

fresh_state()

seq_store.SetProgressionEntry(1, slot(7))
seq_store.SetProgressionEntry(2, slot(8))
seq_store.SetProgressionEntry(3, slot(9))
check(seq_store.GetProgressionEntry(1) ~= nil, "clearundo: slot 1 exists before clear")

-- Clear and verify
seq_store.ClearProgression()
check(seq_store.GetProgressionEntry(1) == nil, "clearundo: slot 1 nil after clear")
check(seq_store.GetProgressionEntry(2) == nil, "clearundo: slot 2 nil after clear")

-- Undo: should restore
seq_store.HandleProgUndo()
check(seq_store.GetProgressionEntry(1).degree == 7, "clearundo: after undo slot 1 = 7")
check(seq_store.GetProgressionEntry(2).degree == 8, "clearundo: after undo slot 2 = 8")
check(seq_store.GetProgressionEntry(3).degree == 9, "clearundo: after undo slot 3 = 9")

-- ============================================================
-- Test 9: Push/PopUndo/Redo direct stack operations
-- ============================================================
io.write("\n-- Direct Stack Ops\n")

fresh_state()

local snap1 = {[1] = {degree = 1}}
local snap2 = {[2] = {degree = 2}}
seq_store.PushProgUndo(snap1)
seq_store.PushProgUndo(snap2)
check(#seq_store.GetProgUndoStack() == 2, "stack: 2 undo entries")
check(#seq_store.GetProgRedoStack() == 0, "stack: 0 redo entries")

local popped = seq_store.PopProgUndo()
check(popped ~= nil, "stack: PopUndo returns entry")
check(popped[2].degree == 2, "stack: LIFO — last pushed popped first")
check(#seq_store.GetProgUndoStack() == 1, "stack: 1 undo remaining")

seq_store.PushProgRedo(popped)
check(#seq_store.GetProgRedoStack() == 1, "stack: 1 redo entry after push")

local redo_popped = seq_store.PopProgRedo()
check(redo_popped ~= nil, "stack: PopRedo returns entry")
check(redo_popped[2].degree == 2, "stack: redo entry matches")

-- ============================================================
-- Test 10: Redo cleared on new edit (after undo)
-- ============================================================
io.write("\n-- Redo Cleared on New Edit\n")

fresh_state()

seq_store.SetProgressionEntry(1, slot(100))
seq_store.SetProgressionEntry(1, slot(200))

-- Undo — redo should get the latest state
seq_store.HandleProgUndo()
check(#seq_store.GetProgRedoStack() == 1, "redo: redo has 1 entry after undo")

-- New mutation — redo should be cleared
seq_store.SetProgressionEntry(2, slot(300))
check(#seq_store.GetProgRedoStack() == 0, "redo: cleared after new edit")
check(#seq_store.GetProgUndoStack() >= 1, "redo: undo stack still has entries")

-- ============================================================
-- Test 11: Max redo stack FIFO eviction
-- ============================================================
io.write("\n-- Redo Stack Eviction\n")

fresh_state()

for i = 1, 52 do
    seq_store.PushProgRedo({[1] = {degree = 200 + i}})
end
check(#seq_store.GetProgRedoStack() == 50, "redo evict: redo stack capped at 50 after 52 pushes")

-- ============================================================
-- Test 12: HandleProgUndo/HandleProgRedo restack correctly
-- ============================================================
io.write("\n-- Undo/Redo Restack\n")

fresh_state()

seq_store.SetProgressionEntry(1, slot(500))
check(#seq_store.GetProgUndoStack() == 1, "restack: 1 undo entry after first mutation")

seq_store.SetProgressionEntry(1, slot(501))
check(#seq_store.GetProgUndoStack() == 2, "restack: 2 undo entries after second mutation")

-- Undo once — current state pushed to redo
seq_store.HandleProgUndo()
check(seq_store.GetProgressionEntry(1).degree == 500, "restack: undo restored slot 1 = 500")
check(#seq_store.GetProgRedoStack() == 1, "restack: 1 redo entry after undo")

-- Undo again — previous state pushed to redo
seq_store.HandleProgUndo()
check(seq_store.GetProgressionEntry(1) == nil, "restack: undo restored slot 1 = nil (initial)")
check(#seq_store.GetProgRedoStack() == 2, "restack: 2 redo entries after second undo")

-- Redo once — state pushed to undo, redo popped
seq_store.HandleProgRedo()
check(seq_store.GetProgressionEntry(1).degree == 500, "restack: redo restored slot 1 = 500")
check(#seq_store.GetProgRedoStack() == 1, "restack: 1 redo entry after redo")
check(#seq_store.GetProgUndoStack() >= 1, "restack: undo has entries after redo")

-- ============================================================
-- Test 13: Getters/setters round-trip for stack tables and gate
-- ============================================================
io.write("\n-- Getter/Setter Round-trips\n")

fresh_state()

-- Gate round-trip
check(seq_store.GetProgUndoGate() == false, "getset: gate defaults to false")
seq_store.SetProgUndoGate(true)
check(seq_store.GetProgUndoGate() == true, "getset: gate round-trip true")
seq_store.SetProgUndoGate(false)
check(seq_store.GetProgUndoGate() == false, "getset: gate round-trip false")

-- Stack table set/get
local test_stack = { {[1] = {degree = 7}} }
seq_store.SetProgUndoStack(test_stack)
check(#seq_store.GetProgUndoStack() == 1, "getset: undo stack table round-trip")
check(seq_store.GetProgUndoStack()[1][1].degree == 7, "getset: undo stack entry preserved")

seq_store.SetProgRedoStack(test_stack)
check(#seq_store.GetProgRedoStack() == 1, "getset: redo stack table round-trip")

-- Final
io.write("\n=== Progression Undo/Redo Tests Complete ===\n")
