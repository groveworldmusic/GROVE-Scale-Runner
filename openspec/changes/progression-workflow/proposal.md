# Proposal: Progression Workflow

## Intent

The 16-slot progression has 10 mutation points but zero undo — every slot edit, swap, clear, or preset load is irreversible. Meanwhile, the v2 preset format already saves progression alongside notes but offers no way to save/load progression independently. Both gaps break the undo-safe, focused workflow users expect from a mature tool.

## Scope

### In Scope
1. **P1: Progression undo/redo** — 50-entry snapshot-based undo stack at the store level, hooking into `seq_store.SetProgressionEntry()`, `SetProgression()`, `ClearProgression()`. Ctrl+Z/Y routing becomes context-aware (progression vs piano-roll focus).
2. **P2: Progression-only save/load** — new `SavePresetProgression()`, `LoadPreset()` branching on type/extension, filter/badge UI in preset browser. Clears progression undo stacks on load (depends on P1).

### Out of Scope
- Piano-roll undo changes (existing 181 LOC untouched)
- Full preset format refactor (v2 already saves progression)
- Progression drag-and-drop reordering
- MIDI export of progression

## Capabilities

### New Capabilities
- `progression-undo`: Undo/redo for the 16-slot progression array. Snapshot-based (deep copy before mutation). 50-entry stack with FIFO eviction. Ctrl+Z/Y dispatch based on focus context (progression vs piano-roll).

### Modified Capabilities
- `undo-system`: Requirements expand to cover progression undo/redo alongside existing note undo/redo. Shared Ctrl+Z/Y shortcuts with context-aware routing. Preset load clears progression undo stacks (mirrors note `ClearUndoStacks()`).
- `preset-browser`: Requirements expand to include progression-only save/load. New file extension or type flag. `ScanDirectory()` scans both types. `LoadPreset()` branches on type — skips notes restoration for progression-only files.
- `keyboard-shortcuts`: Ctrl+Z/Y routing becomes context-aware. When progression is focused → progression undo; when piano-roll is focused → note undo. Unfocused → no-op (no crash).

## Approach

### P1 — Progression Undo
1. Add `prog_undo_stack`, `prog_redo_stack` to `sequencer.lua` store (max 50 each, FIFO eviction).
2. `ProgSnapshot()` deep-copies the 16-slot array via `{...}` per-entry copy.
3. Wrap the 3 store functions (`SetProgressionEntry`, `SetProgression`, `ClearProgression`) to push snapshot before mutation.
4. `ProgHandleUndo/Redo()` restore snapshot via `SetProgression()`. New edit after undo clears redo.
5. `ClearProgressionUndoStacks()` for preset load (called from `io.lua` `LoadPreset()`).
6. Keyboard dispatch: detect progression focus at `keyboard.lua` or `main.lua` level; route Ctrl+Z/Y accordingly.

### P2 — Progression-Only Save/Load
1. `IsValidPresetFile()` accepts `.grove-prog` extension. `ScanDirectory()` scans for both `.grove` and `.grove-prog`.
2. `SavePresetProgression()` serializes only progression[1..16] + context fields (root, scale, octave, chord_mode). No notes array.
3. `LoadPreset()` branches: `type == "progression"` → restore progression + context only, skip notes validation.
4. UI: filter tabs ("Notes" / "Progressions") or unified list with type badge in preset browser. "Save Progression" button alongside existing SAVE.
5. Clear progression undo stacks after load (uses P1 `ClearProgressionUndoStacks()`).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/state/sequencer.lua` | Modified | Add prog_undo_stack, prog_redo_stack, snapshot/undo/redo/clear functions |
| `src/ui/slots.lua` | Modified | Wrap mutation calls (remove, swap, add) with PushUndo |
| `src/ui/views.lua` | Modified | Wrap clear progression with PushUndo |
| `src/ui/docked.lua` | Modified | Wrap clear progression with PushUndo |
| `src/ui/midi-island.lua` | Modified | Wrap SyncNotesToProgression with PushUndo |
| `src/ui/preset-browser/io.lua` | Modified | New SavePresetProgression, LoadPreset branching, scan for both types |
| `src/ui/preset-browser/main.lua` | Modified | Filter tabs or type badges, "Save Progression" button |
| `src/core/keyboard.lua` | Modified | Context-aware Ctrl+Z/Y dispatch (progression vs piano-roll) |
| `src/ui/preset-browser.lua` | Modified | Re-export new functions from barrel |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Ctrl+Z conflict between piano-roll and progression undo | High | Focus-based dispatch in keyboard.lua; progression light-gray border = progression focus, else piano-roll |
| P2 loads progression but user expects notes restored too | Medium | UI type badge + button label "Save Progression" (not ambiguous "Save"). Load shows "Progression loaded" toast |
| P2 and Batch A (preset-browser-enhancements) both modify io.lua | Medium | Feature branch chain isolates changes; P2 built on top of Batch A's barrel if merged first |
| Undo snapshot performance at 50 entries × 16 slots | Low | Snapshot is cheap (~16 table copies). Piano-roll already handles 200+ note snapshots |

## Rollback Plan

- **P1**: Remove `prog_undo_stack`/`prog_redo_stack` fields, undo hooks, and keyboard dispatch branch. Revert to direct mutation at each of the 10 sites.
- **P2**: Remove `SavePresetProgression()`, revert `ScanDirectory()` and `LoadPreset()` branching, remove UI filter/badge code. All reverted per file — no schema changes.

## Dependencies

- None external. P2 depends on P1 (`ClearProgressionUndoStacks()` call).
- Potential sequencing conflict with Batch A (preset-browser-enhancements barrel) — both touch `io.lua`.

## Success Criteria

- [ ] P1: Every progression mutation (add, remove, swap, clear, preset load, note-sync) push an undo entry
- [ ] P1: Undo restores exact previous progression state; redo restores forward; new edit clears redo
- [ ] P1: 50-entry cap with FIFO eviction verified
- [ ] P1: Ctrl+Z/Y trigger progression undo when progression is focused, note undo otherwise
- [ ] P1: Empty progression undo stack is a no-op (no crash)
- [ ] P2: Users can save progression independently of notes as `.grove-prog` files
- [ ] P2: Load progression-only preset does not touch piano-roll notes
- [ ] P2: Preset browser shows/hides/filters by type correctly
- [ ] P2: Undo stacks clear after progression preset load
