# GROVE Scale Runner — Catálogo de Features

> **Convención**: Este documento es el catálogo maestro de features. Toda feature nueva que se implemente debe agregarse aquí con su estado (`✅ Implementada` / `🚧 En progreso` / `📋 Planificada`).
>
> **Última actualización**: 2026-05-18 (sesión presets-full-features + Phase 1 & 2)
> **Versión del script**: v1.1.0-dev

---

## 1. Sistema de Escalas y Acordes

*Módulos: `src/core/midi.lua` (resolución de notas), `src/core/api-guard.lua` (validación de APIs obligatorias)*

### 1.1 Escalas musicales
| Feature | Detalle |
|---------|---------|
| 21 escalas | Major, Major Bebop, Major Pentatonic, Minor Harmonic, Minor Hungarian, Minor Melodic, Minor Natural (Aeolian), Minor Neapolitan, Minor Pentatonic, Arabic, Blues, Diminished, Dominant Bebop, Dorian, Enigmatic, Japanese Insen, Locrian, Lydian, Mixolydian, Neapolitan, Phrygian |
| Selección de raíz | 12 notas (C–B) |
| Selección de octava | C0–C8 |

- **`midi.GetMidiNote(degree, octave, root, scale, chord_mode)`** → `note_number[]`: función pura que resuelve un grado dentro de una escala+acorde a un array de notas MIDI. Soporta wraparound: cuando degree ≥ scale length, envuelve.
- **`midi.TriggerChord(degree, is_note_on, ctx)`**: resuelve degree → scale → chord → MIDI notes, envía cada nota via `SendMidi`. Usa `temp_ctx` para zero-allocation en hot path. Velocidad: 85+random(30) o 127 según modo.
- Referencia de escalas definida en `config.lua` como `SCALES[21]`: cada entrada tiene `{name: string, intervals: number[]}`.

### 1.2 Modos de acorde
| Modo | Intervalos |
|------|-----------|
| NOTE | {0} — nota individual |
| Tri | {0, 2, 4} — tríada mayor |
| 7ma | {0, 2, 4, 6} — séptima |
| 9na | {0, 2, 4, 6, 8} — novena |
| sus2 | {0, 2, 7} |
| sus4 | {0, 5, 7} |
| dim | {0, 3, 6} — disminuido |
| aug | {0, 4, 8} — aumentado |
| 11th | {0, 4, 7, 10, 14, 17} |
| 13th | {0, 4, 7, 10, 14, 17, 21} |

10 modos de acorde: NOTE, Tri, 7ma, 9na + 7 modos extendidos (sus2, sus4, dim, aug, 11th, 13th). `CHORD_MODES` en `config.lua` define los intervalos de cada modo.

### 1.3 Inversiones
- **Base, 1st, 2nd, 3ra** inversión
- **Dirección de inversión**: Up / Down
- Función pura `midi.InvertChord(notes, inv_idx, direction)` — reordena notas del acorde moviendo N notas una octava arriba/abajo
- `INVERSION_MODES` en `config.lua`: `{"Base", "1st", "2nd", "3rd"}`

### 1.4 Subdivisión de compás
- **6 resoluciones**: 1/1, 1/2, 1/3, 1/4, 1/8, 1/16
- Cada grado de la progresión se puede subdividir en hasta N acordes (ej: slot 1 toca Tri, slot 1 sub-step 2 = 9na)
- El secuenciador sincroniza cada sub-step con el tempo de REAPER
- `SUBDIVISION_MODES` en `config.lua`: `{1, 2, 3, 4, 8, 16}`

---

## 2. Captura de Teclado QWERTY

*Módulos: `src/core/keyboard.lua` (interceptación y manejo), `src/core/midi.lua` (envío MIDI)*

### 2.1 VKEY_MAP — 28 teclas mapeadas
| Fila física | Teclas | Octava |
|-------------|--------|--------|
| Fila 1: números | 1–7 | +1 |
| Fila 2: QWERTYU | Q, W, E, R, T, Y, U | 0 (base) |
| Fila 3: ASDFGHJ | A, S, D, F, G, H, J | −1 |
| Fila 4: ZXCVBNM | Z, X, C, V, B, N, M | −2 |

- Mapeo de **grado (1–7) + octava** → nota MIDI absoluta
- Wrappeo de grado si excede la longitud de la escala
- Interceptado via `JS_VKeys_Intercept()` (js_ReaScriptAPI) — 28 teclas en 4 filas × 7 grados
- **`keyboard.InterceptMappedKeys(enabled)`**: activa/desactiva interceptación
- **`keyboard.HandleKeyboard(ctx)`**: lee `JS_VKeys_GetState()`, detecta transiciones press/release, llama `TriggerChord`. Usa `temp_ctx` (tabla reutilizable) para zero-allocation.
- **`keyboard.CheckFocus()`**: throttled 0.2s, verifica foco de ventana GFX via `JS_Window_GetFocus()`. Pierde foco → desactiva intercept + AllNotesOff.
- **Ref-counted active notes**: mismo trigger puede apuntar a la nota desde teclado + pads. El note-off solo se envía cuando TODOS los triggers liberan la nota.
- `VKEY_MAP` en `config.lua` (`src/config.lua`): `table[28]` con `{deg: 1..7, oct: -2..1}`

### 2.2 Input directo de pads
*Módulo: `src/ui/pads.lua`*
- 7 pads que representan los grados 1–7 de la escala actual
- Click para toggle on/off, drag entre pads para mover progresión
- Progresión visualizada sobre los pads en modo FULL
- 8px drag threshold antes de activar drag-to-slot (Issue 5)
- Release solo de notas mantenidas por el pad, no por QWERTY

---

## 3. Barra de Transporte Compacta

*Módulos: `src/ui/compact.lua` (barrel), `src/ui/compact-init.lua` (ciclo de vida), `src/ui/compact-bar.lua` (render LICE), `src/ui/compact-intercept.lua` (intercepción WM), `src/ui/compact-panel.lua` (panel flotante), `src/ui/compact-menu.lua` (menú contextual)*

