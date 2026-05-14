-- Tests for keyboard.InterceptMappedKeys(true/false)
-- Requires mock reaper.* globals installed by run.lua
-- Each test file clears the keyboard module cache for a fresh closure

-- Clear cached keyboard module to get a fresh is_intercepting closure
package.loaded["core.keyboard"] = nil

local config = require("config")
local keyboard = require("core.keyboard")
local helpers = require("tests.helpers")
local check = helpers.check

io.write("=== Keyboard Intercept Tests ===\n")

-- Count VKEY_MAP entries for assertion: 4 rows × 7 degrees = 28
local vkey_count = 0
for _ in pairs(config.VKEY_MAP) do vkey_count = vkey_count + 1 end

-- ================================================================
-- InterceptMappedKeys(true): intercept all mapped keys
-- ================================================================
io.write("\n-- InterceptMappedKeys(true)\n")

reaper.reset_all_calls()
keyboard.InterceptMappedKeys(true)

check(reaper.get_mock("JS_VKeys_Intercept").call_count == vkey_count,
    "Intercept(true): " .. vkey_count .. " calls, got "
    .. tostring(reaper.get_mock("JS_VKeys_Intercept").call_count))

-- Each call should have action=1
for i = 1, vkey_count do
    local call = reaper.get_mock("JS_VKeys_Intercept").calls[i]
    if call[2] ~= 1 then
        check(false, "Intercept(true): call " .. i .. " action=1, got " .. tostring(call[2]))
        break
    end
end
-- Bulk pass check
local all_action_1 = true
for i = 1, vkey_count do
    if reaper.get_mock("JS_VKeys_Intercept").calls[i][2] ~= 1 then
        all_action_1 = false
        break
    end
end
check(all_action_1, "Intercept(true): all calls have action=1")

-- Verify each VKEY_MAP entry was called (check a sample)
local call_keys = {}
for i = 1, vkey_count do
    call_keys[reaper.get_mock("JS_VKeys_Intercept").calls[i][1]] = true
end
local all_keys_intercepted = true
for kc, _ in pairs(config.VKEY_MAP) do
    if not call_keys[kc] then
        all_keys_intercepted = false
        break
    end
end
check(all_keys_intercepted, "Intercept(true): all VKEY_MAP entries intercepted")

-- ================================================================
-- InterceptMappedKeys(false): release all mapped keys
-- ================================================================
io.write("\n-- InterceptMappedKeys(false)\n")

reaper.reset_all_calls()
keyboard.InterceptMappedKeys(false)

check(reaper.get_mock("JS_VKeys_Intercept").call_count == vkey_count,
    "Intercept(false): " .. vkey_count .. " calls, got "
    .. tostring(reaper.get_mock("JS_VKeys_Intercept").call_count))

-- Each call should have action=-1
local all_action_neg1 = true
for i = 1, vkey_count do
    if reaper.get_mock("JS_VKeys_Intercept").calls[i][2] ~= -1 then
        all_action_neg1 = false
        break
    end
end
check(all_action_neg1, "Intercept(false): all calls have action=-1")
