# Keyboard Shortcuts Specification

## Purpose

Standard DAW keyboard shortcuts for the piano roll: undo/redo, delete, arrow nudge, tool switching, and note audition.

## Requirements

### Requirement: Undo/Redo Shortcuts

Ctrl+Z SHALL trigger undo. Ctrl+Y SHALL trigger redo. Both SHALL consume the key event (not propagate to REAPER). Empty stack SHALL be a no-op (no error, no crash).

#### Scenario: Ctrl+Z triggers undo

- GIVEN note moved and undo stack has 1 entry
- WHEN user presses Ctrl+Z
- THEN undo is invoked AND note returns to original position

#### Scenario: Empty undo stack no-op

- GIVEN no edits made
- WHEN user presses Ctrl+Z
- THEN nothing happens (no crash, no error)

### Requirement: Delete Key

Delete SHALL remove all notes in `selected_indices`. A single undo entry SHALL capture the bulk deletion. Empty selection SHALL be a no-op.

#### Scenario: Delete selected notes

- GIVEN 5 notes, indices 2 and 4 selected
- WHEN user presses Delete
- THEN notes at 2 and 4 removed AND remaining notes shift AND one undo entry captures both deletions

### Requirement: Arrow Nudge

Arrow keys SHALL nudge selected notes. Left/Right change start_beat by 1 snap unit. Up/Down change pitch by ±1 semitone. Shift+arrow SHALL nudge by 1 beat (left/right) or 12 semitones (up/down). Snap awareness applies to X-axis nudge.

#### Scenario: Right arrow at 1/16 snap

- GIVEN note at start_beat 2.0, snap at 1/16 (0.0625)
- WHEN user presses Right arrow
- THEN start_beat = 2.0625

#### Scenario: Shift+Up octave jump

- GIVEN note at pitch 60
- WHEN user presses Shift+Up arrow
- THEN pitch = 72

#### Scenario: Multi-nudge

- GIVEN notes at indices 1 (pitch 60) and 2 (pitch 64) selected
- WHEN user presses Down arrow
- THEN both notes drop 1 semitone (to 59 and 63)

### Requirement: Tool Switching Shortcuts

Keys '1' (char 49), '2' (char 50), and '3' (char 51) SHALL switch the active piano roll tool. The tool state SHALL be stored in `ui_store` or `island_store`. The mapping SHALL be: '1' = paint tool (create notes on click), '2' = knife tool (split notes on click), '3' = eraser tool (delete notes on left-click). Tool switching shortcuts MUST be consumed by the piano roll and MUST NOT fall through to REAPER. Key events SHALL be checked via `gfx.getchar()` with char codes 49, 50, 51.

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

When the paint tool is active, clicking on an existing note or creating a new note SHALL send a brief MIDI note-on (via `core.midi.SendMidi`) followed by a note-off after approximately 50ms. The note-off SHALL be scheduled via `reaper.defer` for the next frame (~30ms). Only the note that was clicked or created SHALL audition — not the full selection. Audition notes SHALL NOT be added to the active notes ref-counted table (they are preview only, not held).

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

- [ ] Ctrl+Z/Y trigger undo/redo (no-op on empty stack)
- [ ] Delete removes selected notes with single undo entry
- [ ] Arrow keys nudge by snap unit (X) / 1 semitone (Y)
- [ ] Shift+arrow nudges by 1 beat / 12 semitones
- [ ] Empty selection: Delete and arrows are no-ops
- [ ] '1' switches to paint tool, '2' to knife, '3' to eraser
- [ ] Tool switch keys are consumed, not propagated to REAPER
- [ ] Eraser left-click deletes single note at cursor with undo entry
- [ ] Paint click on empty grid creates note + sends MIDI audition (note-on + ~30ms note-off)
- [ ] Paint click on existing note auditions without modifying it
- [ ] Non-paint tools (knife, eraser) do NOT audition notes
- [ ] Audition notes bypass active notes ref-count table
- [ ] Unrecognized shortcuts fall through to REAPER
