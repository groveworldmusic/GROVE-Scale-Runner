# GROVE FL MIDI — Root Agent

Sos el **orquestador principal** del proyecto. Tu responsabilidad es coordinar a los agentes hijo, mantener el orden del proyecto, y asegurar que todo el desarrollo siga los estándares definidos.

## Stack

- **Lenguaje**: Lua 5.x / LuaJIT
- **Entorno**: REAPER GFX API (`reaper.*`, `gfx.*`)
- **Propósito**: Controlador MIDI QWERTY-to-MIDI para REAPER con interfaz visual GFX
- **Estado**: Maduro, post-refactor estructural completo (fases 1-3d)

## Project Metrics

| Métrica | Valor |
|---------|-------|
| Archivos fuente (`src/`) | 55 (Lua) + 4 AGENTS.md (src, core, ui, state) = 59 |
| TLOC estimados (src/) | ~9,800 |
| State stores | 9 (compact, drag, midi, sequencer, ui, island, piano-roll-store, preset-store, preferences) + persist (load/save) |
| Core modules | 6 (midi, keyboard, sequencer, progression, api-guard, snap) |
| UI modules | 37 (29 root + 6 piano-roll/ + 2 midi-island/) |
| Tests | 14 test files in runner, 497 check() calls, 1 static-test outside runner |
| Referencias a `config.state.*` runtime | ~17 (view_offset_x/y only) |
| Total archivos en proyecto | ~90 (src/ + tests/ + docs/ + config) |

## Jerarquía de Agentes

| Ruta | Responsabilidad |
|------|----------------|
| `AGENTS.md` (root) | Orquestación general, estándares, entrada principal, dependency map, init/teardown contract, pattern glossary, issue registry |
| `src/AGENTS.md` | Orquesta core + ui + state, estructura de `src/`, reglas de módulo Lua, life cycle del run loop |
| `src/core/AGENTS.md` | Lógica de dominio: MIDI, teclado, secuenciador, progresión, api-guard, snap — firmas de funciones, pitfalls, patterns |
| `src/ui/AGENTS.md` | Interfaz GFX: componentes, vistas, layout, temas, piano-roll, midi-island, icons, gfx-safe — convenciones GFX, barrel modules, compact view architecture |
| `src/state/AGENTS.md` | Stores de estado: 9 stores + persist, Init semantics, remnant keys, getters/setters detallados |
| `tests/AGENTS.md` | Infraestructura de testing, mocks, ~497 assertions, test file list |

## Circular Dependency Map

```
sequencer.lua ──require──► midi.lua ──require──► sequencer_store (state)
                                   └─require──► midi_store (state)

progression.lua ──require──► sequencer_store (state)

keyboard.lua ──require──► midi.lua
                require──► core.sequencer (para Stop)
                require──► midi_store (state)
                require──► preferences_store (state)

slots.lua ──Lazy require──► components.lua (ui, en runtime)  [moved to src/ui/slots.lua — see ui/AGENTS.md]

widgets/*.lua ──Lazy require──► components.lua (en runtime)

components.lua ──require──► buttons, paginator, dropdown, piano, pads, drag
                 require──► slots (ui/slots.lua — moved from core/)

views.lua ──require──► sequencer (para sequencer.Stop() en play/stop toggle)
```

**⚠️ CRUCIAL**: `sequencer → midi` es la dirección correcta. `midi → sequencer` NO existe — `midi.lua` usa `sequencer_store` (state) para leer volumen. Esta regla evita la dependencia circular.

**⚠️ keyboard → sequencer**: `keyboard.lua` ahora requiere `core.sequencer` (para interpretar shortcuts globales). NO hay ciclo porque `sequencer.lua` no requiere `keyboard.lua`.

## Init / Teardown Contract

