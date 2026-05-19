-- Tests for midi.SendMidi, midi.TriggerChord, midi.AllNotesOff
-- Requires mock reaper.* globals installed by run.lua

local config = require("config")
local midi = require("core.midi")
local sequencer_store = require("state.sequencer")
local midi_store = require("state.midi")
local preferences_store = require("state.preferences")
local helpers = require("tests.helpers")
local check = helpers.check
local assert_eq = helpers.assert_eq

io.write("=== SendMidi / TriggerChord / AllNotesOff Tests ===\n")

-- Setup: init stores with clean state
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

local midi_state = {
    use_velocity = false,
    last_note_played = "None",
    active_note_draw_timer = 0,
    key_states = config.state.key_states,
    active_notes = {},
    mouse_pad_state = { active_degree = -1, midi_notes = {} },
}
midi_store.Init(midi_state)

-- Ensure deterministic velocity
midi_store.SetUseVelocity(false)

-- Set channel 1 explicitly
midi.SetMidiChannel(1)

-- Initialize preferences_store for TriggerChord reads
preferences_store.Init({
    root_index = 1,        -- C
    scale_index = 1,       -- Major
    octave = 4,
    chord_mode_index = 2,  -- Tri
})

-- ================================================================
-- SendMidi: Note-on
-- ================================================================
io.write("\n-- SendMidi note-on/off\n")

reaper.reset_all_calls()
midi.SendMidi(60, true, 100)
check(reaper.get_mock("StuffMIDIMessage").call_count == 1,
    "SendMidi: note-on makes 1 call")
local c1 = reaper.get_mock("StuffMIDIMessage").calls[1]
check(c1[1] == 0, "SendMidi: channel = midi_channel-1 = 0, got " .. tostring(c1[1]))
check(c1[2] == 0x90, "SendMidi: note-on message byte 0x90, got " .. tostring(c1[2]))
check(c1[3] == 60, "SendMidi: note 60, got " .. tostring(c1[3]))
check(c1[4] == 100, "SendMidi: velocity 100, got " .. tostring(c1[4]))

-- SendMidi: Note-off
reaper.reset_all_calls()
midi.SendMidi(60, false, 0)
local c2 = reaper.get_mock("StuffMIDIMessage").calls[1]
check(c2[2] == 0x80, "SendMidi: note-off message byte 0x80, got " .. tostring(c2[2]))
check(c2[3] == 60, "SendMidi: note-off note 60, got " .. tostring(c2[3]))
check(c2[4] == 0, "SendMidi: note-off velocity 0, got " .. tostring(c2[4]))

-- SendMidi: nil note is no-op
reaper.reset_all_calls()
midi.SendMidi(nil, true, 100)
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "SendMidi: nil note is no-op")

-- SendMidi: out-of-range note is no-op
reaper.reset_all_calls()
midi.SendMidi(-1, true, 100)
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "SendMidi: note -1 is no-op")

reaper.reset_all_calls()
midi.SendMidi(128, true, 100)
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "SendMidi: note 128 is no-op")

-- ================================================================
-- Ref-counted active notes
-- ================================================================
io.write("\n-- Ref-counted active notes\n")

reaper.reset_all_calls()
midi_store.ClearActiveNotes()

-- First note-on: count = 1
midi.SendMidi(60, true, 100)
check(midi_store.GetActiveNote(60) == 1,
    "Ref-count: first note-on count = 1, got " .. tostring(midi_store.GetActiveNote(60)))

-- Second note-on (duplicate): count = 2
midi.SendMidi(60, true, 100)
check(midi_store.GetActiveNote(60) == 2,
    "Ref-count: second note-on count = 2, got " .. tostring(midi_store.GetActiveNote(60)))

-- First note-off: count = 1
midi.SendMidi(60, false)
check(midi_store.GetActiveNote(60) == 1,
    "Ref-count: first note-off count = 1, got " .. tostring(midi_store.GetActiveNote(60)))

-- Second note-off: count = nil (freed)
midi.SendMidi(60, false)
check(midi_store.GetActiveNote(60) == nil,
    "Ref-count: second note-off count = nil, got " .. tostring(midi_store.GetActiveNote(60)))

-- Multiple notes tracked independently
reaper.reset_all_calls()
midi_store.ClearActiveNotes()
midi.SendMidi(60, true, 100)
midi.SendMidi(64, true, 100)
midi.SendMidi(67, true, 100)
check(midi_store.GetActiveNote(60) == 1, "Ref-count: multiple notes, 60 = 1")
check(midi_store.GetActiveNote(64) == 1, "Ref-count: multiple notes, 64 = 1")
check(midi_store.GetActiveNote(67) == 1, "Ref-count: multiple notes, 67 = 1")

