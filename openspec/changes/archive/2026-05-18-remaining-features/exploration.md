# Exploration: remaining-features

## Current State

### arch-debt-sweep
- **P1** ✅ View offset persistence — DONE (committed)
- **P2** ✅ Preset browser barrel refactor — **DONE in code** (preset-browser.lua is a 39 LOC barrel). The task checkbox in tasks.md was never updated but the implementation is complete.
- **P3** ❌ **UI Tests** — 3 of 4 test files don't exist yet (`test_piano_roll_grid.lua`, `test_preset_browser_io.lua`, `test_piano_roll_drag.lua`). `test_note_store.lua` exists but contains different content (not the arch-debt P3 version). None of the 4 are registered in `tests/run.lua`'s `test_names` array.

### progression-workflow
- **P1** ✅ Progression undo/redo — FULLY DONE. `sequencer.lua` (lines 30-165) implements:
  - `prog_undo_stack` / `prog_redo_stack` with FIFO eviction at MAX_PROG_UNDO=50
  - `ProgSnapshot()`, `PushProgUndo()`, `PopProgUndo()`, `PushProgRedo()`, `PopProgRedo()`
  - `HandleProgUndo()`, `HandleProgRedo()`, `ClearProgUndoStacks()`
  - Guard gate in `SetProgressionEntry`, `SetProgression`, `ClearProgression`
  - **⚠️ Discovery**: Guard gate polarity is INVERTED from the design doc. `prog_undo_gate = false` (default) means "snapshot on mutation" (`if not prog_undo_gate` = true). The design doc specified `_prog_undo_gate = true`. The implementation IS functionally correct — just note the naming difference.
- **P2** ❌ Remaining:
  - **T2**: progression.lua `Swap()` calls `SetProgressionEntry` twice, creating double undo snapshots. Needs `ProgBeginComposite()`/`ProgEndComposite()` wrapping (~15 LOC).
  - **T3**: Ctrl+Z/Y dispatch in `midi-island/input.lua` — `HandleKeyboard(char)` only handles Escape and piano-roll shortcuts. No progression undo/redo dispatch. Need to add before collapsed-island early return in `midi-island.lua` ~line 178 (~20 LOC).
  - **T4**: `SyncNotesToProgression()` in `note-store.lua` line 416 — no undo snapshot call before mutation. Need `seq_store.ProgPushUndo()` at top (~2 LOC).
  - **T5**: `preset-browser/io.lua` — only `.grove` extension. No `.grove-prog`, no `SaveProgressionPreset`, no `type` field in LoadPreset branching (~75 LOC).
  - **T6**: `preset-browser/main.lua` — no "Save Progression" button, no filter tabs for Notes/Progression (~90 LOC).
  - **T7**: `preset-browser/preset-list.lua` — no type-aware filtering (~2 LOC).
  - **T9**: P2 tests (~30 assertions).

### expansion-features
- **P1** ✅ Color themes — DONE. `theme_index` in preferences, themes dropdown in header.lua (line 193), theme selection persists. T14 (verify) unchecked but trivial.
- **P2** ❌ **Vkey-map configurables**:
  - **T5**: `src/core/vkey-map.lua` — doesn't exist.
  - **T6**: `keyboard.lua` line 34 — still references `config.VKEY_MAP` directly. Need to replace with `vkey_map.GetVkeyMap()`.
  - **T7**: No `vkey_map_raw`/`vkey_map_modified` keys in preferences/persist/config.
  - **T8**: No remap modal overlay anywhere.
  - **T9**: No gear button in header.lua (between SYNC and SNAP).
- **P3** ❌ **MIDI input recording**:
  - **T10**: `src/core/midi-input.lua` — doesn't exist.
  - **T11**: `note-store.lua` has `AddNote` with `origin` field (line 84) but no `UpdateOpenNoteDuration()` function.
  - **T12**: No record-arm toggle in header.lua.
  - **T13**: main.lua has no `midi_input.Poll()` or `midi_input.Cleanup()`.
- **P4** ❌ Verification (T14-T17).

## Affected Areas

### Progression dispatch hooks (Phase A)
- `src/core/progression.lua` — Add ProgBeginComposite/EndComposite around Swap
- `src/ui/midi-island.lua` — Add Ctrl+Z/Y dispatch before collapsed-island return
- `src/ui/midi-island/input.lua` — No changes needed (char flows through midi-island.lua)
- `src/state/note-store.lua` — Add ProgPushUndo() at top of SyncNotesToProgression

### Progression-only presets (Phase B)
- `src/ui/preset-browser/io.lua` — Accept .grove-prog, SaveProgressionPreset, LoadPreset branching
- `src/ui/preset-browser/main.lua` — Add "Save Progression" button + Notes/Progression filter tabs
- `src/ui/preset-browser/preset-list.lua` — Accept type_filter param
- `src/ui/preset-browser.lua` — Barrel re-export new functions

### Vkey-map configurables (Phase C)
- `src/core/vkey-map.lua` — NEW: GetVkeyMap, SetEntry, ResetToDefaults, serialization
- `src/core/keyboard.lua` — Replace config.VKEY_MAP → vkey_map.GetVkeyMap(); add RebuildKeyStates
- `src/state/preferences.lua` — Add vkey_map_raw, vkey_map_modified keys
- `src/state/persist.lua` — Add vkey_map_raw to PREF_KEYS
- `src/config.lua` — Add vkey_map pref keys
- `src/ui/midi-island/header.lua` — Add gear button between SYNC and SNAP
- `src/ui/midi-island/input.lua` — Add remap modal overlay handler

