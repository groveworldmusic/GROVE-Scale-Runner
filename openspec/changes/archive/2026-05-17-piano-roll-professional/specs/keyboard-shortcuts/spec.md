# Delta for Keyboard Shortcuts

## ADDED Requirements

### Requirement: Tool Switching Shortcuts

Keys '1' (char 49), '2' (char 50), and '3' (char 51) SHALL switch the active piano roll tool. The tool state SHALL be stored in `piano-roll-store` or `ui_store`. The mapping SHALL be: '1' = paint tool (create notes on click), '2' = knife tool (split notes on click), '3' = eraser tool (delete notes on left-click). Tool switching shortcuts MUST be consumed by the piano roll and MUST NOT fall through to REAPER. Key events SHALL be checked via `gfx.getchar()` with char codes 49, 50, 51.

#### Scenario: Key '1' switches to paint tool

- GIVEN piano roll active, current tool = eraser
- WHEN user presses '1'
- THEN current tool becomes paint
- AND REAPER does NOT receive the '1' key event

#### Scenario: Key '2' switches to knife tool

- GIVEN piano roll active, current tool = paint
- WHEN user presses '2'
- THEN current tool becomes knife

#### Scenario: Key '3' switches to eraser tool

- GIVEN piano roll active, current tool = paint
- WHEN user presses '3'
- THEN current tool becomes eraser

#### Scenario: Eraser left-click deletes note

- GIVEN current tool = eraser
- WHEN user left-clicks on a note block
- THEN that note SHALL be deleted
- AND a single undo entry SHALL capture the deletion

#### Scenario: Tool key consumed, not propagated

- GIVEN piano roll active, REAPER idle
- WHEN user presses '1', '2', or '3'
- THEN REAPER SHALL NOT interpret the key (e.g., no "1" typed in REAPER's console)

### Requirement: Note Audition on Click/Create

When the paint tool is active, clicking on an existing note or creating a new note SHALL send a brief MIDI note-on (via `core.midi.SendMidi`) followed by a note-off after approximately 50ms. The note-off SHALL be scheduled via a one-shot timer or delayed call. Only the note that was clicked or created SHALL audition — not the full selection. Audition notes SHALL NOT be added to the active notes ref-counted table (they are preview only, not held).

#### Scenario: Paint click on empty grid creates note and auditions it

- GIVEN paint tool active, snap enabled
- WHEN user clicks on an empty grid cell
- THEN a new note is created at that pitch and beat
- AND `SendMidi` is called with note-on for that pitch at velocity 100
- AND after ~50ms, `SendMidi` is called with note-off for that pitch

#### Scenario: Paint click on existing note auditions it

- GIVEN paint tool active, an existing note at pitch 60
- WHEN user clicks on that note block
- THEN `SendMidi` is called with note-on for pitch 60
- AND after ~50ms, note-off for pitch 60 is sent
- AND no note position or property is modified

#### Scenario: Knife tool click does NOT audition

- GIVEN knife tool active, an existing note at pitch 60
- WHEN user clicks on that note block
- THEN `SendMidi` SHALL NOT be called
- AND the note is split at the click beat instead

## MODIFIED Requirements

### Requirement: Fall-Through for Unhandled Keys

Keys not matching any piano roll shortcut (including tool switching keys '1'-'3', undo/redo, delete, arrow nudge) SHALL NOT be consumed and MUST propagate to REAPER's default handling.
(Previously: only undo/redo, delete, arrow nudge were handled; now also tool switching '1', '2', '3')

#### Scenario: Tool keys are handled, not passed through

- GIVEN piano roll focused
- WHEN user presses '2'
- THEN tool switches to knife
- AND the key event is consumed (does not reach REAPER)

#### Scenario: Unknown key passes through

- GIVEN piano roll focused
- WHEN user presses a key not in the dispatch table (e.g., Space)
- THEN REAPER receives the native key event

## Acceptance Criteria

- [ ] '1' switches to paint tool, '2' to knife, '3' to eraser
- [ ] Tool switch keys are consumed, not propagated to REAPER
- [ ] Eraser left-click deletes single note at cursor with undo entry
- [ ] Paint click on empty grid creates note + sends MIDI audition (note-on + 50ms note-off)
- [ ] Paint click on existing note auditions without modifying it
- [ ] Non-paint tools (knife, eraser) do NOT audition notes
- [ ] Audition notes bypass active notes ref-count table
- [ ] Unhandled keys still fall through to REAPER
