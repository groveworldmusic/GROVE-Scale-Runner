# Proposal: Address Priority Technical Debt

## Intent

Four isolated fixes completing the store migration, fixing a layer violation, and reducing duplicated state — zero new features.

## Scope

| In | Out |
|----|-----|
| Fix `config.state` fallback in TriggerChord (midi.lua:101, sequencer.lua:90) | Full piano-roll refactor |
| Move `slots.lua` from `core/` to `ui/` | GFX abstraction layer |
| Split `piano-roll-store.lua` → `note-store.lua` | views.lua island extraction |
| Consolidate island/preset-store overlap | Config.state migration beyond TriggerChord |

## Capabilities

### New
- `note-store`: note CRUD + undo/redo state management

### Modified
- None (pure refactor — no spec-level behavior changes)

## Approach

1. **Config.state fix**: Import `preferences_store` in midi.lua + sequencer.lua. Replace `config.state.inversion_index` → `prefs.GetInversionIndex()` and `config.state.subdivision_index` → `prefs.GetSubdivisionIndex()`.
2. **Slots move**: File move + update `components.lua` require path. No code changes.
3. **Piano-roll split**: New `note-store.lua` gets note CRUD/UUID/undo-redo. `piano-roll-store.lua` keeps selection/lasso/viewport/zoom/tool/drag/snap/island-transition. Update 6 consumers (interaction.lua, note.lua, undo.lua, grid.lua, view.lua, velocity.lua).
4. **Island/preset**: Remove 9 duplicate preset fields from island.lua. Add delegation getters that read from `preset_store`. Update `preset-browser.lua` → use `preset_store` directly.

## Affected Areas

| Area | Change |
|------|--------|
| `core/midi.lua` | 2 lines |
| `core/sequencer.lua` | 1 line |
| `core/slots.lua` → `ui/slots.lua` | Move |
| `ui/components.lua` | Require path |
| `state/piano-roll-store.lua` | −250 LOC |
| `state/note-store.lua` | New (+250 LOC) |
| `state/island.lua` | −9 fields + delegation |
| `ui/preset-browser.lua` | Import: island → preset store |
| `ui/piano-roll/*` (6 files) | Import updates |
| AGENTS.md (4 files) | Path update |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Slots lazy require path breaks | Low | Single `components.lua` path change |
| Preset browser breaks | Med | Map every `island_store.*` call to `preset_store.*` in preset-browser.lua |
| Piano-roll imports wrong | Med | 497 test checks catch broken requires |
| Store init ordering | Low | prefs_store inits before midi require (main.lua order) |

## Rollback

4 revertible commits per item. Any item can be rolled back independently.

## Dependencies

None. All 4 items operate on separate files with no ordering constraints.

## Success Criteria

- [ ] `grep "config.state" midi.lua sequencer.lua` → zero hits
- [ ] `slots.lua` in `ui/`, removed from `core/`
- [ ] `piano-roll-store.lua` < 250 LOC; `note-store.lua` exists
- [ ] `island.lua` has zero `current_directory`/`preset_root`/`preset_tree`/etc. field definitions
- [ ] Test suite: 497 checks pass
- [ ] Piano roll note editing + undo/redo works in REAPER
