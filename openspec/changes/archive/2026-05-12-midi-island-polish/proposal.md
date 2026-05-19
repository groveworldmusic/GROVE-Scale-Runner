# Proposal: MIDI Island Polish

## Intent

Fix a crash bug and polish 10 visual/interaction pain points in the MIDI island. Users hit a hard crash on mute toggle in velocity editor, and several UI areas feel unfinished — missing rounded borders on preset buttons, invisible scrollbar interaction, overlapping velocity bars, and visual artifacts at container corners.

## Scope

### In Scope
- Fix MUTED_BAR_COLOR crash in velocity.lua (undefined constant)
- SAVE/RENAME/LOAD buttons → rounded borders via DrawButton
- Note block font size increase + pitch label on notes
- Horizontal scrollbar drag interaction (currently rendered but dead)
- Fix slot notes not redrawing after progression reload (cache dirty flag gap)
- Offset overlapping velocity bars when notes are adjacent
- Info bar: +1px right side length fix
- Timeline ruler top-left: shadow/double border overlap fix
- Preset area: vertical center dividing line (bookmarks left, presets right)
- Velocity panel: collapsible from bottom edge upward
- Piano roll note colors (white/black key) already correct — no change needed

### Out of Scope
- New editing features (note insert/delete, MIDI recording)
- Fundamental island architecture changes
- Slot/progression system changes
- Non-MIDI island UI elements

## Capabilities

### New Capabilities
- None — all changes are bugfixes or visual refinements to existing specs

### Modified Capabilities
- `velocity-editor`: muted bar color fix + overlapping bar offset behavior
- `piano-roll`: horizontal scrollbar interaction (was render-only) + note text labels
- `timeline-ruler`: top-left corner rendering fix
- `preset-browser`: rounded button borders + vertical dividing line layout
- `island-store`: velocity panel collapse state (new getter/setter pair)

## Approach

1. **Bug fix first**: Define `MUTED_BAR_COLOR` in velocity.lua (line ~16-18 before any use) — quickest way to stop the crash
2. **State changes**: Add velocity panel collapse state to island-store (1 getter/setter pair)
3. **Refactors**: Potentially extract shared scrollbar drag handler if timeline/piano-roll/velocity all need it
4. **Visual polish**: Rounded borders, dividing line, font size, info bar length, corner overlap — in order of least to most risky
5. **Interaction**: Horizontal scrollbar drag, velocity panel collapse toggle, overlapping bar offset

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/velocity.lua` | Modified | Add MUTED_BAR_COLOR constant + overlapping bar offset |
| `src/ui/piano-roll.lua` | Modified | Add note text labels + fix cache dirty flag |
| `src/ui/timeline.lua` | Modified | Top-left corner rendering fix |
| `src/ui/preset-browser.lua` | Modified | Rounded buttons via DrawButton + vertical dividing line |
| `src/ui/views.lua` | Modified | Horizontal scrollbar drag handler + info bar width + velocity collapse |
| `src/state/island.lua` | Modified | Add `Get/SetVelocityPanelExpanded` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Scrollbar drag interferes with existing wheel scroll | Low | Use separate interaction zone (thumb only, not track) |
| Velocity collapse breaks layout math | Low | Clamp to min height, test edge cases |
| Note cache fix introduces flicker | Low | Increase dirty flag granularity, not full invalidation |

## Rollback Plan

Revert individual commits per file. The crash fix and each visual item are isolated enough to cherry-pick. Worst case: revert all changes and the MIDI island works as before (minus polish).

## Dependencies

- None beyond existing codebase

## Success Criteria

- [ ] Velocity editor renders muted bars without crash (MUTED_BAR_COLOR defined)
- [ ] SAVE/RENAME/LOAD buttons render with rounded borders matching other UI buttons
- [ ] Note blocks display pitch label text at larger font size
- [ ] Horizontal scrollbar thumb is draggable and updates scroll offset
- [ ] Slot notes redraw reliably after progression changes
- [ ] Adjacent velocity bars have visible gap/separation
- [ ] Info bar width matches container width exactly (no +1px overhang)
- [ ] No double border/shadow at timeline ruler top-left corner
- [ ] Preset area shows vertical dividing line between bookmarks and presets
- [ ] Velocity panel collapses/expands from bottom edge
