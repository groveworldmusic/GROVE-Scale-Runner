# Aprendizajes — Bugs, Gotchas, Soluciones

## Bug: Circular dependency C stack overflow en note-store → midi → gfx-window → island

**Síntoma**: `error loading module 'state.note-store' from file '...note-store.lua': C stack overflow`
**Causa raíz**: note-store.lua requiere core.midi al tope del módulo. core.midi requiere ui.gfx-window (extraído en refactor midi-island-critical-fixes). gfx-window requiere state.island. island requiere note-store → ciclo infinito en require().
**Solución**: Mover `require("core.midi")` a lazy dentro de la única función que lo usa: `ProgressionEntryToPitch()`. Lua cachea require, así que solo la primera llamada ejecuta la carga.
**Archivos**: `src/state/note-store.lua` — línea 10 (removido), línea 206 (lazy require)
**Lección**: Al extraer módulos que introducen nuevas dependencias, verificar que no se cree un ciclo en el grafo de requires. gfx-window se extrajo de core.midi y agregó una dependencia de core.midi → state.island que antes no existía.

## Bug: DrawSlotBackground era local pero el barrel la re-exportaba

**Síntoma**: `components.DrawSlotBackground = slots.DrawSlotBackground` devolvía `nil` en runtime.
**Causa raíz**: DrawSlotBackground era `local function` en el original y se mantuvo `local function` en slots.lua. El barrel intentaba re-exportar una función que no existía en el módulo.
**Solución**: No re-exportar funciones locales del barrel. Verificar que solo funciones públicas (`m.*`) se agreguen al barrel.
**Archivos**: `src/ui/components.lua`, `src/core/slots.lua`

## Gotcha: +1 overshoot en DrawRoundedRect NO es bug — previene seams de GFX

**Contexto**: El SDD "piano-roll-bugs" identificó `+1` en rect width/height de `DrawRoundedRect` como "artefacto de rendering" y los removió.
**Error**: Los `+1` eran un fix deliberado para prevenir gaps de 1px entre rectángulos y círculos en REAPER GFX. `gfx.circle` usa anti-aliasing en sus bordes, dejando transparencia parcial donde un rectángulo termina exactamente donde arranca un círculo.
**Solución**: Restaurar los `+1` + agregar comentario explícito explicando por qué están ahí.
**Lección**: En código de rendering/GFX, no asumir que "código raro" es bug. Entender el dominio primero. Los `+1` en overlapping geometry son un patrón conocido.

## Gotcha: require circular en módulos extraídos

**Contexto**: Los widgets extraídos de components.lua necesitan `DrawRoundedRect` que está en el barrel.
**Solución**: Lazy require — `local components = require("ui.components")` dentro del cuerpo de la función.
**Archivos**: buttons.lua, dropdown.lua, paginator.lua, piano.lua, pads.lua, etc.

## Gotcha: compact-bar necesitaba compact_store

**Contexto**: PR 1 de stores migró config.state.compact a compact_store, pero compact-bar.lua seguía leyendo `config.state.compact` directamente. Hubo que actualizarlo en el mismo PR.
**Lección**: Al migrar stores, verificar TODOS los archivos que referencian las keys migradas, no solo los listados originalmente.
**Archivos**: `src/ui/compact-bar.lua`

## Bug: views.lua asignaba a getter

**Síntoma**: `midi_store.GetUseVelocity() = not midi_store.GetUseVelocity()` — inválido en Lua.
**Causa raíz**: Refactor mecánico reemplazó `config.state.use_velocity = not config.state.use_velocity` por `midi_store.GetUseVelocity() = not midi_store.GetUseVelocity()`.
**Solución**: Cambiar a `midi_store.SetUseVelocity(not midi_store.GetUseVelocity())`.
**Archivos**: `src/ui/views.lua`

## Conocimiento: mouse_click event bus

**Contexto**: `mouse_click` se setea en un frame cuando `gfx.mouse_cap & 1 == 1` y `last_mouse_cap == 0`. Se resetea automáticamente al frame siguiente cuando la condición deja de cumplirse.
**Importante**: No hay setter explícito de "false" para mouse_click — es un evento de un solo frame por diseño.

