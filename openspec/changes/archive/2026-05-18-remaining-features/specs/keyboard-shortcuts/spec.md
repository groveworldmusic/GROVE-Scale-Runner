# Delta for keyboard-shortcuts

## ADDED Requirements

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

- GIVEN `vkey_map.SetEntry(0x51, 3, 0)` (Q → degree 3, octave 0)
- WHEN `keyboard.HandleKeyboard()` reads `GetVkeyMap()`
- THEN pressing 'Q' triggers the chord for degree 3 instead of degree 1

#### Scenario: Reset restores defaults

- GIVEN custom mappings have been set
- WHEN `ResetToDefaults()` is called
- THEN all 28 keys revert to `config.VKEY_MAP` original values

### Requirement: Remap Modal Overlay

A 4×7 grid overlay SHALL render when the user toggles remap mode via a gear button in the MIDI island header. Each cell SHALL show the physical key label and its current degree+octave mapping. Clicking a cell SHALL open a dropdown to assign a new degree (1-7) and octave offset (-2 to +1). Conflict detection SHALL warn when two keys map to the same degree+octave combination. Escape SHALL close the overlay.

#### Scenario: Remap grid renders

- GIVEN the gear button is clicked
- WHEN the remap overlay opens
- THEN a 4×7 grid is drawn showing each row (Number, QWERTYU, ASDFGHJ, ZXCVBNM) and column (degree 1-7)
- AND each cell shows current mapping (e.g., "Q → deg 1")

#### Scenario: Remap one key

- GIVEN the remap overlay is open
- WHEN user clicks cell "Q" and selects "deg 3, oct 0"
- THEN `vkey_map.SetEntry(0x51, 3, 0)` is called
- AND the cell updates to show "Q → deg 3"

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
- AND key `Q` still triggers the user-assigned degree

## MODIFIED Requirements

### Requirement: Undo/Redo Shortcuts

Ctrl+Z SHALL trigger undo. Ctrl+Y SHALL trigger redo. When `IsProgressionFocused()` is true (midi-island expanded, mouse outside piano roll grid), Ctrl+Z SHALL call `HandleProgUndo()` and Ctrl+Y SHALL call `HandleProgRedo()`. When `IsProgressionFocused()` is false, Ctrl+Z/Y SHALL fall through to the piano-roll undo/redo stack (unchanged behavior).
(Previously: Ctrl+Z/Y always targeted piano-roll undo/redo)

#### Scenario: Ctrl+Z progression undo (new)

- GIVEN progression stack has 1 entry, piano-roll stack also has 1 entry
- WHEN user presses Ctrl+Z while progression is focused
- THEN `HandleProgUndo()` fires, progression reverts, piano-roll stack is untouched

#### Scenario: Ctrl+Z piano-roll undo (unchanged)

- GIVEN progression stack has 1 entry, piano-roll stack has 1 entry
- WHEN user presses Ctrl+Z while mouse is over piano roll grid
- THEN piano-roll undo fires, progression stack is untouched
