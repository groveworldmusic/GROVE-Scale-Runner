## Exploration: Production-Readiness Polish

### Current State
El codebase está **maduro y bien estructurado** (~5100 LOC, 38 archivos fuente, 382 tests). Pasó por 4 fases de refactor estructural completo. Tiene:
- Patrones consistentes (barrel, lazy require, ref-counted active notes)
- Tests automatizados con mocks de reaper/gfx
- Cabecera ReaPack estándar completa
- Verificación de dependencia js_ReaScriptAPI al inicio

Sin embargo, faltan pulidos de producción en: manejo de errores, persistencia de preferencias, y algunas funciones muy grandes que deberían splitearse.

### Affected Areas
- `src/main.lua` — entry point, cleanup, init
- `src/ui/views.lua` — ~860 LOC, necesita split
- `src/ui/preset-browser.lua` — ~640 LOC, pcall coverage
- `src/core/midi.lua` — ExportToMidi sin sanity checks
- `src/ui/piano-roll.lua` — HACK comentario
- `src/config.lua` — ~72 refs a `config.state.*` remanentes
- `src/ui/compact-init.lua` — gfx.init/gfx.quit sin pcall

### Findings by Area

#### 1. Limpieza y Legibilidad

**Hallazgos Positivos**:
- ✅ Cero llamadas `print()` encontradas en `src/` (sin debug prints)
- ✅ Patrón de módulo consistente: `local m = {}` + `return m`
- ✅ Naming generalmente claro: `TriggerChord`, `GetMidiNote`, `DrawRoundedRect`

**Problemas Encontrados**:

| Problema | Ubicación | Severidad |
|----------|-----------|-----------|
| Función >300 LOC | `views.lua: DrawMIDIIsland()` ~450 líneas | **Alta** |
| Función >200 LOC | `compact-init.lua: HandlePanel()` ~175 líneas | Media |
| Módulo >600 LOC | `preset-browser.lua` ~640 líneas | Media |
| Comentario HACK | `piano-roll.lua:83` — `-- HACK: Sync PITCH_ROW_H...` | Baja |
| Variables genéricas | `m`, `ok`, `ret`, `n`, `s` (convencional en Lua pero mejorable) | Baja |

**Detalle: DrawMIDIIsland**
La función más grande del proyecto (~450 LOC) incluye:
- Keyboard shortcut dispatch (Ctrl+Z/Y/X/C/V, Delete, arrows)
- 3 tool mode buttons routing
- 7 snap controls
- Preset browser collapsible panel
- Timeline ruler + piano roll + velocity editor
- Lasso multi-select logic

**Debería splitearse en al menos 3-4 funciones auxiliares**.

#### 2. Manejo de Errores

**Coverage Actual**:
- `preset-browser.lua`: 12 usos de `pcall` (buena cobertura para operaciones de archivo)
- `compact-init.lua:36`: 1 uso de `pcall` para `GetTransportHwnd` (SWS fallback)

**Faltantes Críticos**:

| Operación | Riesgo | Ubicación |
|-----------|--------|-----------|
| `gfx.init()` | Puede fallar si REAPER está cerrando | `main.lua:273`, `compact-init.lua:131` |
| `gfx.quit()` | Puede fallar en contextos inválidos | `main.lua:253`, `compact-init.lua:74` |
| `reaper.StuffMIDIMessage` | No valida que el mensaje sea válido | `midi.lua:34`, `midi.lua:50` |
| `ExportToMidi`: sin track validación post-creación | `CreateNewMIDIItemInProj` puede retornar `nil` | `midi.lua:145` ya tiene guard, pero `GetSelectedTrack` no valida |
| `JS_Window_GetRect` HWND puede ser stale | Ya tiene `ValidatePtr` en `RestorePreviousTrack` | `main.lua:131` ✅ |

**Cómo se muestran errores hoy**:
- Solo `reaper.MB()` en 2 lugares:
  1. `main.lua:42` — "Could not determine script path"
  2. `main.lua:261` — "Por favor instala js_ReaScriptAPI via ReaPack"

**Sin mecanismo centralizado de logging ni error display**.

#### 3. Configuración y Persistencia

**Persistencia Actual (GetExtState/SetExtState)**:

