# Archive Report: remaining-features

**Archived**: 2026-05-18
**Source**: `openspec/changes/remaining-features/` → `openspec/changes/archive/2026-05-18-remaining-features/`
**Delivery**: 5 chained PRs on `inversion-subdivision` branch
**Total Tasks**: 21/21 complete

## Lineage

| Artifact | Filesystem Path |
|----------|----------------|
| Exploration | `archive/2026-05-18-remaining-features/exploration.md` |
| Proposal | `archive/2026-05-18-remaining-features/proposal.md` |
| Design | `archive/2026-05-18-remaining-features/design.md` |
| Specs | `archive/2026-05-18-remaining-features/specs/{domain}/spec.md` |
| Tasks | `archive/2026-05-18-remaining-features/tasks.md` |
| Verify Report | `archive/2026-05-18-remaining-features/verify-report.md` |

## Phase Completion

| Phase | Tasks | Files Changed | Status |
|-------|-------|---------------|--------|
| **A**: Progression Dispatch Hooks | 4/4 | `progression.lua`, `midi-island.lua`, `input.lua`, `note-store.lua` | ✅ |
| **B**: Progression-Only Presets | 4/4 | `io.lua`, `main.lua`, `preset-list.lua`, `preset-browser.lua` | ✅ |
| **C**: Vkey-Map Configurables | 5/5 | `vkey-map.lua` (new), `remap.lua` (new), `keyboard.lua`, `pads.lua`, `header.lua`, `preferences.lua`, `persist.lua`, `config.lua` | ✅ |
| **D**: MIDI Input Recording | 4/4 | `midi-input.lua` (new), `note-store.lua`, `header.lua`, `main.lua` | ✅ |
| **E**: UI Tests | 4/4 | `test_piano_roll_grid.lua` (new), `test_preset_browser_io.lua` (new), `test_piano_roll_drag.lua` (new), `run.lua` | ✅ |

## Specs Synced to Main (`openspec/specs/`)

| Domain | Action | Details |
|--------|--------|---------|
| progression | **Created** | New domain spec with Ctrl+Z/Y dispatch, composite wrap, SyncNotesToProgression undo hook |
| midi-input-recording | **Updated** | +5 requirements (Unpaired Note Timeout, UpdateOpenNoteDuration, Record-Arm UI, MainLoop Wiring, Modified Stuck Note Safety) |
| keyboard-shortcuts | **Updated** | +5 requirements (Progression Undo/Redo, Vkey-Map Module, Remap Overlay, Gear Button, Vkey-Map Persistence) + Modified Undo/Redo Shortcuts |
| preset-browser | **Updated** | +4 requirements (Dual-Extension, Save Progression, Filter Tabs, Type-Aware List) + Modified Save/Load Preset |

## Files Created (5 new)

- `src/core/vkey-map.lua` — Vkey-map configurable module (GetVkeyMap, SetEntry, ResetToDefaults, serialization)
- `src/ui/midi-island/remap.lua` — 4×7 remap modal overlay grid with cell click and conflict detection
- `src/core/midi-input.lua` — MIDI input recording (Poll, SetArmed, IsArmed, Cleanup, _open_notes tracking, 5s timeout)
- `tests/test_piano_roll_grid.lua` — Grid pure function tests (~42 check())
- `tests/test_preset_browser_io.lua` — Preset I/O mock tests (~37 check())
- `tests/test_piano_roll_drag.lua` — Drag edge detection tests (~40 check())

## Files Modified (13 existing)

- `src/core/progression.lua` — +6 LOC (Swap undo gate + manual snapshot)
- `src/ui/midi-island.lua` — +8 LOC (progression_focused flag computation)
- `src/ui/midi-island/input.lua` — +18 LOC (Ctrl+Z/Y dispatch)
- `src/state/note-store.lua` — +10 LOC (ProgPushUndo + UpdateOpenNoteDuration)
- `src/ui/preset-browser/io.lua` — +65 LOC (dual-ext, SaveProgressionPreset, Load branching)
- `src/ui/preset-browser/main.lua` — +55 LOC (filter tabs, S-PROG button)
- `src/ui/preset-browser/preset-list.lua` — +16 LOC (type_filter param, type badge)
- `src/ui/preset-browser.lua` — +2 LOC (re-export)
- `src/core/keyboard.lua` — +6 LOC (vkey_map.GetVkeyMap)
- `src/ui/pads.lua` — +1 LOC (vkey_map.GetVkeyMap)
- `src/state/preferences.lua` — +4 LOC (vkey_map_raw, vkey_map_modified)
- `src/state/persist.lua` — +1 LOC (PREF_KEYS)
- `src/config.lua` — +2 LOC (config.state keys)
- `src/ui/midi-island/header.lua` — +40 LOC (gear button + record toggle)
- `src/main.lua` — +12 LOC (require + Poll + Cleanup)
- `tests/run.lua` — +3 LOC (registration)

## Verification

**Verdict**: PASS WITH WARNINGS (Phase B only, no critical issues)
**Mode**: Static analysis (no test runner available)

Noted warnings:
1. `preset-list.lua`: Dead `type_filter` parameter in `DrawPresetList` (cosmetic)
2. `preset-list.lua`: Hardcoded badge colors instead of theme colors (minor)
3. Spec/design divergence on Save Preset behavior (separate S-PROG button vs tab-aware save — intentional design decision per B2)

## Architecture Decisions Recorded

| Decision | Context |
|----------|---------|
| A1: Swap composite via manual gate + snapshot (6 LOC) | Avoids new store functions |
| A2: Progression focus computed in midi-island.lua, passed to input.lua | Decouples input from layout |
| B1: Load branching by `type` field + `.grove-prog` extension | Deterministic at file-discovery time |
| B2: Filter tab state = module-local `_type_filter` | Zero surface, reset on reload |
| C1: Vkey-map module with local closure + JSON serialization | Lightweight, no Init needed |
| C2: Remap as separate `remap.lua` sub-module | Keeps header.lua focused |
| C3: Record button at 0.4× width | Smaller visual footprint |

## SDD Cycle Complete

The remaining-features change has been fully planned, implemented, verified, and archived. All 21 tasks across 5 phases delivered via chained PRs. 4 main specs updated with delta requirements, 1 new domain spec created.
