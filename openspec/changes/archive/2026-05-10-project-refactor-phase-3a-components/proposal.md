# Proposal: Project Refactor — Phase 3a (Decompose Components)

## Intent

Extract buttons, paginator and dropdown from components.lua into standalone modules. After Phase 2 (colors/format/progression), components.lua still sits at 830 lines with 14 public functions. This phase targets the 3 independent widget groups with zero cross-category coupling — reducing the file by ~249 lines while keeping consumer imports unchanged via barrel pattern.

## Scope

### In Scope
- `buttons.lua` — DrawButton, DrawTransportButton, DrawToolIcon, DrawNoteDisplay (~156 LOC)
- `paginator.lua` — DrawPaginator (~28 LOC)
- `dropdown.lua` — DrawDropdown (~65 LOC)
- Barrel pattern: components.lua re-exports all 3 modules
- Internal imports updated (buttons/paginator/dropdown require helpers, theme; components.lua requires the 3 new modules)

### Out of Scope
- DrawPianoKeyboard (Phase 3b)
- DrawScalePad, DrawSlot\*, DrawDragPreview (Phase 3c)
- DrawRoundedRect (stays as foundation re-export)
- DrawIsland (stays, 12 LOC)
- `PIANO_LAYOUT` / `DEGREE_KEY_LABELS` (move with piano)

## Capabilities

### New Capabilities
None — pure refactor, no new user-facing behavior.

### Modified Capabilities
None — all function signatures and behavior are preserved.

## Approach

**Barrel pattern**: each extracted module becomes a local table with functions. `components.lua` requires them and re-exports onto its own table. Consumers (`views.lua`, `compact.lua`) continue using `components.DrawButton(...)` — zero import changes.

```
src/ui/
├── components.lua   → re-exports buttons, paginator, dropdown + stays as DrawRoundedRect host
├── buttons.lua      → DrawButton, DrawTransportButton, DrawToolIcon, DrawNoteDisplay
├── paginator.lua    → DrawPaginator
├── dropdown.lua     → DrawDropdown (inline GetFitText → module-local)
```

Extraction order doesn't matter — zero interdependencies. The `GetFitText` closure in dropdown becomes module-local; grep-confirmed no external references.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/components.lua` | Modified | Remove ~249 lines, add 3 requires + re-exports |
| `src/ui/buttons.lua` | **New** | Button primitives (~156 LOC) |
| `src/ui/paginator.lua` | **New** | Paginator (~28 LOC) |
| `src/ui/dropdown.lua` | **New** | Dropdown (~65 LOC) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Import churn in consumers | Low | Barrel pattern → zero consumer changes |
| `GetFitText` external reference | Very Low | Grep confirms no external callers |
| Name collision with existing modules | Low | `buttons`, `paginator`, `dropdown` unused |
| Circular import (new modules → components for RoundedRect) | Low | Modules import helpers/theme directly; DrawRoundedRect stays in components |

## Rollback Plan

Revert by deleting the 3 new files and restoring components.lua from git. Single-commit extraction makes rollback atomic.

## Dependencies

- `helpers`, `theme` already external — no new deps needed
- `DrawRoundedRect` stays in components as shared foundation

## Success Criteria

- [ ] components.lua reduced by ~249 lines (830 → ~580)
- [ ] All 4 button functions, DrawPaginator, DrawDropdown work identically in main view and compact panel
- [ ] No consumer file requires the new modules directly
- [ ] `git diff --stat` shows 3 new files, 1 modified, 0 deletions
