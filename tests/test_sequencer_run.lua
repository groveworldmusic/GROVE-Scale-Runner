-- Tests for sequencer.Run() — not-playing early return, REAPER sync measure advance,
-- same-measure no-op, empty progression Stop()
-- Requires mock reaper.* globals installed by run.lua

-- Clear cached midi and sequencer modules for fresh state
package.loaded["core.midi"] = nil
package.loaded["core.sequencer"] = nil

local config = require("config")
local sequencer = require("core.sequencer")
local seq_store = require("state.sequencer")
local progression = require("core.progression")
local helpers = require("tests.helpers")
local check = helpers.check

io.write("=== Sequencer Run Tests ===\n")

-- ================================================================
-- Setup: init stores with clean state
-- ================================================================

local midi_state = {
    use_velocity = false,
    last_note_played = "None",
    active_note_draw_timer = 0,
    key_states = config.state.key_states,
    active_notes = {},
    mouse_pad_state = { active_degree = -1, midi_notes = {} },
}
require("state.midi").Init(midi_state)

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

require("state.midi").SetUseVelocity(false)

config.state.root_index = 1
config.state.scale_index = 1
config.state.octave = 4
config.state.chord_mode_index = 2

local function slot(degree)
    return {
        degree = degree,
        root_index = 1,
        scale_index = 1,
        octave = 4,
        chord_mode_index = 2,
    }
end

-- ================================================================
-- Scenario 1: Not playing → Progress=0, no MIDI calls
-- ================================================================
io.write("\n-- Not playing\n")

seq_store.SetIsPlaying(false)
seq_store.SetProgress(0.75)

reaper.reset_all_calls()
sequencer.Run()

check(seq_store.GetProgress() == 0,
    "Not playing: Progress reset to 0, got " .. tostring(seq_store.GetProgress()))
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Not playing: no MIDI calls")

-- ================================================================
-- Scenarios 2-4: REAPER sync path
-- ================================================================
reaper.GetPlayState = function() return 1 end

local current_measure = 0.5
reaper.TimeMap2_timeToBeats = function(rev_id, time)
    return 0, current_measure, 0, 0
end

-- ================================================================
-- Scenario 2: Measure advance (cur_m=0, LastMeasure=-1 → trigger)
-- ================================================================
io.write("\n-- Measure advance: chord trigger\n")

seq_store.SetIsPlaying(true)
seq_store.SetLastMeasure(-1)
seq_store.SetCurrentStep(1)
seq_store.SetMidiNotes({})
progression.Add(1, slot(1))
progression.Add(3, slot(5))

reaper.reset_all_calls()
sequencer.Run()

check(reaper.get_mock("StuffMIDIMessage").call_count == 3,
    "Measure adv: 3 note-ons, got "
    .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))

for i = 1, 3 do
    local c = reaper.get_mock("StuffMIDIMessage").calls[i]
    check(c[2] == 0x90,
        "Measure adv: call " .. i .. " is note-on (0x90), got " .. tostring(c[2]))
end

check(seq_store.GetLastMeasure() == 0,
    "Measure adv: LastMeasure = 0")
check(seq_store.GetCurrentStep() == 1,
    "Measure adv: CurrentStep = 1")
check(seq_store.GetProgress() == 0.5,
    "Measure adv: Progress = 0.5")
check(#seq_store.GetMidiNotes() == 3,
    "Measure adv: MidiNotes has 3 held notes")

-- ================================================================
-- Scenario 3: Same measure → NO trigger
-- ================================================================
io.write("\n-- Same measure: no chord\n")

reaper.reset_all_calls()
sequencer.Run()

check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Same measure: no MIDI calls")
check(seq_store.GetLastMeasure() == 0,
    "Same measure: LastMeasure unchanged")
check(seq_store.GetCurrentStep() == 1,
    "Same measure: CurrentStep unchanged")
check(#seq_store.GetMidiNotes() == 3,
    "Same measure: MidiNotes still has 3 held notes")

-- ================================================================
-- Scenario 4: Empty progression → Stop()
-- ================================================================
io.write("\n-- Empty progression to Stop\n")

seq_store.ClearProgression()
current_measure = 2.5

reaper.reset_all_calls()
sequencer.Run()

check(reaper.get_mock("StuffMIDIMessage").call_count == 3,
    "Empty prog: 3 note-offs, got "
    .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))

for i = 1, 3 do
    local c = reaper.get_mock("StuffMIDIMessage").calls[i]
    check(c[2] == 0x80,
        "Empty prog: call " .. i .. " note-off, got " .. tostring(c[2]))
end

check(reaper.get_mock("StuffMIDIMessage").calls[1][3] == 60,
    "Empty prog: note 60")
check(reaper.get_mock("StuffMIDIMessage").calls[2][3] == 64,
    "Empty prog: note 64")
check(reaper.get_mock("StuffMIDIMessage").calls[3][3] == 67,
    "Empty prog: note 67")

check(seq_store.GetIsPlaying() == false,
    "Empty prog: IsPlaying = false")
check(seq_store.GetCurrentStep() == 0,
    "Empty prog: CurrentStep = 0")
check(seq_store.GetProgress() == 0,
    "Empty prog: Progress = 0")
check(seq_store.GetLastMeasure() == -1,
    "Empty prog: LastMeasure = -1")
check(#seq_store.GetMidiNotes() == 0,
    "Empty prog: MidiNotes cleared")

progression.Clear()