## Conocimiento: Scroll wheel en dual context

Cada contexto GFX (main y compact) tiene su propio `gfx.mouse_wheel`. El patrón correcto es:
1. `config.state.mouse_wheel_delta = gfx.mouse_wheel` (capturar)
2. `gfx.mouse_wheel = 0` (zerear a nivel GFX)
3. Cada widget lee `config.state.mouse_wheel_delta` y si lo consume, hace `config.state.mouse_wheel_delta = 0`

## Isla MIDI: Gotchas y aprendizajes

### gfx.quit()/gfx.init() en pcall
Ambos pueden fallar (e.g., REAPER closing mid-transition). Siempre wrappear en pcall con revert logic. Ver `compact-init.lua` P5-01.

### Grid alignment en todos los zoom levels
Beat ticks y note positions deben usar la misma fórmula: `(value - scroll_x) * zoom_x`. Cualquier mismatch causa misalignment visible entre timeline y piano roll.

### Drag state modular debe resetearse al salir del modo
`velocity.ResetDrag()` se llama al salir de ISLAND mode. Sin esto, un drag a medio completar queda en estado stale si el usuario cambia de modo.

### dofile() para presets: conveniente pero riesgoso
`dofile()` ejecuta código Lua arbitrario. Funciona para datos de usuario pero puede crashear el script si el archivo está corrupto. Wrappear en pcall con validación y rollback.

### io.popen('dir') es Windows-específico
Para listing de directorios, `io.popen('dir ...')` no funciona en macOS/Linux. Usar `reaper.EnumerateSubdirectories()` como fallback para cross-platform.

### Favoritos via GetExtState/SetExtState
Se serializan como tablas Lua y se parsean via `load()`. Sobrevive reinicios del script. Usar `persist=true` en SetExtState. Formato: `{"path1","path2",...}`.

## Piano Roll: Vertical Keyboard Strip

### Separate label functions for keyboard vs note blocks
`OctaveLabel()` (always "C4", "D#4", etc.) is shared by DrawNoteBlock and was used by the old flat key strip. When implementing `DrawVerticalKeyboard`, a new `KeyboardNoteLabel()` was created that only shows octave number on C (pitch_class=0). This avoids changing the note block label behavior which needs full labels.

### Black key sizing: 35% width, right-aligned, top-aligned
Black keys use 35% of PITCH_LABEL_W width (14px at default 40px strip width), positioned at the right edge of the key strip. Height is 60% of PITCH_ROW_H. Keys are top-aligned (bk_y = ky) since higher pitch = top of row in the inverted Y coordinate system.

### Inline fill colors preferred over theme colors
The existing `KEY_WHITE_FILL` ({0.55,0.55,0.55,0.7}) and `KEY_BLACK_FILL` ({0.06,0.06,0.06,0.9}) constants were reused instead of `theme.colors.piano_white`/`piano_black` because the theme values differ (piano_white is {0.85,0.85,0.85,1.0}). The inline constants match the original visual style with specific alpha values.

### Border colors added for key definition
White keys: `{0.2,0.2,0.2,0.6}`, Black keys: `{0.3,0.3,0.3,0.8}`. Drawn as unfilled rect via `gfx.rect(x, y, w, h, 0)`.

### Caché de ComputeVisibleRanges()
Parámetros (scroll_y, scroll_x, zoom_x, w, h) sin cambios → devolver valores cacheados. Esto elimina cómputo redundante en cada frame. Implementado como tabla _cache con chequeo de igualdad.

## Piano Roll Phase 4: Tool Selector + Lasso Multi-Select

