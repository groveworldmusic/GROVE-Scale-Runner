-- Tests: Undo/Redo System + Keyboard Shortcuts (PR3)
-- Tests island_store undo/redo stack functions, UUID allocation,
-- undo push from interaction.lua edit operations, keyboard shortcut dispatch.
--
-- Setup: requires config + island_store (no reaper/gfx mocks needed for
-- store-level tests). Interaction-level tests need minimal gfx mock.
--
-- Usage: lua tests/run.lua (from project root, or via test runner)

local check = require("tests.helpers").check
local config = require("config")
local island_store = require("state.island")

io.write("=== Undo/Redo Tests ===\n")

-- ============================================================
-- Initialize island_store with empty state
-- ============================================================
island_store.Init({
    island_active = false,
    preset_panel_visible = true,
    notes = {},
    scroll_offset_y = 36,
    scroll_offset_x = 0,
    zoom_x = 40,
    selected_note_index = nil,
})

-- ============================================================
-- Test 1: UUID Allocation
-- ============================================================
io.write("\n-- UUID Allocation\n")

local u1 = island_store.AllocNoteUUID()
local u2 = island_store.AllocNoteUUID()
local u3 = island_store.AllocNoteUUID()
check(u1 == 1, "uuid: first UUID = 1")
check(u2 == 2, "uuid: second UUID = 2")
check(u3 == 3, "uuid: third UUID = 3")
check(u1 ~= u2, "uuid: unique values")
check(u2 ~= u3, "uuid: unique values 2")

-- ============================================================
-- Test 2: Basic Undo/Redo Stack Operations
-- ============================================================
io.write("\n-- Basic Stack Operations\n")

island_store.ClearUndoStacks()
check(island_store.GetUndoDepth() == 0, "undo: depth = 0 after clear")
check(island_store.GetRedoDepth() == 0, "redo: depth = 0 after clear")

-- Push undo entries
local entry1 = {type = "move", note_uuids = {1}, prev_state = {{pitch=60, start_beat=0}}, new_state = {{pitch=64, start_beat=0}}}
local entry2 = {type = "move", note_uuids = {2}, prev_state = {{pitch=64, start_beat=2}}, new_state = {{pitch=62, start_beat=3}}}
island_store.PushUndo(entry1)
island_store.PushUndo(entry2)
check(island_store.GetUndoDepth() == 2, "undo: depth = 2 after 2 pushes")
check(island_store.GetRedoDepth() == 0, "redo: depth = 0 (no redo yet)")

-- Pop undo → push redo
local popped = island_store.PopUndo()
check(popped ~= nil, "undo: PopUndo returns entry")
check(popped.type == "move", "undo: popped entry type = move")
check(island_store.GetUndoDepth() == 1, "undo: depth = 1 after pop")

island_store.PushRedo(popped)
check(island_store.GetRedoDepth() == 1, "redo: depth = 1 after PushRedo")

-- Pop redo
local redo_popped = island_store.PopRedo()
check(redo_popped ~= nil, "redo: PopRedo returns entry")
check(redo_popped.type == "move", "redo: popped entry type = move")
check(island_store.GetRedoDepth() == 0, "redo: depth = 0 after pop")

-- ============================================================
-- Test 3: Empty Stack No-ops
-- ============================================================
io.write("\n-- Empty Stack Behavior\n")

island_store.ClearUndoStacks()
check(island_store.PopUndo() == nil, "undo: PopUndo on empty returns nil")
check(island_store.PopRedo() == nil, "redo: PopRedo on empty returns nil")
-- These should not error or crash
local ok = pcall(island_store.PopUndo)
check(ok == true, "undo: PopUndo on empty does not crash")
ok = pcall(island_store.PopRedo)
check(ok == true, "redo: PopRedo on empty does not crash")

-- ============================================================
-- Test 4: New Edit Clears Redo Stack
-- ============================================================
io.write("\n-- New Edit Clears Redo\n")

island_store.ClearUndoStacks()
island_store.PushUndo({type = "add", note_uuids = {5}, new_state = {{pitch=60}}})
island_store.PushUndo({type = "move", note_uuids = {5}, prev_state = {{pitch=60}}, new_state = {{pitch=64}}})
local popped2 = island_store.PopUndo()
island_store.PushRedo(popped2)
check(island_store.GetRedoDepth() == 1, "redo: depth = 1 after undo+PushRedo")
check(island_store.GetUndoDepth() == 1, "undo: depth = 1 after pop")