-- ================================================================
-- Volume passthrough
-- ================================================================
io.write("\n-- Volume passthrough\n")

-- Half volume
reaper.reset_all_calls()
sequencer_store.SetVolume(50)
midi.SendMidi(60, true, 100)
local vol_call = reaper.get_mock("StuffMIDIMessage").calls[1]
check(vol_call[4] == 50,
    "Volume: 50% velocity = 50, got " .. tostring(vol_call[4]))

-- Full volume
reaper.reset_all_calls()
sequencer_store.SetVolume(100)
midi.SendMidi(60, true, 100)
local full_call = reaper.get_mock("StuffMIDIMessage").calls[1]
check(full_call[4] == 100,
    "Volume: 100% velocity = 100, got " .. tostring(full_call[4]))

-- Zero volume
reaper.reset_all_calls()
sequencer_store.SetVolume(0)
midi.SendMidi(60, true, 100)
local zero_call = reaper.get_mock("StuffMIDIMessage").calls[1]
check(zero_call[4] == 0,
    "Volume: 0% velocity = 0, got " .. tostring(zero_call[4]))

-- Restore default
sequencer_store.SetVolume(100)

-- ================================================================
-- TriggerChord: Tri (index 2)
-- ================================================================
io.write("\n-- TriggerChord: Tri\n")

-- Clean accumulated active_notes from previous sections (volume tests sent
-- extra note-ons that unbalance ref-counts). TriggerChord(false) below needs
-- clean 1→0 decrements to send note-offs.
midi_store.ClearActiveNotes()
preferences_store.SetChordModeIndex(2)
reaper.reset_all_calls()
local tri_notes = midi.TriggerChord(1, true)
check(#tri_notes == 3,
    "Tri: returns 3 notes, got " .. tostring(#tri_notes))
check(reaper.get_mock("StuffMIDIMessage").call_count == 3,
    "Tri: sends 3 note-ons, got " .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))
-- All should be note-on (0x90)
for i = 1, 3 do
    local call = reaper.get_mock("StuffMIDIMessage").calls[i]
    check(call[2] == 0x90,
        "Tri: call " .. i .. " is note-on (0x90), got " .. tostring(call[2]))
end

-- Tri with note-off
reaper.reset_all_calls()
midi.TriggerChord(1, false)
check(reaper.get_mock("StuffMIDIMessage").call_count == 3,
    "Tri: sends 3 note-offs, got " .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))
for i = 1, 3 do
    local call = reaper.get_mock("StuffMIDIMessage").calls[i]
    check(call[2] == 0x80,
        "Tri: call " .. i .. " is note-off (0x80), got " .. tostring(call[2]))
end

-- ================================================================
-- TriggerChord: 7ma (index 3)
-- ================================================================
io.write("\n-- TriggerChord: 7ma\n")

