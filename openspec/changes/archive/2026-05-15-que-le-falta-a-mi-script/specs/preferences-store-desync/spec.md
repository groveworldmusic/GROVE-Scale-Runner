# Spec: preferences_store Desync

## Description
UI mutation sites (`views.lua`, `compact-menu.lua`, `compact-init.lua`) set `config.state.*` values directly and call `persist.Save()`, but never call the corresponding `preferences_store.Set*()` setters. The store remains stale after UI changes.

## Requirements
1. Every `config.state.root_index = X` mutation MUST be followed by `prefs.SetRootIndex(X)`
2. Same for scale_index, octave, chord_mode_index, inversion_index, inversion_direction, subdivision_index
3. `require("state.preferences")` must be added to each file that doesn't already import it
4. Existing `persist.Save()` calls are preserved (double-write is safe; prefs uses debounced TickSaveDebounce)

## Scenarios
- **Happy path**: User changes root from UI → config.state updated + prefs store updated + ExtState saved
- **Edge case**: User changes value and immediately reads from prefs.Get*() → returns correct value (no longer stale)
- **Edge case**: File already has persist.Save() but no prefs.Set*() → prefs.Set*() added; persist.Save() kept as fallback

## Files Affected
- `src/ui/views.lua`: +22 lines (1 require + 21 prefs.Set*() calls)
- `src/ui/compact-menu.lua`: +5 lines (1 require + 4 prefs.Set*() calls)
- `src/ui/compact-init.lua`: +4 lines (1 require + 3 prefs.Set*() calls)

## Estimated LOC
~31 lines changed across 3 files
