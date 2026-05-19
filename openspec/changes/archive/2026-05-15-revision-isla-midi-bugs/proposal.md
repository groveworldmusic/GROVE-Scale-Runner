# Proposal: Revisión de bugs en isla MIDI

## Intent

Corregir 11 bugs encontrados en la isla MIDI y piano roll, desde el scroll overflow reportado por el usuario (CRITICAL) hasta code smells (LOW). El objetivo es que notas, ghosts y velocity bars respeten los bounds del grid horizontal.

## Scope

### In Scope
- B1-B4 (CRITICAL): X clipping en DrawNoteBlocks, ghost rendering, velocity bars + corregir ComputeVisibleRanges
- B5-B6 (HIGH): `_focus_pending` global → local; measure lines overflow derecho
- B7-B9 (MEDIUM): ref-counted notes en keyboard strip; `grid_x` redeclarado; OCTAVE_BUFFER
- B10-B11 (LOW): clamp `beat_start`; validación `snap_resolutions`

### Out of Scope
- Refactors arquitectónicos grandes, nuevas features, tests automatizados

## Capabilities

### New Capabilities
None — pure bug fixing, sin cambios a nivel spec.

### Modified Capabilities
None — no cambia comportamiento contractual. Los fixes son visuales y conforman specs existentes.

## Approach

**Combinado (Approach 3)**:

1. Corregir `ComputeVisibleRanges` para usar `grid_w` en vez de `w` (causa raíz del scroll overflow)
2. Agregar X clipping en `DrawNoteBlocks`, ghost rendering y velocity bars (belt-and-suspenders)
3. Fixes localizados (1-3 líneas) para B5-B11

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/piano-roll/note.lua` | Modified | X clipping en DrawNoteBlocks + ghost |
| `src/ui/piano-roll/view.lua` | Modified | ComputeVisibleRanges usa `grid_w` |
| `src/ui/piano-roll/grid.lua` | Modified | Measure overflow, OCTAVE_BUFFER, beat_start clamp, grid_step |
| `src/ui/velocity.lua` | Modified | X clipping en velocity bars |
| `src/ui/midi-island.lua` | Modified | `_focus_pending` → local |
| `src/ui/timeline.lua` | Modified | Eliminar double `grid_x` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Over-clipping (notas parciales desaparecen) | Low | `math.max`/`math.min` como Y clipping actual |
| Regresión visual ComputeVisibleRanges | Low | Solo beat_end, visual testing rápido |

## Rollback Plan

`git revert` del commit. Cambios localizados en ≤6 archivos, visual-only.

## Dependencies

None. Todos los fixes son independientes entre sí.

## Success Criteria

- [x] B1: Notas no se renderizan sobre tira de teclas ni scrollbar
- [x] B2: ComputeVisibleRanges usa `grid_w` para beat_end
- [x] B3: Ghosts durante drag respetan bounds del grid
- [x] B4: Velocity bars no overflown horizontalmente
- [x] B5: `_focus_pending` declarado `local`
- [x] B6: Measure lines no exceden `x + w`
- [x] B7: Keyboard strip usa `midi_store.SetActiveNote()`
- [x] B8: Sin doble `local grid_x` en timeline.lua
- [x] B9: OCTAVE_BUFFER reducido (ej. 4, no 12)
- [x] B10: `beat_start = math.max(0, scroll_x - 1)`
- [x] B11: `snap_resolutions` validado o min_grid_step normalizado
