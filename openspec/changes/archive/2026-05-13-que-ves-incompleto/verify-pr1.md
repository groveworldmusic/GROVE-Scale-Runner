## Verification Report

**Change**: que-ves-incompleto / PR #1 (Docs + Legal)
**Mode**: Standard

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 7 |
| Tasks complete | 7 |
| Tasks incomplete | 0 |

All 7 tasks were delivered (1.1–1.7). However, several contain stale data that contradicts the actual codebase.

### Spec Compliance Matrix
No spec-level changes in PR #1. This is documentation + legal housekeeping exclusively. No specs to compliance-check.

### Correctness (Static Evidence)

| AGENTS.md File | Exists? | Key Facts Accurate? | Updated Counts Match? |
|----------------|---------|-------------------|----------------------|
| Root `AGENTS.md` | ✅ Yes | ⚠️ **Partial** | ⚠️ **Partial** |
| `src/AGENTS.md` | ✅ Yes | ✅ Yes | ✅ Yes |
| `src/core/AGENTS.md` | ✅ Yes | ✅ Yes | ⚠️ **Partial** |
| `src/ui/AGENTS.md` | ✅ Yes | ✅ Yes | ⚠️ **Minor mismatch** |
| `src/state/AGENTS.md` | ✅ Yes | ✅ Yes | ✅ Yes |
| `tests/AGENTS.md` | ✅ Yes | ⚠️ **Partial** | ❌ **No** |
| `LICENSE` | ✅ Yes | ✅ MIT License | ✅ Correct |

#### Root AGENTS.md

**Correct**:
- ✅ 53 Lua files + 4 AGENTS.md = 57 — confirmed by glob
- ✅ ~8,800 TLOC — actual: 8,793
- ✅ 9 state stores + persist = 10 files in src/state/
- ✅ 7 core modules — confirmed: midi, keyboard, sequencer, progression, slots, api-guard, snap
- ✅ 34 UI modules (28 root + 6 piano-roll/) — confirmed by glob
- ✅ Dependency map matches actual `require()` calls
- ✅ Init order matches main.lua (steps 1–16)
- ✅ Cleanup — `AllNotesOff(true)` → `Stop()` → `keyboard.Cleanup()` → `compact.Cleanup()` — confirmed in main.lua:205-210
- ✅ Pattern glossary — all 10 patterns verified against source
- ✅ Remnant keys — 10 keys listed, `midi.lua:93-94` confirmed `local c = ctx or config.state`
- ✅ Issue registry — all 12 entries confirmed in source comments
- ✅ License — MIT LICENSE exists at project root

**Discrepancies**:
- ⚠️ **Test file count**: Claims "14 test files in runner, 497 check() calls". Actual: **18 test files in runner** (4 more: test_api_guard, test_persist, test_preferences, test_preset_store), **593 check() calls** in runner (+ 96 new). barrel-backward-compat.lua (static test, outside runner) confirmed 0 check() calls.
- ⚠️ **Init order missing api-guard step**: Root AGENTS doesn't list `api_guard = require("core.api-guard")` which runs BEFORE compact_store.Init (main.lua:86). `src/AGENTS.md` correctly includes it.

#### src/AGENTS.md

**Correct**:
- ✅ Directory structure — matches actual tree
- ✅ Init order — matches main.lua exactly (includes api-guard step)
- ✅ MainLoop 3 branches — confirmed against main.lua:212-318
- ✅ CleanupAll — matches main.lua:205-210
- ✅ config.lua API reference — all constants verified
- ✅ External requirements table — accurate
- ✅ Dependency graph — matches source
- ✅ Delegation rules — correct
- ✅ Pitfalls — all 8 verified against source

**No discrepancies found** ⭐

#### src/core/AGENTS.md

**Correct**:
- ✅ All 7 module descriptions accurate
- ✅ Function signatures verified against actual code:
  - `GetMidiNote(root_idx, scale_idx, degree_idx, octave_val)` → matches midi.lua:28
  - `SendMidi(note, on, velocity?, force?)` → matches midi.lua:41
  - `TriggerChord(degree, on, ctx?, velocity?, inversion_index?)` → matches midi.lua:93
  - `InvertChord(notes, inv_idx, direction)` → matches midi.lua:71
  - `AllNotesOff(force?)` → matches midi.lua:117
  - `SnapBeat(beat, resolution, triplet)` → matches snap.lua:13
  - All 3 api-guard functions match api-guard.lua:11,22,43
- ✅ Dependency graph — confirmed correct
- ✅ Patterns — all 7 documented patterns verified
- ✅ Pitfalls — all 5 verified

**Discrepancies**:
- ⚠️ **LOC counts** (using `(Get-Content).Count` method which matches state AGENTS):

| File | Claimed | Actual | Delta |
|------|---------|--------|-------|
| midi.lua | 232 | 232 | ✅ 0 |
| keyboard.lua | 105 | 113 | +8 |
| sequencer.lua | 131 | 136 | +5 |
| progression.lua | 33 | 40 | +7 |
| slots.lua | 313 | 339 | +26 |
| api-guard.lua | 44 | 49 | +5 |
| snap.lua | 26 | 31 | +5 |

These likely reflect code growth since the AGENTS was last synced. Minor (<10%) for most files; slots.lua grew 8.3%.

- ⚠️ **midi.lua module fields**: Table says "3 module fields" but documentation lists only 2 (`midi_island_expanded`, `midi_island_toggled`). No third field exists.

#### src/ui/AGENTS.md

