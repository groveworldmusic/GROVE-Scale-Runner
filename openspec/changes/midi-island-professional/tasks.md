# Tasks: MIDI Island Professional

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~2,200 (3 sprints) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1a → PR1b → PR2 → PR3 (feature-branch-chain) |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1a | Grid + Note module split | PR1a → tracker | ~600 LOC, base = `feature/midi-island-professional` |
| 1b | Interaction + View + ToggleIsland | PR1b → PR1a | ~450 LOC, base = PR1a branch |
| 2 | Snap + Note move/resize | PR2 → PR1b | ~250 LOC, base = PR1b branch |
| 3 | Undo/redo + keyboard shortcuts | PR3 → PR2 | ~250 LOC, base = PR2 branch |

---

## Sprint 1 — Module Split & ToggleIsland Resilience

### PR 1a: Grid + Note extraction

- [x] 1.1 Create `src/ui/piano-roll/grid.lua` — Extract `PITCH_ROW_H`, `ComputeVisibleRanges`, beat grid lines, pitch rows, scrollbar from monolith
- [x] 1.2 Create `src/ui/piano-roll/note.lua` — Extract `DrawNoteBlock`/`DrawNoteBlocks`, `NoteBlockHitTest`, `GetNotesInRect`, `MarkNotesDirty`, dirty cache
- [x] 1.3 Modify `src/ui/piano-roll.lua` → barrel re-exporting grid.lua + note.lua functions, remove extracted code
- [x] 1.4 Tests: barrel backward compat (all exported functions delegate correctly, views.lua call sites unchanged, visual rendering pixel-identical)

### PR 1b: Interaction + View + ToggleIsland

- [ ] 1.5 Create `src/ui/piano-roll/interaction.lua` — Extract `HandleMouseClick`, `HandleRightClickMute`, `HandlePencilClick`, `HandleEraserClick`, `DrawLassoRect`, `HandleMouseWheel*`, `HandleZoom*`, `SetPitchRowH`, shift-click additive, Ctrl+A select-all
- [ ] 1.6 Create `src/ui/piano-roll/view.lua` — `DrawPianoRoll` coordinator: compute visible ranges, call grid/note/lasso, draw scrollbar
- [ ] 1.7 Update barrel `piano-roll.lua` — add interaction + view exports, remove remaining extracted code
- [ ] 1.8 Modify `src/core/midi.lua` — `ToggleIsland()`: save `_pre_toggle_dock`/`_pre_toggle_rect` before `gfx.quit()`, restore font + clear flag after `gfx.init()`
- [ ] 1.9 Modify `src/state/island.lua` — Add `island_transition_in_progress`, `pre_toggle_dock`, `pre_toggle_rect` fields + getters/setters
- [ ] 1.10 Tests: shift-click additive scenarios (toggle selection, select without shift clears), Ctrl+A select-all/toggle, ToggleIsland resilience (`transitioning` flag lifecycle, pre_toggle_rect saved)

---

## Sprint 2 — Snap Grid + Note Move/Resize

- [ ] 2.1 Modify `src/state/island.lua` — Add `snap_enabled`, `snap_resolution`, `snap_triplet`, `note_drag_active`, `note_drag_indices`, `note_drag_start_pitch`, `note_drag_start_beat`, `note_drag_origin_mx`, `note_drag_origin_my`, `note_resize_edge` fields + getters/setters
- [ ] 2.2 Create `src/core/snap.lua` — `SnapBeat(beat, resolution, triplet)` pure function, zero side effects, returns identity when disabled
- [ ] 2.3 Modify `src/ui/piano-roll/interaction.lua` — Add `HandleNoteDrag` (pitch+beat delta, snap-aware, multi-note group move, undo push on commit) + `HandleNoteResize` (4px right-edge zone, min 1 subdivision, snap-aware) + Escape cancel
- [ ] 2.4 Modify `src/ui/piano-roll/grid.lua` — Grid line filtering to active snap tier when snap enabled
- [ ] 2.5 Modify `src/ui/views.lua` — Add snap toggle button + resolution dropdown in island header
- [ ] 2.6 Modify `src/ui/theme.lua` — Add snap indicator colors
- [ ] 2.7 Tests: `SnapBeat()` all 7+3 resolutions + 0/negative edge cases, note move coordinate math (inverted Y, snap on drop), multi-note relative offset preservation

---

## Sprint 3 — Undo/Redo + Keyboard Shortcuts

- [ ] 3.1 Modify `src/state/island.lua` — Add `undo_stack` (max 50, FIFO), `redo_stack`, `next_note_uuid` counter, `undo_depth`, `redo_depth` fields + `PushUndo()`, `PopUndo()`, `PushRedo()`, `PopRedo()`, `ClearUndoStacks()`, `GetUndoDepth()`, `GetRedoDepth()` functions
- [ ] 3.2 Add `note.uuid` to all note creation paths (pencil tool, ProgressionToNotes) — monotonic counter, UUID lookup via reverse index
- [ ] 3.3 Modify `src/ui/piano-roll/interaction.lua` — On drag commit, push undo entry; add keyboard shortcut dispatch (Ctrl+Z/Y → undo/redo, Delete → remove selected, arrows → nudge by snap unit/1 semitone, Shift+arrow → nudge 1 beat/12 semitones)
- [ ] 3.4 Modify `src/ui/velocity.lua` — On velocity drag release, push undo entry via `island_store.PushUndo()`
- [ ] 3.5 Modify `src/ui/views.lua` — Wire Ctrl+Z/Y detection, unhandled keys fall through to REAPER
- [ ] 3.6 Tests: undo/redo cycle all 6 edit types (add, delete, move, resize, velocity, mute), stack overflow eviction, new edit clears redo, shallow capture verification; keyboard: Ctrl+Z/Y, Delete, arrows, Shift+arrows, empty stack no-op, unhandled key fall-through
