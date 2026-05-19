# Proposal: DAW-Style Piano Roll

## Intent

Add 4 DAW piano roll features: grid hierarchy, note gradient + velocity opacity, vertical keyboard, and tool selector with lasso multi-select. Solves flat visuals, single-note selection limit, and no tool modes.

## Scope

**In Scope**: Grid hierarchy (4 opacity levels), note vertical gradient + velocity→alpha mapping, real black/white keyboard via PIANO_LAYOUT, 3-mode toolbar (pointer/pencil/eraser) + rectangle lasso multi-select.
**Out of Scope**: Shift+click additive selection (v2), note edge-drag resizing, MIDI recording/quantize, manual note save/load.

## Capabilities

### New Capabilities
None — all changes modify the existing `piano-roll` capability.

### Modified Capabilities
- `piano-roll`: Grid hierarchy, note gradient, vertical keyboard, tool selector (pointer/pencil/eraser), and lasso multi-select — delta spec covers all phases.

## Approach

4-phase implementation. P1–P3 isolated and independent. P4 is coupled (tool modes + multi-selection + lasso share state schema change).

| Phase | Feature | Files | Effort |
|-------|---------|-------|--------|
| 1 | Grid hierarchy | piano-roll.lua, timeline.lua, theme.lua | ~30m |
| 2 | Note gradient + velocity | piano-roll.lua | ~1h |
| 3 | Vertical keyboard | piano-roll.lua | ~2h |
| 4 | Tool selector + Lasso | piano-roll.lua, views.lua, island.lua, velocity.lua | ~5h |

P4 breaking change: `island_store.selected_note_index` (number\|nil) → `selected_indices` (table `{[idx]=true}`). Backward compat via `GetPrimarySelectedNoteIndex()` for velocity.lua and info bar.

## Affected Areas

| Area | Phase | Change |
|------|-------|--------|
| `src/ui/piano-roll.lua` | 1–4 | Grid line opacities, gradient note draw, keyboard strip replacement, lasso + tool routing |
| `src/ui/views.lua` | 4 | Tool selector buttons in MIDI island header, Delete key routing |
| `src/ui/velocity.lua` | 4 | Bulk velocity edit across all selected notes |
| `src/state/island.lua` | 4 | New state: selected_indices, lasso_active/start/end, tool_mode enum |
| `src/ui/theme.lua` | 1,4 | Grid hierarchy colors, lasso rect fill/border |
| `src/ui/timeline.lua` | 1 | Mirror grid hierarchy in beat tick rendering |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Single→multi selection breaks velocity.lua, info bar | Med | `GetPrimarySelectedNoteIndex()` compat shim returning last selected |
| Pencil notes vs progression notes collide on island reset | Med | Add `origin` field: `"progression"` / `"manual"` |
| Gradient perf: 3–4× rect calls per note | Low | 30 visible notes ≈ 120 rect calls — negligible at 60fps |
| Delete key undetectable in GFX | Med | `gfx.getchar()` non-blocking loop or VK map intercept |

## Rollback

P1–P3 revert individually — each phase touches isolated files. P4 reverts atomically (island.lua state schema + all consumers must revert together). No data migration needed since island state is ephemeral per session.

## Dependencies

P4 requires P3 (lasso coordinate math depends on keyboard row positions for hit testing). No external libraries; all REAPER GFX native.

## Success Criteria

- [ ] Grid renders 4 distinct opacity levels (measure/beat/1/8/1/16) matching DAW convention
- [ ] Note blocks have visible vertical gradient + velocity→alpha (35%–100%)
- [ ] Vertical keyboard shows real black/white key shapes matching PIANO_LAYOUT
- [ ] 3 tool modes cycle via header buttons; pencil adds notes, eraser removes on click
- [ ] Lasso draws visible rect during drag; notes inside become multi-selected on release
- [ ] Bulk operations (delete, mute, velocity) apply to all selected notes
- [ ] `GetPrimarySelectedNoteIndex()` returns correct value for velocity.lua and info bar
- [ ] All 382 existing tests pass — no regression on single-select path