| Key | Namespace | Persiste? |
|-----|-----------|-----------|
| `auto_start_compact` | `GROVE_Scale_Runner` | ✅ |
| `auto_start_reaper` | `GROVE_Scale_Runner` | ✅ |
| `auto_track_setup` | `GROVE_Scale_Runner` | ✅ |
| `preset_favorites` | `GROVE_FL_MIDI` | ✅ |

**NO Persiste (se pierde al cerrar el script)**:

| Configuración | Impacto Usuario |
|---------------|-----------------|
| `root_index` (nota raíz) | Tiene que re-seleccionar C/Am cada vez |
| `scale_index` (escala) | Mayor escala: Minor Harmonic, etc. |
| `octave` | Octava base preferida |
| `chord_mode_index` | Off/Tri/7ma/9na |
| `inversion_index` / `inversion_direction` | Inversión preferida |
| `subdivision_index` | Subdivisión del secuenciador |
| `volume` (sequencer) | Volumen MIDI default |
| `color_mode` ("grade" vs "flat") | Preferencia visual |
| `use_velocity` | Velocity humanization on/off |
| `view_offset_x` / `view_offset_y` | Posición de ventana (tiene default pero no persiste) |

**Problema Adicional**: 2 namespaces inconsistentes:
- `GROVE_Scale_Runner` para auto-start
- `GROVE_FL_MIDI` para preset_favorites

**Deberían unificarse** bajo un solo namespace.

**Remnant Keys**: ~72 referencias a `config.state.*` permanecen. Idealmente toda preferencia debería:
1. Vivir en su store correspondiente
2. Persistir via ExtState
3. Cargarse al inicio en `Init()`

#### 4. Cabecera Estándar de Reaper

**Estado: EXCELENTE** ✅

`main.lua` lines 1-37 tiene una cabecera ReaPack COMPLETA y bien formada:

```lua
-- @description Scale Runner — QWERTY to MIDI Controller for REAPER
-- @version 1.0.0
-- @author GROVE WORLD MUSIC
-- @about
--   Scale Runner: QWERTY to MIDI Controller...
-- @provides
--   [main] src/main.lua
--   src/config.lua
--   ... (todos los módulos listados)
-- @website https://github.com/GroveWorldMusic/GROVE-Scale-Runner
```

**Único faltante menor**:
- Sin `@changelog` (no crítico pero recomendado para versiones)
- Sin `@screenshot` o `@gif` (opcional pero ayuda en ReaPack)

#### 5. Optimización de Rendimiento

**Patrones Óptimos Ya Implementados**:

| Optimización | Ubicación | Issue |
|--------------|-----------|-------|
| Cache scale note tables | `piano.lua` | #13 |
| Pitch-class set O(1) lookup | `piano.lua` | #18 |
| Cache `GetLastFilled()` por tick | `sequencer.lua` | #19 |
| `mouse_click` evento de 1 frame | `ui_store` | Event Bus pattern |
| `ConsumeMouseWheelDelta()` zero-after-read | `ui_store` | Delta lifecycle |
| `temp_ctx` reusable table (zero-allocation) | `keyboard.lua` | #12 |

**Áreas de Mejora Potencial**:

| Problema | Ubicación | Impacto |
|----------|-----------|---------|
| Full redraw cada frame | `views.lua` | Sin dirty regions |
| `SCALE_OPTIONS` se crea al cargar módulo (ok) pero `AbbreviateScale()` se llama cada frame | `views.lua:90` | Menor |
| `GetTransportScreenRect()` puede cachearse | `positioning.lua` | Menor |
| Sin throttle en `UpdateCompactView()` cuando el transporte no se movió | `compact-init.lua` | #10 registrado |

**Nota**: Issue #10 ya existe: "Invalidate auto-position cache on transport resize".

**Rendimiento Actual**:
- ~30-60 FPS típico en defer loop
- Sin hot spots obvios en el código
- `sequencer.Run()` es early-return si `not IsPlaying`
- `HandleKeyboard()` es early-return si `not is_intercepting`

#### 6. Empaquetado de Dependencias

**Estado: BUENO** ✅

**Requerimientos**:
1. **js_ReaScriptAPI** — REQUERIDO
   - Verificación al inicio: `main.lua:260-263`
   - Muestra `reaper.MB()` en español si no está instalado
   - Early return sin crash

2. **SWS Extension** — OPCIONAL (fallback)
   - `compact-init.lua:33-38` — `GetTransportHwnd` como fallback
   - Protegido con `pcall`
   - Funciona sin SWS (usa `JS_Window_Find` con "Transport"/"Transporte")

