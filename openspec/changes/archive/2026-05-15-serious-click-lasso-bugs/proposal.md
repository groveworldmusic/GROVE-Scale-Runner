# Proposal: serious-click-lasso-bugs

## Intent

Lasso selection in the MIDI island piano roll is broken on multiple fronts: mouse-up finalization is silently skipped by a stale guard that runs first, the GFX redraw system never fires during lasso drags (freezing the rect visually), and `fresh_click` detection fails when right-click was held the previous frame. These bugs make the piano roll selection feel broken or unresponsive.

## Scope

### In Scope

- **Bug 1 (CRITICAL)**: Reorder stale lasso guard after finalization code in `midi-island.lua`. Guard at lines 215-217 clears `lasso_active` before the finalization block at lines 549-573 can read it on mouse-up.
- **Bug 2 (HIGH)**: Add `lasso_active` check to the dirty-flag block in `main.lua`. During a lasso drag (mouse held, moving) no state toggle triggers redraw, freezing the rect on screen.
- **Bug 3 (LOW)**: Fix `fresh_click` bitmask in `main.lua:265` — use `(ui_store.GetLastMouseCap() & 1) == 0` instead of `ui_store.GetLastMouseCap() == 0` to handle right-click-held case.
- **Bug 4 (NICE-TO-HAVE)**: Add `ConsumeMouseClick()` after successful click+handler matches in raw handlers across `views.lua`, `pads.lua`, `piano.lua`, `dropdown.lua`, `paginator.lua`.

### Out of Scope

- Refactoring the click dispatch architecture — direct fixes only.
- New selection features (multi-touch, gesture-based, etc.).
- Changes to the lasso behavioral spec (lasso already has spec coverage in piano-roll and selection specs).
- Test framework changes.

## Capabilities

### New Capabilities

None — this is a bug-fix change. No new user-facing behavior is introduced.

### Modified Capabilities

None — existing specs (`piano-roll`, `selection`) already describe correct lasso behavior. The bugs are implementation deviations being corrected.

## Approach

| Bug | File | Fix |
|-----|------|-----|
| 1 | `src/ui/midi-island.lua` | Move stale guard (lines 215-217) after finalization block (lines 549-573), OR delete the guard and handle staleness inside finalization by checking `(gfx.mouse_cap & 1)==1` before updating end position |
| 2 | `src/main.lua` | Add `if island_store and island_store.GetLassoActive and island_store.GetLassoActive() then gfx_needs_redraw = true end` to dirty-flag block (~line 270) |
| 3 | `src/main.lua` | Change `ui_store.GetLastMouseCap() == 0` to `(ui_store.GetLastMouseCap() & 1) == 0` on line 265 |
| 4 | `src/ui/views.lua`, `pads.lua`, `piano.lua`, `dropdown.lua`, `paginator.lua` | Add `ui_store.ConsumeMouseClick()` after each `GetMouseClick()` read that results in a handled click action |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/midi-island.lua` | Critical | Stale guard ordering kills lasso finalization |
| `src/main.lua` | High | Missing redraw flag + broken fresh_click bitmask |
| `src/ui/views.lua` | Low | ~14 raw GetMouseClick handlers missing ConsumeMouseClick |
| `src/ui/pads.lua` | Low | 1 missing consume (line 141) |
| `src/ui/piano.lua` | Low | 1 missing consume (line 163) |
| `src/ui/dropdown.lua` | Low | 1 missing consume (line 65) |
| `src/ui/paginator.lua` | Low | 1 missing consume (line 39) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Deleting guard removes REAPER-focus-loss protection | Low | Handle staleness inside finalization block instead; finalization with `gfx.mouse_cap & 1 == 1` as active-lasso condition |
| ConsumeMouseClick breaks widgets that read the event bus in sequence | Low | Each widget already checks its own hover rect — consume after handling ensures no double-fire |
| Wrong lasso rect rendered for one frame during guard/finalization swap | Low | Stale guard after finalization means mouse-up frame correctly computes selection before clearing |
| Right-click context menu affected by fresh_click fix | Very Low | fresh_right_click has its own bitmask check — independent from fresh_click |

## Rollback Plan

Revert each file individually:
- `midi-island.lua`: Move stale guard back before finalization (or restore the guard if deleted)
- `main.lua`: Remove lasso_active redraw check; restore `== 0` comparison on line 265
- `views.lua`, `pads.lua`, `piano.lua`, `dropdown.lua`, `paginator.lua`: Remove added ConsumeMouseClick() calls

No migration or data changes needed — state model is unchanged.

## Dependencies

None. All fixes are self-contained within the affected files.

## Success Criteria

- [ ] **Bug 1 fixed**: Lasso drag → mouse-up → notes inside rect become selected (verified by observing `selected_indices` and visual highlight)
- [ ] **Bug 2 fixed**: During lasso drag (mouse held + moving), lasso rect updates each frame without stutter
- [ ] **Bug 3 fixed**: After right-click context menu dismiss, next left-click on piano roll correctly triggers selection
- [ ] **Bug 4 fixed**: No regression in button/dropdown/pad click behavior — each handler fires once per click
- [ ] Existing selection behavior preserved: single-click select, shift-click additive, Ctrl+A select-all