### Init() — Orden exacto (actualizado)
1. `config = require("config")`
2. `compact_store.Init(config.state)`
3. `drag_store.Init(config.state)`
4. `sequencer_store.Init(config.state)`
5. `midi_store.Init(config.state)`
6. `ui_store.Init(config.state)`
7. `island_store.Init(config.state)` — inits piano-roll-store internamente
8. `preset_store.Init(config.state)`
9. `preferences_store.Init(config.state)`
10. core requires: `theme`, `midi`, `sequencer`, `views`, `compact`, `keyboard`
11. `persist` + `gfx_safe` requires
12. `persist.Load(config.state)` — load ExtState overlays
13. `preferences_store.SyncFromState(config.state)` — push overlays into store
14. `gfx.init(...)` con `config.state.view_offset_x/y`
15. Keyboard intercept + auto-start logic
16. `reaper.defer(MainLoop)`

### Cleanup — CleanupAll() (main.lua línea 205)
1. `midi.AllNotesOff(true)` — force=true bypasses ref-count gate on cleanup
2. `sequencer.Stop()`
3. `keyboard.Cleanup()` — release intercept
4. `compact.Cleanup()`

### Guard
`reaper.atexit(CleanupAll)` en Init + flag `ui_store.GetDidCleanup()` previene double cleanup. CleanupAll es idempotente.

## Pattern Glossary

### Patrón: Ref-counted Active Notes
**Contexto**: Múltiples triggers (teclado + pads) pueden targetear la misma nota MIDI. Un booleano simple causa stuck notes al liberar una sola vez.
**Implementación**: `midi.lua` lines 41-68 — `midi_store.SetActiveNote(note, (cur or 0) + 1)` en note-on; decrement en note-off; `nil` al llegar a 0.
**Por qué**: Note-off solo se dispara cuando TODOS los triggers liberan la nota.

