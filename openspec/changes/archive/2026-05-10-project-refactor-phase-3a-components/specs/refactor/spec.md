# Delta for Refactor — Project Refactor Phase 3a (Decompose Components)

## Nature of Change

**Pure structural refactor.** No behavioral changes. No new capabilities. No modified capabilities. All extractions are internal code moves that preserve every existing behavior identically.

All existing behaviors MUST be preserved identically after each extraction. The system SHALL behave exactly as before the refactor across all entry points, inputs, and UI states.

## Extractions

| # | Extract | Source | Target | Nature |
|---|---------|--------|--------|--------|
| 1a | `DrawButton` | `src/ui/components.lua` | `src/ui/buttons.lua` | Logic move, calls `DrawRoundedRect` internally |
| 1b | `DrawToolIcon` | `src/ui/components.lua` | `src/ui/buttons.lua` | Logic move, pure GFX drawing, no internal deps |
| 1c | `DrawTransportButton` | `src/ui/components.lua` | `src/ui/buttons.lua` | Logic move, calls `DrawRoundedRect` internally |
| 1d | `DrawNoteDisplay` | `src/ui/components.lua` | `src/ui/buttons.lua` | Logic move, calls `DrawRoundedRect` internally |
| 2 | `DrawPaginator` | `src/ui/components.lua` | `src/ui/paginator.lua` | Logic move, no internal deps |
| 3 | `DrawDropdown` | `src/ui/components.lua` | `src/ui/dropdown.lua` | Logic move, calls `DrawRoundedRect`, contains `GetFitText` closure |
| 4 | Barrel re-export | — | `src/ui/components.lua` | `components.lua` requires all 3 modules and re-exports their functions |
| 5 | Keep in place | `DrawRoundedRect`, `DrawIsland` | — | Remain in `components.lua`, unchanged |

## Constraints

- Every extracted function MUST behave identically to its previous inline definition.
- No function signature MAY change.
- No constant value MAY change.
- No state initialization semantics MAY change.
- The Lua module system (`local m = {}` + `return m`) SHALL be used for all new files.
- `components.lua` MUST re-export all extracted functions so consumer imports remain unchanged.
- No consumer file (`views.lua`, `compact.lua`, etc.) MAY require the new modules directly — all access SHALL remain through `components.*`.
- `DrawRoundedRect` SHALL remain accessible to extracted modules — either via shared import or parameter passing (design decision).
- The `GetFitText` closure (inside `DrawDropdown`) SHALL remain local to the extracted module — no external references exist.
- `DrawIsland` and `DrawRoundedRect` SHALL NOT be moved in this phase.
- Each extraction SHALL be an independent commit with its own verification.

## Verification

- After each extraction commit, the script SHALL start without runtime errors (REAPER load + GFX init).
- All button interactions (hover, click, active state) SHALL render and respond identically before and after.
- All toolbar icons (settings, view, help, scroll, clear, export) SHALL render identically before and after.
- Note display SHALL render label, octave, and MIDI note number identically before and after.
- Paginator dots SHALL render, highlight, and respond to click identically before and after.
- Dropdown SHALL render label, value, arrow, respond to click menu and scroll wheel identically before and after.
- Transport buttons SHALL render and respond to click identically before and after.
- `DrawRoundedRect` SHALL render identically in all contexts (buttons, dropdown, note display, islands).
- Both expanded and collapsed UI modes SHALL work without errors.
