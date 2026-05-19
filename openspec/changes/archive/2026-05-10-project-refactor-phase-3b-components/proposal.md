# Proposal: Project Refactor — Phase 3b (Piano, Pads, Slots, Drag)

## Intent

After Phase 3a extracted buttons/paginator/dropdown, `components.lua` still sits at 592 lines. This phase extracts the remaining 4 independent widget groups: piano keyboard, scale pads, progression slots, and drag preview. Target: reduce `components.lua` from 592 to ~60 LOC (pure barrel + DrawRoundedRect + DrawIsland).

## Scope

### In Scope
- `piano.lua` — `PIANO_LAYOUT`, cached scale notes, `DrawPianoKeyboard` (~124 LOC)
- `pads.lua` — `DrawScalePad` (~114 LOC), `DEGREE_KEY_LABELS` (used only by DrawScalePad)
- `slots.lua` — `DrawSlotBackground`, `DrawSlotLabel`, `HandleSlotInteraction`, `DrawProgressionSlot` (~170 LOC)
- `drag.lua` — `DrawDragPreview` (~87 LOC)
- Barrel re-exports in `components.lua`
- Internal imports in new modules (require `config`, `theme`, `helpers`, `colors`, `format`, `midi`, `progression`)

### Out of Scope
- `DrawRoundedRect` — stays in `components.lua` (called from `views.lua`, `compact.lua`)
- `DrawIsland` — stays (12 LOC)
- All functions extracted in Phase 2 (colors/format/progression) and Phase 3a (buttons/paginator/dropdown)
- `main.lua` — already indirectly references everything through `components.*`

## Capabilities

### New Capabilities
None — pure refactor, no new user-facing behavior.

### Modified Capabilities
None — all function signatures and behavior are preserved.

## Approach

**Barrel pattern** (same as Phase 3a): each extracted module uses `local m = {}; return m`. `components.lua` requires and re-exports them. Zero consumer changes.

**Cross-reference note**: `DEGREE_KEY_LABELS` is referenced only in `DrawScalePad` (not in piano). Moving it to pads.lua is cleaner than importing piano.lua from pads. Grouped under piano conceptually but lives with its consumer.

**PR split** (2 chained PRs, validated against 400-line review budget):

| PR | Modules | Est. LOC | Est. Delta |
|----|---------|---------|-----------|
| 3b-a | `piano.lua` + `pads.lua` | ~248 | ~496 |
| 3b-b | `slots.lua` + `drag.lua` | ~267 | ~534 |

> Note: LOC = source lines, Delta = additions + deletions. Each PR creates ~2 new files + modifies `components.lua`. Both PRs fit the 400-line budget within margin of error (±10%).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/components.lua` | Modified | Remove ~524 lines, add 4 requires + re-exports |
| `src/ui/piano.lua` | **New** | Piano keyboard (~124 LOC) |
| `src/ui/pads.lua` | **New** | Scale pads (~114 LOC), DEGREE_KEY_LABELS |
| `src/ui/slots.lua` | **New** | Progression slots (~170 LOC) |
| `src/ui/drag.lua` | **New** | Drag preview (~87 LOC) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| DEGREE_KEY_LABELS cross-ref (used by pads, grouped with piano) | Low | Move constant to pads.lua, its sole consumer |
| Drag preview cleanup reads stale config.state.drag | Low | HandleSlotInteraction clears drag state before DrawDragPreview runs each frame |
| Import churn in consumers | Very Low | Barrel pattern → zero consumer changes |
| Circular import (new modules → components for RoundedRect) | Low | Modules import helpers/theme/colors directly; DrawRoundedRect stays in components |

## Rollback Plan

Per-PR rollback (independent due to chained PRs):
- **PR 3b-a**: delete `piano.lua`, `pads.lua`; restore `components.lua` from git.
- **PR 3b-b**: delete `slots.lua`, `drag.lua`; restore `components.lua` from git.

Each PR is a single-commit extraction — rollback is atomic.

## Dependencies

- No new external dependencies
- New modules depend on: `config`, `theme`, `helpers`, `colors`, `format`, `midi`, `progression` (all already external from Phase 2/3a)
- `DrawRoundedRect` stays in `components.lua` — new modules call it via the `components` parameter or direct require

## Success Criteria

- [ ] components.lua reduced from 592 to ~60 LOC (barrel + DrawRoundedRect + DrawIsland)
- [ ] All 4 widget groups render identically in main view and compact panel
- [ ] Drag-from-pad → drop-on-slot works identically (cross-module via config.state.drag)
- [ ] Drag-from-slot → swap works identically
- [ ] Piano keyboard click changes root note identically
- [ ] No consumer file requires the new modules directly (access through `components.*`)
- [ ] `git diff --stat` shows 4 new files, 1 modified, 0 deletions (per PR cumulative)
