# Proposal: MIDI Island Professional — Core Editor Upgrade

## Intent

Transform the MIDI island from a "progression viewer" into a genuine MIDI editor. The island has grid rendering, selection, and velocity editing, but lacks the three foundational features that define a professional piano roll: note move/resize, snap grid control, and undo/redo. The piano-roll monolith (1022 LOC) is the primary architectural bottleneck.

## Scope

### In Scope
- Split piano-roll.lua into 4 sub-modules (grid-renderer, note-block, keyboard-strip, interaction)
- Fix ToggleIsland: resize GFX window instead of destroy/recreate (eliminates visual flash)
- Note move: click-drag to change pitch (Y) and start_beat (X)
- Note edge-drag resize: grab right edge to change duration
- Snap grid: toggle button + resolution selector (1/1, 1/2, 1/4, 1/8, 1/16, 1/32, triplet)
- Undo/redo: command pattern with 50-deep stack for all edit operations
- Keyboard shortcuts: Ctrl+Z (undo), Ctrl+Y (redo), Delete (delete selected), arrows (nudge)

### Out of Scope
- MIDI CC lanes (modulation, expression, etc.) — deferred
- Quantize — deferred, depends on snap infrastructure
- Note preview audio — deferred
- Copy/cut/paste clipboard — deferred
- Fold to scale — deferred
- Ghost notes / multi-clip — deferred
- Step input / MIDI recording — deferred
- Arpeggiator panel — deferred

## Capabilities

### New Capabilities
- `note-move-resize`: Drag notes to new pitch/time. Edge-drag to change duration. Snap-aware.
- `snap-grid`: Toggle snap on/off. Resolution selector. Snap indicator in UI. Centralized `SnapBeat()` pure function.
- `undo-system`: Command pattern. 50-deep stack. Covers: add, delete, move, resize, velocity change, mute toggle.
- `keyboard-shortcuts`: Ctrl+Z/Y for undo/redo. Delete key for removal. Arrow keys for nudge.

### Modified Capabilities
- `piano-roll`: Grid rendering + interaction split into 4 sub-modules (refactored, not new behavior). DrawNoteBlock extracted. Hit-testing centralized.
- `island-store`: Add `GetSnapEnabled()`, `GetSnapResolution()`, undo stack fields. Selection indices remain unchanged.
- `velocity-editor`: Velocity changes now push undo entries. No spec-level behavior change — only implementation.

## Approach

**Phased Hybrid** (3 sprints):

| Sprint | Deliverables | Risk |
|--------|-------------|------|
| 1 | Split piano-roll → 4 sub-modules. Fix ToggleIsland → gfx resize. Add barrel module. | Medium — regression on every interaction point |
| 2 | Note move/resize. Snap grid control. Centralized `SnapBeat()`. | Medium — coordinate transform complexity |
| 3 | Undo/redo command pattern (50-deep). Keyboard shortcuts (Ctrl+Z/Y, Del, arrows). | Low-Medium — well-understood pattern |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/piano-roll.lua` | Removed (split) | 1022 LOC → 4 sub-modules in `src/ui/piano-roll/` |
| `src/ui/views.lua` | Modified | Scrollbar drag, mouse routing → move into piano-roll modules |
| `src/core/midi.lua` | Modified | ToggleIsland: gfx.init args change, no gfx.quit |
| `src/state/island.lua` | Modified | Snap state + undo stack fields |
| `src/ui/velocity.lua` | Modified | Push undo entries on velocity change |
| `src/ui/theme.lua` | Modified | Snap indicator colors, undo button icon colors |
| `src/ui/timeline.lua` | Modified | Fix progress sync (absolute beats vs per-measure) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Piano-roll refactor regression | Medium | Tag pre-refactor. Write batch hit-test tests before split. Verify each interaction post-split. |
| Undo memory with large note counts | Low | 50 max depth. Shallow diff snapshots, not full array copies. |
| Snap-edge cases (pencil, lasso, timeline) | Medium | Centralize `SnapBeat()`. All tools call same function. Unit test edge cases. |
| GFX resize instability on REAPER <6.x | Low | Test on supported REAPER versions. Fall back to destroy-recreate if resize fails. |
| Note move/resize + lasso interaction | Medium | Lasso disabled during drag. Drag commit clears lasso state. |

## Rollback Plan

- **Per-sprint revert**: each sprint is a self-contained PR. Revert the PR.
- **Pre-refactor tag**: `git tag refactor/piano-roll-pre-split` before Sprint 1.
- **ToggleIsland fallback**: if gfx resize fails on any REAPER version, re-enable destroy-recreate path behind a config flag.

## Dependencies

- REAPER GFX API: gfx.init resize behavior (tested on REAPER 6.x/7.x)
- `SnapBeat()` must not break existing pencil snap (currently hardcoded half-beat)
- Undo system requires no data model change — notes remain flat array with 1-based indices

## Success Criteria

- [ ] Piano-roll renders identically before and after split (visual diff)
- [ ] Note drag changes pitch and position, snap-aware, updates selection
- [ ] Note resize via edge-drag changes duration, minimum 1 subdivision
- [ ] Snap toggle hides/shows grid lines, affects all note creation/move
- [ ] Resolution selector changes snap granularity (test: 1/1, 1/4, 1/16, triplet)
- [ ] Ctrl+Z undoes last operation, Ctrl+Y redoes, across all edit types
- [ ] Delete key removes selected notes with undo support
- [ ] ToggleIsland resizes window without visual flash or context loss
- [ ] Existing 382 tests pass, plus new tests per sprint
