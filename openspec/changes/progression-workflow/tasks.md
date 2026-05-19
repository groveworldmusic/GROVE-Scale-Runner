# Tasks: Progression Workflow

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~259 |
| 400-line budget risk | Low |
| Chained PRs recommended | Yes (P1→P2 dependency) |
| Suggested split | PR 1: P1 Undo/Redo (~92), PR 2: P2 Progression Presets (~167) |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Base |
|------|------|-----------|------|
| 1 | Progression Undo/Redo (P1) | PR 1 | feature/tracker branch |
| 2 | Progression-Only Presets (P2) | PR 2 | PR 1 branch |

## Phase 1: Foundation — Store Layer (P1)

- [x] **T1: Add undo/redo stacks + guard + 5 functions to `src/state/sequencer.lua`** — Add `prog_undo_stack`, `prog_redo_stack`, `MAX_UNDO=50`, `prog_undo_gate=false`. Implement `PushProgUndo()` (FIFO, evict at 51), `PopProgUndo()`, `PushProgRedo()`, `PopProgRedo()`, `ClearProgUndoStacks()`, `ProgSnapshot()`, `HandleProgUndo()`, `HandleProgRedo()`. Guard-wrap `SetProgressionEntry`, `SetProgression`, `ClearProgression` to snapshot when gate is open (`if not prog_undo_gate`). (~85 LOC — merged T1+T2+T3+T4 from apply scope)

## Phase 2: Core Integration — Dispatch (P1)

- [ ] **T2: Wire progression CRUD into snapshot chain in `src/core/progression.lua`** — Add `seq_store.ProgPushUndo()` call at top of `progression.Add()`, `Remove()`, `Swap()`, `Clear()`. `Swap()` wraps the two `SetProgressionEntry` calls in `ProgBeginComposite()`/`ProgEndComposite()` to prevent double snapshot. (~15 LOC)
- [ ] **T3: Add Ctrl+Z/Y context-aware dispatch in `src/ui/midi-island.lua`** — Before the collapsed-island early return, check `char==346` (Ctrl+Z) / `char==345` (Ctrl+Y). When `IsProgressionFocused()` returns true (mouse in perf area + island collapsed), call `seq_store.ProgHandleUndo()`/`ProgHandleRedo()`. Otherwise fall through to existing piano-roll dispatch. Add `_perf_area_top/bottom` caches updated by `DrawPerformanceArea`. (~20 LOC)
- [ ] **T4: Hook SyncNotesToProgression in `src/state/note-store.lua`** — At the top of `SyncNotesToProgression()` (before any `SetProgressionEntry` call), add `seq_store.ProgPushUndo()` to snapshot pre-sync state. (~2 LOC)

## Phase 3: Progression-Only Presets (P2)

- [ ] **T5: Add dual-ext scanning + SaveProgressionPreset + LoadPreset branching** — Modify `src/ui/preset-browser/io.lua`: extend `IsValidPresetFile` to accept `.grove` and `.grove-prog`; update `ScanDirectory` to collect both with `type` field; add `SaveProgressionPreset(file_path, name)` (serializes only `progression[1..16]` + context keys, no notes); update `LoadPreset` to branch on `result.type == "progression"` (restore progression + context, skip notes validation, call `ClearProgressionUndoStacks()`). Add `GetPresetFilePath` variant for `.grove-prog`. (~75 LOC)
- [ ] **T6: Add "Save Progression" button + filter tabs in preset-browser UI** — Modify `src/ui/preset-browser/main.lua`: add "Save Progression" button adjacent to SAVE with same name-input pattern; add "Notes" / "Progression" filter tabs at top of file list; tabs set active filter type, file list displays only matching `type` entries; update `preset-browser.lua` (monolithic barrel at root) to re-export new functions. (~90 LOC)
- [ ] **T7: Update preset list rendering for type-aware display** — Modify `src/ui/preset-browser/preset-list.lua`: accept `type_filter` param, filter/display based on `entry.type`; show type badge or subtle indicator per row. (~2 LOC)

## Phase 4: Testing

- [x] **T8: Test P1 — undo/redo stacks, guard gate, FIFO eviction, keyboard dispatch** — Verify ProgSnapshot captures full 16-slot snapshot; HandleProgUndo/HandleProgRedo restore via SetProgression; FIFO eviction at 51; redo clear on new edit; guard gate prevents double-snapshot; empty stack no-op; ClearProgUndoStacks idempotent. (~83 assertions in `tests/test_progression_undo.lua`). Keyboard dispatch tests deferred to PR #2.
- [ ] **T9: Test P2 — save/load `.grove-prog`, scan dual-ext, branch behavior** — Verify SaveProgressionPreset creates `.grove-prog` with no notes key; ScanDirectory returns both types with correct `type` field; LoadPreset on `type=="progression"` restores only progression + context; malformed `.grove-prog` shows error; ClearProgressionUndoStacks called after load. (~30 assertions)
