-- Unified test runner: mock installation, path setup, os.exit override, test discovery, aggregation
-- Usage: lua tests/run.lua  (from project root, or absolute)

-- Derive paths from script location using debug.getinfo
local info = debug.getinfo(1, "S")
local source = info.source or ""
local script_dir = source:match("@(.*[/\\])") or ""
script_dir = script_dir:gsub("\\", "/")

-- Derive project root: if script_dir ends with "tests/", strip it
local root_dir = script_dir:match("(.*/)tests/$") or ""

-- Set up package.path to find src/ modules and project-root modules
-- Pattern 1: src/?.lua    → require("core.midi"), require("state.*")
-- Pattern 2: ?.lua        → require("config"), require("tests.helpers")
package.path = root_dir .. "src/?.lua;" .. root_dir .. "?.lua;" .. package.path

-- Install mock globals BEFORE any require("core.*") call
-- Mocks are at tests/mock/reaper.lua and tests/mock/gfx.lua
_G.reaper = require("tests.mock.reaper")
_G.gfx = require("tests.mock.gfx")

-- Load helpers (shared counters survive across dofile calls)
local helpers = require("tests.helpers")

-- Discover test files (known list — add new test_*.lua here)
local test_files = {}
local test_names = {
    "test_midi.lua",
    "test_stores.lua",
    "test_progression.lua",
    "test_progression_undo.lua",
    "test_sendmidi.lua",
    "test_sequencer_stop.lua",
    "test_keyboard_intercept.lua",
    "test_keyboard_cleanup.lua",
    "test_keyboard_handle.lua",
    "test_keyboard_focus.lua",
    "test_toggle_island.lua",
    "test_export_midi.lua",
    "test_sequencer_run.lua",
    "snap-tests.lua",
    "undo-tests.lua",
    "test_api_guard.lua",
    "test_persist.lua",
    "test_preferences.lua",
    "test_preset_store.lua",
    "barrel-backward-compat.lua",
}
for _, name in ipairs(test_names) do
    local path = script_dir .. name
    local f = io.open(path, "r")
    if f then
        f:close()
        table.insert(test_files, path)
    end
end

if #test_files == 0 then
    io.write("ERROR: No test files found in " .. script_dir .. "\n")
    os.exit(1)
end

-- Override os.exit so individual test files cannot abort the runner
local original_exit = os.exit
os.exit = function() end

-- Run each test file via dofile for fresh execution
-- Reset mock call counters between files for clean state isolation
for _, file_path in ipairs(test_files) do
    local file_name = file_path:match("([^/]+)$")
    io.write("\n=== " .. file_name .. " ===\n")
    _G.reaper.reset_all_calls()
    dofile(file_path)
end

-- Restore real os.exit
os.exit = original_exit

-- Print aggregate summary and exit with proper code
helpers.summary()
