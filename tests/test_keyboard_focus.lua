-- Tests for keyboard.CheckFocus() — throttle, focus gain/loss, AllNotesOff on blur
-- Requires mock reaper.* globals installed by run.lua
-- Tests run WITHOUT resetting mocks between scenarios to show cumulative intercept count

-- Clear cached keyboard module to get fresh is_intercepting=false, last_focus_check=0
package.loaded["core.keyboard"] = nil
package.loaded["core.midi"] = nil

local config = require("config")
local keyboard = require("core.keyboard")
local midi = require("core.midi")
local midi_store = require("state.midi")
local sequencer_store = require("state.sequencer")
local helpers = require("tests.helpers")
local check = helpers.check

io.write("=== Keyboard CheckFocus Tests ===\n")

-- ================================================================
-- Setup: init stores, configure state
-- ================================================================

midi_store.Init({
    use_velocity = false,
    last_note_played = "None",
    active_note_draw_timer = 0,
    key_states = config.state.key_states,
    active_notes = {},
    mouse_pad_state = { active_degree = -1, midi_notes = {} },
})

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

-- Clear any stale key state subfields from previous test files (shared reference)
local all_ks = midi_store.GetKeyStates()
for _, state in pairs(all_ks) do
    state.is_pressed = false
    state.midi_notes = {}
end

-- Deterministic velocity
midi_store.SetUseVelocity(false)

-- Config.state remnant keys (for TriggerChord — not needed for CheckFocus itself,
-- but AllNotesOff calls midi.SendMidi which reads sequencer volume)
config.state.root_index = 1
config.state.scale_index = 1
config.state.octave = 4
config.state.chord_mode_index = 2

-- Count VKEY_MAP entries for intercept assertions
local vkey_count = 0
for _ in pairs(config.VKEY_MAP) do vkey_count = vkey_count + 1 end

-- ================================================================
-- Mock overrides for focus detection
-- ================================================================

-- gfx.hwnd used by IsPluginOrScriptFocused for script-window focus check
gfx.hwnd = 12345

-- Default: unfocused
reaper.GetFocusedFX2 = function() return 0 end
reaper.JS_Window_GetFocus = function() return nil end

-- Frozen time progression for throttle control
local frozen_time = 1000.0
reaper.time_precise = function() return frozen_time end

-- Reset ALL mock call counters — all scenarios will accumulate from here
reaper.reset_all_calls()

-- ================================================================
-- Scenario 1: First call at T=1000 → runs (no prior throttle, last_focus_check=0)
--             Unfocused → no intercept, no allnotesoff
-- ================================================================
io.write("\n-- Scenario 1: First call, unfocused\n")

keyboard.CheckFocus()
check(reaper.get_mock("JS_VKeys_Intercept").call_count == 0,
    "Sc1: no intercept calls (unfocused)")
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Sc1: no MIDI calls")

-- ================================================================
-- Scenario 2: Second call at same T=1000 → throttled (gap < 0.2s)
-- ================================================================
io.write("\n-- Scenario 2: Same time, throttled\n")

keyboard.CheckFocus()
check(reaper.get_mock("JS_VKeys_Intercept").call_count == 0,
    "Sc2: no intercept calls (throttled)")
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Sc2: no MIDI calls")

-- ================================================================
-- Scenario 3: Advance to T=1000.5 → gap > 0.2s → runs, but unfocused → no-op
-- ================================================================
io.write("\n-- Scenario 3: Time advanced, still unfocused\n")

frozen_time = 1000.5
keyboard.CheckFocus()
check(reaper.get_mock("JS_VKeys_Intercept").call_count == 0,
    "Sc3: no intercept calls (unfocused, gap>0.2s)")
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Sc3: no MIDI calls")

-- ================================================================
-- Scenario 4: Gain focus → intercept 28 keys
-- ================================================================
io.write("\n-- Scenario 4: Focus gained\n")

-- Make IsPluginOrScriptFocused return true (script window focused)
reaper.JS_Window_GetFocus = function() return gfx.hwnd end
frozen_time = 1002.0  -- advance time past throttle

keyboard.CheckFocus()
check(reaper.get_mock("JS_VKeys_Intercept").call_count == vkey_count,
    "Sc4: intercepted " .. vkey_count .. " keys, got "
    .. tostring(reaper.get_mock("JS_VKeys_Intercept").call_count))
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Sc4: no MIDI calls (focus gain only intercepts)")

-- ================================================================
-- Scenario 4b: Stay focused + advance time → no-op (already intercepting + focused)
-- ================================================================
io.write("\n-- Scenario 4b: Already intercepting + focused, no-op\n")

