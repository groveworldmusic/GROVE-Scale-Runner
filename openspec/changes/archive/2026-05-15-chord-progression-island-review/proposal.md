# Proposal: Chord Progression Island — Targeted Bug Fixes

## Intent

The Chord Progression Island subsystem has 8 bugs, 7 gaps, and 6 quality issues from a full system review (see `exploration.md`). This sprint fixes the highest-impact issues with surgical precision — no architecture changes. Dead config writes, duplicated logic, platform-unsafe IO, stale markers, missing UX affordances, and a per-frame O(N) scrollbar scan are the targets.

## Scope

### In Scope
1. Fix `GetSelectionCount` duplication in `velocity.lua` → use `island_store.GetSelectionCount()`
2. Remove dead `config.state.*` triple-writes in `views/islands.lua`
3. Fix lasso right-edge precision — add epsilon in `note.lua` pixel→beat conversion
4. Add "force reload from progression" button in midi-island header (bypass `notes_dirty`)
5. Cache `total_beats` in midi-island scrollbar, invalidate on note mutation
6. Migrate preset-browser directory listing from `io.popen` to `lfs`
7. Clean stale investigation markers (`ve_h=0`, `dragged`) from root `AGENTS.md`

### Out of Scope
Bidirectional progression↔notes sync (Approach B), architecture extraction (Approach C), note preview on hover, numeric velocity input, beat overlays, paint duration selector, undo stack depth, GC optimization, lasso visual clipping fix, knife split feedback.

## Capabilities

**None** — pure bug-fix/cleanup sprint with no spec-level behavior changes.

### New Capabilities
None

### Modified Capabilities
None

## Approach

Surgical edits (~250 lines across 7 files), each independently revertible:

1. **`velocity.lua`**: delete inline `sel_count` loop → call `island_store.GetSelectionCount()`
2. **`views/islands.lua`**: strip `config.state.* = choice` lines; keep prefs + persist calls
3. **`note.lua:301`**: add `epsilon = 0.0001` to `beat_end` pixel→beat conversion
4. **`midi-island/header.lua`**: add "Reload" button; handler calls `LoadNotesFromProgression` skipping dirty check with confirmation prompt
5. **`midi-island.lua`**: module-local `_total_beats` cache; `_invalidate_total_beats()` called in add/remove/clear/paste/split paths
6. **`preset-browser.lua`**: replace `io.popen('dir ...')` with `lfs.dir()` + `lfs.attributes()`; `pcall` guard fallback
7. **`AGENTS.md`**: remove stale "INVESTIGATING" markers for resolved issues

## Affected Areas

| File | Impact | What |
|------|--------|------|
| `src/ui/velocity.lua` | Modified | Fix duplicated GetSelectionCount |
| `src/ui/views/islands.lua` | Modified | Remove dead config.state.* writes |
| `src/ui/piano-roll/note.lua` | Modified | Add epsilon to beat_end |
| `src/ui/midi-island.lua` | Modified | total_beats cache + invalidation |
| `src/ui/midi-island/header.lua` | Modified | Add Reload button |
| `src/ui/preset-browser.lua` | Modified | io.popen → lfs |
| `AGENTS.md` (root) | Modified | Clean stale markers |

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| lfs unavailable in REAPER environment | Low | `pcall` guard + fallback to io.popen |
| total_beats cache stale after edge-case mutation | Low | Trace all mutation call sites; verify invalidation |
| Reload button destroys manual edits with no undo | Low | Add confirmation prompt before reload |

## Rollback Plan

Each fix is a single-hunk edit. Revert by file: `git checkout -- <file>`. The header button is the only new UI element — revert if unwanted.

## Dependencies

- `lfs` (LuaFileSystem): present in most REAPER installs, guarded with `pcall`.

## Success Criteria

- [ ] `velocity.lua` no longer has inline selection count logic — calls store function
- [ ] `grep "config\.state\.\w*_index" views/islands.lua` returns zero matches
- [ ] Lasso selects notes at far-right grid edge correctly
- [ ] Reload button visible in island header; clicking it reloads from progression with confirmation
- [ ] Scrollbar `total_beats` computed once per mutation batch, not every frame
- [ ] `preset-browser.lua` lists directories without `io.popen`
- [ ] `AGENTS.md` has no stale "INVESTIGATING" markers
