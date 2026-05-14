-- Tests for core.api-guard: CheckAPI, AssertAPIs, ClampIndex
-- Scenarios AG1-AG10 per spec

local check = require("tests.helpers").check
local api_guard = require("core.api-guard")

io.write("=== api-guard ===\n")

-- Save original for restoration
local orig_exists = reaper.APIExists

-- AG1: CheckAPI with APIExists available delegates to APIExists
reaper.APIExists = function(name) return name ~= "NonexistentFunc" end
check(api_guard.CheckAPI("JS_VKeys_GetState") == true, "AG1: CheckAPI existing returns true")
check(api_guard.CheckAPI("NonexistentFunc") == false, "AG1: CheckAPI missing returns false")

-- AG2: CheckAPI fallback when APIExists is nil
reaper.APIExists = nil
check(api_guard.CheckAPI("StuffMIDIMessage") == true, "AG2: CheckAPI fallback existing returns true")
-- NonexistentFunc doesn't exist on reaper, so type is nil not "function"
check(api_guard.CheckAPI("NonexistentFunc") == false, "AG2: CheckAPI fallback missing returns false")

-- AG3: CheckAPI returns false for missing API in APIExists path (explicit)
reaper.APIExists = function(name) return false end
check(api_guard.CheckAPI("Anything") == false, "AG3: CheckAPI returns false with APIExists false")

-- AG4: AssertAPIs missing API returns false and calls reaper.MB
reaper.APIExists = function(name) return name ~= "NonexistentFunc" end
reaper.reset_all_calls()
local result4 = api_guard.AssertAPIs({ NonexistentFunc = "Missing!" })
check(result4 == false, "AG4: AssertAPIs missing returns false")
check(reaper.get_mock("MB").call_count >= 1, "AG4: AssertAPIs calls reaper.MB on missing")

-- AG5: AssertAPIs all present returns true, no MB call
reaper.reset_all_calls()
local result5 = api_guard.AssertAPIs({ JS_VKeys_GetState = "VKeys" })
check(result5 == true, "AG5: AssertAPIs all present returns true")
check(reaper.get_mock("MB").call_count == 0, "AG5: AssertAPIs does not call reaper.MB")

-- AG6: AssertAPIs empty table returns true
reaper.reset_all_calls()
local result6 = api_guard.AssertAPIs({})
check(result6 == true, "AG6: AssertAPIs empty table returns true")
check(reaper.get_mock("MB").call_count == 0, "AG6: AssertAPIs empty no MB call")

-- AG7: ClampIndex range clamping
check(api_guard.ClampIndex(5, 1, 10) == 5, "AG7: ClampIndex normal returns 5")
check(api_guard.ClampIndex(15, 1, 10) == 10, "AG7: ClampIndex max clamp returns 10")
check(api_guard.ClampIndex(-5, 1, 10) == 1, "AG7: ClampIndex min clamp returns 1")

-- AG8: ClampIndex floors before clamping
check(api_guard.ClampIndex(2.9, 1, 5) == 2, "AG8: ClampIndex floor 2.9 -> 2")
check(api_guard.ClampIndex(0.5, 1, 5) == 1, "AG8: ClampIndex floor 0.5 -> 0, clamp to 1")

-- AG9: ClampIndex nil value defaults to min (1)
check(api_guard.ClampIndex(nil) == 1, "AG9: ClampIndex nil value returns min 1")
check(api_guard.ClampIndex(3, nil, nil) == 1, "AG9: ClampIndex nil min/max defaults to 1")

-- AG10: ClampIndex degenerate min==max returns that value
check(api_guard.ClampIndex(100, 5, 5) == 5, "AG10: ClampIndex min==max returns 5")

-- Edge: degenerate min>max returns a number (code returns min despite max<min)
check(api_guard.ClampIndex(5, 10, 5) ~= nil, "ClampIndex min>max returns a number")

-- Restore
reaper.APIExists = orig_exists
