-- Tests for state.preferences: Init, SyncFromState,
-- 7 getter/setter round-trips, TickSaveDebounce
-- Scenarios PR1-PR6 per spec
--
-- Requires package.loaded cache clearing for fresh module state

local check = require("tests.helpers").check

io.write("=== preferences ===\n")

-- ============================================================
-- PR1: 7 getter/setter round-trips
-- ============================================================
io.write("-- PR1: round-trips\n")
package.loaded["state.persist"] = nil
package.loaded["state.preferences"] = nil
local prefs = require("state.preferences")

-- Defaults
check(prefs.GetRootIndex() == 1, "PR1: RootIndex default 1")
check(prefs.GetScaleIndex() == 1, "PR1: ScaleIndex default 1")
check(prefs.GetOctave() == 4, "PR1: Octave default 4")
check(prefs.GetChordModeIndex() == 1, "PR1: ChordModeIndex default 1")
check(prefs.GetInversionIndex() == 1, "PR1: InversionIndex default 1")
check(prefs.GetInversionDirection() == 0, "PR1: InversionDirection default 0")
check(prefs.GetSubdivisionIndex() == 1, "PR1: SubdivisionIndex default 1")

-- Set/Get round-trips
prefs.SetRootIndex(5)
check(prefs.GetRootIndex() == 5, "PR1: RootIndex round-trip 5")

prefs.SetScaleIndex(3)
check(prefs.GetScaleIndex() == 3, "PR1: ScaleIndex round-trip 3")

prefs.SetOctave(2)
check(prefs.GetOctave() == 2, "PR1: Octave round-trip 2")

prefs.SetChordModeIndex(4)
check(prefs.GetChordModeIndex() == 4, "PR1: ChordModeIndex round-trip 4")

prefs.SetInversionIndex(3)
check(prefs.GetInversionIndex() == 3, "PR1: InversionIndex round-trip 3")

prefs.SetInversionDirection(1)
check(prefs.GetInversionDirection() == 1, "PR1: InversionDirection round-trip 1")

prefs.SetSubdivisionIndex(4)
check(prefs.GetSubdivisionIndex() == 4, "PR1: SubdivisionIndex round-trip 4")

-- ============================================================
-- PR2: Init with defaults table
-- ============================================================
io.write("-- PR2: Init with defaults\n")
package.loaded["state.persist"] = nil
package.loaded["state.preferences"] = nil
prefs = require("state.preferences")
prefs.Init({ root_index = 3, octave = 2 })
check(prefs.GetRootIndex() == 3, "PR2: Init root_index 3")
check(prefs.GetOctave() == 2, "PR2: Init octave 2")
check(prefs.GetScaleIndex() == 1, "PR2: Init unprovided key keeps module default")

-- ============================================================
-- PR3: Init with empty table keeps all module defaults
-- ============================================================
io.write("-- PR3: Init({}) keeps defaults\n")
package.loaded["state.persist"] = nil
package.loaded["state.preferences"] = nil
prefs = require("state.preferences")
prefs.Init({})
check(prefs.GetRootIndex() == 1, "PR3: Init empty RootIndex default 1")
check(prefs.GetScaleIndex() == 1, "PR3: Init empty ScaleIndex default 1")
check(prefs.GetOctave() == 4, "PR3: Init empty Octave default 4")
check(prefs.GetChordModeIndex() == 1, "PR3: Init empty ChordModeIndex default 1")
check(prefs.GetInversionIndex() == 1, "PR3: Init empty InversionIndex default 1")
check(prefs.GetInversionDirection() == 0, "PR3: Init empty InversionDirection default 0")
check(prefs.GetSubdivisionIndex() == 1, "PR3: Init empty SubdivisionIndex default 1")

-- ============================================================
-- PR4: SyncFromState reads fields from state table
-- ============================================================
io.write("-- PR4: SyncFromState\n")
package.loaded["state.persist"] = nil
package.loaded["state.preferences"] = nil
prefs = require("state.preferences")
prefs.SyncFromState({ root_index = 7, octave = 5 })
check(prefs.GetRootIndex() == 7, "PR4: SyncFromState root_index 7")
check(prefs.GetOctave() == 5, "PR4: SyncFromState octave 5")
check(prefs.GetScaleIndex() == 1, "PR4: SyncFromState unprovided key unchanged")

-- ============================================================
-- PR5: TickSaveDebounce flushes pending saves (7 SetExtState calls)
-- ============================================================
io.write("-- PR5: TickSaveDebounce flush\n")
reaper.reset_all_calls()
package.loaded["state.persist"] = nil
package.loaded["state.preferences"] = nil
prefs = require("state.preferences")
reaper.reset_all_calls()

-- Call all 7 setters (each marks save_pending = true)
prefs.SetRootIndex(3)
prefs.SetScaleIndex(2)
prefs.SetOctave(4)
prefs.SetChordModeIndex(2)
prefs.SetInversionIndex(1)
prefs.SetInversionDirection(0)
prefs.SetSubdivisionIndex(3)

-- First TickSaveDebounce flushes all 7 keys via persist.Save -> SetExtState
prefs.TickSaveDebounce()
check(reaper.get_mock("SetExtState").call_count == 7,
    "PR5: TickSaveDebounce flushes 7 SetExtState calls")

-- Second TickSaveDebounce: save_pending already false -> no-op
prefs.TickSaveDebounce()
check(reaper.get_mock("SetExtState").call_count == 7,
    "PR5: TickSaveDebounce second call no-op")

-- ============================================================
-- PR6: TickSaveDebounce no-op when no setter called
-- ============================================================
io.write("-- PR6: TickSaveDebounce no-op\n")
reaper.reset_all_calls()
package.loaded["state.persist"] = nil
package.loaded["state.preferences"] = nil
prefs = require("state.preferences")
reaper.reset_all_calls()

prefs.TickSaveDebounce()
check(reaper.get_mock("SetExtState").call_count == 0,
    "PR6: TickSaveDebounce no-op when no setter called")
