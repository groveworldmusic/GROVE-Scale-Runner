-- Tests for midi.ExportToMidi() — progression export, track handling, MIDI note insertion
-- Requires mock reaper.* globals installed by run.lua

-- Clear cached midi module for fresh state
package.loaded["core.midi"] = nil

local config = require("config")
local midi = require("core.midi")
local sequencer_store = require("state.sequencer")
local progression = require("core.progression")
local helpers = require("tests.helpers")
local check = helpers.check

io.write("=== ExportToMidi Tests ===\n")

-- ================================================================
-- Setup: init stores with progression defaults
-- ================================================================

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
sequencer_store.Init(seq_state)

-- Helper: build a progression slot table
local function slot(degree)
    return {
        degree = degree,
        root_index = 1,   -- C
        scale_index = 1,  -- Major
        octave = 4,
        chord_mode_index = 2,  -- Tri (offsets {0,2,4} = 3 notes)
    }
end

-- Override reaper functions for deterministic export
-- Track existence: default = has track (tests override per scenario)
reaper.GetSelectedTrack = function() return 1 end  -- truthy = track exists
-- ValidatePtr must pass for the mock track handle
reaper.ValidatePtr = function(ptr, type_s) return true end

-- Cursor and time conversion
reaper.GetCursorPosition = function() return 10.0 end
reaper.TimeMap_timeToQN = function(pos) return pos end  -- identity
reaper.TimeMap_QNToTime = function(qn) return qn * 0.5 end

-- MIDI item creation
reaper.CreateNewMIDIItemInProj = function(track, start_t, end_t, is_new)
    return 1  -- item handle
end
reaper.GetActiveTake = function(item) return 1 end  -- take handle
reaper.MIDI_GetPPQPosFromProjQN = function(take, qn) return qn * 480 end

-- MIDI_InsertNote, MIDI_Sort, UpdateArrange, InsertTrackAtIndex, GetTrack
-- remain as tracked mocks (created by mock/reaper.lua stubs)

-- ================================================================
-- Scenario 1: Empty progression → return early, no MIDI insertion
-- ================================================================
io.write("\n-- Empty progression\n")

progression.Clear()
reaper.reset_all_calls()
midi.ExportToMidi()
check(reaper.get_mock("MIDI_InsertNote").call_count == 0,
    "Empty: MIDI_InsertNote not called")
check(reaper.get_mock("CreateNewMIDIItemInProj").call_count == 0,
    "Empty: CreateNewMIDIItemInProj not called (early return)")

-- ================================================================
-- Scenario 2: Single slot (Tri = 3 notes)
-- ================================================================
io.write("\n-- Single slot (Tri chord)\n")

reaper.GetSelectedTrack = function() return 1 end  -- has track
progression.Add(1, slot(1))  -- degree 1, C major Tri → C4(60) E4(64) G4(67)

reaper.reset_all_calls()
midi.ExportToMidi()

-- Tri chord = 3 notes per slot
check(reaper.get_mock("MIDI_InsertNote").call_count == 3,
    "Single slot: 3 MIDI_InsertNote calls, got "
    .. tostring(reaper.get_mock("MIDI_InsertNote").call_count))
check(reaper.get_mock("InsertTrackAtIndex").call_count == 0,
    "Single slot: InsertTrackAtIndex NOT called (existing track)")
check(reaper.get_mock("MIDI_Sort").call_count == 1,
    "Single slot: MIDI_Sort called once")
check(reaper.get_mock("UpdateArrange").call_count == 1,
    "Single slot: UpdateArrange called once")

-- Verify InsertNote call args (take, selected, muted, ppq_start, ppq_end, channel, note, vel, is_quantized)
-- take=1, selected=false, muted=false, vel=100, is_quantized=true
local c1 = reaper.get_mock("MIDI_InsertNote").calls[1]
check(c1[1] == 1, "Single slot: InsertNote take=1, got " .. tostring(c1[1]))
check(c1[4] == 4800, "Single slot: InsertNote ppq_start=4800, got " .. tostring(c1[4]))
check(c1[5] == 6720, "Single slot: InsertNote ppq_end=6720, got " .. tostring(c1[5]))
check(c1[8] == 100, "Single slot: InsertNote vel=100, got " .. tostring(c1[8]))
check(c1[9] == true, "Single slot: InsertNote is_quantized=true")

