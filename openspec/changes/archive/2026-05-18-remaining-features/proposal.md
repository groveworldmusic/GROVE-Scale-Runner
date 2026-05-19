# Proposal: remaining-features

## Intent

Complete remaining P2/P3 work across arch-debt-sweep, progression-workflow, and expansion-features after all P1 features shipped. Five independent phases: progression dispatch hooks, progression-only presets, vkey-map configurables, MIDI input recording, arch-debt UI tests.

All changes affect the **main GFX window** (midi-island context). No compact panel changes.

## Scope

### In Scope
- **A**: Wire progression undo snapshots into progression.lua CRUD + Ctrl+Z/Y dispatch in midi-island
- **B**: Dual-ext preset browser (.grove / .grove-prog) with SaveProgressionPreset, filter tabs, type-aware list
- **C**: Runtime-configurable vkey map with remap modal overlay + gear button in header
- **D**: MIDI input recording via `MIDI_GetRecentInputEvent()`, record-arm toggle, Poll/Cleanup wiring
- **E**: UI tests (piano roll grid, preset I/O, drag detection) + runner registration

### Out of Scope
Color themes (done), preset barrel (done in code — arch-debt P2 checkbox stale), config.lua restructuring, performance tuning.

## Capabilities

### New Capabilities
None — all domain specs already exist in `openspec/specs/` from earlier exploration phases.

### Modified Capabilities
- `preset-browser`: Add `.grove-prog` extension, SaveProgressionPreset, Notes/Progression filter tabs, type-aware preset-list display
- `undo-system`: Add progression undo stack (`prog_undo_stack`), guard gate in `SetProgressionEntry`/`SetProgression`/`ClearProgression`, `ProgBeginComposite`/`EndComposite` for atomic transactions
- `keyboard-shortcuts`: Add progression context-aware Ctrl+Z/Y dispatch in midi-island, checked before piano-roll dispatch

## Approach

Sequential phases A→B→C→D→E. Each ships as a chained PR. A+B share progression domain; C+D independent (share only store/preference infra); E must be last (tests late-bound code). Phase D split into D1 (core+store) and D2 (UI+main) if D exceeds 400 LOC.

## Affected Areas

| Area | Impact |
|------|--------|
| `src/core/progression.lua` | Modified — composite wrap in Swap |
| `src/state/note-store.lua` | Modified — ProgPushUndo + UpdateOpenNoteDuration |
| `src/ui/midi-island.lua` | Modified — Ctrl+Z/Y context dispatch |
| `src/ui/preset-browser/io.lua` | Modified — dual-ext, SaveProgressionPreset |
| `src/ui/preset-browser/main.lua` | Modified — save button, filter tabs |
| `src/ui/preset-browser/preset-list.lua` | Modified — type filter param |
| `src/core/vkey-map.lua` | **New** |
| `src/core/keyboard.lua` | Modified — GetVKeyMap, RebuildKeyStates |
| `src/state/preferences.lua` | Modified — vkey_map_raw, vkey_map_modified |
| `src/state/persist.lua` | Modified — vkey_map_raw in PREF_KEYS |
| `src/config.lua` | Modified — vkey_map pref keys |
| `src/core/midi-input.lua` | **New** |
| `src/ui/midi-island/header.lua` | Modified — gear btn + record toggle |
| `src/main.lua` | Modified — midi_input.Poll + Cleanup |
| `tests/` | +3 test files, runner registration |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Swap double-snapshot (2 undo entries per swap) | Low | T2 is first — trivial `ProgBeginComposite` wrap |
| Guard gate polarity: `false` = snapshots active | Low | Doc comment on `prog_undo_gate`; only touched internally |
| Header overflow (gear + record + theme compete) | Medium | Trim PRESETS from 1.2× to 1.0× per design; validate pixel math |
| MIDI recording > 400 LOC | Medium | Split D1 (core+store) / D2 (UI+main) |
| test_note_store.lua name conflict w/ arch-debt scope | Low | Audit existing file; rename if content differs from P3 scope |

## Rollback Plan

Revert per-phase commits — no cross-phase coupling. D split means D1 ships independently if D2 is deferred. Phase E revert won't undo feature code (pure tests).

## Dependencies

None external. Phase ordering enforced in tasks. Delivery: chained PRs (sequential phases), overriding the earlier single-pr assumption — ~1,388 LOC violates the 400-line review budget.

## Success Criteria

- [ ] Ctrl+Z/Y undo/redo progression edits when `IsProgressionFocused()`; fall through to piano-roll otherwise
- [ ] `Swap()` produces single undo entry (not two)
- [ ] Save/load `.grove-prog` presets; persists across script reload
- [ ] Preset browser filters Notes vs Progression type
- [ ] Remap any VK via modal overlay; persists across reload
- [ ] Record-arm captures external MIDI input into piano roll notes
- [ ] No header clipping at any standard REAPER window width
- [ ] All 3 new test files (grid, I/O, drag) registered and passing in runner
