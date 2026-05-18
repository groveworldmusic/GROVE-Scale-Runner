# GROVE Scale Runner — Catálogo de Features

> **Convención**: Este documento es el catálogo maestro de features. Toda feature nueva que se implemente debe agregarse aquí con su estado (`✅ Implementada` / `🚧 En progreso` / `📋 Planificada`).
>
> **Última actualización**: 2026-05-18
> **Versión del script**: v1.0.0

---

## 1. Sistema de Escalas y Acordes

### 1.1 Escalas musicales
| Feature | Detalle |
|---------|---------|
| 21 escalas | Major, Major Bebop, Major Pentatonic, Minor Harmonic, Minor Hungarian, Minor Melodic, Minor Natural (Aeolian), Minor Neapolitan, Minor Pentatonic, Arabic, Blues, Diminished, Dominant Bebop, Dorian, Enigmatic, Japanese Insen, Locrian, Lydian, Mixolydian, Neapolitan, Phrygian |
| Selección de raíz | 12 notas (C–B) |
| Selección de octava | C0–C8 |

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

### 1.3 Inversiones
- **Base, 1st, 2nd, 3ra** inversión
- **Dirección de inversión**: Up / Down
- Función pura `midi.InvertChord(notes, inv_idx, direction)` — reordena notas del acorde moviendo N notas una octava arriba/abajo

### 1.4 Subdivisión de compás
- **6 resoluciones**: 1/1, 1/2, 1/3, 1/4, 1/8, 1/16
- Cada grado de la progresión se puede subdividir en hasta N acordes (ej: slot 1 toca Tri, slot 1 sub-step 2 = 9na)
- El secuenciador sincroniza cada sub-step con el tempo de REAPER

---

## 2. Captura de Teclado QWERTY

### 2.1 VKEY_MAP — 28 teclas mapeadas
| Fila física | Teclas | Octava |
|-------------|--------|--------|
| Fila 1: números | 1–7 | +1 |
| Fila 2: QWERTYU | Q, W, E, R, T, Y, U | 0 (base) |
| Fila 3: ASDFGHJ | A, S, D, F, G, H, J | −1 |
| Fila 4: ZXCVBNM | Z, X, C, V, B, N, M | −2 |

- Mapeo de **grado (1–7) + octava** → nota MIDI absoluta
- Wrappeo de grado si excede la longitud de la escala
- Interceptado via `JS_VKeys_Intercept()` (js_ReaScriptAPI)
- **Ref-counted active notes**: mismo trigger puede apuntar a la nota desde teclado + pads. El note-off solo se envía cuando TODOS los triggers liberan la nota.

### 2.2 Input directo de pads
- 7 pads que representan los grados 1–7 de la escala actual
- Click para toggle on/off, drag entre pads para mover progresión
- Progresión visualizada sobre los pads en modo FULL

---

## 3. Barra de Transporte Compacta

### 3.1 Modos de vista
| Modo | Código | Descripción |
|------|--------|-------------|
| FULL | `VIEW_MODES.FULL = 1` | Ventana completa 720×497, dockeable, todos los widgets |
| COMPACT | `VIEW_MODES.COMPACT = 2` | Panel flotante compacto |

- Toggle entre modos via botón 👁 en el header
- La vista COMPACT puede superponerse sobre la barra de transporte de REAPER como overlay

### 3.2 Funcionalidades compactas
- **Auto-start en compact view**: el script puede iniciar directamente en modo compacto
- **Dock en barra de transporte de REAPER**: ventana acoplada al transport bar nativo
- **Auto-posicionamiento**: detección automática de la barra de transporte y posicionamiento relativo
- **Posición manual**: usuario puede ajustar offset X/Y manualmente desde el menú de Settings
- **Botón "M"**: alterna entre FULL y COMPACT
- **Esc en mode COMPACT**: cierra el panel flotante (sin cerrar el script)

### 3.3 Overlay Compact + Full
- Modo overlay: barra compacta visible simultáneamente con la vista FULL
- Seleccionable desde menú de Settings → "Mostrar Barra Mini" (no soportado en docked mode)

---

## 4. Secuenciador Interno

### 4.1 Modos de reloj
| Modo | Descripción |
|------|-------------|
| **REAPER Sync** | Sincronizado al cabezal de reproducción de REAPER (`TimeMap2_timeToBeats`) |
| **Internal Clock** | Modo autónomo: BPM del master de REAPER, contador interno con `time_precise()` |

