# Keyboard Shortcuts Specification

## Purpose

Standard DAW keyboard shortcuts for the piano roll: undo/redo, delete, arrow nudge, tool switching, and note audition. Extended with progression context undo/redo dispatch and vkey-map configurables.

## Requirements

### Requirement: Undo/Redo Shortcuts

Ctrl+Z SHALL trigger undo. Ctrl+Y SHALL trigger redo. Both SHALL consume the key event (not propagate to REAPER). Empty stack SHALL be a no-op (no error, no crash).

When `IsProgressionFocused()` is true (midi-island expanded, mouse outside piano roll grid), Ctrl+Z SHALL call `HandleProgUndo()` and Ctrl+Y SHALL call `HandleProgRedo()`. When `IsProgressionFocused()` is false, Ctrl+Z/Y SHALL fall through to the piano-roll undo/redo stack (unchanged behavior).
(Previously: Ctrl+Z/Y always targeted piano-roll undo/redo)

#### Scenario: Ctrl+Z triggers undo

- GIVEN note moved and undo stack has 1 entry
- WHEN user presses Ctrl+Z
- THEN undo is invoked AND note returns to original position

#### Scenario: Empty undo stack no-op

- GIVEN no edits made
- WHEN user presses Ctrl+Z
- THEN nothing happens (no crash, no error)

#### Scenario: Ctrl+Z progression undo (new)

- GIVEN progression stack has 1 entry, piano-roll stack also has 1 entry
- WHEN user presses Ctrl+Z while progression is focused
- THEN `HandleProgUndo()` fires, progression reverts, piano-roll stack is untouched

#### Scenario: Ctrl+Z piano-roll undo (unchanged)

- GIVEN progression stack has 1 entry, piano-roll stack has 1 entry
- WHEN user presses Ctrl+Z while mouse is over piano roll grid
- THEN piano-roll undo fires, progression stack is untouched

### Requirement: Delete Key

Delete SHALL remove all notes in `selected_indices`. A single undo entry SHALL capture the bulk deletion. Empty selection SHALL be a no-op.

#### Scenario: Delete selected notes

- GIVEN 5 notes, indices 2 and 4 selected
- WHEN user presses Delete
- THEN notes at 2 and 4 removed AND remaining notes shift AND one undo entry captures both deletions

### Requirement: Arrow Nudge

Arrow keys SHALL nudge selected notes. Left/Right change start_beat by 1 snap unit. Up/Down change pitch by 1 semitone. Shift+arrow SHALL nudge by 1 beat (left/right) or 12 semitones (up/down). Snap awareness applies to X-axis nudge.

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

### Requirement: Progression Context Undo/Redo

When the MIDI island is expanded and progression slots are focused (not inside piano roll grid), Ctrl+Z SHALL trigger `seq_store.HandleProgUndo()` and Ctrl+Y SHALL trigger `seq_store.HandleProgRedo()`. Progression dispatch SHALL be checked BEFORE piano-roll dispatch. When progression undo/redo fires, the key event SHALL be consumed and SHALL NOT propagate.

#### Scenario: Ctrl+Z while progression focused

- GIVEN progression has 3 entries and undo stack has 1 entry
- WHEN user presses Ctrl+Z in the midi-island (outside piano roll grid)
- THEN progression entries revert to previous state
- AND the piano-roll undo stack is NOT affected

#### Scenario: Ctrl+Z falls through to piano roll

- GIVEN piano roll grid is focused (mouse over grid)
- WHEN user presses Ctrl+Z
- THEN piano-roll undo fires (existing behavior)

### Requirement: Vkey-Map Configurable Module

A new module `src/core/vkey-map.lua` SHALL export: `GetVkeyMap()`, `SetEntry(vk_code, deg, oct)`, `ResetToDefaults()`, and serialization helpers. The module SHALL start as a deep copy of `config.VKEY_MAP` and SHALL be the single source of truth for key-to-degree/octave mapping. `keyboard.lua` SHALL replace `config.VKEY_MAP` references with `vkey_map.GetVkeyMap()`.

#### Scenario: Custom mapping takes effect

- GIVEN `vkey_map.SetEntry(0x51, 3, 0)` (Q -> degree 3, octave 0)
- WHEN `keyboard.HandleKeyboard()` reads `GetVkeyMap()`
- THEN pressing 'Q' triggers the chord for degree 3 instead of degree 1

#### Scenario: Reset restores defaults

- GIVEN custom mappings have been set
- WHEN `ResetToDefaults()` is called
- THEN all 28 keys revert to `config.VKEY_MAP` original values

### Requirement: Remap Modal Overlay

A 4x7 grid overlay SHALL render when the user toggles remap mode via a gear button in the MIDI island header. Each cell SHALL show the physical key label and its current degree+octave mapping. Clicking a cell SHALL open a dropdown to assign a new degree (1-7) and octave offset (-2 to +1). Conflict detection SHALL warn when two keys map to the same degree+octave combination. Escape SHALL close the overlay.

#### Scenario: Remap grid renders

- GIVEN the gear button is clicked
- WHEN the remap overlay opens
- THEN a 4x7 grid is drawn showing each row (Number, QWERTYU, ASDFGHJ, ZXCVBNM) and column (degree 1-7)
- AND each cell shows current mapping (e.g., "Q -> deg 1")

#### Scenario: Remap one key

- GIVEN the remap overlay is open
- WHEN user clicks cell "Q" and selects "deg 3, oct 0"
- THEN `vkey_map.SetEntry(0x51, 3, 0)` is called
- AND the cell updates to show "Q -> deg 3"

#### Scenario: Conflict detection warns

- GIVEN key 'W' maps to "deg 2, oct 0" and user tries to set 'Q' to the same
- WHEN the dropdown selection completes
- THEN a `reaper.MB` dialog SHALL display "Key Q conflicts with key W (deg 2, oct 0)"
- AND the mapping SHALL NOT be applied until the user confirms the override

### Requirement: Gear Button in Header

The MIDI island header SHALL include a gear button (icon) positioned between the SYNC button and SNAP controls. Clicking the gear SHALL toggle the remap overlay visibility.

#### Scenario: Gear toggles overlay

- GIVEN the MIDI island is expanded
- WHEN user clicks the gear button
- THEN the remap modal overlay SHALL appear
- AND clicking again SHALL close it

### Requirement: Vkey-Map Persistence

`vkey_map_raw` SHALL be stored as a JSON string in ExtState. On script load, the persisted map SHALL be deserialized and applied. `vkey_map_modified` flag SHALL indicate whether the user has deviated from defaults for UI hinting.

#### Scenario: Mapping survives reload

- GIVEN user remapped 3 keys
- WHEN the script reloads
- THEN `vkey_map.GetVkeyMap()` returns the persisted custom mappings
- AND key 'Q' still triggers the user-assigned degree

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
- [ ] Ctrl+Z/Y dispatch to progression undo/redo when progression focused
- [ ] Ctrl+Z/Y fall through to piano roll when NOT progression focused
- [ ] Vkey-map module loads defaults from config.VKEY_MAP
- [ ] Custom vkey mapping persists across script reload
- [ ] Remap overlay renders 4x7 grid with current mappings
- [ ] Conflict detection warns on duplicate degree+octave
- [ ] Gear button toggles remap overlay
