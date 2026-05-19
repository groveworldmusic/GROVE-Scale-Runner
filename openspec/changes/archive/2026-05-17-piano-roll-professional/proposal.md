# Proposal: Piano Roll Professional

## Intent

Llevar el piano roll a nivel DAW profesional (FL Studio, Ableton). 12 gaps identificados que cubren edición, musicalidad, visuales y workflow. Implementación por fases para mantener review budget.

## Scope

### In Scope
- **Fase 1 — Editing UX Core**: Auto-scroll playback, quantize, note audition, tool shortcuts (1/2/3), Alt+drag clone
- **Fase 2 — MIDI CC Lanes**: Infraestructura multicanal (modulation, expression, pan, sustain), lane selector UI, drawing
- **Fase 3 — Musical Operations**: Humanize, strum, arpeggiate, line/ramp tool en velocity editor
- **Fase 4 — Visual Polish**: Fold to scale, ghost notes (octavas adyacentes), note coloring (velocity/pitch schemes)
- **Fase 5 — Advanced**: Step recording, time signature support

### Out of Scope
- MIDI recording desde teclado externo (requiere REAPER MIDI input, fuera del scope GFX)
- Audio rendering / export a audio file
- Plugin VSTi hosting

## Capabilities

### New Capabilities
- `auto-scroll`: Playhead-follow viewport durante playback
- `quantize`: Alinear timing de notas seleccionadas con % de fuerza + swing
- `midi-cc-lanes`: Edición multicanal de MIDI CC (modulation, expression, pan, sustain)
- `musical-operations`: Humanize, strum, arpeggiate sobre selección
- `fold-to-scale`: Ocultar filas no-escala del grid
- `ghost-notes`: Notas fantasma en octavas adyacentes
- `note-coloring`: Esquemas de color por velocity, pitch class, o grado
- `step-recording`: Inserción nota-por-nota sincronizada al playhead
- `time-signature`: Soporte de compases no-4/4 (3/4, 6/8)

### Modified Capabilities
- `velocity-editor`: Line/ramp tool (Ctrl+drag crea rampa lineal)
- `note-editing`: Alt+drag para clonar notas en vez de mover
- `keyboard-shortcuts`: Tool switching shortcuts (1=paint, 2=knife, 3=eraser) + note audition on click

## Approach

5 fases secuenciales. Cada fase se entrega como un PR encadenado en la feature branch `feat/piano-roll-pro`. Fase 1 ataca los mayores dolores (auto-scroll + quantize + audition). Fases posteriores agregan capabilities sin modificar la base existente.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/piano-roll/*` | Modified | Todos los submódulos |
| `src/state/island.lua` | Modified | Nuevos flags: follow_playhead, quantize_strength, cc_lane_active, fold_scale, color_scheme |
| `src/state/note-store.lua` | Modified | Quantize function, humanize/strum/arpeggiate |
| `src/ui/velocity.lua` | Modified | Line/ramp tool mode |
| `src/ui/midi-island.lua` | Modified | Auto-scroll loop, lane selector UI, step recording state |
| `src/ui/midi-island/input.lua` | Modified | Tool switching dispatch, alt-key detection |
| `src/ui/timeline.lua` | Modified | Time signature display |
| `src/state/` | New | `cc-lane-store.lua` |
| `src/ui/piano-roll/` | New | `quantize.lua`, `musical-ops.lua` |
| `src/ui/icons.lua` | Modified | Nuevos icons |
| `src/ui/theme.lua` | Modified | Nuevos colores |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| CC Lanes muy grande para un solo slice | Medium | Fase 2 independiente con budget 400 líneas |
| Auto-scroll flicker en GFX | Low | clamped scroll_x + dirty flag |
| Step recording sincronía precisa | Medium | Usar sequencer clock ticks existente |

## Rollback Plan

Cada fase es autónoma. Si Fase 1 falla → `git revert` del merge commit de esa fase.

## Dependencies

- `core.midi.SendMidi` para note audition
- `core.sequencer` clock para auto-scroll y step recording
- `core.snap.SnapBeat` para quantize
- Infraestructura existente de undo/redo en note-store

## Success Criteria

- [ ] Auto-scroll mantiene playhead visible durante playback en todo momento
- [ ] Quantize alinea notas al snap grid con % de fuerza seleccionable
- [ ] Note audition suena MIDI al clickear o crear notas
- [ ] CC Lanes permite seleccionar y editar >=4 tipos de CC
- [ ] Line/ramp tool dibuja rampa lineal en velocity editor al Ctrl+drag
- [ ] Alt+drag clona notas seleccionadas en vez de moverlas
- [ ] Fold to scale oculta filas no-escala del grid y del keyboard strip
- [ ] Humanize/strum/arpeggiate operan sobre selección con undo
- [ ] Todos los cambios pasan verify estático
