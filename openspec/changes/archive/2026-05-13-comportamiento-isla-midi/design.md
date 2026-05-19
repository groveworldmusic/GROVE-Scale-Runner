# Design: Comportamiento Isla MIDI — Bug Fixes

## Technical Approach

Batch by layer, each independently verifiable by static analysis. No behavioral changes — every fix preserves existing contract with a corrected edge case. Order matters for state deps: state layer first (stores need init fields), then consumers (UI/core use those fields).

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|-------------|-----------|
| MAX_UNDO scope | `local` in island.lua | Config constant | Only undo stack needs it; keeps change local |
| folder_scroll ownership | island_state + getter/setter | Local var in browser | Persists across DrawMIDIIsland calls, survives redraw |
| Height constants | Local in midi.lua | Config.lua | Matches existing `config.script_title` pattern; avoids touching config.lua |
| Pencil snap-off | Remove fallback branch | Return raw beat | Direct, zero overhead, matches user expectation |
| Scrollbar clamp | `math.min` on bar position | Clamp ratio pre-multiplication | More explicit, matches existing `math.max` clamping pattern |

## Data Flow

```
island_state ←── Init() ←── config.state
     │
     ├── PushUndo/PopUndo ←── interaction.lua (Ctrl+Z/Y)
     ├── ClearUndoStacks ←── preset-browser.lua (LoadPreset)
     ├── folder_scroll ←── DrawFolderList (read/write per frame)
     └── _uuid_to_idx ←── AddNote/RemoveNoteAtIndex/RebuildUUIDIndex

views.lua ── shift_held ──→ interaction.HandleMouseClick

grid.lua: ComputeVisibleRanges cache
    cache_key = {scroll_y, scroll_x, zoom_x, w, h, PITCH_ROW_H}
    ↑ new field
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/state/island.lua` | Modify | Add `MAX_UNDO=50`, init `undo_stack/redo_stack/undo_depth/redo_depth` in island_state, add `folder_scroll=0`, add `local _uuid_to_idx` declaration, add folder_scroll getter/setter |
| `src/ui/preset-browser.lua` | Modify | AllocNoteUUID in LoadPreset loop, ClearUndoStacks after SetNotes, read/write folder_scroll in DrawFolderList call |
| `src/ui/views.lua` | Modify | Pass `(gfx.mouse_cap & 32) ~= 0` to HandleMouseClick; clamp HSB/VSB thumb position |
| `src/ui/piano-roll/interaction.lua` | Modify | Remove half-beat snap in pencil when snap_res<=0 (line 154) |
| `src/ui/piano-roll/grid.lua` | Modify | Add `m.PITCH_ROW_H` to `_cache` comparison + store |
| `src/ui/piano-roll/view.lua` | Modify | Clamp VSB thumb `bar_y` so `bar_y + bar_h ≤ vsb_y + vsb_h` (line 63) |
| `src/ui/piano-roll/note.lua` | Modify | Clamp `pitch_high` with `math.min(MAX_PITCH, ...)` |
| `src/ui/velocity.lua` | Modify | Remove unused `local base_initial_vel` (line 353) |
| `src/core/midi.lua` | Modify | Replace 793/497 with local `EXPANDED_H`/`COLLAPSED_H` constants |

## Interfaces / Contracts

### New island_store API

```lua
-- island.lua
m.GetFolderScroll() → number
m.SetFolderScroll(v) → void  -- math.max(0, v or 0)
```

### Updated interaction.HandleMouseClick signature

```lua
-- Before: no shift_held param → selection always clears
-- After: shift_held=true → additive toggle
function m.HandleMouseClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x, shift_held)
```

### Changed internal constants

```lua
-- midi.lua
local COLLAPSED_H = 497
local EXPANDED_H = 793
-- usage: local new_h = midi.midi_island_expanded and EXPANDED_H or COLLAPSED_H
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Static | C1-C2: island_state has stack fields | Verify island_state table init block |
| Static | C3: `local _uuid_to_idx` | Verify `local` keyword on first use |
| Static | C4: UUIDs in LoadPreset | Verify `n.uuid = island_store.AllocNoteUUID()` in loop |
| Static | C5: shift_held passed | Verify `(gfx.mouse_cap & 32)` in views.lua call, `shift_held` consumed in HandleMouseClick |
| Static | C6: PITCH_ROW_H in cache | Verify cache compare includes `m.PITCH_ROW_H` |
| Static | C7: folder_scroll stored | Verify SetFolderScroll called after DrawFolderList |
| Static | W1-W2: thumb inside track | Verify `math.min` clamp on bar position |
| Static | W4: ClearUndoStacks called | Verify call after SetNotes in LoadPreset |
| Static | W5: pitch_high clamped | Verify `math.min(MAX_PITCH, ...)` |
| Static | W6: heights from consts | Verify 793/497 not in literal form |
| Static | S2: no snap when off | Verify `snapped_beat = beat` (no fallback) when snap_res<=0 |
| Static | S4: dead code removed | Verify `base_initial_vel` not in file |

## Migration / Rollback

No migration required. Rollback: revert commits in reverse order — layout (midi.lua) → visual (view/note.lua) → interaction (interaction/grid.lua) → presets (preset-browser.lua) → state (island.lua).

## Open Questions

None.