### 4.2 Funcionamiento del loop
- Loop automático sobre la progresión: cuando llega al último slot con contenido, vuelve al slot 1
- **Caché `GetLastFilled()` por tick**: una sola consulta por frame
- Por cada paso del compás: detiene notas anteriores, dispara acorde del slot actual
- **TriggerSubChord**: resuelve sub-chords para slots subdivididos o acorde base para slots legacy

### 4.3 Auto-paginación
- 16 slots organizados en 4 páginas (4 slots por página)
- Cuando el paso actual cruza de página (ej: paso 5 → página 2), la UI actualiza automáticamente

### 4.4 Play/Stop
- Botón en UI togglea reproducción
- **Fix de stuck notes**: `sequencer.Stop()` itera `MidiNotes` y envía note-offs explícitos antes de limpiar la tabla (Issue 22)

---

## 5. Isla MIDI

La Isla MIDI es un panel expandible dentro del modo FULL que agrega:

### 5.1 Piano Roll
- **Rango de altura**: C0 a B8 (108 pitch rows, 12 semitonos por octava)
- **Grid de beats**: timeline horizontal en beats (4 compases visibles por defecto)
- **Ruler timeline**: barra superior con marcas de compás, puntos de beat
- **Teclado vertical**: franja izquierda con teclas blancas/negras; notas activas se iluminan en rojo
- **Notas como rectángulos**: `start_beat + duration`, con altura según pitch
- **Render de nota**: `note.lua` usa `gfx.rect` con fill + border; optimizado con `+1` en width/height para prevenir seams de REAPER GFX (gotcha documentado)

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

### 5.4 Time Selection (ruler → slots)
- Selección de rango en el timeline superior del piano roll
- Rango seleccionado sincroniza con los slots de progresión (afecta qué parte de la progresión se ve/busca)

### 5.5 Hover Highlight Piano Vertical
> 📋 Planificada
> Al pasar el cursor sobre una celda de la grilla del piano roll, se ilumina la nota correspondiente en el teclado vertical izquierdo.

### 5.6 Zoom / Scroll
- **Zoom horizontal**: `scroll_zoom_x`, rango 10–200 px/beat
- **Zoom vertical**: eje Y con culling de filas fuera de viewport
- **Auto-scroll y seguimiento del playhead**:
  - `follow_playhead = true`: el scroll horizontal sigue al cabezal de reproducción
  - **Grace period de 2 segundos**: después de un scroll manual del usuario, el auto-scroll se desactiva temporalmente antes de reenganchar
  - Caché de `ComputeVisibleRanges()` — se recalcula solo cuando cambian los parámetros de scroll/zoom

### 5.7 Snap a grilla
- **Toggle SNAP**: activa/desactiva snap en el grid del piano roll
- **Resolución**: 1/1, 1/2, 1/4, 1/8, 1/16, 1/32
- **Triplet mode**: snap en corcheas de tresillo
- Función pura `snap.SnapBeat(beat, resolution, triplet)` en `core/snap.lua` — sin estado, testeable

### 5.8 Herramientas de edición (Tool Mode)
| Herramienta | Icono | Descripción |
|-------------|-------|-------------|
| **Paint (✎)** | ✎ | Clic para añadir notas, Shift+clic en nota existente para eliminarla |
| **Knife (✂)** | ✂ | Partir notas en dos en el punto de corte |
| **Eraser (⨯)** | ⨯ | Eliminar notas por clic o por lasso |

---

## 6. Piano Roll — Edición de Notas

### 6.1 Añadir / Eliminar / Mover notas
- **Añadir**: Clic en la grilla con herramienta Paint → nota en ese pitch + beat
- **Eliminar**: Shift + clic en nota (Paint), clic directo (Eraser), o lasso multi-select + Delete
- **Mover**: Drag & drop de nota a nueva posición (start beat + pitch)
- **Redimensionar duración**: Drag del borde derecho de la nota (resize edge)

### 6.2 Knife (cortar notas)
- Clic sobre una nota con herramienta Knife → la nota se divide en dos en el punto de corte
- Shortcut de teclado: botón Knife en header o atajo de teclado

