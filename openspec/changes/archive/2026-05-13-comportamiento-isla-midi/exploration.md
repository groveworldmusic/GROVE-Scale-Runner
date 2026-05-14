# Exploration: Bug Audit — Implementación Actual de la Isla MIDI

## Current State

El sistema de MIDI island es funcional pero tiene múltiples bugs — algunos críticos que causan crashes o datos corruptos, otros visuales que afectan la experiencia de usuario. El análisis cubre ~2,800 LOC distribuidas en 8 archivos principales.

El flujo general: `views.DrawMIDIIsland(char)` orquesta el layout completo — header (CH + PRESETS + snap controls + tool mode), preset panel colapsable a la izquierda, timeline ruler arriba, piano roll en el centro, velocity editor abajo, y scrollbar horizontal. El estado vive en `island_store` (state/island.lua). La interacción de mouse/routing se maneja inline en `views.lua` con delegación a `piano-roll.*` sub-módulos.

## Affected Areas

| Archivo | LOC | Rol |
|---------|-----|-----|
| `src/state/island.lua` | 552 | State store + undo/redo + Progression→Notes + UUID index |
| `src/ui/views.lua` | 1,294 | DrawMIDIIsland, mouse routing, scrollbar, zoom handlers |
| `src/ui/piano-roll/grid.lua` | 449 | Grid rendering, visible range cache, keyboard strip, scroll/zoom |
| `src/ui/piano-roll/note.lua` | 284 | Note block rendering, hit testing, rect selection |
| `src/ui/piano-roll/interaction.lua` | 1,166 | Drag/resize, undo/redo restore, keyboard shortcuts, clipboard |
| `src/ui/piano-roll/view.lua` | 72 | DrawPianoRoll coordinator |
| `src/ui/timeline.lua` | 195 | Timeline ruler + playhead |
| `src/ui/velocity.lua` | 393 | Velocity bars + drag editing |
| `src/ui/preset-browser.lua` | 755 | File browser, save/load presets |
| `src/core/midi.lua` | 221 | ToggleIsland, MIDI state fields |

## Bug Inventory

---

### CRITICAL

#### Bug C1: `MAX_UNDO` no está declarado — undo stack crashes o corrompe

- **File**: `src/state/island.lua`
- **Type**: functional
- **Severity**: CRITICAL
- **Description**: Las líneas 355 y 379 usan `MAX_UNDO` para limitar el tamaño del undo stack. La constante aparece en comentarios como "MAX_UNDO (50)" (línea 348), pero **nunca se declara** — no hay `local MAX_UNDO = 50` en ninguna parte del archivo ni en `config.lua`.
- **Impact**: 
  - Lua 5.1 (LuaJIT): `number > nil` lanza **error** → **crash** en el primer PushUndo.
  - Lua 5.2+: `nil > number` → el FIFO eviction se dispara en CADA push, corrompiendo el undo stack permanentemente.
- **Fix**: Agregar `local MAX_UNDO = 50` antes de `PushUndo`.

#### Bug C2: `undo_stack` y `redo_stack` no están inicializados en `island_state`

- **File**: `src/state/island.lua:13-44`
- **Type**: functional
- **Severity**: CRITICAL
- **Description**: La tabla `island_state` (líneas 13-44) no incluye los fields `undo_stack`, `redo_stack`, `undo_depth`, `redo_depth`. `PushUndo()` hace `table.insert(island_state.undo_stack, entry)` — si `undo_stack` es `nil`, `table.insert` lanza **error** en todas las versiones de Lua.
- **Impact**: Cualquier operación que dispare undo (crear nota, borrar, mover, cambiar velocity, mute) CRASHEA.
- **Fix**: Agregar al `island_state`:
  ```lua
  undo_stack = {},
  redo_stack = {},
  undo_depth = 0,
  redo_depth = 0,
  ```

#### Bug C3: `_uuid_to_idx` es una variable global, no module-local

