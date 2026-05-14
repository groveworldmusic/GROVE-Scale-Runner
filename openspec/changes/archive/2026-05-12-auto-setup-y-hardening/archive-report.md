# Archive Report: auto-setup-y-hardening

**Archived**: 2026-05-12
**Verdict**: PASS WITH WARNINGS
**Engram Observation IDs**:
- proposal: #552
- spec: #553
- design: #554
- tasks: #555
- verify-report: #558

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| midi-runtime-tests | Updated | M1 modified (ref-count gate on note-off), M5 modified (force param), M6 added (nil guard) |
| sequencer-run-tests | Updated | Catch-up Without Notes requirement added (state-only catch-up) |
| check-focus-tests | Updated | Focus Transitions modified (+ sequencer.Stop() on focus loss) |
| auto-track-setup | Created | New full spec (track scan, creation, ExtState persistence) |

## Archive Contents

- proposal.md ✅
- design.md ✅
- tasks.md ✅
- verify-report.md ✅
- specs/midi-runtime-tests/spec.md ✅
- specs/sequencer-run-tests/spec.md ✅
- specs/check-focus-tests/spec.md ✅
- specs/auto-track-setup/spec.md ✅

## Implementation Summary

**6 bug fixes** (3 critical, 3 moderate):
1. Ref-count note-off gate in `midi.lua` (0x80 only when count reaches 0)
2. Force param for AllNotesOff/sequencer.Stop cleanup callers
3. Nil guard in ExportToMidi (protect against nil CreateNewMIDIItemInProj)
4. State-only catch-up in `sequencer.lua` (suppress TriggerChord/SendMidi during skipped measures)
5. sequencer.Stop() on focus loss in `keyboard.lua`
6. VIEW_MODES.ISLAND dead code removed from `compact-init.lua`
7. Redundant InterceptMappedKeys(false) removed from `main.lua`

**1 new capability**: Auto-track-setup in `main.lua` — ExtState gate, track scan, consent dialog, track creation with arm/monitor/input routing.

## Design Deviations

- D2 (Track Selection): Implementation checks `recinput > 0` instead of specifically `0x1000` (virtual MIDI keyboard). Functionally safe but looser than specified.

## Files Changed

| File | Action |
|------|--------|
| `src/core/midi.lua` | ref-count gate + force param + nil guard |
| `src/core/sequencer.lua` | state-only catch-up |
| `src/core/keyboard.lua` | sequencer.Stop() on focus loss |
| `src/ui/compact-init.lua` | removed ISLAND dead code |
| `src/main.lua` | AutoSetupTrack + CleanupAll force=true |
| `.llm/knowledge/architecture.md` | updated docs |

## SDD Cycle Complete

This change has been fully explored, proposed, specified, designed, implemented, verified (PASS WITH WARNINGS), and archived.
