# Proposal: Piano Roll Bugs

## Intent

Fix 7 visual + interaction bugs in the MIDI island: pad drag activation without originating click, velocity overlapping note display, velocity editing missing pre-selected note, note rendering artifacts (seams and overshoot), horizontal scroll notes bunching at keyboard strip, velocity click clearing piano roll selection, and ghost note same bunching issue.

## Scope

### In Scope
- Bug 1: Pad drag hitbox too permissive (`pads.lua`)
- Bug 2: Velocity overlapping notes display side-by-side instead of stacked (`velocity.lua`)
- Bug 3: Velocity editing targets hit-test result over pre-selected note (`velocity.lua`)
- Bug 4: Note rendering artifacts in `DrawRoundedRect` + velocity dim overlay (`components.lua`, `note.lua`)
- Bug 5: Horizontal scroll notes bunching at left keyboard strip boundary (`note.lua`)
- Bug A: Velocity click clears piano roll selection (`velocity.lua`)
- Bug B: Muted note velocity label visual inconsistency (`velocity.lua`)
- Bug C: Ghost notes same bunching as Bug 5 (`note.lua`)

### Out of Scope
- New features or capabilities
- MIDI sequencer engine changes
- Keyboard interaction changes
- Compact view changes
- Preset browser changes

## Capabilities

### Modified Capabilities
- `velocity-editor`: Offset overlapping bars → stack at same X (Bug 2); hit test uses pre-selected note when available (Bug 3); preserve piano roll selection on velocity click instead of clearing (Bug A)
- `piano-roll`: Clip boundary changed from `x - PITCH_LABEL_W` to `x` for notes AND ghost notes (Bug 5, C)

## Approach

All fixes are local, small changes in 4 files. No refactors or new abstractions:

| Bug | File | Strategy |
|-----|------|----------|
| 1 | `pads.lua:59-77` | Gate drag initiation with `ui_store.GetMouseClick()` (fresh down-transition) before setting `PendingDegree` |
| 2 | `velocity.lua:192-210` | Remove `offset_map` application, render all notes at same beat at same X |
| 3 | `velocity.lua:387` | Check `GetPrimarySelectedIndex()` before hit test; use selected index when valid |
| 4 | `components.lua:50-56,118-128` | Remove `+1` overshoots in opaque rects; replace `gfx.rect` in velocity dim overlay with `DrawRoundedRect` call |
| 5 | `note.lua:208-209` | Change `x - grid.PITCH_LABEL_W` to `x` in clip boundary |
| A | `velocity.lua:396-398` | Don't clear selection on velocity click; only update selected note's velocity |
| C | `note.lua:179-180` | Same fix as Bug 5 for ghost note clip boundary |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/pads.lua` | Modified | Bug 1: Add fresh-click gate |
| `src/ui/velocity.lua` | Modified | Bugs 2, 3, A, B: Stack bars, pre-selected hit, preserve selection, muted label |
| `src/ui/components.lua` | Modified | Bug 4: Remove +1 overshoot in DrawRoundedRect + DrawRoundedRectEx |
| `src/ui/piano-roll/note.lua` | Modified | Bug 4 (velocity dim overlay), Bug 5 + C (clip boundary) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Bug 1 gate too restrictive — drag stops working for normal use | Low | Test all drag scenarios; gate fires on fresh click only, subsequent frames skip |
| Bug 2 stacked bars become visually indistinguishable | Low | Use z-order render (last-drawn wins); selected vs unselected color distinction |
| Bug 4 removed +1 creates 1px gaps in rounded rects | Low | Verify visually; the +1 was the bug, not the feature |
| Regression in piano scroll behavior | Low | Clip boundary change is 2 characters; test left-edge note rendering |

## Rollback Plan

Revert individual changes per file. Each fix is isolated — no cross-file dependencies. No migration or state changes.

## Dependencies

None.

## Success Criteria

- [ ] Pad drag only activates when click originated on the pad (drag from outside ignored)
- [ ] Velocity bars at same beat render stacked at same X (no side-by-side offset)
- [ ] Velocity editing targets pre-selected note from piano roll when one is selected
- [ ] No visible seams, valleys, or +1 overshoot artifacts in rounded rects or note blocks
- [ ] Notes scroll off-screen left without bunching at keyboard strip boundary
- [ ] Clicking a velocity bar does NOT clear piano roll multi-selection
- [ ] All existing tests pass (497 checks)
