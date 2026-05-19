# Proposal: Comportamiento de la isla MIDI + Sistema de Presets

## Intent

Three gaps prevent the MIDI island from being a fully usable composition environment: (1) note materialization from progression hardcodes velocity=100 and duration=4 — no per-slot velocity metadata exists, (2) preset serialization saves only the flat notes array, losing the progression context (root, scale, octave, chord_mode, progression entries) needed to restore working state, (3) no rename capability for presets.

## Scope

### In Scope
- Per-slot `velocity` + `duration` fields on progression entries, set at drop time from pads/keyboard
- `ProgressionToNotes()` uses per-slot velocity/duration when present (fallback to defaults)
- `.grove` format v2: saves full progression context + root/scale/octave/chord_mode metadata
- Preset load restores BOTH notes array AND progression context
- Rename preset via `reaper.GetUserInputs()` + filesystem rename

### Out of Scope
- Per-note velocity editing in piano roll grid (Phase 2 scope)
- Drag-to-adjust bars in velocity editor (already exists as click-drag)
- Preset folder/category organization
- Live preview while renaming

## Capabilities

### New Capabilities
None — all changes are extensions to existing capabilities.

### Modified Capabilities
- `preset-browser` (spec): `.grove` format extends to v2 — adds `progression`, `root_index`, `scale_index`, `octave`, `chord_mode_index` fields. Backward-compatible reader for v1. Adds rename action in browser UI.
- `island-store` (spec): Progression entry schema extended with optional `velocity` (1-127) and `duration` (beats). `ProgressionToNotes()` reads per-slot values with fallback to parameter defaults.

## Approach

1. **Schema**: `progression.Add()` in `slots.lua` sets default velocity=100, duration=4 on new entries. Drag-from-pad creation (line 152-158) adds these fields. Velocity-editor changes per-note velocity propagate back via editable slot metadata (future).
2. **Materialization**: `island_store.ProgressionToNotes()` checks per-entry `velocity` (fallback 100) and `duration` (fallback `beats_per_slot`). `LoadNotesFromProgression()` passes default params, slot-level overrides apply.
3. **Presets**: `SavePreset()` serializes progression entries + context fields into `.grove` v2. `LoadPreset()` detects format version: v1 reads notes only, v2 restores notes + progression + context. Progression restored via `seq_store.SetProgression()`.
4. **Rename**: New `RenamePreset()` function → `reaper.GetUserInputs()` dialog → file rename → directory rescan.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/core/slots.lua` | Modified | Add velocity/duration to new slot entries (lines 152-158) |
| `src/core/progression.lua` | Modified | `Add()` accepts optional velocity/duration |
| `src/state/island.lua` | Modified | `ProgressionToNotes()` reads per-slot fields |
| `src/ui/preset-browser.lua` | Modified | Format v2 save/load, rename action |
| `src/state/sequencer.lua` | Observed | No change needed — entries are tables, extra keys pass through |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| v1 preset backward compat break | Low | Loader detects `version` field; v1 (no version or version=1) reads notes-only and upgrades in-memory |
| Schema extension breaks existing progression consumers | Low | All consumers access `entry.degree`, `entry.root_index` etc — new optional fields (`velocity`, `duration`) are ignored if absent |
| Rename on filesystem fails (locked file) | Low | Show error banner, existing preset unaffected |

## Rollback Plan

1. Revert changes to the 4 modified files
2. v2 `.grove` files remain on disk but are readable (v1 loader ignores unknown fields)
3. Existing v1 presets unaffected by rollback

## Dependencies

None — all changes are self-contained within existing modules and stores.

## Success Criteria

- [ ] Progression entries created from pads carry velocity=100, duration=4 by default
- [ ] `ProgressionToNotes()` produces notes with per-entry velocity when present, fallback 100 otherwise
- [ ] Save preset writes v2 format with `progression` + context fields
- [ ] Load preset restores both notes array AND progression to sequencer_store
- [ ] Load v1 preset (no version field) reads notes-only, no crash
- [ ] Rename preset via UI → filesystem renamed → list refreshes
