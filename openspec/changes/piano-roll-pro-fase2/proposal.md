# Proposal: Piano Roll Professional — Fase 2 (Musicality & Groove)

## Intent

Transition the Piano Roll from mechanical precision to musical expression. This change introduces tools to add "groove" and human-like imperfections to MIDI sequences, moving beyond rigid quantization.

## Scope

### In Scope
- **Swing**: Wire the `quantize_swing` parameter from `island_store` to `QuantizeBeat()` and add a UI control.
- **Humanize**: Implement `HumanizeNotes()` to randomize start times and velocities within a percentage range.
- **Velocity Improvements**: Add a "Set All Selected to Value" drag handler and a right-click "Reset to 100" menu to the velocity panel.
- **Arpeggiator**: Implement a destructive "Generate Arpeggio" tool that creates notes from a selection based on pattern (Up, Down, Random) and speed.

### Out of Scope
- Real-time arpeggiation (non-destructive playback).
- Complex velocity ramps or automated curves.
- Global groove templates/presets.

## Capabilities

### New Capabilities
- `humanize`: Randomization of note timing and velocity for selected notes.
- `velocity-editing`: Enhanced batch velocity controls (absolute set, reset).
- `arpeggiator`: Destructive generation of arpeggio sequences from existing notes.

### Modified Capabilities
- `quantize`: Integration of a swing offset into the quantization process.

## Approach

- **Swing**: Connect existing `island_store.quantize_swing` to `core.quantize.QuantizeBeat`. Add a slider/dropdown in the Piano Roll header.
- **Humanize**: Implement `HumanizeNotes()` as a pure function in `core.quantize`. Use a random offset based on a configurable percentage. Store a snapshot of notes for the `"humanize"` undo type in `piano-roll-store`.
- **Velocity**: Extend `ui.velocity` to handle absolute value dragging (shift-drag or toggle) and implement a right-click context menu via `ui.components.dropdown` or native REAPER menu.
- **Arpeggiator**: Create a generator that iterates through sorted selected notes, calculates intervals based on the chosen pattern, and inserts new notes into the `piano-roll-store`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/core/quantize.lua` | Modified | Updated `QuantizeBeat` for swing; added `HumanizeNotes`. |
| `src/state/island_store.lua` | Modified | Ensure `quantize_swing` getters/setters are utilized. |
| `src/ui/velocity.lua` | Modified | New drag handler and right-click menu. |
| `src/ui/piano-roll-header.lua` | New | Added Swing UI control. |
| `src/ui/piano-roll/interaction.lua` | Modified | Added Arpeggiator tool trigger and logic. |
| `src/ui/piano-roll/piano-roll-store.lua` | Modified | Added `"humanize"` undo type. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Arpeggiator logic complexity with scale modes | Medium | Leverage existing `progression` and `scale` modules for pitch calculation. |
| Velocity panel UI clutter | Low | Use context menus for less frequent actions (Reset to 100). |
| Conflict between Humanize and Quantize | Low | Process them as separate, sequential tool calls. |

## Rollback Plan

Revert all changes in `src/` and remove the `openspec/changes/piano-roll-pro-fase2` directory using git.

## Dependencies

- Requires the Piano Roll Fase 1 architecture (Store-based note management).

## Success Criteria

- [ ] Quantizing with Swing visibly shifts notes off-grid according to the offset.
- [ ] Humanize creates subtle, random timing and velocity variations in selected notes.
- [ ] "Reset to 100" correctly sets all selected note velocities to 100.
- [ ] Arpeggiator generates a valid sequence of notes from a chord selection in Up/Down/Random patterns.
