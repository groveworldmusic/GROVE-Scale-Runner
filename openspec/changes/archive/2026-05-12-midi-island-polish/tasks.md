# Tasks: MIDI Island Polish

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 200-350 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | All 11 polish items | PR 1 | Items independent enough for auto-split if risk materializes |

## Phase 1: Crash Fix & Store

- [x] 1.1 `src/state/island.lua` — Add `GetVelocityPanelExpanded()` / `SetVelocityPanelExpanded(v)`, default `true`
- [x] 1.2 `src/ui/velocity.lua` — Replace undefined `MUTED_BAR_COLOR` with `theme.colors.island_note_muted`

## Phase 2: Visual Polish

- [x] 2.1 `src/ui/preset-browser.lua` — Replace `gfx.rect` in `DrawActionButton` with `components.DrawRoundedRect`
- [x] 2.2 `src/ui/preset-browser.lua` — Add vertical dividing line between action row and content below
- [x] 2.3 `src/ui/views.lua` — Info bar right margin: change `rr - 8` to `rr - 9` (line 854)
- [x] 2.4 `src/ui/timeline.lua` — Replace rounded rect with plain fill to remove top-left corner overlap
- [x] 2.5 `src/ui/views.lua` — Timeline container background: `DrawRoundedRectEx` with only bottom corners (`{bl=true, br=true}`)

## Phase 3: Interaction

- [x] 3.1 `src/ui/views.lua` — Add module-local horizontal scrollbar thumb drag state (capture / delta / release)
- [x] 3.2 `src/ui/velocity.lua` — Group notes by `start_beat`, compute offset per overlapping bar
- [x] 3.3 `src/ui/velocity.lua` — Add 6px collapsible drag handle at bottom, click calls `SetVelocityPanelExpanded`
- [x] 3.4 `src/ui/views.lua` — Read `GetVelocityPanelExpanded()` to set velocity editor height (`EDITOR_H` / `COLLAPSED_H`)

## Phase 4: Piano Roll

- [x] 4.1 `src/ui/piano-roll.lua` — Increase reference font from 9 to 10 for note block labels
- [x] 4.2 `src/ui/piano-roll.lua` — Add `OctaveLabel()` call inside `DrawNoteBlock` when block width > 30px
- [x] 4.3 `src/ui/views.lua` — Call `piano_roll.MarkNotesDirty()` after `LoadNotesFromProgression` (line 577)

## Phase 5: Testing

- [x] 5.1 Verified: `velocity_panel_expanded = true` in state default, getter returns it, setter flips it — round-trip confirmed
- [x] 5.2 Manual visual verification page — all changes documented in apply-progress