### Patrón: Barrel (Re-export)
**Contexto**: Submódulos de compact/ y widgets/ necesitan una fachada unificada para los consumers.
**Implementación**: `components.lua` (184 LOC) y `compact.lua` (25 LOC) — require de submódulos + re-assign de funciones. Consumers usan `components.*` o `compact.*`. `piano-roll.lua` (83 LOC) también es barrel para piano-roll/*.
**Por qué**: Un solo require en vez de 7+. Aísla cambios de estructura interna.

### Patrón: Lazy require
**Contexto**: `slots.lua`, `buttons.lua` requieren `components.lua` que a su vez los requiere (dependencia circular).
**Implementación**: `require("ui.components")` dentro de cada función, no al tope del módulo. Posterga la resolución hasta runtime cuando ambos módulos están cargados.
**Por qué**: Rompe la circularidad sin refactor arquitectónico.

### Patrón: Event Bus (mouse_click)
**Contexto**: Evento de click con vida de 1 frame. Múltiples widgets necesitan leerlo pero solo uno debe consumirlo.
**Implementación**: `ui_store.SetMouseClick()` en main.lua. `ui_store.ConsumeMouseClick()` devuelve y resetea.
**Por qué**: Ciclo de vida predecible — cero estado stale entre frames.

### Patrón: Temporary Context (temp_ctx)
**Contexto**: Cada key press en HandleKeyboard necesita un context table para TriggerChord. Alocar por frame es GC-heavy.
**Implementación**: `keyboard.lua` line 16: `local temp_ctx = {}` — table mutada in-place (lines 36-39) antes de cada llamada.
**Por qué**: Zero-allocation en hot path. Uso sincrónico → seguro.

### Patrón: Consume (mouse_wheel_delta)
**Contexto**: Scroll delta debe leerse UNA vez por widget y no acumularse entre frames.
**Implementación**: `ui_store.ConsumeMouseWheelDelta()` — devuelve valor actual y lo zeroa.
**Por qué**: Evita scroll fantasma cuando múltiples widgets procesan el mismo delta.

### Patrón: Play/Stop → sequencer.Stop()
**Contexto**: El botón Play/Stop en la UI (views.lua) togglea reproducción. Al detener, las notas MIDI activas en `MidiNotes` deben silenciarse.
**Implementación**: Cuando `is_playing == true` y se clickea, se llama `sequencer.Stop()` en vez de solo `seq_store.SetIsPlaying(false)`. `sequencer.Stop()` itera `MidiNotes` y manda note-offs, limpia la tabla, resetea step/progress/measure/clock.
**Por qué**: `sequencer.Run()` retorna early si `IsPlaying == false`, entonces las notas nunca recibirían note-off sin esta llamada explícita.
**Riesgos**: views.lua ahora requiere `core.sequencer` — verificar que no haya ciclo (no lo hay: views → sequencer → midi → sequencer_store, midi NO requiere views).

### Patrón: API Guard
**Contexto**: REAPER scripts pueden fallar si APIs opcionales no están instaladas. El script debe validar dependencias al inicio.
**Implementación**: `api-guard.lua` — `AssertAPIs({...})` checkea cada API via `reaper.APIExists`, muestra mensaje de error si faltan.
**Por qué**: Previene crashes en mid-session por APIs faltantes. Mensaje claro al usuario sobre qué extensión instalar.

### Patrón: Snap Grid (Pure Function)
**Contexto**: Piano roll necesita snap a grid para beats. Sin estado, sin side effects.
**Implementación**: `snap.lua` — `SnapBeat(beat, resolution, triplet)` es una función pura que redondea un beat a la grilla más cercana.
**Por qué**: Fácil de testear, cero deuda técnica, reutilizable en cualquier contexto.

### Patrón: Lasso Selection
**Contexto**: Piano roll necesita selección multi-nota por arrastre de rectángulo.
**Implementación**: `piano-roll-store.lua` almacena `lasso_active`, `lasso_start_x/y`, `lasso_end_x/y`. `interaction.lua` dibuja el rect y detecta notas dentro.
**Por qué**: Estado centralizado para lasso evita duplicación entre módulos de interacción y rendering.

### Patrón: Undo/Redo Stack
**Contexto**: Ediciones en piano roll necesitan deshacer/rehacer.
**Implementación**: `piano-roll-store.lua` mantiene `undo_stack` y `redo_stack` (max 50 entradas). Cada snapshots de notas antes de mutar. UUID-based note identification.
**Por qué**: Stack-based approach es simple, predecible y suficientemente performante para uso musical interactivo.

### Patrón: Debounced Preference Save
**Contexto**: Cada setter de preferences escribe a `reaper.SetExtState`. Múltiples setters por frame causan N escrituras sincrónicas.
**Implementación**: `preferences.lua` marca `save_pending = true` en cada setter. `TickSaveDebounce()` flush una vez por frame desde MainLoop.
**Por qué**: Reduce I/O de ExtState, agrupa cambios en una sola escritura batch por frame.

## Remnant Keys (config.state)

Keys que permanecen como root keys de `config.state`. Las 7 preference keys (root_index, scale_index, octave, chord_mode_index, inversion_index, inversion_direction, subdivision_index) ya fueron migradas a `preferences_store` (Sprint 1). Solo view_offset_x/y y use_scroll permanecen como remnant runtime reads directos:

| Key | Rango | Propósito |
|-----|-------|-----------|
| `view_offset_x` | number | Posición X de ventana GFX |
| `view_offset_y` | number | Posición Y de ventana GFX |
| `use_scroll` | boolean | Scroll habilitado |

~17 runtime reads remanentes en 5+ archivos (views.lua, main.lua, midi.lua, compact-init.lua, compact-menu.lua). Todos son reads/escrituras de `config.state.view_offset_x/y` para posicionamiento de ventana GFX. `use_scroll` se lee via `ui_store.GetUseScroll()` — sin reads directos remanentes.

## Issue Registry

Issues referenciados en comentarios del código fuente:

| Issue | Archivos | Resumen |
|-------|----------|---------|
| 5 | `pads.lua` | Release pad-held notes only when drag starts | ✅ FIXED |
| 6 | `views.lua` | U+25C4 glyph support for undock button | ✅ FIXED (Phase 4, replaced with gfx.triangle) |
| 7 | `compact-init.lua` | Transport window find — SWS fallback chain | ✅ FIXED |
| 8 | `views.lua`, `main.lua` | DecrementPageOverrideTimer in ALL modes | ✅ FIXED |
| 9 | `views.lua` | Octave dropdown rendering | ✅ FIXED (Phase 4, dynamic oct_open_up) |
| 10 | `positioning.lua` | Invalidate auto-position cache on transport resize | ✅ FIXED |
| 12 | `keyboard.lua` | Reusable temp_ctx table for key press handling | ✅ FIXED |
| 13 | `piano.lua` | Cached scale note tables — avoid recompute on every draw | ✅ FIXED |
| 18 | `piano.lua` | O(N·M) inner loop → O(1) via pre-computed pitch-class set | ✅ FIXED |
| 19 | `sequencer.lua` | Cache GetLastFilled() once per tick | ✅ FIXED |
| 21 | `keyboard.lua` | Velocity humanization (85 + math.random(30)) | ✅ FIXED |
| 22 | `views.lua` | Stuck note on play/stop toggle | ✅ FIXED |

## Reglas Obligatorias para TODOS los agentes

### Orden del proyecto

1. **NO crear archivos sueltos en la raíz del proyecto.** Todo archivo nuevo debe ir en su directorio correspondiente (`src/`, `tests/`, `.llm/`, `openspec/`, `docs/`).
2. **NO crear documentación sin estructura.** Los únicos directorios para documentación son `docs/` (documentación de desarrollo, NO modificar) y `.llm/knowledge/` (conocimiento para LLMs).
3. **docs/ es read-only.** El contenido de `docs/` es documentación de desarrollo escrita por el usuario. NO se modifica, NO se elimina, NO se reorganiza.
4. **`.llm/` es el lugar para todo lo relacionado con LLMs.** AGENTS.md hijos, knowledge, templates — todo va allí.

### Auto-update de conocimiento

Cuando ocurra cualquiera de estos eventos, DEBÉS actualizar los archivos correspondientes:

| Evento | Archivo a actualizar |
|--------|---------------------|
| Decisión técnica (arquitectura, patrón, librería) | `.llm/knowledge/decisions.md` + Engram |
| Bug encontrado y corregido | `.llm/knowledge/learnings.md` + Engram |
| Gotcha / edge case / descubrimiento | `.llm/knowledge/learnings.md` + Engram |
| Convención establecida (naming, estructura) | `.llm/knowledge/conventions.md` |
| Cambio en la arquitectura (archivos nuevos, directorios) | `.llm/knowledge/architecture.md` |
| Actualización de estándares del proyecto | `AGENTS.md` correspondiente |
| Issue identificado en código | `.llm/knowledge/learnings.md` + Engram |
| Dependencia circular nueva o corregida | `.llm/knowledge/architecture.md` + root `AGENTS.md` |

Usá las plantillas en `.llm/templates/` para formato consistente.

### Persistencia con Engram

Usá Engram para memoria persistente entre sesiones:
- `mem_save` después de decisiones, bugs, descubrimientos
- `mem_search` al empezar una tarea que pueda tener contexto previo
- Usá `topic_key` consistente: `architecture/*`, `decision/*`, `bug/*`, `learning/*`

### Delegation Protocol

1. Identificá qué área toca el cambio (core, ui, state, tests)
2. Pasá el control al AGENTS.md hijo correspondiente
3. El agente hijo ejecuta y reporta resultados
4. Si hay aprendizajes, actualizás `.llm/knowledge/` al finalizar
5. Si el cambio toca múltiples áreas, coordiná via `src/AGENTS.md`
6. NO implementés cambios de código fuente directamente — siempre delegá al agente hijo

### Enlaces rápidos

- `.llm/knowledge/architecture.md` — Mapa completo del proyecto
- `.llm/knowledge/decisions.md` — Decisiones técnicas registradas
- `.llm/knowledge/learnings.md` — Bugs, gotchas, soluciones
- `.llm/knowledge/conventions.md` — Estándares de código
- `.llm/templates/adr.md` — Plantilla para nuevas decisiones
- `.llm/templates/learning.md` — Plantilla para nuevos aprendizajes
- `openspec/specs/refactor/spec.md` — Especificaciones del refactor completo
- `src/AGENTS.md` — Orquestación de core + ui + state
- `src/core/AGENTS.md` — Lógica de dominio con firmas de funciones
- `src/ui/AGENTS.md` — Componentes GFX y convenciones visuales
- `src/state/AGENTS.md` — Stores de estado y getters/setters
- `tests/AGENTS.md` — Infraestructura de testing
