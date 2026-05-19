-- Tests for keyboard.HandleKeyboard() — key-down/up dispatch, unmapped keys
-- Requires mock reaper.* globals installed by run.lua

-- Clear cached keyboard module to get a fresh is_intercepting=false closure
package.loaded["core.keyboard"] = nil

local config = require("config")
local keyboard = require("core.keyboard")
local midi_store = require("state.midi")
local preferences_store = require("state.preferences")
local helpers = require("tests.helpers")
local check = helpers.check

io.write("=== Keyboard HandleKeyboard Tests ===\n")

-- ================================================================
-- Setup: init stores, configure state, activate intercept
-- ================================================================

-- Init preferences_store: keyboard.lua reads chord/root/scale/octave from here,
-- not from config.state.*. Without this, defaults (chord_mode_index=1=Off) apply.
preferences_store.Init({
    root_index = 1,         -- C
    scale_index = 1,        -- Major
    octave = 4,
    chord_mode_index = 2,   -- Tri
    inversion_index = 1,
    inversion_direction = 0,
    subdivision_index = 1,
})

-- Init midi_store with populated key_states from config
midi_store.Init({
    use_velocity = false,
    last_note_played = "None",
    active_note_draw_timer = 0,
    key_states = config.state.key_states,
    active_notes = {},
    mouse_pad_state = { active_degree = -1, midi_notes = {} },
})

-- Deterministic velocity
midi_store.SetUseVelocity(false)

-- Config.state remnant keys for TriggerChord
config.state.root_index = 1       -- C
config.state.scale_index = 1      -- Major
config.state.octave = 4
config.state.chord_mode_index = 2 -- Tri

-- Count VKEY_MAP entries
local vkey_count = 0
for _ in pairs(config.VKEY_MAP) do vkey_count = vkey_count + 1 end

-- ================================================================
-- Test 1: HandleKeyboard early return when not intercepting
-- ================================================================
io.write("\n-- HandleKeyboard when not intercepting\n")

-- is_intercepting starts false in the fresh module
reaper.reset_all_calls()
keyboard.HandleKeyboard()
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "HandleKeyboard: no calls when is_intercepting=false")

-- ================================================================
-- Activate intercept via CheckFocus
-- ================================================================
io.write("\n-- Activate intercept\n")

gfx.hwnd = 12345
reaper.JS_Window_GetFocus = function() return 12345 end
reaper.time_precise = function() return 10 end

reaper.reset_all_calls()
keyboard.CheckFocus()
check(reaper.get_mock("JS_VKeys_Intercept").call_count == vkey_count,
    "CheckFocus: intercepted " .. vkey_count .. " keys")

-- ================================================================
-- Test 2: Key-down triggers note-on via TriggerChord
-- ================================================================
io.write("\n-- Key-down triggers note-on\n")

-- VK code 0x31 = '1' = degree 1, oct +1 → actual octave = 5
-- C Major, degree 1, octave 5: C5(72), E5(76), G5(79)
local vk_1 = 0x31

-- Set byte at position 0x31 to non-zero (key pressed)
local vks = string.rep("\0", 256)
vks = vks:sub(1, vk_1 - 1) .. "\x01" .. vks:sub(vk_1 + 1)
reaper._vkey_string = vks

reaper.reset_all_calls()
keyboard.HandleKeyboard()

-- Should trigger Tri chord: 3 note-ons
check(reaper.get_mock("StuffMIDIMessage").call_count == 3,
    "Key-down: 3 note-ons (Tri chord), got "
    .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))

-- Check each note-on
local c1 = reaper.get_mock("StuffMIDIMessage").calls[1]
local c2 = reaper.get_mock("StuffMIDIMessage").calls[2]
local c3 = reaper.get_mock("StuffMIDIMessage").calls[3]
check(c1[2] == 0x90, "Key-down: call 1 is note-on (0x90)")
check(c2[2] == 0x90, "Key-down: call 2 is note-on (0x90)")
check(c3[2] == 0x90, "Key-down: call 3 is note-on (0x90)")

-- Notes should be C5(72), E5(76), G5(79) for C Major Tri at octave 5
check(c1[3] == 72 or c2[3] == 72 or c3[3] == 72,
    "Key-down: one note is C5(72)")
check(c1[3] == 76 or c2[3] == 76 or c3[3] == 76,
    "Key-down: one note is E5(76)")
check(c1[3] == 79 or c2[3] == 79 or c3[3] == 79,
    "Key-down: one note is G5(79)")

