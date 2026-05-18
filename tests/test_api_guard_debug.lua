-- Test api_guard.CheckAPI
local api_guard = require("core.api-guard")
local reaper = _G.reaper

print("Testing api_guard.CheckAPI...")

-- Check if it correctly identifies our mocked APIExists
local res = api_guard.CheckAPI("SomeAPI")
print("Result for SomeAPI: ", tostring(res))

if res == true then
    print("SUCCESS: CheckAPI returned true for mocked API")
else
    print("FAILURE: CheckAPI returned " .. tostring(res))
    os.exit(1)
end
