# Apply Progress: Que ves incompleto (PR #2 — State + Test)

**Status**: 12/12 tasks complete (PR #1: 7/7, PR #2: 5/5)
**Mode**: Standard
**PR Boundary**: feature-branch-chain, PR #2 (Base = PR #1 branch)

## Completed Tasks

### PR #1: Docs + Legal

#### 1.1 Sync root AGENTS.md
- Verified all counts accurate against actual source files
- 53 Lua + 4 AGENTS.md = 57 src files, ~8,800 TLOC
- 9 state stores (compact, drag, midi, sequencer, ui, island, piano-roll-store, preset-store, preferences) + persist
- 7 core modules (midi, keyboard, sequencer, progression, slots, api-guard, snap)
- 34 UI modules (28 root + 6 piano-roll/)
- 497 check() calls across 14 test files in runner, 1 static-test outside (barrel-backward-compat.lua)
- Circular dependency map already includes keyboard → core.sequencer
- Issue registry already current with all 12 issues

### 1.2 Sync src/AGENTS.md
- Added `api-guard = require("core.api-guard")` step (#2) to Init order
- Updated delegation table to mention piano-roll sub-modules, gfx-safe, icons
- Updated config.state remnants line to show all 10 keys matching root

### 1.3 Sync src/core/AGENTS.md
- Updated midi.lua LOC from 220→232 (actual file has 232 lines)
- All function signatures verified correct against actual source:
  - GetMidiNote, SendMidi, TriggerChord (5 params), InvertChord, AllNotesOff (force param)
  - GetMidiChannel, SetMidiChannel
  - ExportToMidi, ToggleIsland
  - All api-guard.lua (3 functions) and snap.lua documented

### 1.4 Sync src/ui/AGENTS.md (MAJOR UPDATE)
- Header: 25→34 files, ~3,350→~6,342 LOC
- Added midi-island.lua (662 LOC) to Core UI section
- Added piano-roll/* 6 sub-modules with LOC:
  - grid.lua (446), interaction.lua (795), note.lua (250)
  - undo.lua (148), clipboard.lua (126), view.lua (44)
- Added icons.lua (92 LOC) and gfx-safe.lua (47 LOC) to Utilities
- Updated all LOC values to match actual files (views 860→654, components 55→84, etc.)
- Updated barrel pattern to mention piano-roll.lua as third barrel
- Added convention #7 (MIDI island expand pattern) to GFX Conventions
- Updated Dependencies section with state/island, state/piano-roll-store, state/preset-store, core/snap, core/api-guard
- Updated Cross-References to reflect new stores

### 1.5 Sync src/state/AGENTS.md (MAJOR UPDATE)
- Added piano-roll-store (426 LOC, 50+ functions) with full API docs:
  - Note CRUD (AddNote, RemoveNoteAtIndex), Selection (multi-index), Lasso, Tool, Snap
  - Note drag, Undo/Redo (max 50), UUID management, Velocity panel, Island transition
  - Conversion helpers: ProgressionToNotes, LoadNotesFromProgression, GetVisibleNotes
- Added preset-store (72 LOC, 10 pairs + ClearBrowserState) with API docs
- Added preferences (81 LOC, 7 pairs + SyncFromState + TickSaveDebounce) with API docs
- Updated island LOC from 233→136 (piano-roll-store extracted)
- Updated all LOC values in overview table to match actual files
- Fixed remnant keys: 6→10 keys with migration status explanation
- Added new stores to Init Merge Semantics, Mutable Table Warnings, and Cross-Store Dependencies

### 1.6 Sync tests/AGENTS.md
- Added snap-tests.lua (286 LOC, 89 check()) to file inventory
- Added undo-tests.lua (345 LOC, 94 check()) to file inventory
- Added barrel-backward-compat.lua (21 LOC, 0 check(), static-only, NOT in runner)
- Added LOC column to inventory table
- Updated coverage table: 6→9 state stores, added snap.lua + piano-roll-store rows

### 1.7 LICENSE — Already Exists

### PR #2: State + Test

#### 2.1 Audit all config.state.* runtime reads
- Comprehensive grep across all `src/` files for `config.state` references
- **Only 1 runtime read remnant found**: `src/core/midi.lua:94` — `local c = ctx or config.state` in `TriggerChord`
- All other matches are:
  - AGENTS.md documentation
  - State-store header comments (`-- Extracted from config.state.*`)
  - Init-time setup in `main.lua` (`store.Init(config.state)`, `persist.Load(config.state)`, `preferences_store.SyncFromState(config.state)`)
- The 10 remnant keys in `config.state` defaults are no longer read at runtime outside `config.lua` itself
- Mapped the 4 preference values read via the fallback: `chord_mode_index`, `root_index`, `scale_index`, `octave` — all have `preferences_store.*` equivalents

#### 2.2 Migrate reads in views.lua, compact-*.lua, piano.lua, keyboard.lua
- **Result**: zero `config.state.*` runtime reads found in any of these files
- `keyboard.lua`: already uses `preferences_store.GetOctave()`, `preferences_store.GetRootIndex()`, `preferences_store.GetScaleIndex()`, `preferences_store.GetChordModeIndex()` (lines 36-39)
- All UI files (`views.lua`, `compact-*.lua`, `piano.lua`): no `config.state.*` references at all
- No migration needed — the stores were already the access pattern

#### 2.3 Remove config.state fallback in midi.lua TriggerChord
- Replaced `local c = ctx or config.state` (line 94) with individual `preferences_store.*` getter calls
- Before: `local c = ctx or config.state` then `c.chord_mode_index`, `c.root_index`, `c.scale_index`, `c.octave`
- After: 
  - `ctx and ctx.chord_mode_index or preferences_store.GetChordModeIndex()`
  - `ctx and ctx.root_index or preferences_store.GetRootIndex()`
  - `ctx and ctx.scale_index or preferences_store.GetScaleIndex()`
  - `ctx and ctx.octave or preferences_store.GetOctave()`
- When `ctx` is provided (keyboard temp_ctx, sequencer slot, pads slot), its values take precedence — same behavior as before
- When `ctx` is nil (pads.lua direct call), falls back to `preferences_store` instead of `config.state`
- Updated related comment: `-- Apply inversion (parameter takes precedence, fallback to preferences_store)`

#### 2.4 Verify zero config.state.* reads remain in runtime code outside src/config.lua
- Confirmed via comprehensive grep for `config.state` across all `src/` files
- Only references remaining are:
  - `config.lua` — definition + key_states initialization
  - `main.lua` — Init-time calls (`compact_store.Init(config.state)`, etc., `persist.Load(config.state)`, `preferences_store.SyncFromState(config.state)`) — these are one-time setup, not runtime reads
  - Comments/docs in AGENTS.md files and state-store header comments

#### 2.5 Append barrel-backward-compat to test_names in tests/run.lua
- Added `"barrel-backward-compat.lua"` to the `test_names` list after `test_preset_store.lua`
- The test file itself already exists at `tests/barrel-backward-compat.lua` (21 LOC, static-only barrel backward-compat check)
- No changes needed to the test file itself
- LICENSE already exists with proper MIT text
- SPDX `MIT` identifier present in all source file headers
- No changes needed

## Files Changed
| File | Action | What Was Done (PR #1) | What Was Done (PR #2) |
|------|--------|------------------------|------------------------|
| `AGENTS.md` (root) | Verified (minor) | Fixed AGENTS.md count | — |
| `src/AGENTS.md` | Modified | Added api-guard, delegation, remnants | — |
| `src/core/AGENTS.md` | Modified | Updated midi.lua LOC | — |
| `src/ui/AGENTS.md` | Modified (major) | 34 files, midi-island, piano-roll/*, etc. | — |
| `src/state/AGENTS.md` | Modified (major) | piano-roll-store, preset-store, preferences | — |
| `tests/AGENTS.md` | Modified | snap-tests, undo-tests, barrel-backward-compat | — |
| `src/core/midi.lua` | Modified | — | Removed `config.state` fallback in TriggerChord, replaced with `preferences_store.*` getters |
| `tests/run.lua` | Modified | — | Added `barrel-backward-compat.lua` to test_names |
| `openspec/changes/que-ves-incompleto/tasks.md` | Updated | Phase 1 tasks [x] | Phase 2 tasks [x] |
| `openspec/changes/que-ves-incompleto/apply-progress.md` | Updated | Created | Extended with PR #2 progress |

## Deviations from Design
None — implementation matches the tasks.

## Issues Found
- `tasks.md` had stale expected values in PR #1 (file counts 38→50 vs actual 57, LOC ~5,100 vs ~8,800, test count 382 vs 497). The actual AGENTS.md files were already more up to date.
- LICENSE already existed with proper MIT text — task 1.7 was pre-completed.
- No issues found in PR #2 — the grep confirmed `config.state.*` runtime reads had already been largely eliminated in previous refactors. Only the single `midi.lua:94` line remained.

## Remaining Tasks
- [ ] Phase 3: Velocity Editor (PR #3) — 3.1, 3.2, 3.3, 3.4

## Workload / PR Boundary
- Mode: chained PR slice (PR #2 of 3)
- Current work unit: State + Test
- Boundary: feature-branch-chain, PR #2 (Base = PR #1 branch)

## Status
12/12 tasks complete (PR #1: 7/7, PR #2: 5/5). Ready for verify.