frozen_time = 1004.0  -- advance time past throttle
keyboard.CheckFocus()
check(reaper.get_mock("JS_VKeys_Intercept").call_count == vkey_count,
    "Sc4b: no new intercept calls, still " .. vkey_count)
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Sc4b: no MIDI calls (stable state)")

-- ================================================================
-- Scenario 5: Lose focus → release 28 keys (total 56) + AllNotesOff
-- ================================================================
io.write("\n-- Scenario 5: Focus lost (release + AllNotesOff)\n")

-- Set up held notes so AllNotesOff has something to release
local ks = midi_store.GetKeyStates()
local first_vk = next(config.VKEY_MAP)
if first_vk then
    ks[first_vk].is_pressed = true
    ks[first_vk].midi_notes = {60, 64, 67}
end

local mps = midi_store.GetMousePadState()
mps.active_degree = 3
mps.midi_notes = {72}

-- Set active notes ref counts for clearing assertion
midi_store.ClearActiveNotes()
midi_store.SetActiveNote(60, 1)
midi_store.SetActiveNote(64, 1)
midi_store.SetActiveNote(67, 1)
midi_store.SetActiveNote(72, 1)

-- Lose focus: unfocus our script window AND ensure no plugin is focused
reaper.JS_Window_GetFocus = function() return nil end
reaper.GetFocusedFX2 = function() return 0 end
frozen_time = 1005.0  -- advance time past throttle

keyboard.CheckFocus()
check(reaper.get_mock("JS_VKeys_Intercept").call_count == vkey_count * 2,
    "Sc5: total intercept calls = " .. (vkey_count * 2) .. " (28+28), got "
    .. tostring(reaper.get_mock("JS_VKeys_Intercept").call_count))

-- AllNotesOff sends: CC123 + key_state note-offs (3) + mouse_pad note-offs (1) = 5
local expected_midi = 1 + 3 + 1
check(reaper.get_mock("StuffMIDIMessage").call_count == expected_midi,
    "Sc5: AllNotesOff sent " .. expected_midi .. " MIDI messages, got "
    .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))

-- Verify CC123 is first call (message byte 0xB0, CC number 123)
local cc123 = reaper.get_mock("StuffMIDIMessage").calls[1]
check(cc123[2] == 0xB0,
    "Sc5: CC123 message byte 0xB0, got " .. tostring(cc123[2]))
check(cc123[3] == 123,
    "Sc5: CC123 number 123, got " .. tostring(cc123[3]))

-- Verify note-offs for key_state notes (calls 2, 3, 4 should be 60, 64, 67)
local off60 = reaper.get_mock("StuffMIDIMessage").calls[2]
check(off60[2] == 0x80 and off60[3] == 60,
    "Sc5: note-off 60, msg=" .. tostring(off60[2]) .. " note=" .. tostring(off60[3]))

local off64 = reaper.get_mock("StuffMIDIMessage").calls[3]
check(off64[2] == 0x80 and off64[3] == 64,
    "Sc5: note-off 64, msg=" .. tostring(off64[2]) .. " note=" .. tostring(off64[3]))

local off67 = reaper.get_mock("StuffMIDIMessage").calls[4]
check(off67[2] == 0x80 and off67[3] == 67,
    "Sc5: note-off 67, msg=" .. tostring(off67[2]) .. " note=" .. tostring(off67[3]))

-- Verify note-off for mouse_pad note (call 5 = 72)
local off72 = reaper.get_mock("StuffMIDIMessage").calls[5]
check(off72[2] == 0x80 and off72[3] == 72,
    "Sc5: note-off 72, msg=" .. tostring(off72[2]) .. " note=" .. tostring(off72[3]))

-- Verify active notes were cleared
check(midi_store.GetActiveNote(60) == nil, "Sc5: active note 60 cleared")
check(midi_store.GetActiveNote(64) == nil, "Sc5: active note 64 cleared")
check(midi_store.GetActiveNote(67) == nil, "Sc5: active note 67 cleared")
check(midi_store.GetActiveNote(72) == nil, "Sc5: active note 72 cleared")

-- Verify key state was cleared
if first_vk then
    check(ks[first_vk].is_pressed == false, "Sc5: key state is_pressed cleared")
    check(#ks[first_vk].midi_notes == 0, "Sc5: key state midi_notes cleared")
end

-- Verify mouse pad state was cleared
check(mps.active_degree == -1, "Sc5: mouse pad active_degree = -1")
check(#mps.midi_notes == 0, "Sc5: mouse pad midi_notes cleared")
