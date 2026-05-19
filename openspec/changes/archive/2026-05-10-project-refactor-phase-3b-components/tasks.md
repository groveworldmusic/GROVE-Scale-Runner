# Tasks: Project Refactor — Phase 3b (Piano, Pads, Slots, Drag)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,026 (524 new + 502 modified) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 3b-a (piano 124 + pads 114 + barrel) → PR 3b-b (slots 170 + drag 87 + barrel) |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Extract piano + pads from components.lua | PR 3b-a | Base = feature/tracker branch. Create piano.lua, pads.lua, barrel exports, update main.lua @provides |
| 2 | Extract slots + drag from components.lua | PR 3b-b | Base = PR 3b-a branch. Create slots.lua (core/), drag.lua, barrel exports, update main.lua @provides |

## Phase 1: PR 3b-a — Piano + Pads

- [x] 1.1 Create `src/ui/piano.lua` — `PIANO_LAYOUT`, cached scale upvalues, `DrawPianoKeyboard()` (no signature change)
- [x] 1.2 Create `src/ui/pads.lua` — `DEGREE_KEY_LABELS`, `DrawScalePad()` (no signature change)
- [x] 1.3 Modify `src/ui/components.lua` — remove piano + pads (~270 LOC), add `local piano = require("ui.piano")`, `local pads = require("ui.pads")`, barrel re-exports
- [x] 1.4 Modify `src/main.lua` — add `@provides src/ui/piano.lua` + `@provides src/ui/pads.lua`
- [x] 1.5 Verify: piano renders in main view + compact panel, pads render, click changes root note (scenarios: piano click, pad interaction)

## Phase 2: PR 3b-b — Slots + Drag

- [x] 2.1 Create `src/core/slots.lua` — `DrawSlotBackground()`, `DrawSlotLabel()`, `HandleSlotInteraction()` (local), `DrawProgressionSlot()` (public, no signature change)
- [x] 2.2 Create `src/ui/drag.lua` — `DrawDragPreview()` (no signature change)
- [x] 2.3 Modify `src/ui/components.lua` — remove slots + drag (~254 LOC), add `local slots = require("core.slots")`, `local drag = require("ui.drag")`, barrel re-exports
- [x] 2.4 Modify `src/main.lua` — add `@provides src/core/slots.lua` + `@provides src/ui/drag.lua`
- [x] 2.5 Verify: progression slots render, slot hover highlights, drag-from-pad → drop-on-slot works, drag-from-slot → swap works, right-click deletes slot, drag preview renders (scenarios: slot rendering, drag/drop, right-click delete, compact panel)
