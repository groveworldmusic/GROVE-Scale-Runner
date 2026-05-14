# Tasks: Auto Setup y Hardening

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 200-250 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | PR | Notes |
|------|------|----|-------|
| 1 | 6 bug fixes (Phase 1) | Single | Independent, minimal per module |
| 2 | Auto track setup (Phase 2) | Single | New capability, same PR |
| 3 | Knowledge + verification (Phases 3-4) | Single | Docs + manual verification |

## Phase 1: Bug Fixes

- [x] 1.1 `src/core/midi.lua`: Gate 0x80 note-off behind ref-count `cur <= 0`; add 4th `force` bool param that bypasses gate for cleanup callers (AllNotesOff, sequencer.Stop)
- [x] 1.2 `src/core/midi.lua`: Add nil guard before `GetActiveTake` in `ExportToMidi` — protect against `CreateNewMIDIItemInProj` returning nil
- [x] 1.3 `src/core/sequencer.lua`: Replace `TriggerChord(true)+SendMidi(n,false)` with state-only advance in catch-up loop (advance `LastMeasure`, `CurrentStep`, suppress all MIDI calls)
- [x] 1.4 `src/core/keyboard.lua`: Insert `sequencer.Stop()` before `midi.AllNotesOff()` in `CheckFocus` on focus loss
- [x] 1.5 `src/ui/compact-init.lua`: Remove dead `if VIEW_MODES.ISLAND then ... end` branch in `SwitchViewMode`
- [x] 1.6 `src/main.lua`: Delete redundant `keyboard.InterceptMappedKeys(false)` call in `Init`

## Phase 2: Auto Track Setup

- [x] 2.1 `src/main.lua`: Insert auto-setup block after `gfx.setfont` (line 216), before ExtState load — scan tracks via `GetTrack(0,i)` for arm=1 + monitoring=1 + `I_RECINPUT=4096`
- [x] 2.2 Auto-setup logic: if no suitable track found, show consent MB dialog; on accept, create+configure track (arm=1, monitoring=1, I_RECINPUT=4096); persist flag via `SetExtState("GROVE_SCALE_RUNNER", "auto_track_setup_done", "true")`

## Phase 3: Knowledge Updates

- [x] 3.1 `.llm/knowledge/architecture.md`: Remove VIEW_MODES.ISLAND references; document ref-count gate + `force` param + auto-track-setup capability

## Phase 4: Verification

- [x] 4.1 Manual verify bug fixes: ref-count gate (multiple note-ons, single note-off no 0x80), nil guard (force nil return), catch-up (skip measures, no clicks), CheckFocus (focus loss stops sequencer)
- [x] 4.2 Manual verify auto-track-setup: fresh launch shows prompt → track created with correct props; subsequent launch skips silently
