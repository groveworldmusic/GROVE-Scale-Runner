-- Mock reaper.* globals for testing
-- Provides 50+ stubs via make_mock_fn(name) factory + special handling for functions
-- that need specific return values. Exports reset_all_calls() and get_mock(name).
--
-- NOTE: Lua 5.4 does not support setting arbitrary properties (like .mock) on functions.
-- Mock call data is stored in _mock_storage[name] instead of fn.mock.
-- Use reaper.get_mock(name) to access track info.

local reaper = {}

-- Internal storage for mock call data, keyed by function name
local _mock_storage = {}
local _tracked_fns = {}  -- name → fn, used for reset_all_calls via _mock_storage

--- Factory: creates a tracked function stub that records calls
--- The generated function returns nil by default
--- Access mock data via reaper.get_mock(name) which returns { call_count, calls[] }
local function make_mock_fn(name)
    local track = { call_count = 0, calls = {} }
    _mock_storage[name] = track
    local fn = function(...)
        track.call_count = track.call_count + 1
        track.calls[track.call_count] = {...}
    end
    _tracked_fns[name] = fn
    return fn
end

-- ================================================================
-- Special-tracked functions (need specific return values)
-- ================================================================

-- StuffMIDIMessage: primary assertion target for MIDI calls
reaper.StuffMIDIMessage = make_mock_fn("StuffMIDIMessage")

-- JS_VKeys_Intercept: primary assertion target for keyboard intercept
reaper.JS_VKeys_Intercept = make_mock_fn("JS_VKeys_Intercept")

-- JS_VKeys_GetState: returns 256-byte string; tests control via _vkey_string
-- Needs manual tracking since it must return the dynamic _vkey_string
local _vkey_track = { call_count = 0, calls = {} }
_mock_storage["JS_VKeys_GetState"] = _vkey_track
reaper._vkey_string = string.rep("\0", 256)
reaper.JS_VKeys_GetState = function(state)
    _vkey_track.call_count = _vkey_track.call_count + 1
    _vkey_track.calls[_vkey_track.call_count] = {state}
    return reaper._vkey_string
end
_tracked_fns["JS_VKeys_GetState"] = reaper.JS_VKeys_GetState

-- time_precise: returns 0 by default; tests can override for throttle bypass
local _time_track = { call_count = 0, calls = {} }
_mock_storage["time_precise"] = _time_track
reaper.time_precise = function()
    _time_track.call_count = _time_track.call_count + 1
    _time_track.calls[_time_track.call_count] = {}
    return 0
end
_tracked_fns["time_precise"] = reaper.time_precise

-- GetPlayState: returns 0 (stopped) by default
local _play_track = { call_count = 0, calls = {} }
_mock_storage["GetPlayState"] = _play_track
reaper.GetPlayState = function()
    _play_track.call_count = _play_track.call_count + 1
    _play_track.calls[_play_track.call_count] = {}
    return 0
end
_tracked_fns["GetPlayState"] = reaper.GetPlayState

-- GetFocusedFX2: returns 0 (no FX focused) by default
local _fx_track = { call_count = 0, calls = {} }
_mock_storage["GetFocusedFX2"] = _fx_track
reaper.GetFocusedFX2 = function()
    _fx_track.call_count = _fx_track.call_count + 1
    _fx_track.calls[_fx_track.call_count] = {}
    return 0
end
_tracked_fns["GetFocusedFX2"] = reaper.GetFocusedFX2

-- ================================================================
-- Simple no-op stubs (tracked, return nil)
-- Created en masse via a helper to reduce boilerplate
-- ================================================================

local function stub(name)
    reaper[name] = make_mock_fn(name)
end

-- Window management
stub("JS_Window_Find")
stub("JS_Window_GetFocus")
stub("JS_Window_GetRect")
stub("JS_Window_GetClientSize")
stub("JS_Window_ClientToScreen")
stub("JS_Window_ScreenToClient")
stub("JS_Window_InvalidateRect")

-- Window message hooks
stub("JS_WindowMessage_Intercept")
stub("JS_WindowMessage_Peek")
stub("JS_WindowMessage_Release")

-- Composite / LICE drawing
stub("JS_Composite")
stub("JS_Composite_Unlink")
stub("JS_LICE_CreateBitmap")
stub("JS_LICE_DestroyBitmap")
stub("JS_LICE_Resize")
stub("JS_LICE_RoundRect")
stub("JS_LICE_FillRect")
stub("JS_LICE_FillCircle")
stub("JS_LICE_CreateFont")
stub("JS_LICE_DestroyFont")
stub("JS_LICE_SetFontFromGDI")

-- GDI font management
stub("JS_GDI_CreateFont")
stub("JS_GDI_DeleteObject")

-- Color
stub("ColorToNative")

-- Transport / tempo / time
stub("Master_GetTempo")
stub("GetPlayPosition2")
stub("TimeMap_timeToQN")
stub("TimeMap_QNToTime")
stub("TimeMap2_timeToBeats")
stub("GetCursorPosition")
stub("GetTransportHwnd")

-- Track management
stub("GetSelectedTrack")
stub("InsertTrackAtIndex")
stub("GetTrack")

-- MIDI item editing (for ExportToMidi)
stub("CreateNewMIDIItemInProj")
stub("GetActiveTake")
stub("MIDI_GetPPQPosFromProjQN")
stub("MIDI_InsertNote")
stub("MIDI_Sort")
stub("UpdateArrange")

-- Script lifecycle
stub("atexit")
stub("defer")

-- Ext state (persistence)
stub("GetExtState")
stub("SetExtState")

-- Path / directory
stub("GetResourcePath")
stub("RecursiveCreateDirectory")

-- UI helpers
stub("GetUserInputs")
stub("MB")
stub("ValidatePtr")

-- Undo blocks
stub("Undo_BeginBlock")
stub("Undo_EndBlock")
stub("GetMousePosition")
stub("GetThingFromPoint")

-- ================================================================
-- Helpers
-- ================================================================

--- Reset all mock call counters and call history across all tracked functions
function reaper.reset_all_calls()
    for _, track in pairs(_mock_storage) do
        track.call_count = 0
        track.calls = {}
    end
end

--- Get mock call data for a tracked function by name
--- Returns { call_count: number, calls: table[] } or nil
--- @param name string — function name (e.g. "StuffMIDIMessage")
function reaper.get_mock(name)
    return _mock_storage[name]
end

--- Get the Nth call arguments for a named mock function
--- @param name string — function name
--- @param n number — 1-based call index
--- @return table|nil — the arguments table {...} or nil
function reaper.get_mock_call(name, n)
    local m = _mock_storage[name]
    if m and m.calls[n] then
        return m.calls[n]
    end
    return nil
end

return reaper