- **File**: `src/state/island.lua:318`
- **Type**: code-quality
- **Severity**: CRITICAL
- **Description**: La variable `_uuid_to_idx` se usa en `RebuildUUIDIndex()` (línea 318: `_uuid_to_idx = {}`), `AddNote()` (línea 197), y `FindNoteByUUID()` (línea 339). **No tiene declaración `local`**. Es una variable GLOBAL. Si dos módulos usan el mismo nombre global, hay colisión.
- **Impact**: Potencial corrupción de datos si otro módulo escribe en `_uuid_to_idx` por accidente. Dificulta testing (no se puede aislar).
- **Fix**: Agregar `local _uuid_to_idx = {}` después de `local m = {}`.

#### Bug C4: `LoadPreset` asigna notas SIN UUID — undo/redo rotos después de cargar preset

- **File**: `src/ui/preset-browser.lua:265-276` + `src/state/island.lua:79-84`
- **Type**: functional
- **Severity**: CRITICAL
- **Description**: `LoadPreset()` construye notas sin campo `uuid`, luego llama `SetNotes()`. `SetNotes()` llama `RebuildUUIDIndex()` que solo indexa notas con `uuid` — el índice queda VACÍO. `SavePreset()` tampoco guarda UUIDs en el archivo.
- **Impact**: Cualquier operación de undo/redo después de cargar un preset no puede encontrar notas por UUID — `FindNoteByUUID()` siempre retorna `nil`. Las operaciones de undo son **silent no-ops**, el usuario cree que undo funciona pero no hay efecto.
- **Fix**: En `LoadPreset`, asignar UUIDs a cada nota antes de llamar `SetNotes()`:
  ```lua
  n.uuid = island_store.AllocNoteUUID()
  ```
  Opcional: guardar UUIDs en el formato de preset (v3) para conservarlos entre sesiones.

#### Bug C5: `shift_held` nunca se pasa a `HandleMouseClick` — shift+click toggle no funciona

- **File**: `src/ui/views.lua:944-948` → `src/ui/piano-roll/interaction.lua:57`
- **Type**: functional
- **Severity**: CRITICAL
- **Description**: `HandleMouseClick()` acepta `shift_held` como 8vo parámetro y lo usa en línea 61 para toggle aditivo de selección. Pero en `views.lua` línea 944, la llamada es:
  ```lua
  piano_roll.HandleMouseClick(mx, my, grid_x, pr_y,
      island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
      island_store.GetZoomX())
  ```
  **Solo 7 argumentos** — `shift_held` es siempre `nil`. Shift+click nunca togglea selección.
- **Impact**: El usuario no puede hacer multi-selección aditiva con shift+click.
- **Fix**: Pasar `shift_held` desde views.lua. Idealmente leer el estado de la tecla Shift via `gfx.mouse_cap` (bit 5 = 32) o desde el char de gfx.getchar.

#### Bug C6: `ComputeVisibleRanges` cache no se invalida al cambiar `PITCH_ROW_H`

- **File**: `src/ui/piano-roll/grid.lua:40-44, 77-78`
- **Type**: functional
- **Severity**: CRITICAL
- **Description**: El cache de `ComputeVisibleRanges` solo checkea `scroll_y, scroll_x, zoom_x, w, h` (línea 77-78). **NO incluye `m.PITCH_ROW_H`**. Cuando el usuario hace zoom vertical (Alt+wheel), `PITCH_ROW_H` cambia pero el cache no se invalida → las filas visibles computadas son incorrectas.
- **Impact**: Después de zoom vertical, el grid dibuja filas incorrectas hasta que el usuario scrollea o cambia otro parámetro. Las notas se renderizan en posiciones Y incorrectas.
- **Fix**: Agregar `m.PITCH_ROW_H` a la key del cache:
  ```lua
  if _cache.scroll_y == scroll_y and _cache.scroll_x == scroll_x
     and _cache.zoom_x == zoom_x and _cache.w == w and _cache.h == h
     and _cache.pitch_row_h == m.PITCH_ROW_H then
  ```
  Y guardar `_cache.pitch_row_h = m.PITCH_ROW_H` al final.