-- Velocity should be 100 (deterministic, no humanization)
check(c1[4] == 100 and c2[4] == 100 and c3[4] == 100,
    "Key-down: all notes velocity 100")

-- Key states should show the key as pressed with midi_notes
local ks = midi_store.GetKeyStates()
check(ks[vk_1] ~= nil, "Key-down: key state entry exists for 0x31")
check(ks[vk_1].is_pressed == true, "Key-down: key is_pressed = true")
check(#ks[vk_1].midi_notes == 3, "Key-down: 3 midi_notes recorded, got "
    .. tostring(#ks[vk_1].midi_notes))

-- ================================================================
-- Test 3: Same key still down — no extra calls
-- ================================================================
io.write("\n-- Same key still down (no repeat)\n")

reaper.reset_all_calls()
keyboard.HandleKeyboard()
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Key-held: no new MIDI calls while key still down")

-- ================================================================
-- Test 4: Key-up sends note-off for all chord notes
-- ================================================================
io.write("\n-- Key-up sends note-off\n")

-- Clear the byte (key released)
reaper._vkey_string = string.rep("\0", 256)

reaper.reset_all_calls()
-- skip_poll=true from "key-held" test (no transitions); first call clears it
keyboard.HandleKeyboard()
-- Second call actually processes the key-up
keyboard.HandleKeyboard()

-- Should send note-off for each chord note (3 notes)
check(reaper.get_mock("StuffMIDIMessage").call_count == 3,
    "Key-up: 3 note-offs, got "
    .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))

-- All should be note-off (0x80)
for i = 1, 3 do
    local call = reaper.get_mock("StuffMIDIMessage").calls[i]
    check(call[2] == 0x80,
        "Key-up: call " .. i .. " is note-off (0x80), got " .. tostring(call[2]))
end

-- Key state should be cleared
check(ks[vk_1].is_pressed == false, "Key-up: key is_pressed = false")
check(#ks[vk_1].midi_notes == 0, "Key-up: midi_notes cleared")

-- ================================================================
-- Test 5: Unmapped keys ignored
-- ================================================================
io.write("\n-- Unmapped keys ignored\n")

-- Set byte at a non-VKEY_MAP position (0x01 = non-printable, not in VKEY_MAP)
local unmapped_vks = string.rep("\0", 256)
unmapped_vks = unmapped_vks:sub(1, 0) .. "\x01" .. unmapped_vks:sub(2)
-- Note: sub(1, 0) returns empty string in Lua. So this sets byte 1 to 0x01.
reaper._vkey_string = unmapped_vks

reaper.reset_all_calls()

-- Also need to reset all key states to unpressed to ensure no stale state
-- from previous tests
local all_ks = midi_store.GetKeyStates()
for _, state in pairs(all_ks) do
    state.is_pressed = false
    state.midi_notes = {}
end

keyboard.HandleKeyboard()
check(reaper.get_mock("StuffMIDIMessage").call_count == 0,
    "Unmapped: no MIDI calls for non-VKEY_MAP byte")

-- ================================================================
-- Test 6: Multiple keys simultaneously
-- ================================================================
io.write("\n-- Multiple keys simultaneously\n")

-- Set keys 0x31 (deg=1, oct+1) and 0x32 (deg=2, oct+1)
local multi_vks = string.rep("\0", 256)
multi_vks = multi_vks:sub(1, 0x30) .. "\x01" .. multi_vks:sub(0x32)  -- 0x31 pressed
multi_vks = multi_vks:sub(1, 0x31) .. "\x01" .. multi_vks:sub(0x33)  -- 0x32 pressed
reaper._vkey_string = multi_vks

reaper.reset_all_calls()
-- skip_poll=true from previous test; first call clears it
keyboard.HandleKeyboard()
-- Second call processes the multi-key press
keyboard.HandleKeyboard()

-- Each key triggers a Tri chord (3 notes each) = 6 total
check(reaper.get_mock("StuffMIDIMessage").call_count == 6,
    "Multi-key: 6 note-ons (2 keys × 3 notes), got "
    .. tostring(reaper.get_mock("StuffMIDIMessage").call_count))

-- All should be note-on
for i = 1, 6 do
    local call = reaper.get_mock("StuffMIDIMessage").calls[i]
    check(call[2] == 0x90,
        "Multi-key: call " .. i .. " is note-on (0x90), got " .. tostring(call[2]))
end