### 3.1 Modos de vista
| Modo | Código | Descripción |
|------|--------|-------------|
| FULL | `VIEW_MODES.FULL = 1` | Ventana completa 720×497, dockeable, todos los widgets |
| COMPACT | `VIEW_MODES.COMPACT = 2` | Panel flotante compacto, sin ventana GFX principal |

- Toggle entre modos via botón 👁 en el header
- La vista COMPACT puede superponerse sobre la barra de transporte de REAPER como overlay
- `VIEW_MODES` en `config.lua`: `{ FULL = 1, COMPACT = 2 }`

### 3.2 Funcionalidades compactas
- **`compact-init.SwitchViewMode()`**: FULL↔COMPACT con `gfx.quit()`/`gfx.init()`; flag `view_mode == COMPACT` previene dibujo en contexto muerto
- **Auto-start en compact view**: el script puede iniciar directamente en modo compacto
- **Dock en barra de transporte de REAPER**: ventana acoplada al transport bar nativo (DOCK_MIN_W=400, DOCK_MIN_H=50)
- **`compact-init.InitOverlay()`**: encuentra transporte + init LICE para overlay mode
- **`compact-init.FindTransportWindow()`**: búsqueda "Transport" → "Transporte" → SWS fallback chain (Issue 7)
- **`compact-init.HandlePanel()`**: ciclo de vida del panel flotante con auto-reposición si transport se mueve >50px
- **Auto-posicionamiento**: detección automática de la barra de transporte vía `positioning.lua`
- **Posición manual**: usuario puede ajustar offset X/Y manualmente desde el menú de Settings
- **Botón "M"**: alterna entre FULL y COMPACT
- **Esc en mode COMPACT**: cierra el panel flotante (sin cerrar el script)

### 3.3 Overlay Compact + Full
- Modo overlay: barra compacta visible simultáneamente con la vista FULL
- Seleccionable desde menú de Settings → "Mostrar Barra Mini" (no soportado en docked mode)
- `compact-bar.lua`: render LICE con labels Key/Scale/Octave/Chord + barra de volumen
- `compact-intercept.lua`: `ProcessMouseInterception` — WM_LBUTTONDOWN passthrough, WM_RBUTTONDOWN bloqueado; hit-test entre restore zone ↔ content zone; guard post-menú 200ms

La transición entre modos usa `src/ui/gfx-safe.lua` (`SafeGfxInit`, `SafeGfxQuit`) — wrappers con `pcall` y doble-init prevention para evitar crashes durante el cambio de contexto GFX.

---

## 4. Secuenciador Interno

*Módulos: `src/core/sequencer.lua` (motor), `src/core/progression.lua` (gestión de slots)*

### 4.1 Modos de reloj
| Modo | Descripción |
|------|-------------|
| **REAPER Sync** | Sincronizado al cabezal de reproducción de REAPER (`TimeMap2_timeToBeats`) |
| **Internal Clock** | Modo autónomo: BPM del master de REAPER, contador interno con `time_precise()` |

### 4.2 Funcionamiento del loop
- **`sequencer.Run()`**: motor principal — avanza beats, dispara acordes en límites de compás, auto-stops cuando todos los slots están exhaustos
- Loop automático sobre la progresión: cuando llega al último slot con contenido, vuelve al slot 1
- **Caché `GetLastFilled()` por tick**: una sola consulta por frame (Issue 19)
- Por cada paso del compás: detiene notas anteriores, dispara acorde del slot actual
- **TriggerSubChord**: resuelve sub-chords para slots subdivididos o acorde base para slots legacy
- **`progression.GetLastFilled()`**: retorna índice del último slot no-nil

### 4.3 Auto-paginación
- 16 slots organizados en 4 páginas (4 slots por página)
- Cuando el paso actual cruza de página (ej: paso 5 → página 2), la UI actualiza automáticamente

### 4.4 Play/Stop
- Botón en UI togglea reproducción
- **Fix de stuck notes**: `sequencer.Stop()` itera `MidiNotes` y envía note-offs explícitos antes de limpiar la tabla, resetea step/progress/measure/clock (Issue 22)
- **`sequencer.Stop()`**: envía note-offs para todas las notas activas en MidiNotes, resetea estado
- **`progression.Add(degree, root_index, scale_index, octave, chord_mode_index, velocity, duration, ctx)`**: inserta slot en próxima posición disponible (1-16)
- **`progression.Remove(slot_idx)`**, **`progression.Swap(idx_a, idx_b)`**, **`progression.Clear()`**: CRUD de slots

---

## 5. Isla MIDI

*Módulos: `src/ui/midi-island.lua` (orquestador), `src/ui/piano-roll.lua` (barrel), `src/ui/piano-roll/` (9 sub-módulos), `src/ui/midi-island/header.lua`, `src/ui/midi-island/input.lua`*

La Isla MIDI es un panel expandible dentro del modo FULL que agrega:

### 5.1 Piano Roll
- **Rango de altura**: C0 a B8 (108 pitch rows, 12 semitonos por octava)
- **Grid de beats**: timeline horizontal en beats (4 compases visibles por defecto)
- **Ruler timeline**: barra superior con marcas de compás, puntos de beat
- **Teclado vertical**: franja izquierda con teclas blancas/negras; notas activas se iluminan en rojo
- **Notas como rectángulos**: `start_beat + duration`, con altura según pitch
- **Render de nota**: `piano-roll/note.lua` usa `gfx.rect` con fill + border; optimizado con `+1` en width/height para prevenir seams de REAPER GFX (gotcha documentado)
- **`piano-roll/grid.lua`**: `DrawVerticalPianoKeyboard()` — filas de semitonos uniformes, indicadores de escala, glow de nota activa; `DrawPianoRollGrid()` — pitch rows + scale highlighting + beat lines 4-tier + snap-aware subdivision filtering
- **`src/ui/piano-roll/coord.lua`**: funciones puras `BeatToX`, `XToBeat`, `PitchToY`, `YToPitch` — transformación de coordenadas
- **`piano-roll/view.lua`**: `DrawPianoRoll()` — compute visible ranges una vez, delega a grid → note → lasso