#### Bug C7: Folder list scroll siempre 0 — carpetas no scrolleables

- **File**: `src/ui/preset-browser.lua:693`
- **Type**: functional
- **Severity**: CRITICAL
- **Description**: `DrawFolderList()` recibe `scroll_offset` y devuelve `new_scroll_offset` (primer return). Pero en la llamada desde `DrawPresetBrowser()` línea 693:
  ```lua
  _, _, nav_result = DrawFolderList(x + 2, current_y, left_w - 2, content_h, dirs, 0)
  ```
  **Siempre pasa 0** como scroll y descarta el return. El scroll vertical de carpetas nunca se guarda.
- **Impact**: Si hay más de ~10 carpetas, las carpetas sobrantes son inaccesibles. El usuario no puede scrollear la lista de carpetas.
- **Fix**: Mantener un estado de scroll de carpetas (análogo a `browser_scroll` para la lista de archivos). Agregar un field `folder_scroll` a `island_state` y pasar/usar ese valor.

#### Bug C8: Velocity undo bulk puede restaurar valores incorrectos cerca de 0/127

- **File**: `src/ui/velocity.lua:341-360`
- **Type**: functional
- **Severity**: CRITICAL
- **Description**: En `HandleVelocityMouse`, cuando termina un drag bulk (sel_count > 1), calcula el undo prev_state como `notes[sel_idx].velocity - delta`. Pero las velocidades se clampan a 0-127 durante el drag (`ApplyVelocity` línea 252 usa `math.max(0, math.min(127, ...))`). Si un note tenía velocity 5 y el delta era -10, la nueva velocity clamped es 0, entonces `prev = 0 - (-10) = 10` — se restaura 10 en vez de 5.
- **Impact**: Undo de velocity drag bulk produce valores incorrectos para notas que tocaron los límites 0 o 127 durante el drag.
- **Fix**: Guardar los valores originales de TODAS las notas seleccionadas ANTES de iniciar el drag, en vez de reconstruirlos con delta. Es decir, usar `_drag_initial_velocities = {}` indexado por note index.

---

### WARNING

#### Bug W1: Scrollbar vertical — thumb position no considera thumb height

- **File**: `src/ui/piano-roll/view.lua:63`
- **Type**: visual
- **Severity**: WARNING
- **Description**: `local sb_y = y + (clamped_scroll_y / max_scroll_y) * h`. Cuando `clamped_scroll_y = max_scroll_y` (scroll al fondo), `sb_y = y + h`. Pero el thumb tiene altura `sb_h`, así que el borde inferior del thumb está en `y + h + sb_h`, extendiéndose fuera del track.
- **Impact**: Scrollbar visualmente incorrecto cuando se scrollea al final — el thumb se sale del track.
- **Fix**: `sb_y = y + (clamped_scroll_y / max_scroll_y) * (h - sb_h)`

#### Bug W2: Scrollbar horizontal — thumb position no considera bar width

- **File**: `src/ui/views.lua:1139`
- **Type**: visual
- **Severity**: WARNING
- **Description**: `local bar_x = right_x + PITCH_LABEL_W + (scroll_x / max_scroll_x) * sb_w`. Cuando `scroll_x = max_scroll_x`, `bar_x = grid_start + sb_w`. Pero el thumb tiene width `bar_w`, extendiéndose fuera del track.
- **Impact**: Scrollbar horizontal visualmente incorrecto al scrollear al final.
- **Fix**: `local track_w = sb_w - bar_w; bar_x = right_x + PITCH_LABEL_W + (scroll_x / max_scroll_x) * track_w`

#### Bug W3: `DrawVerticalPianoKeyboard` — pitch row loop puede dibujar fuera del área de keyboard strip