**Correct**:
- ✅ All 34 files listed with matching LOC (28 root + 6 piano-roll/)
- ✅ LOC verified accurate for ALL files — every claim matches `Measure-Object -Line` count
- ✅ Total: 6,342 LOC confirmed (4,533 root + 1,809 piano-roll/)
- ✅ Dual GFX context documentation accurate
- ✅ Function signatures match actual code
- ✅ Barrel pattern documented correctly
- ✅ GFX conventions (mouse_wheel zeroing, consume pattern, etc.) verified
- ✅ Dependencies table — accurate
- ✅ Pitfalls — all 7 verified

**Discrepancies**:
- ⚠️ **slots.lua LOC**: Table entry shows 194 LOC for `slots.lua` (in core/). Actual file at `src/core/slots.lua` has 313 LOC. The core AGENTS correctly says 313. This is a stale number in the UI AGENTS.

#### src/state/AGENTS.md

**Correct**: ✅ ALL claims verified! ⭐

- ✅ 10 state files listed (9 stores + persist)
- ✅ LOC counts match `(Get-Content).Count` exactly:
  - compact.lua: 37 — ✅
  - drag.lua: 51 — ✅
  - sequencer.lua: 81 — ✅
  - midi.lua: 57 — ✅
  - ui.lua: 121 — ✅
  - island.lua: 136 — ✅
  - piano-roll-store.lua: 426 — ✅
  - preset-store.lua: 72 — ✅
  - preferences.lua: 81 — ✅
- ✅ All getter/setter function docs verified accurate
- ✅ Init semantics for each store documented correctly
- ✅ Consume pattern documented correctly
- ✅ Remnant keys (10) match root AGENTS
- ✅ Mutable table warnings accurate
- ✅ Cross-store dependencies: "no inter-store deps" confirmed
- ✅ "~1 runtime read remanente: midi.lua:94" confirmed in source

**No discrepancies found** ⭐

#### tests/AGENTS.md

**Correct**:
- ✅ Mock infrastructure documentation accurate
- ✅ Test patterns (keyboard isolation, CheckFocus, Sequencer.Run, AllNotesOff) verified
- ✅ Mock installation order in run.lua matches

**Discrepancies**: This is the **most outdated** file. Systematic freshness issue:

1. ❌ **Test file count**: Claims "14 test files in runner". Runner has **18** — 4 missing:
   - `test_api_guard.lua` (66 lines, 20 check())
   - `test_persist.lua` (82 lines, 10 check())
   - `test_preferences.lua` (131 lines, 30 check())
   - `test_preset_store.lua` (129 lines, 39 check())

2. ❌ **check() call count**: Claims "497 check() calls". Actual: **593** (+96 from 4 new test files).

3. ❌ **ALL file LOC claims are stale** — every test file has grown:

| File | Claimed LOC | Actual LOC |
|------|------------|------------|
| test_midi.lua | 77 | 128 |
| test_stores.lua | 304 | 318 |
| test_progression.lua | 67 | 78 |
| test_sendmidi.lua | 171 | 337 |
| test_sequencer_stop.lua | 68 | 125 |
| test_keyboard_intercept.lua | 33 | 83 |
| test_keyboard_cleanup.lua | 34 | 80 |
| test_keyboard_handle.lua | 89 | 215 |
| test_keyboard_focus.lua | 97 | 225 |
| test_toggle_island.lua | 77 | 126 |
| test_export_midi.lua | 104 | 174 |
| test_sequencer_run.lua | 98 | 177 |
| snap-tests.lua | 286 | 301 |
| undo-tests.lua | 345 | 414 |
| barrel-backward-compat.lua | 21 | 322 |

4. ⚠️ **Coverage table** still accurate (no new modules to cover), but the check() counts are stale.

#### LICENSE

- ✅ MIT License file exists at `D:\...\GROVE FL MIDI\LICENSE`
- ✅ SPDX-License-Identifier: MIT header on **all 53** `src/` .lua files
- ✅ Copyright: `Copyright (c) 2026 Andrik on the beat`
- ✅ No license issues found

### Issues Found

**CRITICAL**: None

**WARNING**:
- **tests/AGENTS.md is systematically stale**: 18 files in runner but only 14 documented; 593 check() calls but 497 claimed; all LOC counts outdated. Task 1.6 (sync tests/AGENTS.md) was incomplete — it added 3 new files to the list (snap-tests, undo-tests, barrel-backward-compat) but missed the subsequent 4 (test_api_guard, test_persist, test_preferences, test_preset_store).
- **Root AGENTS.md test metrics stale**: Claims 14 files / 497 check() calls — actual is 18 / 593.
- **Root AGENTS.md Init order**: Missing `core.api-guard` step that runs before compact_store.Init (main.lua:86). Present in src/AGENTS.md but absent from root.

**SUGGESTION**:
- Sync the 4 missing test files (test_api_guard, test_persist, test_preferences, test_preset_store) into tests/AGENTS.md file inventory table.
- Update all LOC counts in tests/AGENTS.md to match current files.
- Update check() call total in root AGENTS.md from 497 to 593+.
- Fix Init order in root AGENTS.md to include `core.api-guard` step (step 2).
- Fix `slots.lua` LOC in ui/AGENTS.md from 194 to 313 (or remove the LOC column for cross-referenced files).
- Fix midi.lua module fields count in core/AGENTS.md (claims 3, documents 2).

### Verdict

**PASS WITH WARNINGS**

PR #1 delivered all 7 tasks. The LICENSE is correct, SPDX headers are on all files, and the documentation is largely accurate. However, `tests/AGENTS.md` has significant stale data (18 vs 14 files, 593 vs 497 check() calls, all LOC counts outdated), and root `AGENTS.md` has matching stale test metrics plus a missing init step. These are documentation freshness issues that don't affect functionality but should be corrected in a follow-up.