### 5.2 Three-panel layout
```
┌──────────────────────────────────────────────────────┐
│ Timeline ruler (altura fija)                         │
├──────┬───────────────────────────────────────────────┤
│ Pkbd │ Piano Roll Grid (scrollable Y + X)            │
│ virt │                                               │
│      │                                               │
├──────┴──────┬────────────────────────────────────────┤
│   (toggles) │   Velocity Editor (altura colapsable)  │
└─────────────┴────────────────────────────────────────┘
```

### 5.3 Búsqueda de usuario
- Gesto de búsqueda en piano roll: escribir números de nota, filtrar por coincidencia
- `midi-island/input.lua`: dispatch de eventos de mouse y teclado

### 5.4 Time Selection (ruler → slots)
- Selección de rango en el timeline superior del piano roll
- Rango seleccionado sincroniza con los slots de progresión (afecta qué parte de la progresión se ve/busca)
- `timeline.lua`: dibuja timeline con ticks de compás/beat, cabezal de reproducción; jerarquía 4-tier: measure → beat → 1/8 → 1/16 (filtrado por snap resolution)

### 5.5 Hover Highlight Piano Vertical
> 📋 Planificada
> Al pasar el cursor sobre una celda de la grilla del piano roll, se ilumina la nota correspondiente en el teclado vertical izquierdo.

### 5.6 Zoom / Scroll
- **Zoom horizontal**: `scroll_zoom_x`, rango 10–200 px/beat
- **Zoom vertical**: eje Y con culling de filas fuera de viewport
- **Auto-scroll y seguimiento del playhead**:
  - `follow_playhead = true`: el scroll horizontal sigue al cabezal de reproducción
  - **Grace period de 2 segundos**: después de un scroll manual del usuario, el auto-scroll se desactiva temporalmente antes de reenganchar
  - **Frame-cached Visible Ranges**: `src/ui/piano-roll/grid.lua` — `ComputeVisibleRanges()` cachea resultado hasta que cambian scroll/zoom/dimensiones, sub-pixel smooth scrolling
- **Scroll/zoom handlers**: scroll horizontal/vertical, zoom X/Y, cache invalidation

### 5.7 Snap a grilla
- **Toggle SNAP**: activa/desactiva snap en el grid del piano roll
- **Resolución**: 1/1, 1/2, 1/4, 1/8, 1/16, 1/32
- **Triplet mode**: snap en corcheas de tresillo
- Función pura `snap.SnapBeat(beat, resolution, triplet)` en `src/core/snap.lua` — sin estado, testeable (89 checks en tests)

### 5.8 Herramientas de edición (Tool Mode)
| Herramienta | Icono | Descripción |
|-------------|-------|-------------|
| **Paint (✎)** | ✎ | Clic para añadir notas, Shift+clic en nota existente para eliminarla |
| **Knife (✂)** | ✂ | Partir notas en dos en el punto de corte (`piano-roll/knife.lua`) |
| **Eraser (⨯)** | ⨯ | Eliminar notas por clic o por lasso (`midi-island/input.lua`) |

- `midi-island/header.lua` (194 LOC): toggle tool mode, MIDI channel selector, snap controls, zoom in/out

---

## 6. Piano Roll — Edición de Notas

*Módulos: `src/ui/piano-roll/interaction.lua` (barrel), `src/ui/piano-roll/interaction/handlers.lua`, `src/ui/piano-roll/interaction/drag.lua`, `src/ui/piano-roll/interaction/shortcuts.lua`, `src/ui/piano-roll/knife.lua`, `src/ui/piano-roll/clipboard.lua`, `src/ui/piano-roll/undo.lua`*

### 6.1 Añadir / Eliminar / Mover notas
- **Añadir**: Clic en la grilla con herramienta Paint → nota en ese pitch + beat (`handlers.HandlePaintClick`)
- **Eliminar**: Shift + clic en nota (Paint), clic directo (Eraser), right-click delete (`handlers.HandlePaintRightClick`), o lasso multi-select + Delete
- **Mover**: Drag & drop de nota a nueva posición (`drag.StartNoteDrag` → `drag.UpdateNoteDrag` → `drag.CommitNoteDrag`): 8px threshold, multi-note group move con snap + undo
- **Redimensionar duración**: Drag del borde derecho/izquierdo de la nota (resize edge, 4px hotzone) — `drag.StartNoteResize` / `drag.CommitNoteResize`

### 6.2 Knife (cortar notas)
- **`knife.HandleKnifeClick`**: divide nota en el punto de corte (cuantizado a 1/16). Mitad izquierda conserva UUID, mitad derecha recibe nuevo UUID + flag split. Undo type "split" revierte ambas mitades.

### 6.3 Selección múltiple (Lasso)
- Clic + drag sobre área vacía de la grilla → rectángulo de selección
- `handlers.DrawLassoRect`: fill + border
- `GetNotesInRect`: pitch+beat space, normalized rect anti-flicker
- Todas las notas dentro del rectángulo se seleccionan
- `selected_indices{}` en `island_store` (set de índices para multi-select)
- `GetPrimarySelectedIndex()` retorna el índice más reciente (compat con velocity.lua)
- `SetNotes()` llama `ClearSelection()` automáticamente (índices viejos son inválidos)

### 6.4 Velocity Editor
*Módulo: `src/ui/velocity.lua`*
- **Panel colapsable**: botón toggle en la UI
- **Head circular de edición**: arrastrar el cabezal circular para ajustar la velocidad de la(s) nota(s) seleccionada(s)
- **Delta relativo para multi-selección**: al arrastrar con varias notas seleccionadas, el delta desde el click inicial se aplica a todas, preservando diferencias relativas entre notas
- **Número dinámico sobre cabezal**: muestra el valor de velocidad actual
- **Ajuste a la izquierda**: si el número dinámico choca con el borde de la franja del piano (teclado), se muestra a la derecha
- Glass Blade aesthetic con glow stems + rounded pins; gradient coloring desde note color

### 6.5 Undo / Redo
*Módulo: `src/ui/piano-roll/undo.lua`*
- Stack de hasta 50 entradas
- Snapshot de notas antes de cada mutación (note added / removed / moved / resized)
- `undo.RestoreUndo/RestoreRedo`: maneja tipos "move", "resize", "delete", "add", "velocity", "mute", "split", "preset_load"
- Shortcuts Ctrl+Z (undo) y Ctrl+Shift+Z (redo) en el piano roll

