# Exploration: Que ves incompleto

## Current State

The codebase is mature and post-major-refactor, but in an awkward transitional state: some areas (piano roll, snap grid, undo/redo, preferences persistence) have received extensive recent development, while others (velocity editor, config.state migration, AGENTS.md docs) lag behind. The project has ~50+ source files and ~350+ tests, but the documentation (AGENTS.md files across the tree) is systematically outdated — they describe ~38 source files when there are actually ~50+. The architecture is clean overall (stores, core/ui separation, barrel pattern) but has accumulated technical debt in documentation accuracy, dual state access paths, and several "disabled" features.

## Findings by Category

### Architecture & Patterns

- **Documented source count is wrong** — Root AGENTS.md says 38 source files in `src/`, but actual count is ~50+. New files not documented: `core/api-guard.lua`, `core/snap.lua`, `state/persist.lua`, `state/preferences.lua`, `state/piano-roll-store.lua`, `state/preset-store.lua`, `ui/gfx-safe.lua`, `ui/icons.lua`, `ui/midi-island.lua`, `ui/piano-roll/` (6 files). Every AGENTS.md in the tree needs updating.

- **keyboard.lua now requires core.sequencer** — line 8: `local sequencer = require("core.sequencer")`. This is a NEW dependency path not documented in any AGENTS.md. While not technically a cycle (keyboard → sequencer → midi is fine since midi doesn't require keyboard), this makes the graph more fragile. If anyone adds a `require("core.keyboard")` in midi.lua, it creates a cycle. The root AGENTS.md circular dependency map doesn't mention this edge.

- **Dual state access for preferences** — `config.state.root_index/scale_index/octave/chord_mode_index` are accessed via BOTH `preferences_store.*` (correct/new) and raw `config.state.*` (legacy). The `midi.TriggerChord()` function (line 93) still falls back to `local c = ctx or config.state`, meaning any caller that passes `nil` ctx reads from config.state directly instead of preferences_store. This dual-path can cause stale/different values if one path updates but the other is read.

- **~72 config.state remnant count is stale** — grep shows that most config.state references in runtime code have been migrated. The count in the root AGENTS.md is outdated. Actual remaining runtime references are ~10, mostly in comments and config.lua init code.

### Core Logic

- **midi.lua grew 60% (144→232 LOC)** without documentation updates. New functions: `InvertChord()` (with UP/DN direction), `GetMidiChannel()`/`SetMidiChannel()`, `force` parameter in `AllNotesOff()`. None of these are in `src/core/AGENTS.md` API docs.

- **progression.lua Add/Remove/Swap don't bump progression_revision** — `seq_store.SetProgressionEntry()` increments revision internally, but `progression.Add()` calls through to that. However `progression.Remove()` calls `SetProgressionEntry(i, nil)` which does bump revision. This is actually correct — but it's worth noting that `progression.Add()` also calls `SetSlotFlashIdx/SetSlotFlashTimer` which don't bump revision. This means the MIDI island (midi-island.lua) won't detect flash-only changes as progression changes. Not a bug, but subtle.

- **TriggerChord inversion and ctx ambiguity** — `TriggerChord` now accepts an `inversion_index` parameter AND reads from `preferences_store` if not provided. But the `ctx` parameter (which overrides root/scale/chord/octave) doesn't have inversion fields. So keyboard calls `midi.TriggerChord(map.deg, true, temp_ctx, vel, preferences_store.GetInversionIndex())` — it passes inversion via parameter, not ctx. But sequencer calls `midi.TriggerChord(slot.degree, true, slot, ...)` where `slot` acts as ctx. If a slot has inversion info, it won't be used because inversion comes from a separate parameter.

- **Snap module (snap.lua) is clean** but only used by the piano roll area. The main sequencer doesn't support snap for progression creation.

### UI Layer

- **midi-island.lua is a monolith (735 LOC)** — contains scrollbar drag state, tool mode row rendering, snap controls, preset panel, note interaction routing, scrollbar thumb tracking, and lasso logic. This could be split into 3-4 focused modules (toolbar, scrollbar, content-area routing).

- **Velocity editor is disabled** — `local ve_h = 0` at line 343 of midi-island.lua. The entire velocity editing area is hardcoded to zero height. The `velocity.lua` module exists (~130 LOC) but is never rendered.

- **views.lua (694 LOC) still large** — although midi-island.lua extracted the island content, views.lua still contains DrawHeader, DrawIslands, DrawPerformanceArea, DrawDockedTransportBar, ShowQuickConfigMenu, and DecrementPageOverrideTimer. Some of these island rendering sections could be further extracted.

- **HACK: PITCH_ROW_H stale barrel copy** — piano-roll.lua line 97: `-- HACK: Sync PITCH_ROW_H on every SetPitchRowH call`. The barrel module keeps a copy of `PITCH_ROW_H` that goes stale if `SetPitchRowH` is not called. The workaround (wrapping SetPitchRowH) fixes the symptom but masks the design issue.

- **icons.lua DrawIcon always draws, never checks for off-screen** — no culling. Could be a minor perf issue with many icons.

### State Stores

- **piano-roll-store.lua (426 LOC) is the largest store by far** — the next largest is island.lua (233 LOC). Contains note CRUD (AddNote, RemoveNoteAtIndex), UUID management (6 functions: AllocNoteUUID, FindNoteByUUID, RebuildUUIDIndex), multi-selection (ToggleNoteSelected, GetSelectedIndices, etc.), undo/redo stacks (PushUndo, PopUndo, etc. — 8 functions), note drag state (9 get/set pairs), lasso state (10 pairs), snap state (6 pairs), and ProgressionToNotes conversion. Consider splitting into mini-stores or a separate "note-editor-store".

- **persist.lua and config.lua PREF_KEYS must be kept in sync manually** — config.lua defines `PREF_KEYS = {"root_index", "scale_index", "octave", "chord_mode_index", "inversion_index", "volume", "color_mode"}` but persist.lua defines its own `PREF_KEYS` with a different structure (paths nested for `volume`). These are two separate registries that must match but have NO shared source of truth.

- **island_store uses both array and set for selected_indices** — `selected_indices` is a set `{[idx] = true}`, but `_last_selected_idx` tracks the "primary" selection. The conversion from old `selected_note_index` (single value) to multi-selection creates backward compat shims (`GetSelectedNoteIndex`, `SetSelectedNoteIndex`). This is fine but adds complexity.

### Testing

- **barrel-backward-compat.lua NOT in run.lua** — this test file validates the piano-roll barrel exports but is NOT executed by the test runner. It uses its own `print`-based verification instead of `tests.helpers.check()`. It would need to be added to `test_names` in run.lua.

- **Zero UI tests** — piano-roll.lua, midi-island.lua, views.lua (694 LOC), icons.lua, buttons.lua, all compact-* modules have zero test coverage. 0 out of ~25 UI files have any tests.

- **No integration tests** — the full lifecycle (Init → MainLoop → CleanupAll) is never tested. keyboard.CheckFocus + sequencer.Run + HandleKeyboard interaction paths are only tested in isolation.

- **No tests for new features** — `midi.InvertChord()`, midi channel getter/setter, auto-track-setup, preferences_store, persist.Load/Save, the full gfx-safe module — all uncovered.

- **Documented 382 tests is inaccurate** — the test count in root AGENTS.md was not updated when snap-tests.lua and undo-tests.lua were added. Total is approximately ~357.

### Code Quality

- **Dual constants for TOTAL_PITCHES** — hardcoded as `108` in both `piano-roll-store.lua` (line 13) and `midi-island.lua` (line 671). Any change to one must be mirrored in the other.

- **Hardcoded dimensions scattered** — VKB_RECINPUT = 6080 (main.lua line 165), window sizes 720×497/793 (midi.lua lines 12-13), SB_SIZE 5 and 7 (midi-island.lua lines 346, 615), ve_h = 0 disabling velocity (midi-island.lua line 343). Many of these could be config constants.

- **TriggerChord has evolved beyond its original design** — the function now takes 5 parameters (degree, on, ctx, velocity, inversion_index) with complex fallback logic (ctx → config.state, inversion_index → preferences_store). The "ctx" parameter was originally designed for octave-override (the temp_ctx pattern), but now also needs to carry inversion, root, scale, chord_mode info. The parameter list is getting unwieldy.

- **The LICENSE SPDX header is on every file** — good practice, but every single .lua file has the exact same 2-line header. For completeness, the actual LICENSE file should exist at project root (it's referenced by SPDX but not present in the repo).

### Missing Features

- **No LICENSE file** — every source file has `SPDX-License-Identifier: MIT` but the actual LICENSE file is not present in the repo root.

- **No configuration/settings UI** — the top-right "settings" icon (gear icon in icons.lua) exists but has no associated settings panel. Users can't configure auto-start, auto-track-setup, tooltips, color mode, or scroll behavior from within the UI.

- **Velocity editing non-functional** — the velocity editor code exists and is well-structured (velocity.lua, ~130 LOC) but is disabled via `ve_h = 0`. This was likely disabled for a reason (performance? incomplete?), but there's no comment explaining why.

- **No MIDI export of the piano roll content** — `ExportToMidi()` only exports the progression, not the notes edited in the piano roll island.

- **No progression save/load between sessions** — persist.lua persists individual preferences (root, scale, octave, chord) but NOT the 16-slot progression content. Users lose their sequence when REAPER closes.

- **No arpeggiator** — common complementary feature for a QWERTY-to-MIDI tool. Only chord playback is supported.

- **No multi-track recording** — AutoTrackSetup only configures one track. Progression always exports to the selected track.

- **Preset browser exists but is incomplete** — preset-browser.lua (~160 LOC) and preset-store.lua (~72 LOC) have the UI shell but the browsing/loading logic appears minimal. No actual preset file format is defined.

- **No keyboard shortcut reference** — there's no help overlay showing the QWERTY mapping. Users must read the source code or documentation to know which keys map to which degrees.

## Top Recommendations

1. **Synchronize AGENTS.md with actual codebase** — every AGENTS.md in the tree (root, src/, core/, ui/, state/, tests/) is outdated. Files exist that aren't documented, LOC counts are wrong, function signatures changed. **Effort: Medium** — systematic update across 6 files.

2. **Eliminate dual state access (config.state vs stores)** — migrate the remaining `config.state.*` reads in midi.TriggerChord and all consumer code to use `preferences_store` uniformly. Remove the `local c = ctx or config.state` fallback. **Effort: Medium** — touches core/midi.lua and all callers.

3. **Complete the velocity editor** — either implement it fully (remove `ve_h = 0`) or remove the dead code. Currently users see a gap where the editor should be. **Effort: Medium** — need to determine why it was disabled first.

4. **Add UI tests and integrate barrel-backward-compat** — add barrel-backward-compat.lua to the test runner, start testing UI modules by mocking gfx state. **Effort: High** — requires GFX mock infrastructure expansion.

5. **Split midi-island.lua monolith** — extract scrollbar logic, toolbar row, and content-area routing into separate files. **Effort: Medium** — pure extraction with no behavioral change.

## Risks

- The exploration itself found no critical bugs or crashes, but the number of "disabled" features (velocity editor, settings panel, preset browser) suggests the project may have over-scoped and left features half-finished. Any work on these needs careful scoping.
- The `keyboard.lua → core.sequencer` dependency is undocumented and fragile — any future refactor that touches module dependencies could accidentally create a cycle here.
- TriggerChord's complex parameter logic (5 params + ctx fallback + preferences fallback) is a maintenance risk for future feature additions.

## Ready for Proposal

Yes

---

**Status**: success
**Summary**: Comprehensive exploration of ~50 source files across 6 directories found systematic documentation drift (AGENTS.md files describe 38 files but ~50 exist), dual state access paths for preferences, a disabled velocity editor, zero UI test coverage, and 3-4 medium-impact architectural improvements. No critical bugs were found.
**Artifacts**: `openspec/changes/que-ves-incompleto/exploration.md`, engram key `sdd/Que ves incompleto/explore`
**Next**: sdd-propose
**Risks**: Undocumented keyboard→sequencer dependency is fragile; disabled features (velocity, settings, preset browser) may have hidden reasons; TriggerChord parameter complexity increases maintenance cost.
**Skill Resolution**: injected
