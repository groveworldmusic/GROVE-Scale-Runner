# Proposal: MIDI Island — Header Icons, Save/Load, Scale Snap, Polish

## Intent

Replace header text labels with icons, add SAVE/LOAD buttons, highlight scale pitches on grid, relocate triplet to context menu, fix velocity height, enlarge PRESETS/BEATS titles, persist window position, fix scroll clipping. All UI/UX refinements.

## Scope

**In**: All 9 items. **Out**: No new capabilities.

## Capabilities — Modified

| Spec | Items | Delta |
|------|-------|-------|
| `midi-island` | 1, 2, 8 | Header icons, save/load buttons, window pos persist |
| `piano-roll` | 3, 9 | Scale snap highlight, scroll clipping fix |
| `snap-grid` | 3, 4 | Scale snap mode, triplet in context menu |
| `timeline-ruler` | 7 | Larger BEATS title, numbers below ticks |
| `velocity-editor` | 5 | Fixed height from constants |
| `preset-browser` | 2, 6 | Save/load header buttons, larger titles |

**New**: None.

## Approach

1. **Icons**: `buttons.lua` uses `DrawIcon` vs inline unicode. Shrink containers.
2. **SAVE/LOAD**: Add toolbar buttons, wire to `preset_browser.SaveAs()` / `LoadSelected()`.
3. **Scale snap**: Toggle in `preferences_store`. `grid.lua` highlights scale pitch lines.
4. **Triplet menu**: Remove button. Add separator + toggle to resolution `gfx.showmenu`.
5. **Velocity height**: Use `COLLAPSED_H`/`EDITOR_H` constants. Remainder → piano roll.
6. **PRESETS title**: Larger `gfx.setfont` in `preset-browser.lua`.
7. **BEATS below**: Larger font. Numbers below tick marks.
8. **Window pos**: Poll `gfx.w`/`gfx.h` → `ui_store` → `persist`. Restore on ToggleIsland.
9. **Scroll clip**: Left clip at `x - LABEL_W`. Right Z-order before scrollbar.

## Dependencies

2 → 1 (same toolbar). 3+4 (snap). 5+7 (layout). 4, 8, 9 independent.

## Phasing

- **Phase 1**: 4, 8, 9 (independent)
- **Phase 2**: 1+2 (header batch)
- **Phase 3**: 3, 5, 6, 7 (polish)

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| gfx.showmenu steals context | Low | Verify frame resumes |
| Scale snap perf at max zoom | Med | Early-exit when off; N=7 |
| Save/load overlap PRESET | Med | Item 1 shrinks containers |
| Velocity height breaks rows | Low | Piano roll gets remainder |

## Rollback

Per-item revert (1–2 files each).

## Success Criteria

- [ ] (1) Glyph rendering, hover rects match icon bounds
- [ ] (2) SAVE/LOAD trigger save/load, coexist with PRESET
- [ ] (3) Scale pitch lines highlighted when on; toggle in preferences_store
- [ ] (4) "Triplet: ON/OFF" in resolution menu; button removed
- [ ] (5) Velocity panel uses COLLAPSED_H/EDITOR_H
- [ ] (6) PRESETS header/titles larger, no clipping
- [ ] (7) BEATS larger; numbers below ticks
- [ ] (8) Window pos survives ToggleIsland; restored on expand
- [ ] (9) Notes clip behind keyboard; no scrollbar overlap
