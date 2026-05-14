-- Tests for sequencer.Stop()
-- Requires mock reaper.* globals installed by run.lua

local config = require("config")
local sequencer = require("core.sequencer")
local sequencer_store = require("state.sequencer")
local midi_store = require("state.midi")
local helpers = require("tests.helpers")
local check = helpers.check

io.write("=== Sequencer Stop Tests ===\n")

-- Setup: init stores with clean state
local midi_state = {
    use_velocity = false,
    last_note_played = "None",
    active_note_draw_timer = 0,
    key_states = config.state.key_states,
    active_notes = {},
    mouse_pad_state = { active_degree = -1, midi_notes = {} },
}
midi_store.Init(midi_state)

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

-- ================================================================
-- Default state: Stop does nothing harmful when already stopped
-- ================================================================
io.write("\n-- Stop when already stopped (idempotent)\n")

reaper.reset_all_calls()
sequencer.Stop()
check(sequencer_store.GetIsPlaying() == false,
    "Stop: IsPlaying stays false")
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Stop: no MIDI calls when stopped with empty MidiNotes")

-- ================================================================
-- Stop resets all state fields
-- ================================================================
io.write("\n-- State field reset\n")

-- Set playback state as if sequencer was running
sequencer_store.SetIsPlaying(true)
sequencer_store.SetLastMeasure(2)
sequencer_store.SetCurrentStep(4)
sequencer_store.SetProgress(0.5)
sequencer_store.SetInternalBeats(8.0)
sequencer_store.SetLastTime(123.4)
-- MidiNotes with held notes
sequencer_store.SetMidiNotes({60, 64, 67})
-- Sync active_notes: SendMidi with force=true still requires the note to exist
-- in active_notes (checks `if cur then`). In real usage Run() populates both,
-- but in test we set MidiNotes directly.
midi_store.ClearActiveNotes()
midi_store.SetActiveNote(60, 1)
midi_store.SetActiveNote(64, 1)
midi_store.SetActiveNote(67, 1)

reaper.reset_all_calls()
sequencer.Stop()

check(sequencer_store.GetIsPlaying() == false,
    "Stop: IsPlaying = false, got " .. tostring(sequencer_store.GetIsPlaying()))
check(sequencer_store.GetLastMeasure() == -1,
    "Stop: LastMeasure = -1, got " .. tostring(sequencer_store.GetLastMeasure()))
check(sequencer_store.GetCurrentStep() == 0,
    "Stop: CurrentStep = 0, got " .. tostring(sequencer_store.GetCurrentStep()))
check(sequencer_store.GetProgress() == 0,
    "Stop: Progress = 0, got " .. tostring(sequencer_store.GetProgress()))
check(sequencer_store.GetInternalBeats() == 0,
    "Stop: InternalBeats = 0, got " .. tostring(sequencer_store.GetInternalBeats()))
check(sequencer_store.GetLastTime() == nil,
    "Stop: LastTime = nil, got " .. tostring(sequencer_store.GetLastTime()))
check(#sequencer_store.GetMidiNotes() == 0,
    "Stop: MidiNotes empty, got " .. tostring(#sequencer_store.GetMidiNotes()))

-- ================================================================
-- Stop sends note-off for each held note
-- ================================================================
io.write("\n-- Note-off for held notes\n")

-- Check that note-offs were sent for each MidiNotes entry (60, 64, 67)
-- sequencer.Stop calls midi.SendMidi(n, false) for each entry
-- midi.SendMidi calls reaper.StuffMIDIMessage(ch, 0x80, note, 0)
check(reaper.get_mock("StuffMIDIMessage").call_count == 3,
    "Stop: 3 note-off calls, got " .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))
-- Verify each call is a note-off
for i = 1, 3 do
    local call = reaper.get_mock("StuffMIDIMessage").calls[i]
    check(call[2] == 0x80,
        "Stop: call " .. i .. " is note-off (0x80), got " .. tostring(call[2]))
end
-- Verify correct notes in order (should be 60, 64, 67 since ipairs iterates in order)
check(reaper.get_mock("StuffMIDIMessage").calls[1][3] == 60,
    "Stop: note-off 60, got " .. tostring(reaper.get_mock("StuffMIDIMessage").calls[1][3]))
check(reaper.get_mock("StuffMIDIMessage").calls[2][3] == 64,
    "Stop: note-off 64, got " .. tostring(reaper.get_mock("StuffMIDIMessage").calls[2][3]))
check(reaper.get_mock("StuffMIDIMessage").calls[3][3] == 67,
    "Stop: note-off 67, got " .. tostring(reaper.get_mock("StuffMIDIMessage").calls[3][3]))

-- ================================================================
-- Stop with empty MidiNotes
-- ================================================================
io.write("\n-- Stop with empty MidiNotes\n")

sequencer_store.SetMidiNotes({})
sequencer_store.SetIsPlaying(true)

reaper.reset_all_calls()
sequencer.Stop()
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Stop: no MIDI calls with empty MidiNotes")
check(sequencer_store.GetIsPlaying() == false,
    "Stop: IsPlaying false after stopped")