### 6.3 Selección múltiple (Lasso)
- Clic + drag sobre área vacía de la grilla → rectángulo de selección
- Todas las notas dentro del rectángulo se seleccionan
- `selected_indices{}` en `island_store` (set de índices para multi-select)
- `GetPrimarySelectedIndex()` retorna el índice más reciente (compat con velocity.lua)
- `SetNotes()` llama `ClearSelection()` automáticamente (índices viejos son inválidos)

### 6.4 Velocity Editor
- **Panel colapsable**: botón toggle en la UI
- **Head circular de edición**: arrastrar el cabezal circular para ajustar la velocidad de la(s) nota(s) seleccionada(s)
- **Delta relativo para multi-selección**: al arrastrar con varias notas seleccionadas, el delta desde el click inicial se aplica a todas, preservando diferencias relativas entre notas
- **Número dinámico sobre cabezal**: muestra el valor de velocidad actual
- **Ajuste a la izquierda**: si el número dinámico choca con el borde de la franja del piano (teclado), se muestra a la derecha

### 6.5 Undo / Redo
- Stack de hasta 50 entradas
- Snapshot de notas antes de cada mutación (note added / removed / moved / resized)
- Shortcuts Ctrl+Z (undo) y Ctrl+Shift+Z (redo) en el piano roll

### 6.6 Clipboard (copiar/pegar)
- Copiar notas seleccionadas al portapapeles interno
- Pegar en nueva posición (manteniendo pitches relativos)
- Atajos: Ctrl+C, Ctrl+V

---

## 7. Preset Browser (Panel Izquierdo)

### 7.1 Funcionalidades
| Feature | Detalle |
|---------|---------|
| Directorios de presets | Navegación por carpetas del sistema de archivos |
| Favoritos | Marcado de directorios favoritos (persistido via ExtState) |
| Búsqueda en tiempo real | Campo de búsqueda que filtra presets mientras se escribe |
| Cross-session refresh | Escaneo automático de presets cada 3 segundos |
| Error banner | Muestra errores de lectura de directorios sin crashear |
| Formato de archivo | `.grove` — archivo Lua serializado via `dofile()` |

### 7.2 Gestion de directorios favoritos
- Agregar/quitar directorios de la lista de favoritos
- Los favoritos se serializan como tabla Lua `{"path1","path2",...}` por `reaper.GetExtState/SetExtState`
- Error handling: `dofile()` envuelto en `pcall` con rollback ante archivos corruptos

---

## 8. Exportación MIDI

### 8.1 ExportToMidi
- Toma la progresión del slot activo y la inserta como item MIDI en la pista seleccionada de REAPER
- Usa `reaper.MIDI_InsertNote`, `MIDI_Sort`, `GetActiveTake`/`SetActiveTake`
- Resuelve notas MIDI desde `midi.GetMidiNote()` con `progression.GetProgressionEntry(i)`
- Cuantiza posiciones a QN (quarter notes) del proyecto

---

## 9. Menú Contextual de Settings

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

---

## 10. Canales MIDI

- Canal MIDI seleccionable de 1 a 16
- Almacenado en `midi_store.GetMidiChannel()` / `SetMidiChannel()`
- Usado por `midi.SendMidi` al empaquetar el byte de canal en el mensaje status

---

## 11. Modulación y Sustain

- **Modulación**: toggle entre off (0) y valor 80 — enviado como CC #1
- **Sustain**: detecta pedal de sustain (Nota MIDI 64), guarda notas activas en tabla `sustain_held_notes`
- Al liberar sustain: envía note-offs a todas las notas sostenidas

---

## 12. Volumen

- **Volumen del secuenciador**: entero 1–127 (default 100)
- Se lee en `midi.SendMidi` como `vol = sequencer_store.GetVolume()`
- Afecta la velocidad de las notas enviadas por el secuenciador

---

## 13. Persistencia de Estado (ExtState)

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

---

## 14. Teclas Rápidas (Keyboard Shortcuts)

### 14.1 QWERTY → Notas MIDI
28 teclas mapeadas (ver Sección 2.1).

