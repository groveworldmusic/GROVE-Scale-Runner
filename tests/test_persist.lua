-- Tests for state.persist: Load, Save, coerce (via Load)
-- Scenarios P1-P6 per spec

local check = require("tests.helpers").check
local persist = require("state.persist")

io.write("=== persist ===\n")

-- Namespace constants (must match persist.lua internals)
local CANONICAL_NS = "GROVE_Scale_Runner"
local LEGACY_NS = "GROVE_FL_MIDI"

-- Inline mock: override reaper.GetExtState / SetExtState with local table
local extstate = {}
local orig_get = reaper.GetExtState
local orig_set = reaper.SetExtState

reaper.GetExtState = function(ns, key)
    if extstate[ns] and extstate[ns][key] ~= nil then
        return extstate[ns][key]
    end
    return ""
end

reaper.SetExtState = function(ns, key, val, persistent)
    extstate[ns] = extstate[ns] or {}
    extstate[ns][key] = val
end

-- P1: Load canonical key -> coerced value applied to state
local s = { root_index = 1, octave = 4 }
extstate = { [CANONICAL_NS] = { root_index = "3" } }
persist.Load(s)
check(s.root_index == 3, "P1: Load canonical root_index coerced to 3 (number)")
check(s.octave == 4, "P1: Load keeps hardcoded default for unprovided key")

-- P2: Load legacy fallback + migration to canonical
local s2 = { octave = 4 }
extstate = {
    [CANONICAL_NS] = { octave = "" },  -- canonical empty -> not found
    [LEGACY_NS]    = { octave = "5" },
}
persist.Load(s2)
check(s2.octave == 5, "P2: Load legacy fallback octave is 5")
check(extstate[CANONICAL_NS]["octave"] == "5", "P2: Load migrates legacy value to canonical SetExtState")

-- P3: Load missing key -> keep hardcoded default
local s3 = { root_index = 1 }
extstate = { [CANONICAL_NS] = {}, [LEGACY_NS] = {} }
persist.Load(s3)
check(s3.root_index == 1, "P3: Load missing key keeps hardcoded default 1")

-- P4: Save writes to canonical namespace with tostring'd value
extstate = {}
persist.Save("root_index", 3)
check(extstate[CANONICAL_NS]["root_index"] == "3", "P4: Save root_index 3 to canonical as '3'")
persist.Save("octave", 5)
check(extstate[CANONICAL_NS]["octave"] == "5", "P4: Save octave 5 to canonical as '5'")

-- P5: coerce numeric string -> number (tested indirectly via Load)
local s5 = { root_index = 1 }
extstate = { [CANONICAL_NS] = { root_index = "100" } }
persist.Load(s5)
check(s5.root_index == 100, "P5: Load coerces numeric string '100' -> number 100")

-- P6: coerce non-numeric string preserved as string (tested via Load with color_mode)
local s6 = { color_mode = "" }
extstate = { [CANONICAL_NS] = { color_mode = "grade" } }
persist.Load(s6)
check(s6.color_mode == "grade", "P6: Load preserves non-numeric string 'grade'")

-- coerce empty string: tonumber("") == nil -> coerce returns "" (preserved)
local s7 = { color_mode = "" }
extstate = { [CANONICAL_NS] = { color_mode = "" } }
persist.Load(s7)
-- get_canonical sees "" as "not found" and returns nil -> falls through to legacy
-- legacy also "" / not found -> keeps default
check(s7.color_mode == "", "P6: Load empty string keeps default ('' treated as missing)")

-- Restore original mocks
reaper.GetExtState = orig_get
reaper.SetExtState = orig_set