-- Notes should be C4(60), E4(64), G4(67) in some order (offsets {0,2,4} preserve order)
check(c1[7] == 60, "Single slot: note 1 = 60 (C4), got " .. tostring(c1[7]))
local c2 = reaper.get_mock("MIDI_InsertNote").calls[2]
check(c2[7] == 64, "Single slot: note 2 = 64 (E4), got " .. tostring(c2[7]))
local c3 = reaper.get_mock("MIDI_InsertNote").calls[3]
check(c3[7] == 67, "Single slot: note 3 = 67 (G4), got " .. tostring(c3[7]))

progression.Clear()

-- ================================================================
-- Scenario 3: Multiple slots (2 slots × Tri = 6 notes)
-- ================================================================
io.write("\n-- Multiple slots (2 × Tri = 6 notes)\n")

reaper.GetSelectedTrack = function() return 1 end  -- has track
progression.Add(1, slot(1))  -- degree 1, C major Tri
progression.Add(3, slot(5))  -- degree 5, G major Tri (count will stop at 3)

reaper.reset_all_calls()
midi.ExportToMidi()

-- 2 slots × 3 notes = 6 MIDI_InsertNote calls
check(reaper.get_mock("MIDI_InsertNote").call_count == 6,
    "Multi slot: 6 MIDI_InsertNote calls (2×3), got "
    .. tostring(reaper.get_mock("MIDI_InsertNote").call_count))
check(reaper.get_mock("MIDI_Sort").call_count == 1,
    "Multi slot: MIDI_Sort called once")
check(reaper.get_mock("UpdateArrange").call_count == 1,
    "Multi slot: UpdateArrange called once")

-- Verify slot 1 ppq range (i=1: q0=10.0, p0=4800, q0+4=14.0, p1=6720)
check(reaper.get_mock("MIDI_InsertNote").calls[1][4] == 4800,
    "Multi slot: slot1 ppq_start=4800")
check(reaper.get_mock("MIDI_InsertNote").calls[1][5] == 6720,
    "Multi slot: slot1 ppq_end=6720")

-- Verify slot 3 ppq range (i=3: q0=10.0+2*4=18.0, p0=8640, q0+4=22.0, p1=10560)
check(reaper.get_mock("MIDI_InsertNote").calls[4][4] == 8640,
    "Multi slot: slot3 ppq_start=8640, got " .. tostring(reaper.get_mock("MIDI_InsertNote").calls[4][4]))
check(reaper.get_mock("MIDI_InsertNote").calls[4][5] == 10560,
    "Multi slot: slot3 ppq_end=10560, got " .. tostring(reaper.get_mock("MIDI_InsertNote").calls[4][5]))

progression.Clear()

-- ================================================================
-- Scenario 4: No track → shows error MB and returns early
-- ================================================================
io.write("\n-- No track → early return with MB\n")

reaper.GetSelectedTrack = function() return nil end  -- no track selected
progression.Add(1, slot(1))

reaper.reset_all_calls()
midi.ExportToMidi()

-- Current behavior: shows error message and returns, does NOT auto-create track
check(reaper.get_mock("InsertTrackAtIndex").call_count == 0,
    "No track: InsertTrackAtIndex NOT called (MB error shown)")
check(reaper.get_mock("MIDI_InsertNote").call_count == 0,
    "No track: no notes inserted (early return)")
check(reaper.get_mock("MB").call_count >= 1,
    "No track: MB called with error message")

progression.Clear()

-- Restore defaults (optional, since each test file starts fresh)
reaper.GetSelectedTrack = function() return 1 end
