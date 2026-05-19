# Design: MIDI Island Professional — Core Editor Upgrade

## Technical Approach

3-sprint hybrid: refactor first (reduce coupling), then add features (move/resize + snap), then polish (undo + shortcuts). Piano-roll monolith (1022 LOC) splits into 4 modules + barrel to isolate concerns. Note identity via UUID for undo stability. ToggleIsland keeps `gfx.quit()+gfx.init()` but adds full state preservation.

## Architecture Decisions

| Decision | Options | Choice | Rationale |
|----------|---------|--------|-----------|
| Split granularity | 3, 4, 5 modules | **4 + barrel** | Grid, note, interaction, view — aligns with existing render/event separation. Barrel preserves backward compat for `views.lua` consumers. |
| Module dependency direction | Any | **view → interaction → note → grid** | Grid is leaf (constants, compute, draw). View is coordinator. No circular deps. Interaction depends on note (hit test) and grid (constants). |
| Undo note identity | Index-based, UUID, snapshot | **UUID on each note** | Index breaks on insert/delete. UUID is O(1) lookup with reverse index. Minimal data addition — `note.uuid` set on creation. |
| Undo storage model | Full snapshots, diff, command | **Command pattern with before/after per note** | Proposal mandates shallow diff, not full copies. UUID references keep commands compact (2-4 fields per note). |
| Undo stack depth | 25, 50, 100 | **50** | Per proposal. 50 × command size (~200 bytes) = ~10KB worst case. Negligible. |
| Snap resolution storage | String, number index | **Number** (subdivisions per whole note: 4=quarter, 8=eighth, 16=sixteenth) | Direct math: `step = 4 / resolution`. Triplet flag separate. No string parsing needed. |
| Note move edge-zone width | 4px, 6px, 8px | **8px** | Matches existing drag threshold pattern in slots.lua. Wide enough for mouse, narrow enough not to conflict with selection. |
| ToggleIsland pattern | Keep quit+init, Window resize API | **Keep quit+init** | User constraint. Add pre-quit state capture: dock mode, window rect, active font. Store in dedicated island vars (not compact_store). |
| Mute undo grouping | Per-note, batch | **Batch as single command** | Right-click mute toggles ALL selected notes. One undo entry covers the batch. |

## Data Flow

```
Sprint 1 — Module split:

views.lua ──► piano-roll.lua (barrel)
               ├── piano-roll-grid.lua    ← DrawPianoRollGrid, keyboard strip
               ├── piano-roll-note.lua    ← DrawNoteBlock/Blocks, hit test, GetNotesInRect
               ├── piano-roll-interaction.lua ← click/pencil/eraser/lasso/zoom/scroll
               └── piano-roll-view.lua    ← DrawPianoRoll (coordinator entry)

Sprint 2 — Note move/resize + snap:

Mouse down ──► interaction.HandleNoteDrag
                │  (8px threshold → drag start)
                ├── Move: update pitch (Y) + start_beat (X) in island_store
                ├── Resize: detect edge zone → change duration
                └── Drop: commit via note_uuids, push undo entry
                             │
SnapBeat(beat, resolution) ──► pure function
  Used by: pencil, drag-drop, timeline seek
  Reads: island_store.GetSnapEnabled(), GetSnapResolution()

Sprint 3 — Undo/redo:

Edit → undo_stack.push({type, note_uuids, before, after})
         ├── Ctrl+Z → pop → undo() → redo_stack.push
         ├── Ctrl+Y → pop → redo() → undo_stack.push
         └── Delete → pop selection → undo_stack.push
```

## File Changes

| File | Action | LOC Est | Description |
|------|--------|---------|-------------|
| `src/ui/piano-roll.lua` | Modify → barrel | ~50 | Re-exports all 4 sub-modules. Preserves `PITCH_ROW_H`, `SetPitchRowH`, all public functions. |
| `src/ui/piano-roll/piano-roll-grid.lua` | Create | ~380 | Grid bg, pitch rows, beat lines, keyboard strip. Exports: `DrawPianoRollGrid`, `ComputeVisibleRanges`, `PITCH_ROW_H` et al, keyboard helpers. |
| `src/ui/piano-roll/piano-roll-note.lua` | Create | ~180 | Note blocks, hit testing, dirty cache. Exports: `DrawNoteBlock`, `DrawNoteBlocks`, `NoteBlockHitTest`, `GetNotesInRect`, `MarkNotesDirty`. |
| `src/ui/piano-roll/piano-roll-interaction.lua` | Create | ~200 | Mouse event handlers, lasso, zoom/scroll. Exports: `HandleMouseClick`, `HandleRightClickMute`, `HandlePencilClick`, `HandleEraserClick`, `DrawLassoRect`, `HandleMouseWheel*`, `HandleZoom*`, `SetPitchRowH`, `HandleNoteDrag`, `HandleNoteResize`. |
| `src/ui/piano-roll/piano-roll-view.lua` | Create | ~60 | Coordinator: `DrawPianoRoll` entry point. Computes visible ranges, calls grid/note/lasso, draws scrollbar. |
| `src/core/midi.lua` | Modify | ~20 lines changed | ToggleIsland: save dock+rect pre-quit, `_island_transition_flag`, restore font post-init. |
| `src/state/island.lua` | Modify | ~+40 fields | Add: snap state, drag state, undo/redo stacks, transition flag, note UUID counter. |
| `src/ui/velocity.lua` | Modify | ~+10 lines | On drag release, push undo entry via `island_store.PushUndo()`. |
| `src/ui/views.lua` | Modify | ~+30 lines | Snap toggle button + resolution dropdown in island header. Ctrl+Z/Y detection. Keyboard shortcut dispatch. |
| `src/ui/theme.lua` | Modify | ~+3 colors | Snap indicator, undo button, edge-zone hint colors. |