### MIDI input recording (Phase D)
- `src/core/midi-input.lua` — NEW: Poll, SetArmed, GetArmed, Cleanup; _open_notes tracking
- `src/state/note-store.lua` — Add UpdateOpenNoteDuration(pitch, dur)
- `src/ui/midi-island/header.lua` — Add record-arm toggle (red circle, glows when armed)
- `src/main.lua` — Require midi-input in Init, call Poll() in MainLoop after HandleKeyboard, add Cleanup() to CleanupAll

### Arch-debt UI tests (Phase E)
- `tests/test_piano_roll_grid.lua` — NEW: ~80 LOC, ~40 check() for grid pure functions
- `tests/test_preset_browser_io.lua` — NEW: ~70 LOC, ~35 check() for I/O pure functions
- `tests/test_piano_roll_drag.lua` — NEW: ~80 LOC, ~45 check() for edge detection
- `tests/run.lua` — Add 3 (or 4) test filenames to `test_names`
- Note: `test_note_store.lua` already exists but not the P3 version; verify if existing file covers P3 scope

## Approaches

### 1. **Sequential phases (recommended)** — A→B→C→D→E
   Each phase ships independently as a PR in the chain.
   - Pros: Clear dependencies respected (B depends on A for ClearProgressionUndoStacks); each PR stays under 400 LOC except possibly B; easy to revert individually.
   - Cons: Phase E (UI tests) can't reference code from B/C/D if those modify SUT; some tests in E need to exist before B changes I/O functions. Solution: write E tests AFTER B is applied.
   - Effort: Medium (5 PRs in chain)

### 2. **Parallel independent tracks** — A+B together, C alone, D alone, E last
   A and B merge sequentially, C and D can be parallel branches from the same base.
   - Pros: C and D are fully independent of A/B; parallel CI.
   - Cons: More complex branching; E needs all others done first for full coverage.
   - Effort: High (branch management overhead)

### 3. **Monolithic single PR** — everything in one PR
   - Pros: One branch, one review cycle.
   - Cons: ~580+ LOC estimated (92+167+400+480+230 = ~1369) — WAY over 400-line budget; impossible to review effectively.
   - Effort: Low (one branch) but unacceptable review risk.

### Recommendation: **Approach 1 (Sequential phases)**
Dependency chain: A → B → C → D → E. A and B share progression domain, C and D are independent features requiring only store/preference infrastructure (shared setup). E must be last since it tests modules potentially modified by A-E.

## Estimated LOC per Phase

| Phase | LOC | 400-line risk |
|-------|-----|---------------|
| A: Progression dispatch hooks | ~37 | Low |
| B: Progression-only presets | ~167 | Low |
| C: Vkey-map configurables | ~400 | Borderline (modal overlay is bulk) |
| D: MIDI input recording | ~480 | High (split into D1: core+store, D2: UI+main?) |
| E: UI tests | ~304 | Low |

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Guard gate polarity confusion**: `prog_undo_gate=false` means "snapshot enabled" — counterintuitive naming. Future maintainers may set it wrong. | Low | Document in code comment. Gate is only touched by HandleProgUndo/Redo internally. |
| **Swap double-snapshot**: Currently creates 2 undo entries per swap. Fix is trivial (wrap composite) but if missed, undo behavior is buggy (skips back 2 states per undo). | Low | T2 must be first task in Phase A. |
| **P2 tests (T9) depend on Phase A functions**: `ClearProgressionUndoStacks()` must exist before testing P2 preset load behavior. | Medium | Chain order A→B ensures this. |
| **MIDI recording polling perf**: `MIDI_GetRecentInputEvent` called every frame (~60fps). If event queue is deep, could spike frame time. | Low | Queue depth is typically ~32 events max. Poll only when armed. |
| **Header layout overflow**: Adding gear (C) + record toggle (D) to header may exceed available width, displacing existing buttons. | Medium | Follow expansion-features design note: may need PRESETS width trimmed from 1.2× to 1.0×. Validate pixel math in implementation. |
| **test_note_store.lua exists but may conflict**: The glob shows this file already exists. If it's a different test suite, the arch-debt P3 version needs a different name. | Medium | Audit existing test_note_store.lua content; rename if needed. |
| **Key mapping conflicts**: Remap modal must detect duplicate VK assignments. Design calls for `reaper.MB` reject dialog. | Low | Straightforward conflict scan on SetEntry. |

## Ready for Proposal

**Yes.** The scope is clear, all source files have been validated, remaining tasks are well-understood. Two important corrections to the original task specs:

1. **arch-debt-sweep P2 (barrel) is already done in code** — the task checkbox is stale. Do NOT re-spec it.
2. **The guard gate in sequencer.lua uses inverted polarity** from the design doc (`false` = active, `true` = blocked) — this is correct behavior but future maintainers need clear documentation.

The proposal should consolidate into 5 phases as defined, with the understanding that Phase A is mostly already pre-wired (the store layer exists) and only dispatch wiring remains.
