# Tasks: Project Refactor — Phase 3a (Decompose Components)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~514 (249 new + 262 modified + 3 main.lua) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | 4 sequential work-unit commits in 1 PR on feature branch |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Extract buttons.lua — DrawButton, DrawToolIcon, DrawTransportButton, DrawNoteDisplay | Feature branch PR | Base = `refactor/project-refactor-phase-3a-components` tracker branch. Commit 1 of 4. |
| 2 | Extract paginator.lua — DrawPaginator | Feature branch PR | Same tracker branch, base = previous commit. Commit 2 of 4. |
| 3 | Extract dropdown.lua — DrawDropdown + GetFitText | Feature branch PR | Same tracker branch, base = previous commit. Commit 3 of 4. |
| 4 | Wiring barrel + main.lua @provides | Feature branch PR | Same tracker branch, base = previous commit. Commit 4 of 4. Final commit closes the phase. |

## Phase 1: Extract buttons.lua

- [x] 1.1 Create `src/ui/buttons.lua` — module table + requires (helpers, theme, config, components for DrawRoundedRect)
- [x] 1.2 Move DrawButton, DrawToolIcon, DrawNoteDisplay, DrawTransportButton from components.lua into buttons.lua — verbatim, no signature changes
- [x] 1.3 Add `local buttons = require("ui.buttons")` + barrel re-exports (`m.DrawButton = buttons.DrawButton`, etc.) to components.lua
- [x] 1.4 Remove moved functions from components.lua
- [x] 1.5 Verify: script loads without errors, all buttons (scale pads, transport, tool icons, note display) render and respond identically

## Phase 2: Extract paginator.lua

- [x] 2.1 Create `src/ui/paginator.lua` — module table + requires (helpers, theme, config, components for DrawRoundedRect)
- [x] 2.2 Move DrawPaginator from components.lua into paginator.lua — verbatim
- [x] 2.3 Add `local paginator = require("ui.paginator")` + barrel re-export (`m.DrawPaginator = paginator.DrawPaginator`) to components.lua
- [x] 2.4 Remove DrawPaginator from components.lua
- [x] 2.5 Verify: paginator dots render, highlight current page, respond to click identically in full view and compact panel

## Phase 3: Extract dropdown.lua

- [x] 3.1 Create `src/ui/dropdown.lua` — module table + requires (helpers, theme, config, components for DrawRoundedRect)
- [x] 3.2 Move DrawDropdown (including module-local GetFitText closure) from components.lua into dropdown.lua — verbatim, GetFitText stays local
- [x] 3.3 Add `local dropdown = require("ui.dropdown")` + barrel re-export (`m.DrawDropdown = dropdown.DrawDropdown`) to components.lua
- [x] 3.4 Remove DrawDropdown from components.lua
- [x] 3.5 Verify: dropdown renders label, value, arrow, responds to click menu and scroll wheel identically

## Phase 4: Wiring and final verification

- [x] 4.1 Add `src/ui/buttons.lua`, `src/ui/paginator.lua`, `src/ui/dropdown.lua` to `src/main.lua` @provides section
- [x] 4.2 Verify barrel pattern: all consumers (views.lua, compact.lua) access all 6 extracted functions via `components.*` — zero import changes
- [x] 4.3 Full integration verification: all UI modes (full, compact, docked), all interactions (button clicks, paginator, dropdown scroll/click) work without errors