### 14.2 Piano Roll — shortcuts globales
| Atajo | Acción |
|-------|-------|
| `Q` | Mostrar menú de cuantización |
| `Delete` | Eliminar nota(s) seleccionada(s) |
| `Ctrl+Z` | Deshacer |
| `Ctrl+Shift+Z` | Rehacer |
| `Ctrl+C` | Copiar notas seleccionadas |
| `Ctrl+V` | Pegar notas del portapapeles |
| `Escape` | Cancelar drag / salir de modo edición |

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
| **Barrel (Re-export)** | Fachada unificada para submódulos | `components.lua` y `compact.lua` — solo 1 `require` por consumer |
| **Lazy require** | Romper ciclos de dependencia | `require("ui.components")` dentro de la función, no al tope del módulo |
| **Event Bus `mouse_click`** | Click de 1 frame, múltiples widgets, un solo consumidor | `ui_store.SetMouseClick()` / `ConsumeMouseClick()` |
| **Temporary Context `temp_ctx`** | Zero-allocation en hot path del teclado | `keyboard.lua` — tabla mutada in-place antes de cada llamada a `TriggerChord` |
| **Consume `mouse_wheel_delta`** | Scroll delta leído una sola vez por widget | `ui_store.ConsumeMouseWheelDelta()` |
| **API Guard** | Validar dependencias opcionales al inicio | `api-guard.lua` — `reaper.APIExists` sobre cada API requerida |
| **Snap Grid (Pure Function)** | Snap a grilla sin estado ni efectos secundarios | `snap.lua` — `SnapBeat(beat, resolution, triplet)` |
| **Undo/Redo Stack** | Deshacer/rehacer ediciones en piano roll | `piano-roll-store.lua` — hasta 50 entradas, UUID por nota |
| **Lasso Selection** | Selección multi-nota por rectángulo | `island_store` — `lasso_active`, `lasso_start_*`, `lasso_end_*` |
| **Dual Context (Main + Compact)** | Dos contextos GFX independientes | `main.lua` (full) + `compact-init.lua` (compact) — cada uno con su propio `gfx.mouse_wheel` |
| **Auto-scroll Grace Period** | Evitar conflicto entre scroll manual y auto-scroll | 2 segundos de gracia después de scroll manual antes de reenganchar el seguimiento del playhead |

---

## 16. Issues Resueltos

| Issue | Archivo(s) | Resumen |
|-------|-----------|---------|
| #1 | `dropdown.lua` | Scroll wheel en dropdowns funcionando correctamente |
| #2 | `slots.lua` | Slots renderizados correctamente — 4 llamadas a SetSlot son necesarias por frame |
| #3 | `views.lua`, `positions.lua` | Ubicación de ventana corregida: slots ahora después de la barra de progreso |
| #4 | `keyboard.lua` | Arreglado problema de distribución al colocar pads en slots: slots page reset a P1 al colocar el primer pad |
| #5 | `pads.lua` | Release pad-held notes only when drag starts |
| #6 | `views.lua` | U+25C4 glyph support for undock button — reemplazado con `gfx.triangle` |
| #7 | `compact-init.lua` | Transport window find — SWS fallback chain |
| #8 | `views.lua`, `main.lua` | DecrementPageOverrideTimer en ALL modes (incluyendo Docked) |
| #9 | `views.lua` | Octave dropdown rendering — `oct_open_up` dinámico |
| #10 | `positioning.lua` | Invalidate auto-position cache on transport resize |
| #11 | `views.lua` | Fixed tooltip positioning for chord buttons with offset=0 status_text_y |
| #12 | `keyboard.lua` | Reusable `temp_ctx` table — zero-allocation en hot path |
| #13 | `piano.lua` | Cached `active_mod12` — evita recomputar cada frame |
| #14 | `views.lua` | Add name comparison (`ne`) to main scale menu style picker in QUICK_SWITCH |
| #15 | `keyboard.lua` | Velocity humanization: `85 + math.random(30)` |
| #16 | `checkbox.lua` | Change toggle icon glyph from '>' to '✓' |
| #17 | `dropdown.lua` | Rework mouse wheel handling — mouse_wheel sniff test with frame separation detection |
| #18 | `piano.lua` | O(N·M) inner loop → O(1) via pre-computed pitch-class set |
| #19 | `sequencer.lua` | Cache `GetLastFilled()` una sola vez por tick |
| #20 | `piano.lua`, `views.lua` | Piano chord tones: always show chord tones highlighting from progression |
| #21 | `keyboard.lua` | Velocity humanization activada: `85 + math.random(30)` |
| #22 | `views.lua` | Stuck note en play/stop toggle — `sequencer.Stop()` envía note-offs explícitos |