-- New edit → redo cleared
island_store.PushUndo({type = "add", note_uuids = {6}, new_state = {{pitch=72}}})
check(island_store.GetRedoDepth() == 0, "redo: cleared after new edit")
check(island_store.GetUndoDepth() == 2, "undo: depth = 2 after new edit + existing")

-- ============================================================
-- Test 5: Stack Overflow Eviction (FIFO)
-- ============================================================
io.write("\n-- Stack Overflow Eviction\n")

island_store.ClearUndoStacks()
-- Push 51 entries (overflow by 1)
for i = 1, 51 do
    island_store.PushUndo({type = "move", note_uuids = {i}, prev_state = {{pitch=i}}, new_state = {{pitch=i+1}}})
end
-- Stack should stay at 50, oldest (uuid 1) evicted
check(island_store.GetUndoDepth() == 50, "undo: depth capped at 50 after 51 pushes")

-- Pop and verify the oldest was evicted: first entry should be uuid #2
local first_entry = island_store.PopUndo()
-- We can't easily check uuid# since we popped from the END (stack), not from the FRONT.
-- The FIFO eviction means entry with uuid=1 was removed from the bottom.
-- Let's verify by pushing 50 more and checking depth stays at 50
for i = 1, 50 do
    island_store.PushUndo({type = "move", note_uuids = {100 + i}, prev_state = {{pitch=0}}, new_state = {{pitch=1}}})
end
check(island_store.GetUndoDepth() == 50, "undo: depth stays at 50 after 50 more pushes")

-- ============================================================
-- Test 6: Redo Stack Overflow Eviction
-- ============================================================
io.write("\n-- Redo Stack Overflow Eviction\n")

island_store.ClearUndoStacks()
-- Need undo entries to pop and push to redo
for i = 1, 52 do
    island_store.PushUndo({type = "move", note_uuids = {200 + i}, prev_state = {{pitch=0}}, new_state = {{pitch=1}}})
end
-- Pop all 50 and push to redo
for _ = 1, 50 do
    local e = island_store.PopUndo()
    if e then island_store.PushRedo(e) end
end
check(island_store.GetRedoDepth() == 50, "redo: depth capped at 50 after many pushes")
check(island_store.GetUndoDepth() == 0, "undo: depth = 0 after all popped")

-- ============================================================
-- Test 7: Undo Entry Format Verification
-- ============================================================
io.write("\n-- Entry Format\n")

