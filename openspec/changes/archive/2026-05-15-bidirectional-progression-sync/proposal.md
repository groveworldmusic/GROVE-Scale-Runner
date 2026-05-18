# Proposal: Bidirectional Progression Sync

## Intent

Eliminate data loss between progression slots (sequencer input) and piano-roll notes (visual canvas). Manual piano-roll edits set `notes_dirty=true` which permanently blocks progression reload. There is no way to sync edits back to progression slots — edits are ephemeral, lost on island reopen.

## Scope

### In Scope
- `SyncNotesToProgression()` — degree detection via nearest scale degree heuristic
- "Sync to Progression" button in midi-island header (RELOAD button already exists from Approach A)
- Replace `notes_dirty` boolean with 3-state enum: `LOADED_FROM_PROGRESSION`, `USER_EDITED`, `SYNCED_TO_PROGRESSION`
- `progression_revision` audit — verify all `SetProgressionEntry` call sites increment revision
- Extract scrollbar drag state (`_sb_dragging`, `_vsb_dragging`) from module locals into `island_store`
- Fix `pcall(reaper.GetResourcePath, preset_dir)` no-op (arg order) in preset-browser
- Migration: treat existing `notes_dirty=true` sessions as `USER_EDITED`

### Out of Scope
- Architecture extraction (Approach C) — premature
- Note preview on hover, numeric velocity input, beat numbers overlay
- GC optimization, spatial index for notes

## Capabilities

### New Capabilities
- `bidirectional-progression-sync`: sync piano-roll notes to progression slots with nearest-degree detection

### Modified Capabilities
- `note-store`: add `SyncNotesToProgression()` public function with degree heuristic
- `island-store`: add scrollbar drag state fields (`sb_dragging`, `vsb_dragging`); replace `notes_dirty` boolean with `notes_state` enum

## Approach

1. Add `SyncNotesToProgression()` to note-store — group notes by `start_beat`, detect degree via nearest pitch in current scale, write back to sequencer_store
2. Add "Sync to Progression" button in midi-island header, adjacent to existing "Reload from Progression"
3. Replace `notes_dirty` with `notes_state` enum in island-store, transition: `LOADED` → `EDITED` on any note mutation → `SYNCED` on sync button click
4. Audit all `SetProgressionEntry` call sites (progression.lua, preset-browser.lua) — confirm revision increment
5. Move `_sb_dragging`, `_vsb_dragging` from `midi-island.lua` module scope into `island_store` getters/setters
6. Fix `pcall(reaper.GetResourcePath, preset_dir)` → `pcall(reaper.GetResourcePath)` in preset-browser — current call passes preset_dir as second arg to a function that takes none

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/state/note-store.lua` | Modified | Add SyncNotesToProgression() |
| `src/state/island.lua` | Modified | Add scrollbar drag state; notes_dirty → notes_state enum |
| `src/state/sequencer.lua` | Modified | Revision audit (guard against silent mutation) |
| `src/ui/midi-island.lua` | Modified | Module locals → store; revision check on sync |
| `src/ui/midi-island/header.lua` | Modified | Add Sync to Progression button |
| `src/ui/preset-browser.lua` | Modified | Fix pcall arg order |
| `src/core/progression.lua` | Modified | Revision counter check |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Degree detection maps wrong degree for ambiguous chords | Medium | Nearest-match heuristic; user can always use sequencer input |
| notes_dirty migration breaks existing sessions | Low | Migration path: treat `notes_dirty=true` as `USER_EDITED` |
| Scrollbar drag extraction regresses behavior | Low | Same logic, state moved to store — verify mouse release resets |

## Rollback Plan

- Each change independently revertible
- Remove `SyncNotesToProgression` + button if degree detection produces wrong degrees
- Revert `notes_state` to boolean if enum causes issues

## Dependencies

None.

## Success Criteria

- [ ] Editing piano-roll notes then clicking "Sync to Progression" updates 16 progression slots to match
- [ ] Clicking "Reload from Progression" (existing) reloads notes from current progression
- [ ] `notes_state` correctly transitions: `LOADED` → `EDITED` (on any note mutation) → `SYNCED` (on sync button)
- [ ] All `SetProgressionEntry` call sites increment progression revision
- [ ] Scrollbar drag state survives island collapse/reopen without stale state
- [ ] `pcall(reaper.GetResourcePath, ...)` no longer silently succeeds as no-op