---

## 17. Features Planificadas / Pendientes

| # | Feature | Prioridad | Estado |
|---|---------|-----------|--------|
| F01 | **Documento de features** — este mismo archivo | Alta | 🚧 En progreso |
| F02 | Actualizar AGENTS.md para referenciar este documento | Alta | 🚧 En progreso |
| F03 | Refactor SPDX headers (49 archivos stale) | Baja | 📋 pendiente |
| F04 | Persistir `view_offset_x/y` para no perder posición al reiniciar REAPER | Media | 📋 pendiente |

---

## 18. Bugs Conocidos / Pendientes de Fix

| # | Bug | Área | Estado |
|---|-----|------|--------|
| B01 | Scrollwheel en dropdowns requiere múltiples clics y a veces salta números | `dropdown.lua` | 🐛 Pendiente |
| B02 | Subdivisión de slots: cambiar de Tri → 9na no se aplica, piano roll no refleja el cambio | `slots.lua`, piano roll | 🐛 Pendiente |
| B03 | Clic derecho elimina ambos pads en slot subdividido (debería eliminar solo el seleccionado) | `slots.lua` | 🐛 Pendiente |
| B04 | Número del pad en esquina superior izquierda no se ve | `slots.lua` (color/contraste) | 🐛 Pendiente |
| B05 | Scrollwheel en subdivisión de slot: comportamiento inconsistente (debería cambiar entre subs, no paginar) | `slots.lua` | 🐛 Pendiente |
| B06 | Zoom vertical estrecho: notas negras (líneas de texto) dejan de apreciarse | `piano-roll/note.lua` | 🐛 Pendiente |
| B07 | Zoom vertical deforma bordes inferiores de notas (~1px hacia adentro) | `piano-roll/note.lua` | 🐛 Pendiente |
| B08 | Notas en borde inferior: scroll causa deformación por culling strategy | `piano-roll/view.lua` | 🐛 Pendiente |
| B09 | Notas pegadas a barra de velocity al dibujar cerca del borde inferior | `velocity.lua` | 🐛 Pendiente |
| B10 | CH button: posición invertida de botones Tri/7ma/9na | `midi-island/header.lua` | 🐛 Pendiente |
| B11 | Ctrl + drag izquierdo no activa lasso (debería ser selección por rectángulo) | `midi-island/input.lua` | 🐛 Pendiente |
| B12 | Redimensionar ventana FULL: auto-zoom/scroll del piano roll no se reajusta | `midi-island.lua` | 🐛 Pendiente |
| B13 | Isla inversión no sincroniza cambios al piano roll | `island_store`, `note-store.lua` | 🐛 Pendiente |
| B14 | Panel de presets: bugs sin especificar (necesita investigación) | `preset-browser/` | 🐛 Pendiente |
| B15 | Botón X al lado de Cut para eliminar notas (no existe actualmente) | `midi-island/header.lua` | 📋 Planificada |
| B16 | Botón Quantize con popup de 3 knobs (start/duration/strength) | `quantize-popup.lua` (nuevo) | 📋 Planificada |
| B17 | Botón SYNC en header isla MIDI: sincronizar cabezal de reproducción al cabezal de REAPER | `midi-island/header.lua` | 📋 Planificada |
| B18 | Mover botón Autoscroll al header de isla MIDI (actualmente en compact bar) + rediseño | `midi-island/header.lua` | 📋 Planificada |
| B19 | Mover botón CH desde header isla MIDI a submenú contextual de Settings | `views/header.lua` | 📋 Planificada |
| B20 | Subdivisión de slots: mostrar círculo rojo con X en esquina inferior derecha del slot para eliminar todos los pads | `slots.lua` | 📋 Planificada |
| B21 | Time selection en piano roll ruler → sincroniza con slots | `timeline.lua`, `piano-roll/store`, `slots.lua` | 📋 Planificada |
| B22 | Hover highlight: nota del piano vertical se ilumina al pasar cursor por grilla | `piano-roll/view.lua`, `piano.lua` | 📋 Planificada |
| B23 | Vista compacta: renderizada muy a la derecha (solapando controles REAPER) + no reposiciona | `compact-bar.lua`, `positioning.lua` | 📋 Planificada |
