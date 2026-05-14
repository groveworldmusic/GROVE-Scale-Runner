# Proposal: Production-Readiness Polish

## Intent

Eliminar los friction points de producción detectados en la exploración del codebase (~5100 LOC, 382 tests): preferencias de usuario que no persisten entre sesiones, operaciones GFX sin protección `pcall`, código excesivamente grande que perjudica el mantenimiento, y namespaces inconsistentes de ExtState.

## Scope

### In Scope

1. **Split `DrawMIDIIsland()`** (~450 LOC) en 3-4 funciones auxiliares sin cambiar lógica
2. **Persistir preferencias de usuario** vía ExtState (root_index, scale_index, octave, chord_mode_index)
3. **Unificar namespace ExtState**: migrar de `GROVE_Scale_Runner`/`GROVE_FL_MIDI` a `GROVE_FL_MIDI` con migración silenciosa
4. **pcall wrapper** en `gfx.init()`/`gfx.quit()` con display centralizado de errores

### Out of Scope

- Cross-platform preset-browser (reemplazar `io.popen('dir')`)
- Dirty regions / redraw optimization
- Split `preset-browser.lua`
- `@changelog` / `@screenshot` en cabecera ReaPack
- Eliminar ~72 remnant keys de `config.state.*`
- Refactor de `HandlePanel()` (~175 LOC)

## Capabilities

> This section is the CONTRACT between proposal and specs phases.
> The sdd-spec agent reads this to know exactly which spec files to create or update.

### New Capabilities

None — pure refactor and polish change, no spec-level behavior changes.

### Modified Capabilities

None — pure refactor and polish change, no spec-level behavior changes.

## Approach

MVP polish en 4 tareas secuenciales, sin tocar lógica de negocio existente:

1. **Split DrawMIDIIsland** — extraer `DrawKeyboardShortcutOverlay()`, `DrawToolModeRow()`, `DrawSnapControls()`, `DrawPresetPanel()` como funciones top-level. Mismas firmas, mismo comportamiento.
2. **Persistencia ExtState** — `Init()` carga desde ExtState al inicio; cada store setter persiste automáticamente vía `reaper.SetExtState()`. Usar `schema_version` key para migraciones futuras.
3. **Unificar namespace** — en `Init()`, checkear `GROVE_Scale_Runner` primero, si existe leer valores y re-escribir como `GROVE_FL_MIDI`. No borrar legacy hasta próxima versión.
4. **pcall GFX** — crear `SafeGfxInit()`/`SafeGfxQuit()` en `main.lua`. Mostrar error en `reaper.ShowConsoleMsg()` tras cada fallo de pcall. Aplicar también en `compact-init.lua`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/views.lua` | Modified | Split DrawMIDIIsland en funciones helper |
| `src/main.lua` | Modified | SafeGfxInit/SafeGfxQuit con pcall |
| `src/config.lua` | Modified | Init() carga preferencias desde ExtState |
| `src/ui/compact-init.lua` | Modified | pcall en gfx.init/gfx.quit |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Split introduce regresión visual en MIDI Island | Low | Extraer una función a la vez; mantener firmas idénticas; tests visuales manuales |
| Migración de namespace pierde datos legacy | Low | Checkear namespace viejo primero; migrar sin borrar hasta próxima versión |
| pcall silencia errores que deberían ser visibles | Low | Mostrar error via `reaper.ShowConsoleMsg()` SIEMPRE después de pcall |
| Persistencia escribe en cada frame por setter frecuente | Medium | Throttle writes — solo persistir en Init() y en cambio de valor, no en cada acceso |

## Rollback Plan

Cada tarea es un **commit independiente** → `git revert <commit-hash>` revierte solo esa tarea sin afectar el resto. Si todo falla, `git revert HEAD~4..HEAD`.

## Dependencies

- `js_ReaScriptAPI` (ya verificado al inicio)
- `reaper.GetExtState`/`SetExtState` — API nativa de REAPER

## Success Criteria

- [ ] Todos los 382 tests existentes pasan sin modificaciones
- [ ] `root_index`, `scale_index`, `octave`, `chord_mode_index` persisten entre reinicios de REAPER
- [ ] `gfx.init()`/`gfx.quit()` no crashean si se llaman durante REAPER shutdown
- [ ] Namespace ExtState unificado bajo `GROVE_FL_MIDI` sin pérdida de datos de usuario existentes
- [ ] `DrawMIDIIsland()` reducida a <150 LOC (body principal)
