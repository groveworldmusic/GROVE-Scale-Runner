# Apply Progress: Phase 3 — LOW Priority Items

**Change**: phase-3-low-priority
**Mode**: Standard
**Date**: 2026-05-13
**Artifact Store**: Hybrid (openspec + engram)

## Completed Tasks

| # | Task | Status |
|---|------|--------|
| 3.1 | Cache `active_mod12` table with revision counter | ✅ |
| 3.2 | Hoist `GetFitText` closure to module level | ✅ |
| 3.3 | Pre-allocate chord array + configurable `midi_channel` | ✅ |
| 3.4 | Revision tracking for subdivision dots | ✅ |
| 3.5 | Guard module-level `_S`/`_OX`/`_OY` against stale values | ✅ |
| 3.6 | Silent clamp — remove `ShowConsoleMsg` from `ClampIndex` | ✅ |

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `src/state/midi.lua` | Modified | Added `active_notes_revision` field + `GetActiveNotesRevision()` + bump revision on every `SetActiveNote`/`ClearActiveNotes` |
| `src/ui/piano.lua` | Modified | Added `_active_note_revision`/`_cached_active_mod12` module locals; rebuild `active_mod12` only when revision changes |
| `src/ui/dropdown.lua` | Modified | Hoisted `GetFitText` from inner closure in `DrawDropdown` to module-level function |
| `src/core/midi.lua` | Modified | Replaced `table.insert` with pre-allocated array in `TriggerChord`; changed `midi.midi_channel` to local `_midi_channel` with `GetMidiChannel()`/`SetMidiChannel()` getter/setter |
| `src/core/slots.lua` | Modified | Added `_dots_revision` counter + `_dots_cache` per-slot lookup; skip `gfx.circle` calls when dot state unchanged |
| `src/ui/layout.lua` | Modified | Added `_S == 0` guard to `UX()`/`UY()`/`US()` — return 0 when scale not set this frame |
| `src/core/api-guard.lua` | Modified | Removed `ShowConsoleMsg` log from `ClampIndex` — silent clamp for boundary scrolling |
| `src/state/midi.lua` | Modified | Added `GetActiveNotesRevision()` function |

## Deviations from Design

None — implementation matches task descriptions exactly.

## Issues Found

None.

## Workload / PR Boundary

- **Mode**: single-pr
- **Boundary**: PR #3 in feature-branch-chain (Phase 3: LOW items, base = PR #2 branch)
- **Estimated review budget**: ~50 changed lines
- **400-line risk**: Low

## Status

**6/6 tasks complete. Ready for verify.** 
