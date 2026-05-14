-- Tests for core.progression: Add, Remove, Swap, Clear, GetLastFilled

local progression = require("core.progression")
local seq_store = require("state.sequencer")
local check = require("tests.helpers").check

-- Initialize sequencer store with a fresh state for progression tests
local seq_state = {
    progression = {},
    sequencer = {
        is_playing = false, current_step = 0, last_measure = -1,
        midi_notes = {}, progress = 0, internal_beats = 0,
        last_time = nil, volume = 100,
    },
    current_page = 1, page_override_timer = 0,
    slot_flash = { idx = -1, timer = 0 },
}
seq_store.Init(seq_state)

io.write("=== Progression Tests ===\n")

-- Helper: build a slot table
local function slot(degree)
    return { degree = degree, root_index = 1, scale_index = 1, octave = 4, chord_mode_index = 1 }
end

-- 1. Empty → GetLastFilled == 0
io.write("\n-- Empty state\n")
check(progression.GetLastFilled() == 0, "Empty: GetLastFilled == 0")

-- 2. Add → GetLastFilled returns correct position
io.write("\n-- Add\n")
progression.Add(1, slot(1))
check(progression.GetLastFilled() == 1, "Add at 1: GetLastFilled == 1")
check(seq_store.GetProgressionEntry(1) ~= nil, "Add at 1: entry exists")
check(seq_store.GetProgressionEntry(1).degree == 1, "Add at 1: degree == 1")

progression.Add(5, slot(3))
check(progression.GetLastFilled() == 5, "Add at 5: GetLastFilled == 5 (higher index)")

progression.Add(3, slot(2))
check(progression.GetLastFilled() == 5, "Add at 3: GetLastFilled still 5 (slot 5 is highest)")

-- 3. Remove → position empty
io.write("\n-- Remove\n")
progression.Remove(5)
check(progression.GetLastFilled() == 3, "Remove slot 5: GetLastFilled == 3 (next highest)")
check(seq_store.GetProgressionEntry(5) == nil, "Remove slot 5: entry is nil")

progression.Remove(1)
check(progression.GetLastFilled() == 3, "Remove slot 1: GetLastFilled still 3")

-- 4. Swap → values exchanged
io.write("\n-- Swap\n")
progression.Add(1, slot(10))
progression.Add(2, slot(20))

local a_before = seq_store.GetProgressionEntry(1).degree
local b_before = seq_store.GetProgressionEntry(2).degree
check(a_before == 10 and b_before == 20, "Swap setup: slots 1 and 2 have expected values")

progression.Swap(1, 2)
check(seq_store.GetProgressionEntry(1).degree == 20, "Swap: slot 1 gets old slot 2 degree")
check(seq_store.GetProgressionEntry(2).degree == 10, "Swap: slot 2 gets old slot 1 degree")

-- 5. Self-swap → no change
io.write("\n-- Self-swap\n")
local before_self = seq_store.GetProgressionEntry(1).degree
progression.Swap(1, 1)
check(seq_store.GetProgressionEntry(1).degree == before_self, "Self-swap: degree unchanged")

-- 6. Clear → no filled positions
io.write("\n-- Clear\n")
progression.Clear()
check(progression.GetLastFilled() == 0, "Clear: GetLastFilled == 0")
for i = 1, 16 do
    check(seq_store.GetProgressionEntry(i) == nil, "Clear: entry " .. i .. " is nil")
end
