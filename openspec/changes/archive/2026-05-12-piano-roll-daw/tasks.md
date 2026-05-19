# Tasks: DAW-Style Piano Roll (piano-roll-daw)

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: Medium

| Field | Value |
|-------|-------|
| Estimated changed lines | ~320 |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | PR1: P1+P2 → PR2: P3 → PR3: P4 |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

### Suggested Work Units

| Unit | Goal | Likely PR | Base |
|------|------|-----------|------|
| 1 | Grid hierarchy + Note gradient | PR 1 | feature/tracker |
| 2 | Vertical piano keyboard | PR 2 | PR 1 branch |
| 3 | Tool selector + Lasso multi-select | PR 3 | PR 2 branch |

## Phase 1: Grid Hierarchy (P1)

- [x] 1.1 `theme.lua`: Add `grid_measure`, `grid_beat`, `grid_sub_1_8`, `grid_sub_1_16` colors
- [x] 1.2 `piano-roll.lua`: Refactor `DrawPianoRollGrid` to 4-tier alpha (measure/beat/1/8/1/16)
- [ ] 1.3 `timeline.lua`: Mirror 4 tiers in `DrawBeatTicks` tick heights + opacities (deferred: not in PR1 scope)

## Phase 2: Note Gradient + Velocity Opacity (P2)

- [x] 2.1 `piano-roll.lua`: Add `DrawNoteWithGradient` — 3–4 vertical strips, velocity→alpha `0.35 + vel/127*0.65`
- [x] 2.2 `piano-roll.lua`: Wire into note render loop; muted → NOTE_MUTED alpha 1.0

## Phase 3: Vertical Piano Keyboard (P3)

- [x] 3.1 `piano-roll.lua`: Add `DrawVerticalKeyboard` — white keys full height, black keys 60% h × 35% w, right-aligned at top of row
- [x] 3.2 `piano-roll.lua`: Replace pitch label strip with `DrawVerticalKeyboard` using same `ComputeVisibleRanges`

## Phase 4: Tool Selector + Lasso Multi-Select (P4)

- [x] 4.1 `island.lua`: Add `tool_mode`, `selected_indices{}`, `lasso_active/start/end` state + getters/setters
- [x] 4.2 `island.lua`: `GetPrimarySelectedIndex()` returning first key; compat `GetSelectedNoteIndex()`/`SetSelectedNoteIndex()` wrappers
- [x] 4.3 `theme.lua`: Add `lasso_fill` and `lasso_border` colors
- [x] 4.4 `views.lua`: Add 3 tool buttons (pointer/pencil/eraser) in MIDI island header, route tool-specific click dispatch
- [x] 4.5 `views.lua`: Route Delete key → `RemoveNoteAtIndex` loop for all `selected_indices`
- [x] 4.6 `piano-roll.lua`: Add `HandlePencilClick` — `AddNote` at snapped beat/pitch with `origin="manual"`
- [x] 4.7 `piano-roll.lua`: Add `HandleEraserClick` — hit-test notes, remove on match
- [x] 4.8 `piano-roll.lua`: Lasso — render semi-transparent rect during drag, populate `selected_indices` on mouseup
- [x] 4.9 `piano-roll.lua`: Right-click on selected note toggles mute on all `selected_indices`
- [x] 4.10 `velocity.lua`: Bulk velocity drag — relative delta to all `selected_indices`; `GetPrimarySelectedIndex()` for click target

Total: 15 tasks across 6 files. P1–P3 rendering-only, revert individually. P4 (island.lua + 3 consumers) must revert atomically.