### 6.6 Clipboard (copiar/pegar)
*Módulo: `src/ui/piano-roll/clipboard.lua`*
- Copiar notas seleccionadas al portapapeles interno (sin UUIDs en clipboard)
- Pegar en nueva posición (manteniendo pitches relativos), nuevos UUIDs, undo type "add"
- Atajos: Ctrl+C, Ctrl+V
- **`clipboard.HandleCut`**: copy + remove + undo "delete"

### 6.7 Right-drag Delete Sweep
*`piano-roll/interaction/drag.lua`*
- Right-drag sobre área vacía: barrido de eliminación con undo acumulado, UUID tracking, barrido final de seguridad
- `DrawRightDragSweepRect`: rectángulo rojo translúcido durante el barrido

---

## 7. Preset Browser (Panel Izquierdo)

*Módulos: `src/ui/preset-browser.lua` (barrel), `src/ui/preset-browser/main.lua` (composición), `src/ui/preset-browser/io.lua` (filesystem + batch ops + packs + versioning), `src/ui/preset-browser/folder.lua` (árbol de directorios), `src/ui/preset-browser/preset-list.lua` (lista + multi-select + badges), `src/ui/preset-browser/preview.lua` (preview auditivo ghost-notes)*

### 7.1 Funcionalidades Base
| Feature | Detalle |
|---------|---------|
| Directorios de presets | Navegación por carpetas del sistema de archivos |
| Favoritos | Marcado de directorios favoritos (persistido via ExtState) |
| Búsqueda en tiempo real | Campo de búsqueda que filtra presets mientras se escribe |
| Cross-session refresh | Escaneo automático de presets cada 3 segundos |
| Error banner | Muestra errores de lectura de directorios sin crashear |
| Formato de archivo | `.grove` — archivo Lua serializado via `dofile()` con sandbox (`safe-loader.lua`) |

### 7.2 Formato .grove v3 (Metadata)
A partir de Phase 1, los presets incluyen metadata estructurada:

```lua
-- .grove v3 format (simplificado)
return {
  version = 3,
  bpm = 120,
  genre = "pop",
  difficulty = 3,          -- 1-5
  tags = "pop,ballad,piano",
  notes = "Inspired by...",
  scale = { root="C", scale="Major", octave=3, chord_mode="Tri" },
  note_entries = { ... }   -- las notas del preset
}
```

- **`io.SavePresetV3()`**: serializa con metadata; **`LoadPreset()`** compatible con v1/v2/v3
- **`preset_store.GetEditingMetadata()`** / **`SetEditingMetadata()`**: estado transitorio para el modal de edición de metadata
- Tags y notas libres por preset, parseados en la UI

### 7.3 Multi-Select (Set-based Sparse)
- **Ctrl+click**: toggle individual de selección
- **Shift+click**: rango desde el anchor (último click sin Shift) hasta el click actual
- **Anchor point**: `_last_anchor_idx` en `preset-list.lua` — se actualiza en cada click sin Shift
- Implementación: `selected_indices = { [idx] = true }` — set sparse con O(1) lookup y toggle
- `preset_store.SetSelectedIndices()` / `GetSelectedIndices()` / `ClearSelectedIndices()`
- UI feedback: highlight azul semi-transparente en items seleccionados

### 7.4 Batch Operations
Cuando hay 2+ presets seleccionados, el menú contextual muestra opciones batch:

| Operación | Descripción |
|-----------|-------------|
| **Batch Delete** | `io.BatchDeletePresets(indices)` — elimina todos los presets seleccionados |
| **Merge Load** | `io.BatchMergeLoadPresets(indices)` — carga todas las notas de los presets seleccionados en el piano roll actual |
| **Export as MIDI** | `io.ExportPresetsToMIDI(indices)` — exporta cada preset seleccionado como item MIDI separado |

### 7.5 Preview Auditivo (Ghost Notes)
*Módulo: `src/ui/preset-browser/preview.lua` (74 LOC)*

- **Ctrl+Click** sobre un preset → reproduce preview de las notas sin mutar el estado actual
- Usa `reaper.StuffMIDIMessage` directo (bypassea ref-counting de active notes)
- Note-off automático después de `PREVIEW_DURATION = 0.5s`
- Solo un preview activo a la vez
- **Ghost rendering**: las notas del preview se dibujan semi-transparentes sobre la grilla del piano roll

### 7.6 Miniaturas 8×8 (Thumbnail Grid)
- **`preset_store.GetThumbnail(path)`** / **`SetThumbnail(path, grid)`**: grid `table[8][8]` de booleanos (activo/silencio)
- Generadas al guardar el preset analizando la densidad de notas por celda
- **`_thumbnail_cache`**: cache en memoria keyeado por path, `ClearThumbnailCache()` para invalidar
- Renderizadas como matriz 8×8 en la lista de presets junto al nombre

### 7.7 Badges
Indicadores visuales al lado de cada preset en la lista:

| Badge | Condición |
|-------|-----------|
| **Entry Type** | "Prog." (progression-only) ↔ "Notes" (piano-roll notes) |
| **Load Count** | Número de veces cargado desde `preset_stats` |
| **Stats Summary** | Última carga, última modificación (tooltip hover) |

- Badge "Prog." usa `entry_type == "progression"` detectado desde el contenido del archivo
- Stats se muestran en hover tooltip con formato "Loaded 5 times / Last: 2h ago"

### 7.8 Auto-Versioning
*`src/ui/preset-browser/io.lua` (líneas 239, 299, 540-543)*

- **Auto versioning**: si el archivo ya existe, `SavePresetWithVersioning()` genera `_v1`, `_v2`, etc. antes de sobrescribir
- Preserva versiones anteriores en el mismo directorio

### 7.9 Pack Export / Import
*`src/ui/preset-browser/io.lua`*

| Operación | Descripción |
|-----------|-------------|
| **Export Pack** | `ExportPresetsAsPack()` — selecciona N presets, los empaqueta en un archivo `.grove-pack` (Lua table con todos los presets inline) |
| **Import Pack** | `ImportPresetsFromPack(pack_path)` — lee `.grove-pack`, extrae presets, los escribe individualmente en el directorio activo, retorna count |