- **File**: `src/ui/piano-roll/grid.lua:150-173`
- **Type**: visual
- **Severity**: WARNING
- **Description**: El loop de PASS 1 usa `visible_rows = math.ceil(kh / RH) + 2` donde `kh` es la altura del keyboard strip. Pero `visible_rows` podría ser mayor que el grid si la altura del keyboard strip difiere. Un row que debería estar en el grid pero no en el keyboard strip se dibuja parcialmente.
- **Impact**: Sin datos visuales concretos, pero el +2 podría causar que la última fila del teclado no se renderice si `kh` no es múltiplo exacto de RH.
- **Fix**: Asegurar que `kh` y la altura del grid usen el mismo cálculo de `visible_rows`.

#### Bug W4: `LoadPreset` no llama `ClearUndoStacks()` — undo de estado anterior corrompe datos

- **File**: `src/ui/preset-browser.lua:283`
- **Type**: functional
- **Severity**: WARNING
- **Description**: Después de `SetNotes(valid_notes)`, el undo stack anterior contiene referencias UUIDs de las notas viejas. Si el usuario hace Ctrl+Z después de cargar un preset, se intenta restaurar notas con UUIDs que ya no existen → `FindNoteByUUID` retorna nil → silent no-op.
- **Impact**: Cargar un preset no resetea el historial de undo. El usuario puede confundirse al ver que Ctrl+Z no hace nada.
- **Fix**: Llamar `island_store.ClearUndoStacks()` después de cargar el preset.

#### Bug W5: `GetNotesInRect` no clamp `pitch_high` a `MAX_PITCH`

- **File**: `src/ui/piano-roll/note.lua:260-262`
- **Type**: functional
- **Severity**: WARNING
- **Description**: `pitch_high = math.max(MIN_PITCH, top_pitch - pitch_row_top)`. Si el mouse está por ENCIMA del grid (`ry1 < grid_y`, `pitch_row_top` negativo), `pitch_high` puede exceder `MAX_PITCH`. Las notas con pitch <= MAX_PITCH siempre cumplen la condición, incluyendo notas que NO están en el área visible del lasso.
- **Impact**: Selección por lasso puede incluir notas que NO están visualmente dentro del rectángulo de selección cuando el lasso empieza arriba del grid.
- **Fix**: Agregar `math.min(MAX_PITCH, ...)`:
  ```lua
  local pitch_high = math.min(MAX_PITCH, math.max(MIN_PITCH, top_pitch - pitch_row_top))
  ```

#### Bug W6: ToggleIsland — hardcoded heights 793/497 no sincronizadas con layout

- **File**: `src/core/midi.lua:214`
- **Type**: code-quality
- **Severity**: WARNING
- **Description**: `local new_h = midi.midi_island_expanded and 793 or 497`. Si los valores de layout cambian (CANVAS_H = 29162, etc.), las alturas de ventana no se actualizan automáticamente.
- **Impact**: Si se modifica el layout, la ventana expandida muestra contenido cortado o espacio vacío.
- **Fix**: Derivar la altura desde el layout virtual o desde constantes al tope del archivo.

#### Bug W7: `DrawPresetBrowser` — scroll de folder list y preset list pueden tener wheel race condition

- **File**: `src/ui/preset-browser.lua:724-731`
- **Type**: functional
- **Severity**: WARNING
- **Description**: El wheel handler en `DrawPresetBrowser` (línea 726) consume `ConsumeMouseWheelDelta()`. Pero el folder list tiene su propio scroll y no actualiza ningún estado persistente — el scroll siempre es 0. Cuando el mouse está sobre la zona de archivos, el wheel funciona. Cuando está sobre la zona de carpetas, nunca se actualiza el scroll.
- **Impact**: Inconsistente — scroll en folder list no funciona, scroll en file list funciona.
- **Fix**: Agregar folder_scroll state y pasarlo a DrawFolderList.