## State Changes (island_store)

### Sprint 1 — ToggleIsland resilience
| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `island_transition_in_progress` | bool | false | Set before `gfx.quit()`, cleared after `gfx.init()` + first frame render. |
| `pre_toggle_dock` | number | -1 | Saved `gfx.dock(-1)` value before quit. |
| `pre_toggle_rect` | table | nil | `{l, t, r, b}` from `JS_Window_GetRect()`. |

### Sprint 2 — Snap + Note move/resize
| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `snap_enabled` | bool | true | Global snap toggle. |
| `snap_resolution` | number | 4 | Subdivisions per whole note: 1/2/4/8/16/32. |
| `snap_triplet` | bool | false | Triplet grid (1/8t = 12 subdivisions per whole). |
| `note_drag_active` | bool | false | Note drag in progress (MUST disable lasso, pencil, eraser). |
| `note_drag_indices` | table | {} | Indices of dragged notes (all selected during multi-drag). |
| `note_drag_start_pitch` | number | 0 | Pitch at drag start (for delta). |
| `note_drag_start_beat` | number | 0 | Beat at drag start (for delta). |
| `note_drag_origin_mx` | number | 0 | Mouse x at drag start. |
| `note_drag_origin_my` | number | 0 | Mouse y at drag start. |
| `note_resize_edge` | bool | false | True when dragging right edge of note. |

### Sprint 3 — Undo/redo
| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `undo_stack` | table | {} | Array of commands, max 50. Each: `{type, uuids[], before[], after[], timestamp}`. |
| `redo_stack` | table | {} | Array of commands, max 50. |
| `next_note_uuid` | number | 1 | Monotonic counter for new notes. |
| `undo_depth` | number | 0 | Current stack depth (cached). |

New store functions: `PushUndo(command)`, `PopUndo()`, `PushRedo(command)`, `PopRedo()`, `ClearUndoStacks()`, `GetUndoDepth()`, `GetRedoDepth()`.

## Interfaces

```lua
-- Pure function: snap beat to grid
-- @param beat number Raw beat
-- @param resolution number Subdivisions per whole note (1/2/4/8/16/32)
-- @param triplet boolean
-- @return number snapped_beat
function SnapBeat(beat, resolution, triplet) end

-- Note command structure (Sprint 3)
-- {
--   type: "add"|"delete"|"move"|"resize"|"velocity"|"mute",
--   uuids: {number, ...},       -- note UUIDs affected
--   before: {{field=val,...}},   -- per-note before state
--   after: {{field=val,...}},    -- per-note after state
-- }

-- ToggleIsland (Sprint 1 resilience)
-- Before: save dock, rect, font
-- After: restore font, clear transition flag
function midi.ToggleIsland()
    midi._pre_toggle_dock = gfx.dock(-1)
    local l,t,r,b = reaper.JS_Window_GetRect(gfx.hwnd)
    midi._pre_toggle_rect = {l, t, r, b}
    island_store.SetIslandTransitioning(true)
    gfx.quit()
    gfx.init(config.script_title, 720, new_h,
             midi._pre_toggle_dock, l or gs.x, t or gs.y)
    gfx.setfont(1, "Calibri", 16)
    island_store.SetIslandTransitioning(false)
end
```

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Unit | `SnapBeat()` | Pure function — test all 7 resolutions + triplet + edge cases (0, negative). |
| Unit | `ProgressionToPitch()` | Already tested incidentally. No new tests needed. |
| Unit | Note move coordinate math | Verify pitch/beat deltas translate correctly, inverted Y, snap on drop. |
| Integration | Barrel backward compat | Each public function in barrel delegates to correct sub-module. All `views.lua` call sites unchanged. |
| Integration | Undo/redo cycles | Push → undo → redo → verify state equals original. Test all 6 edit types. |
| Integration | ToggleIsland resilience | Verify `pre_toggle_rect` saved before quit, `transitioning` flag lifecycle. |
| Manual | Note drag edge zones | 8px threshold, right-edge resize, multi-note drag. Requires REAPER GFX for pixel accuracy. |
| Manual | GFX window resize | Verify no visual flash, correct position restore. Test REAPER 6.x and 7.x. |

## Rollback Strategy

- **Sprint 1**: Revert PR. Tag `refactor/piano-roll-pre-split` exists. Old `piano-roll.lua` preserved in git.
- **Sprint 2**: Revert PR. New store fields safe to leave (unused after revert). `SnapBeat()` is pure — unused if revert.
- **Sprint 3**: Revert PR. Undo stacks on island_store are no-ops if keyboard shortcuts module not loaded.
- **ToggleIsland**: If `gfx.init()` position restore fails on any REAPER version, fall back to default positioning (remove position args from `gfx.init()` with `pcall` guard).