### 7.10 Preset Stats (Load Tracking)
- **`preset_stats[path]`**: `{ load_count, last_loaded, last_modified }`
- `IncrementLoadStat(path)`: incrementa contador + actualiza timestamp
- Persistido via ExtState (`reaper.SetExtState "preset_stats"`)
- `LoadPresetStats()` / `SavePresetStats()`: carga/guarda desde ExtState
- Stats visibles en tooltip hover del preset

### 7.11 Módulos Internos
| Módulo | LOC | Propósito |
|--------|-----|-----------|
| `preset-browser/main.lua` | — | Composición del panel: botón RANDOM, delega a folder + preset-list |
| `preset-browser/io.lua` | ~940 | Init, ScanDirectory, SavePreset/LoadPreset (v1-v3), Rename, Delete, Batch*, Export*, Pack*, versioning |
| `preset-browser/folder.lua` | — | DrawFolderHeader, DrawFolderList (scrollable), HandleFolderClick/Wheel |
| `preset-browser/preset-list.lua` | — | DrawPresetList (star, hover, selected), HandleMultiSelectClick (Ctrl/Shift), HandleContextMenu batch vs single |
| `preset-browser/preview.lua` | 74 | Preview auditivo con ghost notes, PREVIEW_DURATION=0.5s |

### 7.12 Gestión de directorios favoritos
- Agregar/quitar directorios de la lista de favoritos
- Serializados como tabla Lua `{"path1","path2",...}` por `reaper.GetExtState/SetExtState`
- Error handling: `dofile()` envuelto en `pcall` con rollback ante archivos corruptos

---

## 8. Exportación MIDI

*Módulo: `src/core/midi.lua` — función `ExportToMidi(filename)`*

### 8.1 ExportToMidi
- Toma la progresión del slot activo y la inserta como item MIDI en la pista seleccionada de REAPER
- Usa `reaper.MIDI_InsertNote`, `MIDI_Sort`, `GetActiveTake`/`SetActiveTake`
- Resuelve notas MIDI desde `midi.GetMidiNote()` con `progression.GetProgressionEntry(i)`
- Cuantiza posiciones a QN (quarter notes) del proyecto
- Crea archivo MIDI: track + takes por slot; cada slot = chord en beat 0, slots espaciados 4 beats apart

---

## 9. Menú Contextual de Settings

*Módulo: `src/ui/views.lua` + `src/ui/buttons.lua` (iconos)*

Configuración accesible desde el botón ⚙ del header:

| Opción | Descripción |
|--------|-------------|
| Modo de color | "Grados a color" (notas coloreadas por grado) / "Colores planos" (todas azules) |
| Ajustar posición vista mini | Ajuste manual de offset X/Y para vista compacta |
| Resetear posición vista mini | Vuelve a auto-posicionamiento |
| Activar Scroll en Dropdowns | Habilita scroll del mouse en los menús dropdown |
| Iniciar en Vista Mini | El script arranca en modo COMPACT |
| Iniciar con REAPER | Auto-launch al abrir REAPER |
| Auto armar pista al seleccionar | Crea y arma una pista MIDI automáticamente en el primer arranque |
| Auto-focus al cambiar Slot | Centra el piano roll en las notas cuando cambia el slot |

### 9.1 UI Shared Utilities
Los siguientes módulos de utilería soportan la UI general, accesibles desde todos los contextos de dibujo:

| Módulo | Propósito |
|--------|-----------|
| `src/ui/colors.lua` | `DegreeColor(degree)` → color table (mapeo grado→color) |
| `src/ui/format.lua` | `NoteName(pitch)`, `ChordLabel(degree, scale, chord_mode)`, `RomanNumeral(degree)` |
| `src/ui/helpers.lua` | `SetColor()`, `DrawTooltip()`, `AbbreviateScale()` (7→3 chars), `ComputeScaleNotes()` |
| `src/ui/icons.lua` | `DrawIcon()` — iconos vectoriales SVG-like (settings/help/scroll/clear/export/view/dock/midi) |
| `src/ui/constants.lua` | Dimensiones de ventana (720×497, 720×793), límites de zoom (10-200), códigos de tecla |
| `src/ui/layout.lua` | Sistema de coordenadas virtuales: `SetScale()`, UX/UY/US (39914×29162 → pixels) |
| `src/ui/themes.lua` | 3 paletas de 40+ colores + 7 colores de grado cada una (Current, Dark, HighContrast) |
| `src/ui/theme.lua` | `theme.colors`: 16 color keys + `grade_colors[7]`; switchea via `SetThemeIndex()` |
| `src/ui/path-utils.lua` | `SanitizePresetName()`, `PathJoin()` — prevención de directory traversal |
| `src/ui/gfx-window.lua` | `ToggleMIDIIslandWindow()` — expandir/colapsar tamaño de ventana |
| `src/ui/lice.lua` | LICE wrappers: `EnsureLICE()`, `DrawRoundedRectFill()`, `DrawArrowIcon()`, `DrawProgressBar()`, `DrawModeHint()` |
| `src/ui/drag.lua` | `DrawDragPreview(w, h)` — preview flotante coloreado por grado durante drag-to-slot |
| `src/ui/paginator.lua` | `DrawPaginator(x, y, total_pages)` — puntos de página con hover tooltips |
| `src/ui/safe-loader.lua` | `LoadSandboxed(file_path)` — ejecución Lua en sandbox (math/string/table only, sin io/os/dofile) |

Los submódulos de vista (`src/ui/views/islands.lua`, `src/ui/views/performance.lua`, `src/ui/views/docked.lua`) son fraccionamientos de `views.lua` que manejan secciones específicas de la interfaz FULL, Performance Area y Docked Transport Bar respectivamente.

---

## 10. Canales MIDI

*Módulo: `src/state/midi.lua` — `midi_store.GetMidiChannel()` / `SetMidiChannel()`*

- Canal MIDI seleccionable de 1 a 16
- Almacenado en `midi_store.GetMidiChannel()` / `SetMidiChannel()`
- Usado por `midi.SendMidi` al empaquetar el byte de canal en el mensaje status

