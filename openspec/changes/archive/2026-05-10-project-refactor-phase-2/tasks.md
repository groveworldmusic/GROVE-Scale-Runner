# Tasks: Project Refactor — Phase 2

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~225 (165 new + 60 modified) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: feature-branch-chain
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | All 4 extractions | Single PR | Sequential commits on feature branch `refactor/project-refactor-phase-2` |

## Phase 1: Extract colors.lua

- [x] 1.1 Create `src/ui/colors.lua` — `DegreeColor(degree)` + `ROMAN_NUMERALS` table
- [x] 1.2 Wire into `src/ui/components.lua` — import colors, replace inline DegreeColor callsites
- [x] 1.3 Verify: script loads, degree colors render identically in color/grey modes

## Phase 2: Extract format.lua

- [x] 2.1 Create `src/ui/format.lua` — `NoteName(ctx)`, `ChordLabel(ctx)`, `RomanNumeral(degree)` with context-table pattern
- [x] 2.2 Replace inline note/chord/roman-numeral formatting in `src/ui/components.lua` with format.lua calls
- [x] 2.3 Replace all direct `midi.GetMidiNote` calls in `src/ui/components.lua` — delegate through format.lua
- [x] 2.4 Verify: slot labels, tooltips, drag preview labels match originals

## Phase 3: Extract progression.lua

- [x] 3.1 Create `src/core/progression.lua` — `Add(idx, slot)`, `Remove(idx)`, `Swap(a, b)`, `Clear()`, `GetLastFilled()`
- [x] 3.2 Replace inline progression CRUD in `src/ui/components.lua` with progression.lua calls
- [x] 3.3 Refactor `src/core/sequencer.lua` — replace `GetLastFilledSlot()` with `progression.GetLastFilled()`
- [x] 3.4 Refactor `src/ui/views.lua` — replace inline `Clear()` with `progression.Clear()`
- [x] 3.5 Verify: drag add/swap, right-click remove, clear button, sequencer auto-stop all work identically

## Phase 4: Import cleanup and final wiring

- [x] 4.1 Clean up `src/ui/components.lua` imports — keep `midi` only for `TriggerChord`
- [x] 4.2 Remove any remaining inline code made obsolete by new modules (format, colors, progression)
- [x] 4.3 Final verification: all UI modes (full, compact, docked) and all interactions (drag, drop, play, keyboard) work without errors
