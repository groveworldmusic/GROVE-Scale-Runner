# Delta for Refactor — Project Refactor Phase 2

## Nature of Change

**Pure structural refactor.** No behavioral changes. No new capabilities. No modified capabilities. All extractions are internal code moves that preserve every existing behavior identically.

All existing behaviors MUST be preserved identically after each extraction. The system SHALL behave exactly as before the refactor across all entry points, inputs, and UI states.

## Extractions

| # | Extract | Source | Target | Nature |
|---|---------|--------|--------|--------|
| 1 | Format functions — `FormatNoteLabel`, `FormatChordLabel`, `FormatRomanNumeral` | `src/ui/components.lua` (inline) | `src/ui/format.lua` | Logic move, imports `midi` for `GetMidiNote` |
| 2 | Color semantics — `DegreeColor`, `HoverColor`, `ActiveColor` | `src/ui/components.lua` (inline) | `src/ui/colors.lua` | Move + wrap: `HoverColor` and `ActiveColor` are new wrappers for existing inline patterns |
| 3 | Progression CRUD — `Add`, `Remove`, `Swap`, `Clear`, `GetLastFilled` | `src/ui/components.lua` + `src/ui/views.lua` + `src/core/sequencer.lua` | `src/core/progression.lua` | Consolidation: all progression state access in one module |
| 4 | Update imports — wire new modules into callers | `src/ui/components.lua`, `src/ui/views.lua`, `src/ui/compact.lua`, `src/core/sequencer.lua` | — | Import path updates; `components.lua` keeps `midi` only for `TriggerChord` |

## Constraints

- Every extracted function MUST behave identically to its previous inline definition.
- No function signature MAY change for existing functions. New wrappers (`HoverColor`, `ActiveColor`) MUST match the semantic pattern they replace.
- No constant value MAY change.
- The Lua module system (`local m = {}` + `return m`) SHALL be used for all new files.
- Each extraction SHALL be an independent commit with its own verification.
- `components.lua` MUST delegate `GetMidiNote` calls through `format.lua` — no direct `midi.GetMidiNote` calls shall remain in `components.lua`.

## Verification

- After each extraction commit, the script SHALL start without runtime errors.
- All formatting (note labels, chord labels, roman numerals) SHALL appear identically before and after.
- All color rendering (degree, hover, active) SHALL appear identically before and after.
- All progression operations (add, remove, swap, clear) SHALL behave identically before and after.
- Both expanded and collapsed UI modes SHALL work without errors.