---

## 11. Modulación y Sustain

*Módulo: `src/core/midi.lua`*

- **Modulación**: toggle entre off (0) y valor 80 — enviado como CC #1
- **Sustain**: detecta pedal de sustain (Nota MIDI 64), guarda notas activas en tabla `sustain_held_notes`
- Al liberar sustain: envía note-offs a todas las notas sostenidas

---

## 12. Volumen

*Módulos: `src/state/sequencer.lua` — `sequencer_store.GetVolume()`, `src/core/sequencer.lua`*

- **Volumen del secuenciador**: entero 1–127 (default 100)
- Se lee en `midi.SendMidi` como `vol = sequencer_store.GetVolume()`
- Afecta la velocidad de las notas enviadas por el secuenciador

---

## 13. Persistencia de Estado (ExtState)

### 13.1 Estado persistido

*Módulos: `src/state/preferences.lua` (debounce), `src/state/persist.lua` (load/save)*

Todas las preferencias se guardan via `reaper.SetExtState` en el proyecto de REAPER:

| Clave ExtState | Valores | Propósito |
|---------------|---------|-----------|
| `root_index` | 1–12 | Raíz de la escala |
| `scale_index` | 1–21 | Índice de escala |
| `octave` | 0–8 | Octava base |
| `chord_mode_index` | 1–10 | Modo de acorde |
| `inversion_index` | 1–4 | Inversión |
| `inversion_direction` | 0/1 | Dirección de inversión |
| `subdivision_index` | 1–6 | Resolución de subdivisión |
| `volume` | 1–127 | Volumen del secuenciador |
| `color_mode` | "grade"/"flat" | Modo de color |
| `auto_focus_enabled` | true/false | Auto-focus al cambiar slot |
| `auto_start_compact` | true/false | Auto-inicio en vista mini |
| `auto_start_reaper` | true/false | Auto-launch con REAPER |
| `auto_track_setup_done` | "true"/"skipped"/"" | Flag de una sola ejecución para setup de pista |
| `use_scroll` | 1/0 | Scroll en dropdowns |
| `use_velocity` | 1/0 | Uso de velocidad MIDI |
| `color_mode` | string | Modo de color (grade/flat) |

**Debounce de guardado**: `preferences_store.TickSaveDebounce()` agrupa cambios y guarda todos los keys en una sola operación batch por frame, evitando N escrituras sincrónicas.

**`persist.Load(config.state)`**: lee ExtState overlays → `config.state`. **`preferences_store.SyncFromState(config.state)`**: push overlays a stores (Step 12-13 del Init Order).

### 13.2 Arquitectura de Stores

*Módulos: `src/state/` (10 archivos)*

El sistema de estado se compone de 9 stores + persistencia:

| Store | Módulo | Propósito |
|-------|--------|-----------|
| **ui** | `src/state/ui.lua` | view_mode, color_mode, docked, tooltips, consumables (mouse_click, mouse_wheel_delta), did_cleanup, search, slider_dragging, pad_flash |
| **midi** | `src/state/midi.lua` | use_velocity, last_note_played, key_states (por VK), active_notes (pitch→ref_count), mouse_pad_state |
| **sequencer** | `src/state/sequencer.lua` | is_playing, volume, current_page, progression[16], undo/redo stacks (2 FIFO, cap 50), step, progress, clock |
| **drag** | `src/state/drag.lua` | is_dragging, pending_degree, source_degree, source_slot_idx, start_x/y |
| **compact** | `src/state/compact.lua` | transport_hwnd, overlay_active, LICE bitmap/font/gdi_font, last_gfx_state |
| **island** | `src/state/island.lua` | island_active, scroll_offset_x/y, zoom_x, snap, tool_mode, notes, selection, lasso, undo/redo (max 50) |
| **note-store** | `src/state/note-store.lua` | Notes CRUD: AddNote, RemoveNoteAtIndex, ClearNotes, InsertNoteAtIndex; UUID-based (AllocNoteUUID, FindNoteByUUID); Undo/Redo stacks (50 cap) |
| **piano-roll-store** | `src/state/piano-roll-store.lua` | init interno via island_store; Undo/Redo stacks con UUID-based identification (94 checks en tests) |
| **preset-store** | `src/state/preset-store.lua` | preset_root, directory, preset_tree, files, favorites, bookmarks, search, selected_indices (set-based sparse), preset_stats (load tracking), _editing_metadata (bpm/genre/difficulty/tags/notes), _thumbnail_cache (grid 8×8 keyed by path) |
| **preferences** | `src/state/preferences.lua` | root_index, scale_index, octave, chord_mode_index, inversion_index/direction, subdivision_index, theme_index, show_qwerty_labels, midi_channel — marca save_pending en cada setter, `TickSaveDebounce()` flush por frame |

**Patrón consumable**: `mouse_click` y `mouse_wheel_delta` tienen ciclo de 1 frame — `SetMouseClick()` en MainLoop, `ConsumeMouseClick()` en widget target.

**Estado remnant en `config.state`**: `view_offset_x`, `view_offset_y`, `use_scroll` — ~17 runtime reads directos (5+ archivos: views.lua, main.lua, midi.lua, compact-init.lua, compact-menu.lua). `use_scroll` se lee via `ui_store.GetUseScroll()`.

---

## 14. Teclas Rápidas (Keyboard Shortcuts)

### 14.1 QWERTY → Notas MIDI
28 teclas mapeadas (ver Sección 2.1). Códigos VK en `config.lua`:
- Row1 (0x31-0x37): oct+1
- Row2 QWERTYU (0x51/57/45/52/54/59/55): oct 0
- Row3 ASDFGHJ (0x41/53/44/46/47/48/4A): oct-1
- Row4 ZXCVBNM (0x5A/58/43/56/42/4E/4D): oct-2

### 14.2 Piano Roll — shortcuts globales
*Módulo: `src/ui/piano-roll/interaction/shortcuts.lua`*