#### Bug W8: `SyncPlaybackPosition` puede saltar hacia atrás si el sequencer no reproduce linealmente

- **File**: `src/ui/timeline.lua:190`
- **Type**: functional
- **Severity**: WARNING
- **Description**: Si el sequencer reinicia (vuelve al step 1), `total_beats = current_step * 4 + progress * 4` puede ser MENOR que el valor anterior, causando que el playhead salte hacia atrás. Esto no ocurre actualmente porque el sequencer no loop, pero si se agrega loop en el futuro, el playhead se comportaría incorrectamente.
- **Fix**: No es bloqueante ahora. Documentar como precaución para cuando se implemente loop.

---

### SUGGESTION

#### Bug S1: `DrawRoundedRectEx` — potential gap on partial rounded corners with large `r`

- **File**: `src/ui/components.lua:47-78`
- **Type**: visual
- **Severity**: SUGGESTION
- **Description**: Cuando `r > min(h/2, w/2)`, se reduce a `min(w/2, h/2)`. Pero cuando r es cercano a h/2 y solo algunas esquinas son redondeadas, la sobre-impresión de las esquinas cuadradas (líneas 74-77) podría no cubrir completamente el área.
- **Impact**: Potencial gap visual en esquinas parcialmente redondeadas con radios grandes. Depende de la implementación de `gfx.rect` (si incluye el borde inferior/derecho).
- **Fix**: Usar `math.floor()` o agregar +1 a las rectas de sobre-impresión.

#### Bug S2: `HandlePencilClick` — fallback de snap a half-beat incluso con snap OFF

- **File**: `src/ui/piano-roll/interaction.lua:153-154`
- **Type**: functional
- **Severity**: SUGGESTION
- **Description**: Cuando `snap_enabled = false`, el código usa `math.floor(beat * 2 + 0.5) / 2` — snap a half-beat. Esto significa que con snap OFF, la herramienta pencil sigue forzando notas a posiciones de medio beat. No hay forma de crear una nota en, por ejemplo, beat 0.25 con snap off.
- **Impact**: Comportamiento confuso. El usuario desactiva snap esperando libertad total pero pencil igual lo fuerza a half-beat.
- **Fix**: Cuando `snap_res <= 0`, no aplicar ningún snap: `snapped_beat = beat`.

#### Bug S3: `AddNote` no checkea nota duplicada en mismo pitch+beat

- **File**: `src/state/island.lua:191-199`
- **Type**: functional
- **Severity**: SUGGESTION
- **Description**: `AddNote` inserta una nota sin verificar si ya existe otra en el mismo pitch/beat. La herramienta pencil puede crear múltiples notas superpuestas en la misma posición.
- **Impact**: Notas fantasma no visibles pero que suenan en playback (todas las notas se tocan).
- **Fix**: En `HandlePencilClick`, checkear si ya existe una nota en el mismo pitch/beat y saltar la creación.

#### Bug S4: `base_initial_vel` declarada pero nunca usada (dead code)

- **File**: `src/ui/velocity.lua:353`
- **Type**: code-quality
- **Severity**: SUGGESTION
- **Description**: `local base_initial_vel = drag_initial_vel` — la variable se asigna pero NUNCA se referencia después. Es dead code.
- **Impact**: Ninguno, pero es código muerto que confunde.
- **Fix**: Eliminar la línea.

#### Bug S5: Note drag `CommitNoteDrag` compara solo `pitch` y `start_beat` para detectar cambio

- **File**: `src/ui/piano-roll/interaction.lua:523`
- **Type**: code-quality
- **Severity**: SUGGESTION
- **Description**: El check `any_changed` solo compara `pitch` y `start_beat`, ignorando `duration`, `velocity`, `muted`. Si otros campos cambian durante el drag (no deberían, pero por safety), el undo no los capturaría.
- **Impact**: Undo parcial en caso de modificaciones no intencionales de otros campos.
- **Fix**: Comparar también `duration`, `velocity`, `muted` para safety:

