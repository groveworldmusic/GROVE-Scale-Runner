# Delta for preferences_store Desync

Bug fix: UI code mutates `config.state` directly without updating `preferences_store`, causing stale values when read through store getters.

## ADDED Requirements

### Requirement: Sync preferences_store on every config.state mutation

Every direct mutation of `config.state.{root_index, scale_index, octave, chord_mode_index, inversion_index, inversion_direction, subdivision_index}` in UI code MUST be immediately followed by the corresponding `prefs.Set*()` call.

Affected mutation sites:

| File | Line(s) | config.state key | Missing store setter |
|------|---------|-----------------|---------------------|
| `views.lua` | 48 | root_index | `prefs.SetRootIndex(v)` |
| `views.lua` | 51 | scale_index | `prefs.SetScaleIndex(v)` |
| `views.lua` | 54 | octave | `prefs.SetOctave(v)` |
| `views.lua` | 57 | chord_mode_index | `prefs.SetChordModeIndex(v)` |
| `views.lua` | 212 | scale_index | `prefs.SetScaleIndex(v)` |
| `views.lua` | 229 | subdivision_index | `prefs.SetSubdivisionIndex(v)` |
| `views.lua` | 253 | octave | `prefs.SetOctave(v)` |
| `views.lua` | 255, 257, 259 | octave | `prefs.SetOctave(v)` |
| `views.lua` | 273, 275, 277, 279 | chord_mode_index | `prefs.SetChordModeIndex(v)` |
| `views.lua` | 313 | inversion_direction | `prefs.SetInversionDirection(v)` |
| `views.lua` | 323 | inversion_index | `prefs.SetInversionIndex(v)` |
| `views.lua` | 776 | root_index | `prefs.SetRootIndex(v)` |
| `views.lua` | 785 | scale_index | `prefs.SetScaleIndex(v)` |
| `views.lua` | 792, 799 | octave | `prefs.SetOctave(v)` |
| `views.lua` | 808 | chord_mode_index | `prefs.SetChordModeIndex(v)` |
| `compact-menu.lua` | 76 | root_index | `prefs.SetRootIndex(v)` |
| `compact-menu.lua` | 78 | scale_index | `prefs.SetScaleIndex(v)` |
| `compact-menu.lua` | 80 | octave | `prefs.SetOctave(v)` |
| `compact-menu.lua` | 82 | chord_mode_index | `prefs.SetChordModeIndex(v)` |

The existing `persist.Save()` calls MAY remain — they are harmless duplicates since `prefs.Set*()` uses debounced saves via `TickSaveDebounce()`.

#### Scenario: User changes root note via docked transport bar

- GIVEN the docked transport bar is visible and the user clicks the ROOT button
- WHEN `config.state.root_index` is incremented and `persist.Save("root_index", ...)` is called
- THEN `prefs.SetRootIndex(new_value)` MUST also be called
- AND `prefs.GetRootIndex()` MUST return the new value immediately

#### Scenario: User changes scale via compact context menu

- GIVEN the compact view right-click menu is open
- WHEN the user selects a different scale
- THEN `prefs.SetScaleIndex(new_value)` MUST be called alongside `config.state.scale_index = new_value`
- AND any subsequent read via `prefs.GetScaleIndex()` in keyboard.lua MUST reflect the new value

#### Scenario: Rapid clicking — debounced save still works

- GIVEN the user clicks chord mode buttons rapidly (NOTE → TRI → 7MA → 9NA in under 1 second)
- WHEN each click calls `prefs.SetChordModeIndex(v)`
- THEN only `chord_mode_index` is marked dirty (no duplicate ExtState writes for intermediate values)
- AND `TickSaveDebounce()` flushes the final value once per frame

## MODIFIED Requirements

None — no existing spec for this domain.

## REMOVED Requirements

None.