| Atajo | Acción |
|-------|-------|
| `Q` | Mostrar menú de cuantización |
| `Delete` | Eliminar nota(s) seleccionada(s) |
| `Ctrl+Z` | Deshacer (undo, pop stack + restore) |
| `Ctrl+Shift+Z` | Rehacer (redo, pop stack + restore) |
| `Ctrl+C` | Copiar notas seleccionadas |
| `Ctrl+V` | Pegar notas del portapapeles (nuevos UUIDs) |
| `Ctrl+A` | Toggle select all / deselect all |
| `Ctrl+X` | Cut (copy + delete + undo) |
| `Escape` | Cancelar drag / salir de modo edición |
| `↑/↓` | Nudge pitch +1/-1 semitono |
| `Shift+↑/↓` | Nudge pitch +1/-1 octava |
| `←/→` | Nudge beat -1/+1 |
| `Shift+←/→` | Nudge beat -4/+4 (1 compás) |

### 14.3 Atajos de vista
| Atajo | Acción |
|-------|-------|
| `Ctrl+D` (FULL) | Toggle dock (acoplar/desacoplar al transport bar) |
| `Esc` (COMPACT) | Cerrar panel compacto |

---

## 15. Patrones Arquitectónicos

| Patrón | Propósito | Implementación |
|--------|-----------|---------------|
| **Ref-counted Active Notes** | Evitar stuck notes cuando múltiples triggers apuntan a la misma nota MIDI | `midi.lua` + `midi_store.SetActiveNote()` — incrementa en note-on, decrementa en note-off, envía 0x80 solo cuando llega a 0 |
| **Barrel (Re-export)** | Fachada unificada para submódulos | `src/ui/components.lua`, `src/ui/compact.lua`, `src/ui/piano-roll.lua`, `src/ui/piano-roll/interaction.lua` — solo 1 `require` por consumer |
| **Lazy require** | Romper ciclos de dependencia | `require("ui.components")` dentro de la función, no al tope del módulo (desde `src/ui/components.lua`) |
| **Event Bus `mouse_click`** | Click de 1 frame, múltiples widgets, un solo consumidor | `ui_store.SetMouseClick()` / `ConsumeMouseClick()` |
| **Temporary Context `temp_ctx`** | Zero-allocation en hot path del teclado | `keyboard.lua` — tabla mutada in-place antes de cada llamada a `TriggerChord` |
| **Consume `mouse_wheel_delta`** | Scroll delta leído una sola vez por widget | `ui_store.ConsumeMouseWheelDelta()` |
| **API Guard** | Validar dependencias opcionales al inicio | `api-guard.lua` — `reaper.APIExists` sobre cada API requerida (js_ReaScriptAPI, etc.) |
| **Snap Grid (Pure Function)** | Snap a grilla sin estado ni efectos secundarios | `snap.lua` — `SnapBeat(beat, resolution, triplet)` — 89 checks en tests |
| **Undo/Redo Stack** | Deshacer/rehacer ediciones en piano roll | `piano-roll-store.lua` — hasta 50 entradas, UUID por nota, snapshot-based |
| **Lasso Selection** | Selección multi-nota por rectángulo | `island_store` — `lasso_active`, `lasso_start_*`, `lasso_end_*` |
| **Dual Context (Main + Compact)** | Dos contextos GFX independientes | `main.lua` (full) + `compact-init.lua` (compact) — cada uno con su propio `gfx.mouse_wheel` (DSGVO pattern) |
| **Auto-scroll Grace Period** | Evitar conflicto entre scroll manual y auto-scroll | 2 segundos de gracia después de scroll manual antes de reenganchar el seguimiento del playhead |
| **Frame-cached Visible Ranges** | Evitar recomputar rangos visibles en cada frame | `grid.lua` — `ComputeVisibleRanges()` cachea resultado, invalida solo cuando cambian scroll/zoom/dimensiones |
| **Debounced Preference Save** | Evitar N escrituras sincrónicas por frame | `preferences.lua` — marca `save_pending` en cada setter, `TickSaveDebounce()` flush batch por frame |
| **Play/Stop → sequencer.Stop()** | Asegurar note-offs al detener reproducción | `views.lua` → `sequencer.Stop()` itera MidiNotes y envía note-offs explícitos antes de limpiar estado |
| **Set-based Multi-Select** | Selección múltiple con O(1) lookup, toggle, y anchor para Shift+click range | `preset-store` — `selected_indices = { [idx] = true }`, anchor en `_last_anchor_idx`; Ctrl+click toggle, Shift+click range |

---

## 16. Issues Resueltos

| Issue | Archivo(s) | Resumen |
|-------|-----------|---------|
| #1 | `src/ui/dropdown.lua` | Scroll wheel en dropdowns funcionando correctamente |
| #2 | `src/ui/slots.lua` | Slots renderizados correctamente — 4 llamadas a SetSlot son necesarias por frame |
| #3 | `src/ui/views.lua`, `src/ui/positioning.lua` | Ubicación de ventana corregida: slots ahora después de la barra de progreso |
| #4 | `src/core/keyboard.lua` | Arreglado problema de distribución al colocar pads en slots: slots page reset a P1 al colocar el primer pad |
| #5 | `src/ui/pads.lua` | Release pad-held notes only when drag starts |
| #6 | `src/ui/views.lua` | U+25C4 glyph support for undock button — reemplazado con `gfx.triangle` |
| #7 | `src/ui/compact-init.lua` | Transport window find — SWS fallback chain |
| #8 | `src/ui/views.lua`, `src/main.lua` | DecrementPageOverrideTimer en ALL modes (incluyendo Docked) |
| #9 | `src/ui/views.lua` | Octave dropdown rendering — `oct_open_up` dinámico |
| #10 | `src/ui/positioning.lua` | Invalidate auto-position cache on transport resize |
| #11 | `src/ui/views.lua` | Fixed tooltip positioning for chord buttons with offset=0 status_text_y |
| #12 | `src/core/keyboard.lua` | Reusable `temp_ctx` table — zero-allocation en hot path |
| #13 | `src/ui/piano.lua` | Cached `active_mod12` — evita recomputar cada frame |
| #14 | `src/ui/views.lua` | Add name comparison (`ne`) to main scale menu style picker in QUICK_SWITCH |
| #14b | `src/ui/preset-browser/` | Preset bugs resueltos en presets-full-features Phase 1 & 2: metadata v3, multi-select, batch ops, preview, thumbnails, badges, versioning, packs, stats, auto-save |
| #15 | `src/core/keyboard.lua` | Velocity humanization: `85 + math.random(30)` |
| #16 | `src/ui/checkbox.lua` | Change toggle icon glyph from '>' to '✓' |
| #17 | `src/ui/dropdown.lua` | Rework mouse wheel handling — mouse_wheel sniff test with frame separation detection |
| #18 | `src/ui/piano.lua` | O(N·M) inner loop → O(1) via pre-computed pitch-class set |
| #19 | `src/core/sequencer.lua` | Cache `GetLastFilled()` una sola vez por tick |
| #20 | `src/ui/piano.lua`, `src/ui/views.lua` | Piano chord tones: always show chord tones highlighting from progression |
| #21 | `src/core/keyboard.lua` | Velocity humanization activada: `85 + math.random(30)` |
| #22 | `src/ui/views.lua` | Stuck note en play/stop toggle — `sequencer.Stop()` envía note-offs explícitos |
| #23 | `src/state/note-store.lua`, `src/state/island.lua`, `src/ui/midi-island.lua`, `src/ui/views/islands.lua` | Inversion Island sync to MIDI island piano roll — `ProgressionToNotes` ahora acepta `inv_idx/inv_dir`, se regeneran notas al cambiar inversión cuando notes_state=LOADED |