#### Bug S6: Preset browser usa `io.popen("dir ...")` — solo Windows, inyectable

- **File**: `src/ui/preset-browser.lua:82, 97`
- **Type**: code-quality
- **Severity**: SUGGESTION
- **Description**: El scan de directorios usa `io.popen('dir "' .. dir_path .. '" /B /AD 2>nul')`. Esto es Windows-only y `dir_path` podría contener caracteres especiales que rompan el comando.
- **Impact**: No funciona en macOS/Linux REAPER. Potencial command injection si un nombre de carpeta contiene comillas.
- **Fix**: Usar `reaper.EnumerateFiles()` o `lfs.dir()` (Lua File System) si está disponible. Alternativa: escapar `dir_path` con `string.format("%q", dir_path)`.

#### Bug S7: `ToggleIsland` window position drift en toggles rápidos

- **File**: `src/core/midi.lua:203-212`
- **Type**: functional
- **Severity**: SUGGESTION
- **Description**: Si `gfx.hwnd` es nil (después de `gfx.quit()`), no se actualiza `gs.x/gs.y`. En toggles rápidos, la posición de ventana puede desviarse porque `last_gfx_state` puede quedar desactualizado.
- **Impact**: La ventana puede aparecer en una posición inesperada después de toggle rápido.
- **Fix**: En el toggle collapse (cuando `midi_island_expanded` pasa a false), guardar la posición actual ANTES de `gfx.quit()`.

#### Bug S8: `Init()` retry infinito si `GetResourcePath` falla

- **File**: `src/ui/preset-browser.lua:42-73`
- **Type**: functional
- **Severity**: SUGGESTION
- **Description**: Si `reaper.GetResourcePath()` falla en `Init()`, el `preset_root` queda vacío. `DrawPresetPanel()` (views.lua línea 750) llama `preset_browser.Init()` TODOS los frames si root está vacío. Esto crea un retry infinito con I/O cada frame.
- **Impact**: Spam de I/O en cada frame si el path de REAPER no está disponible. Sin embargo, en la práctica `GetResourcePath` nunca falla en REAPER en ejecución.
- **Fix**: Agregar flag `_init_attempted` para evitar reintentos después del primer fallo.

#### Bug S9: UUID counter unbounded growth on repeated `LoadNotesFromProgression`

- **File**: `src/state/island.lua:463-528`
- **Type**: code-quality
- **Severity**: SUGGESTION
- **Description**: `ProgressionToNotes` llama `m.AllocNoteUUID()` para cada nota creada. Cada vez que la progresión cambia y se re-materializan las notas, el contador `next_note_uuid` crece. En sesiones largas con muchos cambios de progresión, el contador podría exceder `2^31` y wrappear a negativo (Lua usa doubles de 64-bit, así que el wrap es extremadamente improbable pero posible).
- **Impact**: Teóricamente, UUIDs negativos romperían el reverse index.
- **Fix**: No bloqueante. Resetear `next_note_uuid` en `ClearUndoStacks()` o usar un counter más seguro.

#### Bug S10: `DrawPianoRollGrid` — variable `beat` shadowing en loops anidados (código confuso)

- **File**: `src/ui/piano-roll/grid.lua:311, 323`
- **Type**: code-quality
- **Severity**: SUGGESTION
- **Description**: La variable de loop `beat` se usa tanto en el loop de measure lines (línea 312) como en el loop de beat lines (línea 323). No hay bug porque cada loop tiene su propio scope, pero confunde al leer el código.
- **Impact**: Legibilidad reducida.
- **Fix**: Usar `b` o `bi` para el loop de beat lines para evitar shadowing.

---

## Patterns & Risks

