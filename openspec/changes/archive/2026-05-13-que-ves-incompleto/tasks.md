# Tasks: Que ves incompleto

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 500-700 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR #1 → PR #2 → PR #3 |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Sync AGENTS.md (6 files) + add LICENSE | PR #1 | Base = feature/tracker branch. Largest diff (~300-400 lines). Self-contained docs + legal. |
| 2 | Eliminate dual state access + wire barrel test | PR #2 | Base = PR #1 branch. Small diff, low risk, builds on docs context. |
| 3 | Complete velocity editor | PR #3 | Base = PR #2 branch. Riskiest — investigate first, fix or remove. |

## Phase 1: Docs + Legal (PR #1)

- [x] 1.1 Sync root `AGENTS.md` — verified all counts accurate (53 Lua + 4 AGENTS.md = 57 src files, ~8,800 TLOC, 9 state stores, 7 core modules, 34 UI modules, 497 check() calls, 14 test files in runner). Dependency map and issue registry already current.
- [x] 1.2 Sync `src/AGENTS.md` — added api-guard require step to Init order, updated delegation table, added 10-key remnant list matching root. All module counts already correct.
- [x] 1.3 Sync `src/core/AGENTS.md` — updated midi.lua LOC (220→232). All function signatures already correct (InvertChord, GetMidiChannel, SetMidiChannel, force param in AllNotesOff, TriggerChord 5 params, api-guard, snap).
- [x] 1.4 Sync `src/ui/AGENTS.md` — major update: header 25→34 files, ~3,350→~6,342 LOC. Added midi-island.lua, icons.lua, gfx-safe.lua to file map. Added piano-roll/* 6 sub-modules (grid, interaction, note, undo, clipboard, view). Updated barrel pattern, GFX conventions, dependencies, cross-references.
- [x] 1.5 Sync `src/state/AGENTS.md` — major update: added piano-roll-store (426 LOC), preset-store (72 LOC), preferences (81 LOC) to store overview + API docs. Updated island LOC (233→136). Fixed remnant keys from 6→10 with explanation of prefs_store migration status. Added new stores to mutable table warnings and cross-store deps.
- [x] 1.6 Sync `tests/AGENTS.md` — added snap-tests.lua (286 LOC, 89 check()), undo-tests.lua (345 LOC, 94 check()), barrel-backward-compat.lua (21 LOC, 0 check, static-only) to file inventory. Updated coverage table: 6→9 state stores, added snap.lua and piano-roll-store rows. Added LOC column to inventory.
- [x] 1.7 Verify root `LICENSE` — already exists with proper MIT text matching SPDX `MIT` identifier in source file headers. No action needed.

## Phase 2: State + Test (PR #2)

- [x] 2.1 Audit all `config.state.*` runtime reads — comprehensive grep across all `src/` files. **Result**: only 1 runtime read remnant found: `src/core/midi.lua:94` — `local c = ctx or config.state` in `TriggerChord`. All other matches are AGENTS.md docs, state-store header comments, or Init-time setup in `main.lua` (`store.Init(config.state)`, `persist.Load(config.state)`, `preferences_store.SyncFromState(config.state)`). The 10 remnant keys in `config.state` defaults are no longer read at runtime outside `config.lua` itself.
- [x] 2.2 Migrate each read in `views.lua`, `compact-*.lua`, `piano.lua`, `keyboard.lua` — **Result**: zero `config.state.*` runtime reads found in any of these files. They already use `preferences_store.*` getters. No migration needed.
- [x] 2.3 Remove `local c = ctx or config.state` fallback in `src/core/midi.lua` — `TriggerChord` (line 94). Replaced with individual `preferences_store.GetChordModeIndex()`, `GetRootIndex()`, `GetScaleIndex()`, `GetOctave()` calls. When `ctx` is provided (keyboard/sequencer/slots), its values take precedence via `ctx and ctx.key or prefs_store.GetKey()` pattern.
- [x] 2.4 Verify zero `config.state.*` reads remain in runtime code outside `src/config.lua` — confirmed via grep. Only references remaining are: `config.lua` (definition + key_states init), `main.lua` (Init-time store Init + persist.Load + SyncFromState calls), and comments/docs in AGENTS.md + state store headers.
- [x] 2.5 Append `barrel-backward-compat` to `test_names` list in `tests/run.lua` — added after `test_preset_store.lua`.

## Phase 3: Velocity Editor (PR #3)

- [x] 3.1 Investigate `ve_h = 0` at `src/ui/midi-island.lua:343` — git blame, check commit for disable reason
- [x] 3.2 Fix root cause or document blocked status; set `ve_h` to appropriate active height value
- [x] 3.3 Verify `src/ui/velocity.lua` is render-ready — syntax check, function signatures match render pipeline
- [x] 3.4 Wire velocity.lua into midi-island render pipeline — add draw call, integrate click-drag handlers
