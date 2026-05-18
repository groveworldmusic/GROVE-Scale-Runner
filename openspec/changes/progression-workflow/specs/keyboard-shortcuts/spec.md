# Delta for Keyboard Shortcuts

## MODIFIED Requirements

### Requirement: Undo/Redo Shortcuts — Context-aware dispatch (MODIFIED)

Ctrl+Z (char 346) SHALL trigger progression undo when progression is focused, note undo when piano roll is focused. Ctrl+Y (char 345) SHALL mirror for redo. Empty stacks SHALL be no-ops. Unfocused context SHALL also be a no-op (no crash).

Focus detection: progression is considered focused when `gfx.mouse_y` falls within the performance/slots region AND the MIDI island is not currently expanded; otherwise the piano roll is considered focused.
(Previously: Ctrl+Z always triggered note undo; Ctrl+Y always triggered note redo — no progression routing)

#### Scenario: Ctrl+Z in performance area routes to progression undo

- GIVEN both progression and piano-roll undo stacks have 1 entry
- AND mouse is in slots region and MIDI island is collapsed
- WHEN user presses Ctrl+Z
- THEN progression undo fires, not piano-roll undo

#### Scenario: Ctrl+Z in piano-roll area routes to note undo

- GIVEN both stacks have 1 entry
- AND mouse is in MIDI island area
- WHEN user presses Ctrl+Z
- THEN piano-roll undo fires, not progression undo

#### Scenario: Progression undo Ctrl+Y

- GIVEN progression slot 1 removed then undone (progression redo stack non-empty)
- WHEN user presses Ctrl+Y
- THEN slot 1 is removed again (redo applies)
