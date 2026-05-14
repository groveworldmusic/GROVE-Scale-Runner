# Delta for Refactor — Project Refactor Phase 1

## Nature of Change

**Pure structural refactor.** No behavioral changes. No new capabilities. No modified capabilities. All extractions are internal code moves that preserve every existing behavior identically.

All existing behaviors MUST be preserved identically after each extraction. The system SHALL behave exactly as before the refactor across all entry points, inputs, and UI states.

## Extractions

| # | Extract | Source | Target | Nature |
|---|---------|--------|--------|--------|
| 1 | Coordinate system — `SetScale`, `UX`, `UY`, `US`, `CANVAS_W`, `CANVAS_H` | `src/ui/views.lua` | `src/ui/layout.lua` | Pure constants, zero dependencies |
| 2 | Keyboard handling — `HandleKeyboard`, `InterceptMappedKeys`, `IsPluginOrScriptFocused`, `CheckFocus` | `src/main.lua` | `src/core/keyboard.lua` | Logic move, update imports in `main.lua` |
| 3 | MIDI state fields — `midi_channel`, `midi_island_expanded`, `midi_island_toggled` | `src/config.lua` (`config.state`) | `src/core/midi.lua` | State relocation, update all references |
| 4 | `ToggleMIDIIsland` function | `src/ui/views.lua` | `src/core/midi.lua` | Logic move, update imports in `components.lua`, `compact.lua` |

## Constraints

- Every existing function, constant, and state field MUST remain accessible at its original call sites via the new import path.
- No function signature MAY change.
- No constant value MAY change.
- No state initialization semantics MAY change.
- The Lua module system ("require") SHALL be used for all new files.
- Each extraction SHALL be an independent commit with its own verification.

## Verification

- After each extraction commit, the script SHALL start without runtime errors.
- All MIDI operations (channel change, toggle island, volume slider) SHALL behave identically before and after.
- Both expanded and collapsed UI modes SHALL work without errors.
