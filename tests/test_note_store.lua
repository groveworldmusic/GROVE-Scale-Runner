-- Tests for src/state/note-store.lua
-- Run via: lua tests/run.lua

local config = require("config")
local note_store = require("state.note-store")
local helpers = require("tests.helpers")
local check = helpers.check
local assert_eq = helpers.assert_eq

-- Mocks for SyncNotesToProgression
local mock_seq_store = {
    progression = {},
}
function mock_seq_store.GetProgression() return mock_seq_store.progression end
function mock_seq_store.SetProgressionEntry(i, v) mock_seq_store.progression[i] = v end

local mock_prefs_store = {
    GetRootIndex = function() return 1 end, -- C
    GetScaleIndex = function() return 1 end, -- Major
    GetOctave = function() return 4 end,
}

io.write("=== Note Store Tests ===\n")

-- Reset note-store state before each test block (since it's a singleton)
local function reset_note_store()
    note_store.SetNotes({})
    note_store.SetNoteCount(0)
    -- We can't easily reset next_note_uuid because it's private, 
    -- but it's monotonic so it's fine for tests.
end

-- 1. ProgressionToNotes
io.write("\n-- 1. ProgressionToNotes\n")
reset_note_store()

-- Empty progression
local notes_empty = note_store.ProgressionToNotes({})
check(#notes_empty == 0, "Empty progression produces 0 notes")

-- Minimal progression (1 slot, 1 note)
local progression_min = {}
progression_min[1] = { degree = 1, root_index = 1, scale_index = 1, octave = 4, chord_mode_index = 1 }
local notes_min = note_store.ProgressionToNotes(progression_min)
check(#notes_min == 1, "Minimal progression (1 slot, 1 note) produces 1 note")
check(notes_min[1].pitch == 60, "C4 note produced, got " .. notes_min[1].pitch)
check(notes_min[1].start_beat == 0, "Start beat is 0")

-- Maximal progression (16 slots, 1 note each)
local progression_max = {}
for i = 1, 16 do
    progression_max[i] = { degree = 1, root_index = 1, scale_index = 1, octave = 4, chord_mode_index = 1 }
end
local notes_max = note_store.ProgressionToNotes(progression_max)
check(#notes_max == 16, "Maximal progression (16 slots, 1 note each) produces 16 notes")
check(notes_max[16].start_beat == 15 * 4, "Last note starts at 60, got " .. notes_max[16].start_beat)

-- Progression with sub-notes (subdivisions)
local progression_subs = {}
progression_subs[1] = { 
    degree = 1, root_index = 1, scale_index = 1, octave = 4, chord_mode_index = 1,
    subs = { {degree = 3}, {degree = 5} } 
}
local notes_subs = note_store.ProgressionToNotes(progression_subs, 4)
check(#notes_subs == 2, "Progression with 2 subdivisions produces 2 notes")
check(notes_subs[1].start_beat == 0, "First sub note at beat 0")
check(notes_subs[2].start_beat == 2, "Second sub note at beat 2 (half of 4)")
check(notes_subs[1].duration == 2, "Sub-note duration is 2")

-- 2. SyncNotesToProgression
io.write("\n-- 2. SyncNotesToProgression\n")
reset_note_store()
mock_seq_store.progression = {}

-- Add notes to store
note_store.AddNote({ pitch = 60, start_beat = 0, duration = 4, velocity = 100 }) -- C4
note_store.AddNote({ pitch = 64, start_beat = 0, duration = 4, velocity = 100 }) -- E4
note_store.AddNote({ pitch = 67, start_beat = 4, duration = 4, velocity = 100 }) -- G4 (Slot 2)

local written = note_store.SyncNotesToProgression(mock_seq_store, mock_prefs_store, 4)
check(written == 2, "Two slots written (slot 1 and slot 2)")
check(mock_seq_store.progression[1].degree == 1, "Slot 1 degree is 1 (C)")
check(mock_seq_store.progression[1].chord_mode_index == 2, "Slot 1 chord mode is 2 (Tri)")
check(mock_seq_store.progression[2].degree == 5, "Slot 2 degree is 5 (G)")
check(mock_seq_store.progression[2].chord_mode_index == 1, "Slot 2 chord mode is 1 (Off)")

-- 3. FindNearestScaleDegree
io.write("\n-- 3. FindNearestScaleDegree\n")
-- Scale 1 is Major: [0, 2, 4, 5, 7, 9, 11]
-- Root 1 (C)
-- Pitch 60 (C4) -> degree 1
-- Pitch 61 (C#4) -> degree 1 (distance 1 to 60, distance 1 to 62? No, 62 is E? No, 62 is D)
-- Intervals: C(0), D(2), E(4), F(5), G(7), A(9), B(11)

check(note_store.FindNearestScaleDegree(60, 1, 1) == 1, "Pitch 60 (C) nearest to degree 1")
check(note_store.FindNearestScaleDegree(62, 1, 1) == 2, "Pitch 62 (D) nearest to degree 2")
check(note_store.FindNearestScaleDegree(61, 1, 1) == 2, "Pitch 61 (C#) nearest to degree 2 (tie-break)")
-- Let's check tie-break behavior: if dist < best_dist, it updates. 
-- For 61: dist(C, 61)=1, best_deg=1. dist(D, 61)=1, 1 < 1 is false. So it stays 1.

-- 4. DetectChordMode
io.write("\n-- 4. DetectChordMode\n")
-- 1 note -> OFF (1)
check(note_store.DetectChordMode({{pitch=60}}) == 1, "1 note is chord mode 1")
-- 2 notes -> TRI (2)
check(note_store.DetectChordMode({{pitch=60}, {pitch=64}}) == 2, "2 notes is chord mode 2")
-- 3 notes -> TRI (2)
check(note_store.DetectChordMode({{pitch=60}, {pitch=64}, {pitch=67}}) == 2, "3 notes is chord mode 2")
-- 4 notes -> 7MA (3)
check(note_store.DetectChordMode({{pitch=60}, {pitch=64}, {pitch=67}, {pitch=71}}) == 3, "4 notes is chord mode 3")
-- 5 notes -> 9NA (4)
check(note_store.DetectChordMode({{pitch=60}, {pitch=64}, {pitch=67}, {pitch=71}, {pitch=74}}) == 4, "5 notes is chord mode 4")
-- Octave doubling: 4 notes, 2 unique pitch classes -> TRI (2), NOT 7MA (3)
check(note_store.DetectChordMode({{pitch=60}, {pitch=64}, {pitch=72}, {pitch=76}}) == 2, "4 notes (2 unique pitch classes) is chord mode 2")

-- 5. DetectChordModeFromDegrees
io.write("\n-- 5. DetectChordModeFromDegrees\n")
check(note_store.DetectChordModeFromDegrees({1}) == 1, "Degree {1} is chord mode 1")
check(note_store.DetectChordModeFromDegrees({1, 3, 5}) == 2, "Degrees {1,3,5} is chord mode 2")
check(note_store.DetectChordModeFromDegrees({1, 3, 5, 7}) == 3, "Degrees {1,3,5,7} is chord mode 3")
check(note_store.DetectChordModeFromDegrees({1, 3, 5, 7, 9}) == 4, "Degrees {1,3,5,7,9} is chord mode 4")

-- 6. GroupNotesByBeat
io.write("\n-- 6. GroupNotesByBeat\n")
local group_notes = {
    {start_beat = 0, pitch = 60},
    {start_beat = 0, pitch = 64},
    {start_beat = 4, pitch = 67},
    {start_beat = 8, pitch = 72},
}
local groups = note_store.GroupNotesByBeat(group_notes, 4) -- resolution 4 -> step 1
local groups_count = 0
for _ in pairs(groups) do groups_count = groups_count + 1 end
check(groups_count == 3, "3 beat groups found")
check(#groups[0] == 2, "Beat 0 has 2 notes")
check(#groups[4] == 1, "Beat 4 has 1 note")
check(#groups[8] == 1, "Beat 8 has 1 note")

-- Test with different resolution
local groups_res2 = note_store.GroupNotesByBeat(group_notes, 2) -- resolution 2 -> step 2
-- Beat 0: 2 notes
-- Beat 4: 1 note
-- Beat 8: 1 note
-- All should still be in these groups since they are multiples of 2
check(#groups_res2[0] == 2, "Beat 0 (res 2) has 2 notes")
check(#groups_res2[4] == 1, "Beat 4 (res 2) has 1 note")
check(#groups_res2[8] == 1, "Beat 8 (res 2) has 1 note")

helpers.summary()