preferences_store.SetChordModeIndex(3)
reaper.reset_all_calls()
local seven_notes = midi.TriggerChord(1, true)
check(#seven_notes == 4,
    "7ma: returns 4 notes, got " .. tostring(#seven_notes))
check(reaper.get_mock("StuffMIDIMessage").call_count == 4,
    "7ma: sends 4 note-ons, got " .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))

-- ================================================================
-- TriggerChord: 9na (index 4)
-- ================================================================
io.write("\n-- TriggerChord: 9na\n")

preferences_store.SetChordModeIndex(4)
reaper.reset_all_calls()
local nine_notes = midi.TriggerChord(1, true)
check(#nine_notes == 5,
    "9na: returns 5 notes, got " .. tostring(#nine_notes))
check(reaper.get_mock("StuffMIDIMessage").call_count == 5,
    "9na: sends 5 note-ons, got " .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))

-- ================================================================
-- TriggerChord: Off (index 1) — single note
-- ================================================================
io.write("\n-- TriggerChord: Off\n")

preferences_store.SetChordModeIndex(1)
reaper.reset_all_calls()
local off_notes = midi.TriggerChord(1, true)
check(#off_notes == 1,
    "Off: returns 1 note, got " .. tostring(#off_notes))
check(reaper.get_mock("StuffMIDIMessage").call_count == 1,
    "Off: sends 1 note-on, got " .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))

-- Restore Tri for remaining tests
preferences_store.SetChordModeIndex(2)

-- ================================================================
-- TriggerChord: with velocity parameter
-- ================================================================
io.write("\n-- TriggerChord: velocity passthrough\n")

reaper.reset_all_calls()
midi.TriggerChord(1, true, nil, 75)
for i = 1, 3 do
    local call = reaper.get_mock("StuffMIDIMessage").calls[i]
    check(call[4] == 75,
        "TriggerChord: note " .. i .. " velocity 75, got " .. tostring(call[4]))
end

-- ================================================================
-- TriggerChord: with custom ctx table
-- ================================================================
io.write("\n-- TriggerChord: custom ctx\n")

local ctx = {
    root_index = 4,       -- E
    scale_index = 7,      -- Minor Natural
    chord_mode_index = 2, -- Tri
    octave = 3,
}
reaper.reset_all_calls()
local ctx_notes = midi.TriggerChord(1, true, ctx)
check(#ctx_notes == 3,
    "Ctx: returns 3 notes, got " .. tostring(#ctx_notes))
-- First note: root E(4), Minor Natural(7), degree 1, octave 3
-- (3+1)*12 + (4-1) + 0 + intervals[1] = 48 + 3 + 0 + 0 = 51 (E3)
check(ctx_notes[1] == 51,
    "Ctx: first note E3(51), got " .. tostring(ctx_notes[1]))

-- ================================================================
-- AllNotesOff
-- ================================================================
io.write("\n-- AllNotesOff\n")

-- Setup held notes in key_states and mouse_pad_state
local ks = midi_store.GetKeyStates()
-- Find first VKEY_MAP entry and add held notes
local first_vk = next(config.VKEY_MAP)
if first_vk then
    ks[first_vk].is_pressed = true
    ks[first_vk].midi_notes = {60, 64}
end

local mps = midi_store.GetMousePadState()
mps.active_degree = 3
mps.midi_notes = {67}

-- Set active notes ref counts
midi_store.ClearActiveNotes()
midi_store.SetActiveNote(60, 1)
midi_store.SetActiveNote(64, 1)
midi_store.SetActiveNote(67, 1)

reaper.reset_all_calls()
midi.AllNotesOff()

-- Call 1: CC 123
local cc123 = reaper.get_mock("StuffMIDIMessage").calls[1]
check(cc123[2] == 0xB0,
    "AllNotesOff: CC 123 message byte 0xB0, got " .. tostring(cc123[2]))
check(cc123[3] == 123,
    "AllNotesOff: CC 123 number 123, got " .. tostring(cc123[3]))
check(cc123[4] == 0,
    "AllNotesOff: CC 123 value 0, got " .. tostring(cc123[4]))

-- Note-offs for held notes (key_states first, then mouse_pad)
-- Key_states has {60, 64} → 2 note-offs
-- Mouse_pad has {67} → 1 note-off
-- Total: CC123 + 2 + 1 = 4 calls
local expected_total = 1 + 2 + 1
check(reaper.get_mock("StuffMIDIMessage").call_count == expected_total,
    "AllNotesOff: " .. expected_total .. " total calls, got "
    .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))

-- Note-off 60 (from key_states)
local noff60 = reaper.get_mock("StuffMIDIMessage").calls[2]
check(noff60[2] == 0x80 and noff60[3] == 60,
    "AllNotesOff: note-off 60, got msg=" .. tostring(noff60[2])
    .. " note=" .. tostring(noff60[3]))

-- Note-off 64 (from key_states)
local noff64 = reaper.get_mock("StuffMIDIMessage").calls[3]
check(noff64[2] == 0x80 and noff64[3] == 64,
    "AllNotesOff: note-off 64, got msg=" .. tostring(noff64[2])
    .. " note=" .. tostring(noff64[3]))

-- Note-off 67 (from mouse_pad_state)
local noff67 = reaper.get_mock("StuffMIDIMessage").calls[4]
check(noff67[2] == 0x80 and noff67[3] == 67,
    "AllNotesOff: note-off 67, got msg=" .. tostring(noff67[2])
    .. " note=" .. tostring(noff67[3]))

-- Active notes cleared
check(midi_store.GetActiveNote(60) == nil,
    "AllNotesOff: active 60 cleared")
check(midi_store.GetActiveNote(64) == nil,
    "AllNotesOff: active 64 cleared")
check(midi_store.GetActiveNote(67) == nil,
    "AllNotesOff: active 67 cleared")