### gfx.getchar() is non-consuming within a frame
Multiple calls to `gfx.getchar()` within the same frame return the same character value. Calling it from `DrawMIDIIsland` (before MainLoop's own `gfx.getchar()` call) works correctly. VK_DELETE returns 302 (256+46) via `gfx.getchar()`, not 127 (ASCII DEL).

### RemoveNoteAtIndex must fix up selected_indices
When a note is removed at index `idx`, all `selected_indices` entries with key > idx must be decremented by 1. Entries with key == idx are dropped. This prevents stale indices from pointing to wrong notes after deletion.

### Pencil tool snap strategy
Pencil-created notes snap to the nearest half-beat (`floor(beat * 2 + 0.5) / 2`) to ensure alignment with beat grid subdivisions. The note's `origin` field is set to `"manual"` to distinguish from progression-sourced notes (which have no origin field by default).

### Bulk velocity delta strategy
When multiple notes are selected, velocity drag applies a RELATIVE delta from the initial click position. `drag_initial_vel` is captured on mousedown; each frame computes `delta = new_vel - drag_initial_vel` and applies it to all selected notes' base velocities. This preserves relative velocity differences between selected notes.

### SetNotes clears selection
When notes are replaced (e.g., on progression reload), `SetNotes()` now calls `ClearSelection()` since old indices are invalid. This prevents stale selection highlighting after external note changes.

## Phase 2 — Bug/Lag/Edge-Case Fix: pads perf, keyboard buffer, preferences debounce

### Per-frame cache para O(7·28) → O(28) en pads
**Contexto**: 7 pads × 28 key states = 196 iteraciones/frame para determinar si un degree está activo.
**Solución**: Cache `active_degrees_cache` poblado una vez por frame en `ComputeActiveDegrees()` (28 iteraciones total). Cada pad consulta O(1) via `active_degrees_cache[degree]`.
**Lección**: El patrón "rebuild cache una vez por frame antes del loop" es simple y efectivo cuando el dato es frame-constante. Similar al hoisting de `JS_VKeys_GetState` fuera del loop.
**Archivos**: `src/ui/pads.lua`, `src/ui/components.lua`, `src/ui/views.lua`

### Debounce de persist.Save con dirty flag
**Contexto**: Cada setter de preferences llamaba `reaper.SetExtState()` sincrónicamente — hasta 7 llamadas por frame si cambiaban múltiples preferencias.
**Solución**: `save_pending` boolean + `TickSaveDebounce()` en MainLoop que persiste todos los keys en batch una vez por frame.
**Lección**: El dirty flag simple (sin contador) funciona cuando flush es una vez por frame. Si se necesitara batching multi-frame (e.g., agrupar cambios de 3 frames), se usaría un contador regresivo.
**Archivos**: `src/state/preferences.lua`, `src/main.lua`

## distribution-prep: Proposal scope discovery — casi todo ya existía

**Contexto**: El proposal de `distribution-prep` asumía 5 items como "nuevos" (header tags, constants, README, CI workflow, ReaPack config). El spec phase descubrió que 4 de 5 ya existían.
**Lección**: Al planificar cambios de distribución/infra, verificar el estado actual del código primero. El proposal tenía stale assumptions. El SDD cycle catchó esto en spec/design antes de apply, ahorrando trabajo innecesario.
**Archivos**: `src/main.lua` (header completo con @donation/@links), `src/config.lua` (APP_NAME/APP_VERSION/DONATION_URL), `.github/workflows/reapack-index.yml`, `.reapack-index.yaml`

## Tarea masiva: 49 SPDX headers stale pendientes

**Contexto**: Solo se actualizaron 3 archivos con SPDX `Andrik on the beat` → `Andrik Sanz Cordoví` (main.lua, config.lua, README.md). Quedan 49 source files con SPDX stale en `src/`.
**Lección**: Scope slicing correcto — no mezclar branding normalization con batch header update. Recomendar follow-up change con `rg -l "Andrik on the beat" src/` para encontrar todos.
**Archivos**: 49 archivos en `src/` + `LICENSE`

## Full Codebase Bug/Lag/Edge-Case Fix (5 phases)

### HIGH: JS_VKeys_GetState 28x/frame → 1x/frame
**Contexto**: `keyboard.lua` llamaba `JS_VKeys_GetState(0)` dentro del loop de 28 teclas.
**Solución**: Hoistear el call + nil guard fuera del loop, cachear en `local vk_state`.
**Lección**: REAPER VKeys API es frame-constante — safe de cachear. Patrón aplicable a cualquier API de estado global en hot path.
**Archivos**: `src/core/keyboard.lua`

### MEDIUM: Slots click-to-play zero-duration notes
**Contexto**: Click-to-play enviaba note-on + note-off en el mismo frame. REAPER no reproduce notas de duración cero.
**Solución**: Cola `pending_noteoffs` con frame-counter. Note-on inmediato, note-off diferido 3 frames. Guard de `reaper.time_precise()` para una sola procesada por frame a pesar de que DrawProgressionSlot se llama 4 veces/frame.
**Lección**: List-based queue > single counter — handlea múltiples clicks rápidos sin perder notas.
**Archivos**: `src/core/slots.lua`

### LOW: Revision counters para caches per-frame
**Contexto**: piano.lua y slots.lua recomputaban datos cada frame sin verificar si cambiaron.
**Solución**: `active_notes_revision` en midi_store + revision checks en piano.lua (active_mod12) y slots.lua (subdivision dots).
**Lección**: Revision counter es más barato que comparar tablas enteras. Bump en mutaciones, check en reads.
**Archivos**: `src/state/midi.lua`, `src/ui/piano.lua`, `src/core/slots.lua`

## batch-h-presets-panel: Preset Browser bugs

### Bug: Search query/setLastChar store functions missing
**Síntoma**: `preset_store.GetSearchQuery()` y `ui_store.GetLastChar()` no existían. El preset browser llamaba funciones nil → runtime error al mostrar el panel.
**Causa raíz**: La feature "Live Search" (openspec preset-browser-enhancements T3) implementó la UI del search bar en `main.lua` pero nunca agregó los getters/setters al store. `search_query`, `search_active`, y `last_char` faltaban tanto en el state table como en los getters/setters.
**Solución**: Agregar `search_query` field + `GetSearchQuery()`/`SetSearchQuery()`/`ClearSearchQuery()` a `preset-store.lua`. Agregar `search_active` + `GetSearchActive()`/`SetSearchActive()` y `last_char` + `GetLastChar()`/`SetLastChar()` a `ui.lua`. Wire up `ui_store.SetLastChar(char)` en `main.lua` después de `gfx.getchar()`.
**Archivos**: `src/state/preset-store.lua`, `src/state/ui.lua`, `src/main.lua`

### Bug: RefreshPresets clears selection every 3 seconds
**Síntoma**: Multi-select visual feedback desaparece después de 3 segundos. Usuario Ctrl+clickea varios presets pero el highlight se pierde.
**Causa raíz**: `ScanDirectory()` llama `SetSelectedPresetIdx(nil)` en ambos paths (cache-hit y cache-miss). `RefreshPresets()` llama `ScanDirectory()` cada 3 segundos desde `DrawPresetBrowser`, borrando la selección del usuario.
**Solución**: En el cache-hit path de `ScanDirectory`, NO llamar `SetSelectedPresetIdx(nil)` ni `SetBrowserScroll(0)` — solo actualizar la cache y el error. La selección se preserva cuando el directorio no cambió (refresh periódico).
**Archivos**: `src/ui/preset-browser/io.lua`

### Bug: folder_scroll no se resetea al navegar directorios
**Síntoma**: Al navegar a un directorio con menos subdirectorios, el folder_scroll apunta a un valor fuera de rango. El rendering lo clampéa pero el valor almacenado queda stale.
**Solución**: Agregar `preset_store.SetFolderScroll(0)` en el cache-miss path de `ScanDirectory` (junto al `SetBrowserScroll(0)` existente).
**Archivos**: `src/ui/preset-browser/io.lua`

### Lección: Verificar que store functions existan para TODOS los calls en UI
La UI de preset browser llamaba 4 funciones que no existían en stores. Cualquier nueva feature de UI que lea/escriba estado debe verificar que los getters/setters correspondientes estén implementados en la store. No asumir que existen solo porque la UI está escrita.

## MIDI Island Window Minimum Height Enforcement

### REAPER GFX no tiene API para mínimo de ventana
No hay `gfx.setminsize()` ni equivalente. `gfx.init()` sin `gfx.quit()` solo actualiza el canvas GFX, NO el HWND de la ventana OS.

### gfx.hwnd es un HWND hijo (child window)
`gfx.hwnd` en REAPER devuelve un child HWND. El borde de resize (`WS_THICKFRAME`/`WS_SIZEBOX = 0x40000` de Win32) está en el ROOT frame. `SetWindowLongPtr(gfx.hwnd, GWL_STYLE, ...)` no afecta el resize border porque el child no tiene `WS_THICKFRAME`.

Para llegar al root se necesita `JS_Window_GetRoot(hwnd)` (que llama `GetAncestor(GA_ROOT)` internamente), pero no está disponible en todas las versiones de js_ReaScriptAPI.

### JS_Window_GetRect devuelve 5 valores: (bool, left, top, right, bottom)
**CRÍTICO**: El primer return es un booleano de éxito. NO es `left`.
- Correcto: `local _, l, t, r, b = reaper.JS_Window_GetRect(hwnd)`
- Incorrecto: `local l, t, r, b = reaper.JS_Window_GetRect(hwnd)` (l = bool)

`gfx-window.lua` tenía este bug — `config.state.view_offset_x = l` guardaba `true` en vez de la coordenada real.

### Solución para mínimo de ventana
`gfx.quit() + gfx.init(título, gfx.w, 793, dock, saved_x, saved_y)` en MainLoop cuando `gfx.h < 793`:
1. Capturar posición CADA frame via `JS_Window_GetRect` con `type(l) == "number"` guard
2. Usar `gfx.h > 100` para evitar gfx.h inválido del primer frame
3. El enforcement solo corre si `GetMidiIslandExpanded() == true`
4. Después de `gfx.init()`, siempre llamar `gfx.setfont(1, "Calibri", 16)`

### Funciones JS_Window_* disponibles vs no disponibles
- ✅ `JS_Window_Find`, `JS_Window_GetRect`, `JS_Window_GetClientSize`
- ❌ `JS_Window_GetRoot` — no disponible en versiones viejas
- ❌ `JS_Window_GetLong/SetLong` — no disponibles en versiones viejas
- ❌ `JS_Window_Resize/SetPosition` — existen en código fuente pero no constriñen GFX windows durante drag
- ❌ `JS_Window_SetBounds` — NO EXISTE en js_ReaScriptAPI (nombre incorrecto)

## batch-f-velocity-editor: Velocity editor fixes

### Fix 1: Precision drag gate on handle proximity
**Contexto**: Velocity edits started on any click within the note's beat range (broad area hit test via VelocityHitTest). A click on the stem or duration bar would immediately jump velocity to the mouse Y.
**Solución**: Added `GetHandlePosition()` which computes the exact handle circle center matching the render position in `DrawVelocityBar`. Drag only starts when `sqrt(dx² + dy²) <= 6px` from center. Clicks outside the handle zone on a velocity bar update note selection without changing velocity.
**Archivos**: `src/ui/velocity.lua` — GetHandlePosition (nuevo), HandleVelocityMouse (modificado)
**Lección**: The handle position depends on `COLLAPSE_HANDLE_H` (not just `padding`) to match the render baseline. `DrawVelocityEditor` uses `y + content_h` where `content_h = h - COLLAPSE_HANDLE_H`, while the drag handler used `ed_y + ed_h - padding`. The new helper matches the render code exactly.

### Fix 2: Label overflow on left edge → flip to right side
**Contexto**: The velocity value label (centered above the handle) would overflow past the pitch label strip when the note is near the left edge of the grid.
**Solución**: Added `left_boundary` parameter to `DrawVelocityBar`. When `x - lw/2 < left_boundary`, the label is drawn at `x + pinR + 4` (right side of handle) instead of centered.
**Archivos**: `src/ui/velocity.lua` — DrawVelocityBar signature and label block
**Lección**: The label needs `left_boundary` (the grid_x = x + PITCH_LABEL_W edge) to detect overflow. A fallback of `0` prevents crashes if called without the parameter.

### Phase 5: view_offset_x/y migration to ui_store
**Contexto**: 12 referencias a `config.state.view_offset_x/y` en 4 archivos.
**Solución**: Agregar a `ui_store` con getters/setters + reemplazar todas las referencias.
**Lección**: view_offset_x/y NO se persistían via ExtState (no estaban en persist.lua PREF_KEYS) — window position se perdía al reiniciar REAPER. Queda como mejora futura persistirlas.
