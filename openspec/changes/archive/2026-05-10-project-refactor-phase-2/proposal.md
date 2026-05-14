# Proposal: Project Refactor — Phase 2

## Intent

Continue structural refactoring by extracting formatting, color semantics, and progression CRUD logic from `components.lua` (853 lines) into dedicated modules. No behavioral changes — pure code moves with wrapper creation where inline patterns exist.

## Scope

### In Scope
1. Extract note/chord/roman numeral formatting → `ui/format.lua` (FormatNoteLabel, FormatChordLabel, FormatRomanNumeral)
2. Extract color semantics → `ui/colors.lua` (DegreeColor + new HoverColor + new ActiveColor wrappers)
3. Extract progression CRUD → `core/progression.lua` (Add, Remove, Swap, Clear, GetLastFilled)
4. Remove `midi.GetMidiNote` calls from components.lua — delegate to format.lua

### Out of Scope
- Full components.lua decomposition (Phase 3)
- compact.lua decomposition (Phase 3)
- Global state store separation (Phase 4)
- Any behavioral changes or new features
- Removing `midi.TriggerChord` from components.lua (retained for slot play-on-click)

## Capabilities

### New Capabilities
None — pure refactor.

### Modified Capabilities
None — spec-level behavior unchanged.

## Approach

4 sequential extractions, each as a separate commit:

1. **Create `ui/colors.lua`** — Extract existing `DegreeColor(degree)` from components.lua:15. Create `HoverColor()` wrapping `{1,1,1,0.15}` pattern and `ActiveColor(disabled)` wrapping the disabled/grey pattern. Pure functions, no midi dependency.
2. **Create `ui/format.lua`** — Extract inline note name resolution, chord label construction, and roman numeral lookup from DrawSlotLabel (lines 308-322), tooltip (lines 405-411), and drag preview (lines 783-811). Imports midi for `GetMidiNote`.
3. **Create `core/progression.lua`** — Extract CRUD operations: Remove (components.lua:347), Swap (380-382), Add (384-394), Clear (views.lua:281/617), GetLastFilled (from sequencer.lua:6-11). Consolidates all progression state access in one module.
4. **Update imports** — Wire into components.lua, views.lua, compact.lua, sequencer.lua. components.lua keeps midi import only for `TriggerChord`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/components.lua` | Modified | Remove inline formatting, color, progression logic; midi.GetMidiNote → format.lua |
| `src/ui/views.lua` | Modified | Progression.Clear → core/progression.lua |
| `src/ui/compact.lua` | Modified | Update imports if referencing inline logic |
| `src/core/sequencer.lua` | Modified | GetLastFilledSlot → core/progression.lua |
| `src/ui/format.lua` | **New** | FormatNoteLabel, FormatChordLabel, FormatRomanNumeral |
| `src/ui/colors.lua` | **New** | DegreeColor, HoverColor, ActiveColor |
| `src/core/progression.lua` | **New** | Add, Remove, Swap, Clear, GetLastFilled |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|-----------|
| Missing a DegreeColor call site | Medium | Grep for all 10 occurrences before moving |
| HoverColor/ActiveColor are new wrappers, not moves | Low | Verify each inline pattern matches semantic intent |
| GetLastFilled already exists in sequencer.lua | Medium | Move to progression.lua; re-export or update callers |
| midi.GetMidiNote appears in components.lua drag preview (lines 785, 808) | Low | Those will use format.lua functions instead |
| midi.TriggerChord (lines 370-371) keeps midi import in components | Low | Acceptable — Phase 3 or 4 can extract HandleSlotInteraction |

## Rollback Plan

Each extraction is a separate commit. If any breaks, revert that commit. Feature branch — main stays clean.

## Dependencies

None.

## Success Criteria

- [ ] `format.lua` exports FormatNoteLabel, FormatChordLabel, FormatRomanNumeral
- [ ] `colors.lua` exports DegreeColor, HoverColor, ActiveColor
- [ ] `progression.lua` exports Add, Remove, Swap, Clear, GetLastFilled
- [ ] All call sites updated in views.lua, compact.lua, sequencer.lua
- [ ] components.lua no longer calls midi.GetMidiNote directly
- [ ] Script runs without errors in both expanded + collapsed modes
- [ ] All existing behavior preserved (drag, swap, clear, play, keyboard input)