**@provides** en main.lua lista TODOS los archivos fuente — listo para ReaPack.

**Problema Conocido**:
- `preset-browser.lua:80,95` usa `io.popen('dir ...')` que es **Windows-específico**
- Documentado en `.llm/knowledge/learnings.md:55-56`
- Riesgo: no funciona en macOS/Linux
- Mitigación: `reaper.EnumerateSubdirectories()` existe como fallback pero no está implementado

### Approaches

#### Approach 1: Polish Mínimo Viable (MVP)
**Focus**: Lo más crítico para producción inmediata
- Split `DrawMIDIIsland()` en funciones más pequeñas
- Persistir root/scale/octave/chord via ExtState
- Agregar `pcall` alrededor de `gfx.init()`/`gfx.quit()`
- Unificar namespace de ExtState

**Pros**:
- Menor esfuerzo (~4-6 tareas)
- Impacto usuario inmediato (preferencias persisten)
- Estabilidad mejorada (pcall en operaciones GFX)

**Cons**:
- No resuelve limpieza menor
- No resuelve cross-platform preset-browser

**Esfuerzo**: **Bajo** (~1-2 sesiones)

---

#### Approach 2: Polish Completo (Producción Full)
**Focus**: Todo lo de MVP + limpieza completa
- MVP +
- Split `preset-browser.lua` en submódulos
- Agregar wrapper centralizado `SafeGfxInit()`/`SafeGfxQuit()`
- Cross-platform preset browser (reemplazar `io.popen('dir')`)
- Remover comentario HACK y resolver el issue subyacente
- Función `ShowError()` centralizada
- Agregar changelog a cabecera
- Opcional: dirty regions para redraw optimizado

**Pros**:
- Listo para distribución ReaPack oficial
- Cross-platform (Win/Mac/Linux)
- Mantenibilidad mejorada

**Cons**:
- Mayor esfuerzo
- `io.popen` replacement requiere testing en múltiples plataformas

**Esfuerzo**: **Alto** (~4-6 sesiones)

---

#### Approach 3: Incremental (Phaseado)
**Focus**: 2 fases
- **Fase 1**: MVP (igual a Approach 1)
- **Fase 2**: Lo restante (igual a Approach 2 items restantes)

**Pros**:
- Entrega valor rápido
- Feedback usuario entre fases
- Riesgo mitigado

**Cons**:
- Requiere 2 ciclos SDD
- Más overhead de gestión

**Esfuerzo**: **Medio-Alto** (igual a completo pero distribuido)

### Recommendation
**Recomiendo Approach 1 (MVP)** como próxima fase.

**Por qué**:
1. La persistencia de preferencias es la queja más común de usuario ("tengo que reconfigurar todo cada vez")
2. Los `pcall` alrededor de GFX operations resuelven crashes potenciales en edge cases
3. El split de `DrawMIDIIsland()` mejora mantenibilidad y testabilidad
4. Esfuerzo acotado con máximo impacto

**Fase 2 puede seguir después** con: cross-platform preset browser, funciones de error centralizadas, y limpieza menor.

### Risks
- **Riesgo 1**: Al persistir nuevas keys en ExtState, la estructura debe ser versionada para futuros cambios. *Mitigación: usar un `schema_version` key o namespace con versión.*
- **Riesgo 2**: Splittear `DrawMIDIIsland()` puede introducir regresiones si no se hace con cuidado. *Mitigación: extraer una función a la vez, mantener misma firma.*
- **Riesgo 3**: `pcall` puede silenciar errores que deberían ser visibles. *Mitigación: SIEMPRE loguear o mostrar el error después de pcall; no solo ignorarlo.*
- **Riesgo 4**: Unificar namespace de ExtState (`GROVE_Scale_Runner` vs `GROVE_FL_MIDI`) requiere migración para usuarios existentes. *Mitigación: checkear namespace viejo primero, migrar al nuevo silenciosamente.*

### Ready for Proposal
Sí.

**Próximos pasos para el orquestador**:
1. Crear SDD proposal para `production-ready-polish`
2. Incluir estas tareas del Approach 1:
   - Split `DrawMIDIIsland()` en 3-4 funciones auxiliares
   - Persistir: root_index, scale_index, octave, chord_mode_index via ExtState
   - Unificar namespace ExtState (migración automática)
   - Agregar `pcall` wrapper para `gfx.init()`/`gfx.quit()` con error handling
