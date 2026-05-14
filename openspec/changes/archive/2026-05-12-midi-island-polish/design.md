# Design: MIDI Island Polish

## Technical Approach

Eleven targeted fixes and visual polish items on existing MIDI island code. Each is a localized change — no new modules, no architectural shifts. All changes stay within the existing island UI files (`velocity.lua`, `piano-roll.lua`, `preset-browser.lua`, `timeline.lua`, `views.lua`) plus `island.lua` store for the velocity collapse state.

## Architecture Decisions

### 1. MUTED_BAR_COLOR crash fix

**Choice**: Use `theme.colors.island_note_muted` in velocity.lua. **Rationale**: Already exists in theme.lua, used identically in piano-roll.lua. Zero-cost fix, one line change.

### 2. Preset button rounded borders

**Choice**: Replace `gfx.rect` in `DrawActionButton` (preset-browser.lua) with `components.DrawRoundedRect`. **Alternatives**: Use `components.DrawButton` — rejected because it includes hover/press logic that conflicts with the existing event handling in `DrawPresetBrowser`. **Rationale**: Minimal diff, preserves existing mouse interaction flow.

### 3. Pitch labels on note blocks

**Choice**: Add `OctaveLabel()` call inside `DrawNoteBlock` (piano-roll.lua) when block width > 30px. Reuse the existing `OctaveLabel` helper (line 95-99). Increase reference font from 9 to 10. **Rationale**: Same function already exists and renders right — just not called inside blocks.

### 4. Horizontal scrollbar drag

**Choice**: Add module-local drag state to views.lua (analogous to `velocity.ResetDrag` pattern). On click over scrollbar thumb: capture `drag_scroll_start` + `drag_mouse_start`. On mouse move: `new_scroll = drag_scroll_start + (mouse_x - drag_mouse_start) / zoom_x`. On release: clear state. **Alternatives**: Push to island_store — rejected, drag state is frame-local (alive only during drag), same pattern as velocity.lua drag state. **Rationale**: Zero GC, no store pollution.

### 5. Slot notes cache dirty flag

**Choice**: Call `piano_roll.MarkNotesDirty()` immediately after `island_store.LoadNotesFromProgression(seq_store)` in views.lua line 577. **Rationale**: The piano-roll cache (`_last_note_count`, `_last_selected_idx`) skips redraw when count matches — after a reload the note table reference changes but count may be identical. One-line fix.

### 6. Overlapping velocity bars

**Choice**: Group notes by `start_beat` before drawing. Compute offset index per group; each overlapping note draws its bar shifted by `offset * (bar_height / max_overlap)` pixels from baseline. **Rationale**: Keeps all bars visible. The offset is computed per-frame in `DrawVelocityEditor` — no extra state needed.

### 7. Info bar right text +1px

**Choice**: Change line 854 from `island_x + island_w - rr - 8` to `island_x + island_w - rr - 9`. **Rationale**: Current margin overshoots by 1px due to `gfx.measurestr` rounding. Verified by inspection of pixel coordinates vs `gfx.drawstr` placement.

### 8. Timeline ruler corner overlap

**Choice**: Change the right-area background in views.lua to use `DrawRoundedRectEx` with only bottom corners rounded (`{bl=true, br=true}`). Remove the timeline's own `DrawRoundedRectEx` corner rounding — replace with a plain fill rect. **Rationale**: The double rounded rect at the top-left creates a visible shadow/overlap. By making the content area's top corners square (covered by the ruler), the ruler draws cleanly against it.

### 9. Preset divider line

**Choice**: Add a vertical line at the boundary between action buttons row and content below in `DrawPresetBrowser`. Use `DIVIDER_COLOR` (already defined). **Rationale**: Simple 1px decoration, no new colors or logic.

### 10. Velocity collapsible

**Choice**: Add `velocity_collapsed` boolean to island_store. Add a 6px drag handle at the bottom of the velocity editor. Click toggles collapse. `views.DrawMIDIIsland` reads the state to set `ve_h` to either `EDITOR_H` (80) or `COLLAPSED_H` (8, just the handle). **Rationale**: Minimal store addition (1 bool). Handle doubles as indicator and click target.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/velocity.lua` | Modify | Fix MUTED_BAR_COLOR, overlapping offset, collapse handle |
| `src/ui/piano-roll.lua` | Modify | Add pitch labels to note blocks, increase font |
| `src/ui/preset-browser.lua` | Modify | Rounded buttons, vertical divider line |
| `src/ui/views.lua` | Modify | Scrollbar drag, cache dirty flag, info bar +1px, corner overlap, velocity collapse height |
| `src/ui/timeline.lua` | Modify | Remove rounded rect overlap (no top-left corner rounding) |
| `src/state/island.lua` | Modify | Add `velocity_collapsed` getter/setter |

## Data Flow

### Horizontal scrollbar drag

```
Mouse click on thumb → capture {scroll_x, mouse_x}
         ↓
Mouse move (cap held) → delta = (mx - drag_mx) / zoom_x
                      → island_store.SetScrollOffsetX(drag_scroll + delta)
         ↓
Mouse release → clear drag state
```

### Velocity collapse toggle

```
Click on handle area → island_store.SetVelocityCollapsed(not GetVelocityCollapsed())
         ↓
Next frame → views reads GetVelocityCollapsed()
           → ve_h = collapsed ? COLLAPSED_H : EDITOR_H
           → velocity.DrawVelocityEditor uses ve_h for layout
```

## Interfaces / Contracts

```lua
-- island_store additions (state/island.lua)
function m.GetVelocityCollapsed() return island_state.velocity_collapsed end
function m.SetVelocityCollapsed(v) island_state.velocity_collapsed = v end
-- Default: false (expanded)
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | island_store.Get/SetVelocityCollapsed | Default false, round-trip |
| Visual | All 11 items | Manual visual inspection in REAPER with GFX debug overlay |

## Open Questions

- None. Every item has a clear 1-5 line change path verified against source.

## Migration / Rollout

No migration required. All new state has safe defaults.