### Patrón frágil: `note_count` vs `#notes`
`GetNoteCount()` retorna `island_state.note_count` pero `GetNotes()` retorna la tabla por referencia. Si alguien muta la tabla de notas directamente (e.g., agrega/elimina entries sin pasar por `AddNote`/`RemoveNoteAtIndex`), `note_count` se desincroniza. Esto no es un bug hoy (ningún código actual lo hace) pero es un accidente esperando ocurrir.

### Patrón frágil: Cache de visible ranges sin key de PITCH_ROW_H
El cache es una optimización válida pero la omisión de `PITCH_ROW_H` en la key es un bug activo (C6). Este patrón de frame-cache aparece en varios lugares y debe auditarse para asegurar que todas las keys relevantes están incluidas.

### Riesgo sistémico: UUID en presets
El sistema completo de undo/redo depende de UUIDs. `SavePreset` no guarda UUIDs y `LoadPreset` no los asigna. Esto hace que operar undo después de cargar un preset sea una experiencia rota. Es el bug con mayor impacto en usabilidad después de los crashes.

### Riesgo de timing: `ConsumeMouseWheelDelta` en preset browser
El preset browser consume el wheel delta DENTRO de `DrawPresetBrowser`. Luego en `DrawMIDIIsland` línea 906 se consume OTRA VEZ. El orden de dibujo determina quién recibe el wheel. Si el preset panel está visible y el mouse está sobre la zona de archivos, el browser consume el wheel. Si el mouse está sobre el piano roll, `DrawMIDIIsland` lo consume. El orden debe mantenerse consistente.

### Problema de escalabilidad: Iteración completa de notas
`DrawNoteBlocks` itera sobre TODAS las notas cada frame, no solo las visibles. Para sets pequeños (<200 notas) es aceptable a 60fps. Para sets de 1000+ notas en la vista extendida, el rendimiento se degrada. `GetVisibleNotes` existe en el store pero no se usa en el hot path.

---

## Recommendation

### Fase 1: Bugs críticos (CRASH + DATOS CORRUPTOS)
Estos bugs causan crashes o pérdida de datos. Deben corregirse primero:

1. **C1 + C2**: `MAX_UNDO` + init de `undo_stack`/`redo_stack` — sin esto, undo CRASHEA
2. **C3**: `_uuid_to_idx` global → local — riesgo de colisión

### Fase 2: Funcionalidad rota (OPERACIONES QUE NO FUNCIONAN)
3. **C4**: `LoadPreset` sin UUIDs — undo post-load no funciona
4. **C5**: `shift_held` no pasa — shift+click toggle no funciona
5. **C6**: Cache sin PITCH_ROW_H — zoom vertical rompe render
6. **C7**: Folder scroll siempre 0 — folders no scrolleables

### Fase 3: Visuales + Calidad
7. **W1 + W2**: Scrollbar thumbs fuera de track
8. **W4**: `ClearUndoStacks` en LoadPreset
9. **W5**: Lasso pitch_high sin clamp
10. **S2**: Pencil snap behavior
11. **S4**: Dead code removal

### Fase 4: Post-lanzamiento
12. **C8**: Velocity undo bulk edge case
13. **W6**: Hardcoded window heights
14. **S6**: io.popen portabilidad

---

## Ready for Proposal

**Sí** — Los bugs están identificados, categorizados por severidad, y priorizados en fases. Las correcciones son puntuales y de bajo riesgo. Se recomienda corregir las Fases 1-3 como un solo cambio, y la Fase 4 como mantenimiento futuro.

### Resumen ejecutivo

- **6 bugs CRÍTICOS**: 2 crashes (MAX_UNDO + stack init), 1 global leakage, 2 funcionalidad rota (UUIDs en presets, shift+click), 1 cache que produce render incorrecto tras zoom vertical
- **8 bugs WARNING**: scrollbars fuera de track, lasso impreciso, undo no reseteado en load preset, preset carpetas no scrolleables, window heights hardcoded
- **10 SUGGESTIONS**: dead code, snap behavior confuso, portabilidad, etc.
