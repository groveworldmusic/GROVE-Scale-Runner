# Proposal: Comportamiento Isla MIDI — Bug Fixes

## Intent

7 critical bugs crash the MIDI island or break core features: undo crashes (MAX_UNDO, nil stacks), undo broken after preset load, shift+click multi-select non-functional, render corruption after vertical zoom, unscrollable folders. Fix these plus 6 high-priority warnings/suggestions.

## Scope

### In Scope
1. **State** (C1-C3): MAX_UNDO const, undo_stack/redo_stack init, local _uuid_to_idx
2. **Presets** (C4, C7, W4): UUIDs on LoadPreset, ClearUndoStacks, folder scroll state
3. **Interaction** (C5, C6, S2, S4): shift_held arg, PITCH_ROW_H cache key, pencil snap-off, dead code
4. **Visual** (W1-W2, W5): scrollbar thumb bounds, lasso pitch_high clamp
5. **Layout** (W6): derived window heights from constants

### Out of Scope
C8, W3, W7, W8, S1/S3/S5-S10

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `midi-island`: W6 — height derivation via constants (delta spec)
- `piano-roll`: S2 — pencil snap-off behavior (delta spec)
- `undo-system`: C4/W4 — preset-load clears undo stack (delta spec)

## Approach

Batch by layer, independently verifiable:
1. **State** (`island.lua`): `local MAX_UNDO=50`, stack fields in island_state, `local _uuid_to_idx`
2. **Presets** (`preset-browser.lua`): AllocNoteUUID in LoadPreset, ClearUndoStacks, folder_scroll state
3. **Interaction** (`views.lua`+`interaction.lua`+`grid.lua`): shift_held arg, cache key including PITCH_ROW_H, no snap when snap≤0, rm base_initial_vel
4. **Visual** (`view.lua`+`note.lua`): `h - sb_h` track math, `math.min(MAX_PITCH, …)`
5. **Layout** (`midi.lua`): Local consts matching 793/497

## Affected Areas

`src/state/island.lua` | `src/ui/preset-browser.lua` | `src/ui/views.lua` | `src/ui/piano-roll/interaction.lua` | `src/ui/piano-roll/grid.lua` | `src/ui/piano-roll/view.lua` | `src/ui/piano-roll/note.lua` | `src/ui/velocity.lua` | `src/core/midi.lua`

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| UUID assign breaks old presets | Low | Missing UUID → alloc on load |
| Height const mismatch | Low | Match existing 793/497 values |

## Rollback

Revert commits in reverse batch order: layout → visual → interaction → presets → state.

## Dependencies

None.

## Success Criteria

- C1-C2: Undo never crashes
- C3: `_uuid_to_idx` is `local`
- C4: Undo works after LoadPreset
- C5: Shift+click toggles selection
- C6: V-zoom invalidates cache
- C7: Folder list scrolls
- W1/W2: Thumbs inside track
- W4: ClearUndoStacks called
- W5: pitch_high ≤ MAX_PITCH
- W6: Heights from consts
- S2: Snap off = no snap
- S4: Dead code removed
