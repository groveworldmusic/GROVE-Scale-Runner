-- Tests for keyboard.Cleanup() — intercept guard and idempotency
-- Requires mock reaper.* globals installed by run.lua

-- Clear cached keyboard module to get a fresh is_intercepting=false closure
package.loaded["core.keyboard"] = nil

local config = require("config")
local keyboard = require("core.keyboard")
local midi_store = require("state.midi")
local helpers = require("tests.helpers")
local check = helpers.check

io.write("=== Keyboard Cleanup Tests ===\n")

-- Init midi_store for AllNotesOff (called by CheckFocus on focus loss paths,
-- though not exercised in these specific tests; keep init for safety)
midi_store.Init({
    use_velocity = false,
    last_note_played = "None",
    active_note_draw_timer = 0,
    key_states = config.state.key_states,
    active_notes = {},
    mouse_pad_state = { active_degree = -1, midi_notes = {} },
})

-- Count VKEY_MAP entries for assertions
local vkey_count = 0
for _ in pairs(config.VKEY_MAP) do vkey_count = vkey_count + 1 end

-- ================================================================
-- Test 1: Cleanup when not intercepting → no-op
-- ================================================================
io.write("\n-- Cleanup when not intercepting\n")

reaper.reset_all_calls()
keyboard.Cleanup()
check(reaper.get_mock("JS_VKeys_Intercept").call_count == 0,
    "Cleanup: no InterceptMappedKeys when is_intercepting=false")

-- ================================================================
-- Test 2: Activate intercept via CheckFocus, then Cleanup releases
-- ================================================================
io.write("\n-- Cleanup when intercepting (release all keys)\n")

-- We need CheckFocus to set is_intercepting = true.
-- Override mocks to make IsPluginOrScriptFocused return true.
-- Strategy: make JS_Window_GetFocus return the same handle as gfx.hwnd
-- and make time_precise bypass the 0.2s throttle.
gfx.hwnd = 12345
reaper.JS_Window_GetFocus = function() return 12345 end
reaper.time_precise = function() return 10 end

-- Call CheckFocus to activate intercept
reaper.reset_all_calls()
keyboard.CheckFocus()
-- is_intercepting should now be true; InterceptMappedKeys(true) should have been called
check(reaper.get_mock("JS_VKeys_Intercept").call_count == vkey_count,
    "CheckFocus: intercepted " .. vkey_count .. " keys, got "
    .. tostring(reaper.get_mock("JS_VKeys_Intercept").call_count))

-- Now test Cleanup: should release all keys
reaper.reset_all_calls()
keyboard.Cleanup()
-- Cleanup checks is_intercepting (now true), calls InterceptMappedKeys(false)
check(reaper.get_mock("JS_VKeys_Intercept").call_count == vkey_count,
    "Cleanup: released " .. vkey_count .. " keys, got "
    .. tostring(reaper.get_mock("JS_VKeys_Intercept").call_count))

-- ================================================================
-- Test 3: Second Cleanup call — is_intercepting still true
-- Note: keyboard.Cleanup() does NOT reset is_intercepting to false,
-- so the second call enters the if-branch again and calls
-- InterceptMappedKeys(false) a second time.
-- ================================================================
io.write("\n-- Second Cleanup call (still intercepting)\n")

keyboard.Cleanup()
check(reaper.get_mock("JS_VKeys_Intercept").call_count == vkey_count * 2,
    "Cleanup: second call also releases " .. vkey_count .. " keys, total "
    .. tostring(reaper.get_mock("JS_VKeys_Intercept").call_count))