---

## 17. Features Planificadas / Pendientes

| # | Feature | Prioridad | Estado |
|---|---------|-----------|--------|
| F01 | **Documento de features** — este mismo archivo | Alta | ✅ Implementada |
| F02 | Actualizar AGENTS.md para referenciar este documento | Alta | ✅ Implementada |
| F03 | Refactor SPDX headers (49 archivos stale) | Baja | 📋 Pendiente |
| F04 | Persistir `view_offset_x/y` para no perder posición al reiniciar REAPER | Media | ✅ Implementada (window-repositioning-fix) |

---

## 18. Bugs Conocidos / Pendientes de Fix

| # | Bug | Área | Estado |
|---|-----|------|--------|
| B01 | Scrollwheel en dropdowns requiere múltiples clics y a veces salta números | `src/ui/dropdown.lua` | 🐛 Pendiente |
| B02 | Subdivisión de slots: cambiar de Tri → 9na no se aplica, piano roll no refleja el cambio | `src/ui/slots.lua`, piano roll | 🐛 Pendiente |
| B03 | Clic derecho elimina ambos pads en slot subdividido (debería eliminar solo el seleccionado) | `src/ui/slots.lua` | 🐛 Pendiente |
| B04 | Número del pad en esquina superior izquierda no se ve | `src/ui/slots.lua` (color/contraste) | 🐛 Pendiente |
| B05 | Scrollwheel en subdivisión de slot: comportamiento inconsistente (debería cambiar entre subs, no paginar) | `src/ui/slots.lua` | 🐛 Pendiente |
| B06 | Zoom vertical estrecho: notas negras (líneas de texto) dejan de apreciarse | `src/ui/piano-roll/note.lua` | 🐛 Pendiente |
| B07 | Zoom vertical deforma bordes inferiores de notas (~1px hacia adentro) | `src/ui/piano-roll/note.lua` | 🐛 Pendiente |
| B08 | Notas en borde inferior: scroll causa deformación por culling strategy | `src/ui/piano-roll/view.lua` | 🐛 Pendiente |
| B09 | Notas pegadas a barra de velocity al dibujar cerca del borde inferior | `src/ui/velocity.lua` | 🐛 Pendiente |
| B10 | CH button: posición invertida de botones Tri/7ma/9na | `src/ui/midi-island/header.lua` | 🐛 Pendiente |
| B11 | Ctrl + drag izquierdo no activa lasso (debería ser selección por rectángulo) | `src/ui/midi-island/input.lua` | 🐛 Pendiente |
| B12 | Redimensionar ventana FULL: auto-zoom/scroll del piano roll no se reajusta | `src/ui/midi-island.lua` | 🐛 Pendiente |
| B13 | Isla inversión no sincroniza cambios al piano roll | `src/state/note-store.lua`, `src/state/island.lua`, `src/ui/midi-island.lua`, `src/ui/views/islands.lua` | ✅ Resuelto (batch-g-inversion-sync: `ProgressionToNotes` + `LoadNotesFromProgression` aceptan `inv_idx/inv_dir`, islands.lua trigger) |
| B14 | Panel de presets: bugs sin especificar (necesita investigación) | `src/ui/preset-browser/` | ✅ Resuelto (presets-full-features Phase 1 & 2) |
| B15 | Botón X al lado de Cut para eliminar notas (no existe actualmente) | `src/ui/midi-island/header.lua` | 📋 Planificada |
| B16 | Botón Quantize con popup de 3 knobs (start/duration/strength) | `src/core/quantize.lua` (existe), `quantize-popup.lua` (nuevo) | 📋 Planificada |
| B17 | Botón SYNC en header isla MIDI: sincronizar cabezal de reproducción al cabezal de REAPER | `src/ui/midi-island/header.lua` | 📋 Planificada |
| B18 | Mover botón Autoscroll al header de isla MIDI (actualmente en compact bar) + rediseño | `src/ui/midi-island/header.lua` | 📋 Planificada |
| B19 | Mover botón CH desde header isla MIDI a submenú contextual de Settings | `src/ui/views/header.lua` | 📋 Planificada |
| B20 | Subdivisión de slots: mostrar círculo rojo con X en esquina inferior derecha del slot para eliminar todos los pads | `src/ui/slots.lua` | 📋 Planificada |
| B21 | Time selection en piano roll ruler → sincroniza con slots | `src/ui/timeline.lua`, piano-roll/store, `src/ui/slots.lua` | 📋 Planificada |
| B22 | Hover highlight: nota del piano vertical se ilumina al pasar cursor por grilla | `src/ui/piano-roll/view.lua`, `src/ui/piano.lua` | 📋 Planificada |
| B23 | Vista compacta: renderizada muy a la derecha (solapando controles REAPER) + no reposiciona | `src/ui/compact-bar.lua`, `src/ui/positioning.lua` | 📋 Planificada |
