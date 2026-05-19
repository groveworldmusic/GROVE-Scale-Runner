# Proposal: Auto Setup y Hardening

## Intent

Eliminar setup manual (armar track, habilitar monitoreo, configurar entrada MIDI) y corregir 3 bugs críticos que causan notas colgadas y clicks audibles antes de producción.

## Scope

### In Scope
1. Auto track setup: armar, monitorear, routing MIDI, persistencia ExtState, consentimiento usuario
2. Bug #1: Gatear note-off MIDI detrás del ref-count (`midi.lua`)
3. Bug #2: Catch-up solo estado (sin TriggerChord+SendMidi) (`sequencer.lua`)
4. Bug #3: Eliminar VIEW_MODES.ISLAND dead code (`config.lua`, `compact-init.lua`)
5. Bug #4: Añadir `sequencer.Stop()` en CheckFocus al perder foco (`keyboard.lua`)
6. Bug #5: Guard nil item en ExportToMidi (`midi.lua`)
7. Bug #6: Eliminar InterceptMappedKeys redundante (`main.lua`)

### Out of Scope
- Rewrite de stores, migración claves `config.state` remanentes, rediseño UI, nuevas features visuales

## Capabilities

### New Capabilities
- `auto-track-setup`: Armado, monitoreo, input MIDI, persistencia ExtState con consentimiento

### Modified Capabilities
- `midi-runtime-tests`: NoteOff (0x80) solo cuando ref-count llega a 0; parámetro `force` para cleanup
- `sequencer-run-tests`: Catch-up tras pausa usa solo estado (no TriggerChord+SendMidi)
- `check-focus-tests`: Pérdida de foco también llama `sequencer.Stop()`

## Approach

1. **Auto setup**: escanear tracks existentes → si ninguno es apto, crear uno (arm+monitoring+input MIDI) → preguntar consentimiento → persistir flag en ExtState
2. **Bug fixes**: cada fix es el cambio mínimo en su módulo. Los test specs existentes reciben delta specs en este change folder.
3. **VIEW_MODES.ISLAND**: remover referencia en compact-init.lua y `config.lua`. El knowledge doc (`.llm/knowledge/architecture.md`) también se actualiza.

## Affected Areas

| Area | Impact | Files |
|------|--------|-------|
| Core MIDI | Modified | `src/core/midi.lua` |
| Core Sequencer | Modified | `src/core/sequencer.lua` |
| Core Keyboard | Modified | `src/core/keyboard.lua` |
| Config | Modified | `src/config.lua` |
| UI Compact | Modified | `src/ui/compact-init.lua` |
| Main Loop | Modified | `src/main.lua` |
| Knowledge | Updated | `.llm/knowledge/architecture.md` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Auto-setup modifica tracks sin consentimiento | Med | Prompt de confirmación obligatorio |
| Note-off gate rompe AllNotesOff | Low | `force=true` bypasses el gate |
| Fix cambia semántica de test mock assertions | Med | Delta specs en change folder |

## Rollback Plan

Revert commits individuales por bugfix. Auto-setup se deshabilita vía flag ExtState.

## Dependencies

- REAPER API: `GetSetMediaTrackInfo`, `GetSetTrackState`, `GetExtState`, `SetExtState`

## Success Criteria

- [ ] Ref-count note-off no envía 0x80 hasta count = 0
- [ ] Catch-up tras pausa no produce clicks
- [ ] VIEW_MODES.ISLAND no referenciado en ningún .lua
- [ ] CheckFocus al perder foco detiene secuenciador
- [ ] nil item no crashea ExportToMidi
- [ ] Sin InterceptMappedKeys redundante en Init
- [ ] Auto-setup crea track armado + monitoring + input MIDI tras consentimiento