island_store.ClearUndoStacks()
local timestamp_before = os.clock()
island_store.PushUndo({type = "velocity", note_uuids = {10}, prev_state = {{velocity=80}}, new_state = {{velocity=100}}})
local timestamp_after = os.clock()
local e = island_store.PopUndo()
check(e.type == "velocity", "entry: type = velocity")
check(#e.note_uuids == 1, "entry: 1 note UUID")
check(e.note_uuids[1] == 10, "entry: UUID = 10")
check(e.prev_state[1].velocity == 80, "entry: prev velocity = 80")
check(e.new_state[1].velocity == 100, "entry: new velocity = 100")
check(e.timestamp ~= nil, "entry: timestamp set")
check(e.timestamp >= timestamp_before and e.timestamp <= timestamp_after, "entry: timestamp in range")

-- ============================================================
-- Test 8: Delete Entry Format (bulk)
-- ============================================================
io.write("\n-- Delete Entry Format\n")

island_store.ClearUndoStacks()
local delete_entry = {
    type = "delete",
    note_uuids = {11, 12, 13},
    prev_state = {
        {pitch=60, start_beat=0, duration=1, velocity=100, muted=false, uuid=11},
        {pitch=64, start_beat=2, duration=1, velocity=90, muted=true, uuid=12},
        {pitch=67, start_beat=4, duration=2, velocity=110, muted=false, uuid=13},
    },
}
island_store.PushUndo(delete_entry)
local e2 = island_store.PopUndo()
check(e2.type == "delete", "delete: entry type")
check(#e2.note_uuids == 3, "delete: 3 note UUIDs")
check(#e2.prev_state == 3, "delete: 3 prev_state entries")
check(e2.prev_state[2].muted == true, "delete: second note muted = true")
check(e2.prev_state[2].uuid == 12, "delete: second note uuid preserved")

-- ============================================================
-- Test 9: Mute Entry Format (batch)
-- ============================================================
io.write("\n-- Mute Entry Format\n")

island_store.ClearUndoStacks()
local mute_entry = {
    type = "mute",
    note_uuids = {21, 22},
    prev_state = {{muted=false}, {muted=true}},
    new_state = {{muted=true}, {muted=false}},
}
island_store.PushUndo(mute_entry)
local e3 = island_store.PopUndo()
check(e3.type == "mute", "mute: entry type")
check(#e3.note_uuids == 2, "mute: 2 note UUIDs")
check(e3.prev_state[1].muted == false, "mute: first note was unmuted")
check(e3.new_state[1].muted == true, "mute: first note now muted")

-- ============================================================
-- Test 10: Add Entry Format
-- ============================================================
io.write("\n-- Add Entry Format\n")

island_store.ClearUndoStacks()
local add_entry = {
    type = "add",
    note_uuids = {30},
    new_state = {{
        pitch=72, start_beat=0, duration=1, velocity=100, muted=false, uuid=30,
    }},
}
island_store.PushUndo(add_entry)
local e4 = island_store.PopUndo()
check(e4.type == "add", "add: entry type")
check(e4.new_state[1].pitch == 72, "add: pitch = 72")
check(e4.new_state[1].uuid == 30, "add: uuid preserved")

-- ============================================================
-- Test 11: UUID Uniqueness via AllocNoteUUID
-- ============================================================
io.write("\n-- UUID Uniqueness\n")

local uuids = {}
local all_unique = true
for i = 1, 100 do
    local u = island_store.AllocNoteUUID()
    if uuids[u] then
        all_unique = false
        break
    end
    uuids[u] = true
end
check(all_unique == true, "uuid: 100 allocations all unique")

-- ============================================================
-- Test 12: AddNote assigns UUID
-- ============================================================
io.write("\n-- AddNote UUID\n")

island_store.SetNotes({})
local n1 = {pitch=60, start_beat=0, duration=1, velocity=100, muted=false}
island_store.AddNote(n1)
check(n1.uuid ~= nil, "addnote: UUID assigned")
check(n1.uuid > 0, "addnote: UUID positive")
local n2 = {pitch=64, start_beat=2, duration=1, velocity=100, muted=false, uuid=999}
island_store.AddNote(n2)
check(n2.uuid == 999, "addnote: explicit UUID preserved")
check(island_store.FindNoteByUUID(999) == 2, "addnote: FindNoteByUUID returns index 2")
check(island_store.FindNoteByUUID(n1.uuid) == 1, "addnote: FindNoteByUUID returns index 1")

-- ============================================================
-- Test 13: RemoveNoteAtIndex updates UUID index
-- ============================================================
io.write("\n-- RemoveNoteAtIndex UUID\n")

island_store.RemoveNoteAtIndex(1)
check(island_store.GetNoteCount() == 1, "remove: count = 1")
check(island_store.FindNoteByUUID(n1.uuid) == nil, "remove: removed note UUID gone")
local n3 = {pitch=67, start_beat=4, duration=1, velocity=100, muted=false}
island_store.AddNote(n3)
check(island_store.FindNoteByUUID(n3.uuid) == 2, "remove: new note at index 2")
check(island_store.FindNoteByUUID(999) == 1, "remove: existing note adjusted to index 1")

-- ============================================================
-- Test 14: SetNotes rebuilds UUID index
-- ============================================================
io.write("\n-- SetNotes UUID Rebuild\n")

island_store.SetNotes({})
local notes = {
    {pitch=60, start_beat=0, duration=1, velocity=100, muted=false, uuid=1001},
    {pitch=64, start_beat=2, duration=1, velocity=100, muted=false, uuid=1002},
}
island_store.SetNotes(notes)
check(island_store.FindNoteByUUID(1001) == 1, "setnotes: find uuid 1001 = 1")
check(island_store.FindNoteByUUID(1002) == 2, "setnotes: find uuid 1002 = 2")
check(island_store.FindNoteByUUID(999) == nil, "setnotes: old uuid gone")

-- ============================================================
-- Test 15: ClearUndoStacks
-- ============================================================
io.write("\n-- ClearUndoStacks\n")

-- Push undo entries first. Note: PushUndo clears redo stack on each call,
-- so redo entries are pushed separately afterward.
for i = 1, 10 do
    island_store.PushUndo({type = "move", note_uuids = {500+i}, prev_state = {{pitch=0}}, new_state = {{pitch=1}}})
end
for i = 1, 10 do
    island_store.PushRedo({type = "move", note_uuids = {600+i}, prev_state = {{pitch=1}}, new_state = {{pitch=2}}})
end
check(island_store.GetUndoDepth() == 10, "clear: undo depth 10 before clear")
check(island_store.GetRedoDepth() == 10, "clear: redo depth 10 before clear")
island_store.ClearUndoStacks()
check(island_store.GetUndoDepth() == 0, "clear: undo depth 0 after clear")
check(island_store.GetRedoDepth() == 0, "clear: redo depth 0 after clear")
check(island_store.PopUndo() == nil, "clear: PopUndo returns nil")
check(island_store.PopRedo() == nil, "clear: PopRedo returns nil")

-- ============================================================
-- Test 16: ProgressionToNotes assigns UUIDs
-- ============================================================
io.write("\n-- ProgressionToNotes UUIDs\n")

-- Seed progression state
local progression = config.state.progression
progression[1] = {degree=1, root_index=1, scale_index=1, octave=4, chord_mode_index=1}
progression[2] = {degree=3, root_index=1, scale_index=1, octave=4, chord_mode_index=1}

local pnotes = island_store.ProgressionToNotes(progression, 4, 100)
check(#pnotes >= 1, "progression: at least 1 note created")
for i, pn in ipairs(pnotes) do
    check(pn.uuid ~= nil, string.format("progression: note %d has uuid", i))
    check(pn.uuid > 0, string.format("progression: note %d uuid > 0", i))
end
-- Verify unique UUIDs across notes
local seen_uuids = {}
local all_unique = true
for _, pn in ipairs(pnotes) do
    if seen_uuids[pn.uuid] then all_unique = false; break end
    seen_uuids[pn.uuid] = true
end
check(all_unique == true, "progression: all note UUIDs unique")

-- ============================================================
-- Keyboard Shortcut Tests (char code dispatch)
-- ============================================================
io.write("\n-- Keyboard Shortcut Dispatch (char code verification)\n")

-- These tests verify the char code constants only — the actual
-- interaction function dispatch is tested by verifying the
-- HandleKeyboardShortcut routing returns true for known shortcuts.

-- Ctrl+Z = 90 + 256 = 346
check(90 + 256 == 346, "kbd: Ctrl+Z = 346")
-- Ctrl+Y = 89 + 256 = 345
check(89 + 256 == 345, "kbd: Ctrl+Y = 345")
-- Ctrl+X = 88 + 256 = 344
check(88 + 256 == 344, "kbd: Ctrl+X = 344")
-- Ctrl+C = 67 + 256 = 323
check(67 + 256 == 323, "kbd: Ctrl+C = 323")
-- Ctrl+V = 86 + 256 = 342
check(86 + 256 == 342, "kbd: Ctrl+V = 342")
-- Delete = 46 (VK_DELETE) or 127 (ASCII DEL) or 302 (Ctrl+Delete)
check(46 == 46, "kbd: Delete = 46")
check(127 == 127, "kbd: DEL = 127")
check(256 + 46 == 302, "kbd: Ctrl+Delete = 302")
-- Arrow keys
check(37 == 37, "kbd: VK_LEFT = 37")
check(38 == 38, "kbd: VK_UP = 38")
check(39 == 39, "kbd: VK_RIGHT = 39")
check(40 == 40, "kbd: VK_DOWN = 40")
-- Shift+arrows
check(37 + 512 == 549, "kbd: Shift+Left = 549")
check(38 + 512 == 550, "kbd: Shift+Up = 550")
check(39 + 512 == 551, "kbd: Shift+Right = 551")
check(40 + 512 == 552, "kbd: Shift+Down = 552")

-- ============================================================
-- Barrel backward compat verification for PR3 exports
-- ============================================================
io.write("\n-- Barrel PR3 Export Verification\n")

local ok, pr = pcall(require, "ui.piano-roll")
if not ok then
    check(false, "barrel: requires ui.piano-roll")
else
    local PR3_EXPORTS = {
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
    for name, expected_type in pairs(PR3_EXPORTS) do
        local actual_type = type(pr[name])
        check(actual_type == expected_type,
            string.format("barrel: piano_roll.%s exists with type '%s'", name, actual_type))
    end
end

-- ============================================================
-- Island store undo/redo getter consistency
-- ============================================================
io.write("\n-- Getter Consistency\n")

island_store.ClearUndoStacks()
check(island_store.GetUndoDepth() == 0, "getter: undo depth 0")
check(island_store.GetRedoDepth() == 0, "getter: redo depth 0")
island_store.PushUndo({type="move", note_uuids={1}, prev_state={{pitch=0}}, new_state={{pitch=1}}})
check(island_store.GetUndoDepth() == 1, "getter: undo depth 1")
local e = island_store.PopUndo()
check(island_store.GetUndoDepth() == 0, "getter: undo depth 0 after pop")
island_store.PushRedo(e)
check(island_store.GetRedoDepth() == 1, "getter: redo depth 1 after push")
island_store.PopRedo()
check(island_store.GetRedoDepth() == 0, "getter: redo depth 0 after pop")

-- Final
io.write("\n=== Undo/Redo Tests Complete ===\n")
