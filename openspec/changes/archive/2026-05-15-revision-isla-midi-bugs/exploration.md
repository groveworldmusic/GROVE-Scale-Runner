## Exploration: Revisión a fondo de la isla MIDI — bugs y errores

### Current State

La isla MIDI es un componente UI expandible dentro de GROVE FL MIDI. Se compone de:

- **Orquestador**: `src/ui/midi-island.lua` (385 LOC) — layout, rendering, scrollbars, preset panel
- **Header**: `src/ui/midi-island/header.lua` (268 LOC) — controles de snap, tool mode, MIDI CH, PRESETS toggle, RELOAD/SYNC
- **Input dispatcher**: `src/ui/midi-island/input.lua` (437 LOC) — mouse y keyboard dispatch por tool mode
- **Piano roll**: `src/ui/piano-roll/` (6 sub-módulos + barrel) — grid, notas, interacción, coordenadas, undo, clipboard, knife
- **Velocity editor**: `src/ui/velocity.lua` — bars de velocity con drag editing
- **Timeline**: `src/ui/timeline.lua` — ruler con measure/beat ticks y playback head
- **State**: `src/state/island.lua` + `src/state/note-store.lua` — estado del island y notas via note-store delegado

**Layout de la isla MIDI expandida** (midi-island.lua lines 185-210):

```
┌─────────────────────────────────────────────────────┐
│                      HEADER                         │
├──────┬──────────────────────────────────────────────┤
│      │               TIMELINE (30px)                │
│PRE-  ├──────────────────────────────────────────────┤
│SET   │   PIANO ROLL GRID + NOTES                   │
│PANEL │                                              │
│(0 o  │                                              │
│220px)│                                              │
│      ├──────────────────────────────────────────────┤
│      │           VELOCITY EDITOR                    │
│      ├──────────────────────────────────────────────┤
│      │     H-SCROLL  |  V-SCROLL                    │
└──────┴──────────────────────────────────────────────┘
```

Canvas virtual: 39914×29162, escalado a ~720px de ancho. `PITCH_LABEL_W = 48px` para la tira de teclas vertical. `SB_SIZE = 7px` para scrollbars.

### Affected Areas

| Archivo | LOC | Por qué está afectado |
|---------|-----|----------------------|
| `src/ui/piano-roll/note.lua` | 317 | **BUG #1**: No hay X clipping en DrawNoteBlocks ni ghost rendering — notas se dibujan fuera de la grilla |
| `src/ui/piano-roll/view.lua` | 60 | **BUG #2**: ComputeVisibleRanges recibe `w` incluyendo LABEL_W, sobrestimando beats visibles |
| `src/ui/piano-roll/grid.lua` | 579 | **BUG #3**: Measure lines pueden overflow 1-2px a la derecha; keyboard strip no usa ref-counted notes |
| `src/ui/velocity.lua` | 485 | **BUG #4**: Velocity bars no tienen X clipping — mismo problema que notes |
| `src/ui/midi-island.lua` | 385 | **BUG #5**: `_focus_pending` es global (falta `local`); layout inconsistencia potencial |
| `src/ui/timeline.lua` | 203 | **BUG #6**: `grid_x` redeclarado dos veces en DrawTimelineRuler (code smell) |
| `src/ui/midi-island/input.lua` | 437 | Input dispatching — revisado, no se encontraron bugs de clipping aquí |
| `src/state/note-store.lua` | 502 | `goto continue` pattern revisado — correcto, no es bug |
| `src/state/island.lua` | 413 | Getters/setters — revisados, correctos |

### Bugs Found

#### CRITICAL

**BUG #1 — No X clipping en DrawNoteBlocks (scroll overflow)**
- **Archivo**: `src/ui/piano-roll/note.lua`, líneas 196-208
- **Descripción**: El loop de rendering de notas verifica Y clipping (`ny < y + h and ny + nh > y`) pero NO X clipping. Una nota cuya posición pixel X (`nx`) esté por izquierda del `grid_x` (tira de teclas) o cuya posición `nx + nw` esté por derecha de `grid_x + grid_w` (scrollbar vertical) se dibuja igual. GFX no tiene viewport clipping automático — se pinta sobre toda la ventana.
- **Impacto**: Notas MIDI se dibujan sobre la tira de teclas (izquierda) y sobre el scrollbar/background general (derecha). Este es EL bug reportado por el usuario.
- **Evidencia**: `note.lua` lines 196-208 — el `if` solo checkea `ny < y + h and ny + nh > y`, no hay `nx >= x` ni `nx + nw <= x + w`.

**BUG #2 — ComputeVisibleRanges usa w total, no grid_w (sobrestimación de beats)**
- **Archivo**: `src/ui/piano-roll/view.lua` line 36, `src/ui/piano-roll/grid.lua` line 99
- **Descripción**: `view.lua` llama `ComputeVisibleRanges(y, h, scroll_y, scroll_x, zoom_x, w)` donde `w` es el ancho total del piano roll (incluyendo LABEL_W). La función usa `w` para calcular `beat_end = scroll_x + math.ceil((w or 0) / zoom_x) + 1`. Pero el área dibujable real es `grid_w = w - LABEL_W`. A zoom por defecto (28px/beat), esto son ~1.7 beats extra. A zoom 10px/beat: ~4.8 beats extra procesados pero invisibles. Esos beats extras terminan renderizando notas fuera del grid.
- **Impacto**: Agrava BUG #1 — más notas de las necesarias se consideran "visibles" y se renderizan sin X clipping.

**BUG #3 — No X clipping en ghost rendering (drag)**
- **Archivo**: `src/ui/piano-roll/note.lua`, líneas 172-181
- **Descripción**: Los ghosts semi-transparentes durante drag/resize tampoco tienen X clipping. Mismo problema que BUG #1.
- **Impacto**: Durante drag de notas, los ghosts aparecen fuera del grid.

**BUG #4 — No X clipping en velocity bars**
- **Archivo**: `src/ui/velocity.lua`, líneas 212-228
- **Descripción**: Las velocity bars en el editor de velocity tampoco tienen X clipping. `nx` puede ser negativo o exceder `grid_x + grid_w`.
- **Impacto**: Velocity bars se dibujan fuera del grid.

#### HIGH

**BUG #5 — `_focus_pending` es global (falta `local`)**
- **Archivo**: `src/ui/midi-island.lua`, líneas 174, 181, 213, 214
- **Descripción**: Las variables `_focus_pending = true` en líneas 174 y 181, y `if _focus_pending then` / `_focus_pending = false` en líneas 213-214, NO tienen declaración `local`. Son variables globales que contaminan el namespace global de Lua. Otras variables del mismo módulo (`_saved_zoom_x`, `_pending_zoom_target`) SÍ tienen `local`.
- **Impacto**: Potencial conflicto con otros módulos. Podría causar auto-focus espurio si otro módulo escribe a `_focus_pending`.

**BUG #6 — Measure lines overflow 1-2px a la derecha**
- **Archivo**: `src/ui/piano-roll/grid.lua`, línea 427
- **Descripción**: `gfx.rect(bx, y, 2, h, 1)` dibuja medida lines de 2px de ancho. El check previo es `bx >= x and bx <= x + w`, pero si `bx = x + w - 1`, el rectángulo se extiende 1px más allá de `x + w`.
- **Impacto**: Artefacto visual menor en el borde derecho de la grilla.

#### MEDIUM

**BUG #7 — Keyboard strip no usa ref-counted active notes**
- **Archivo**: `src/ui/piano-roll/grid.lua`, líneas 291-321
- **Descripción**: La tira de teclas vertical envía MIDI note-on/off directamente via `midi.SendMidi()`, sin pasar por el sistema de ref-counted de `midi_store.SetActiveNote()`. Si la misma nota es disparada por QWERTY o pads, un note-off desde la tira de teclas descuenta mal el contador.
- **Impacto**: Posibles stuck notes si se combinan triggers. Baja probabilidad porque la tira de teclas es un input secundario.

**BUG #8 — grid_x redeclarado en DrawTimelineRuler**
- **Archivo**: `src/ui/timeline.lua`, líneas 181 y 195
- **Descripción**: `local grid_x` se declara dos veces en la misma función. Lua permite shadowing, pero es confuso y sugiere que hubo una refactorización incompleta.
- **Impacto**: Cero funcional. Code smell.

**BUG #9 — OCTAVE_BUFFER = 12 causa procesamiento redundante**
- **Archivo**: `src/ui/piano-roll/grid.lua`, línea 26
- **Descripción**: `m.OCTAVE_BUFFER = 12` extiende el rango de pitches visibles en 12 filas arriba y abajo del viewport. A `PITCH_ROW_H = 24px`, son 288px de filas procesadas pero no visibles por frame.
- **Impacto**: Rendimiento ligeramente menor en cada frame. No causa bugs visuales.

#### LOW

**BUG #10 — `beat_start` no clamp bound inferior para negative beats**
- **Archivo**: `src/ui/piano-roll/grid.lua`, líneas 97-99
- **Descripción**: `beat_start = scroll_x - 1` permite beats negativos si `scroll_x = 0`. Aunque los checks `bx >= x` evitan dibujo, el loop itera sobre beats negativos innecesariamente.
- **Impacto**: Minúsculo overhead de rendimiento.

**BUG #11 — `min_grid_step` usado para filtrar beat lines**  
- **Archivo**: `src/ui/piano-roll/grid.lua`, líneas 407-419
- **Descripción**: La lógica de filtrado de subdivision lines usa `min_grid_step` comparado con 1.0/2.0/4.0, pero `min_grid_step = 4 / snap_res` puede ser valores no exactos (ej. snap_res=3 no existe en el menú pero no está validado).
- **Impacto**: Sub-grid lines podrían no filtrarse correctamente con snap_resolutions no estándar. Baja probabilidad.

### Approaches

#### Para el scroll clipping bug (BUG #1 + BUG #2):

1. **X clipping en note rendering + velocity** (mínimo esfuerzo)
   - Agregar `nx + nw > x and nx < x + w` en DrawNoteBlocks, ghost rendering, y velocity bars
   - No tocar ComputeVisibleRanges
   - **Pros**: Simple, localizado, riesgo mínimo, arregla el síntoma
   - **Cons**: No arregla la causa raíz (sobrestimación de beats), sigue procesando notas innecesarias
   - **Effort**: Bajo (~15 líneas en 3 archivos)

2. **Corregir ComputeVisibleRanges** (causa raíz)
   - Pasar `grid_w` en vez de `w` a ComputeVisibleRanges, o ajustar beat_end para usar `(w - LABEL_W) / zoom_x`
   - **Pros**: Arregla la causa raíz, menos procesamiento innecesario
   - **Cons**: No es suficiente solo — sin X clipping, notas en el borde aún podrían overflow por sub-pixel offset
   - **Effort**: Bajo (~3 líneas)

3. **Combinado: X clipping + ComputeVisibleRanges corregido** (RECOMENDADO)
   - Arreglar ComputeVisibleRanges para usar grid_w como ancho real
   - Agregar X clipping en note rendering, ghost rendering, y velocity bars como belt-and-suspenders
   - **Pros**: Arregla causa raíz Y previene cualquier overflow futuro
   - **Cons**: Mínimo — toca 4 archivos
   - **Effort**: Bajo (~20 líneas en total)

### Recommendation

**Approach 3 (Combinado)**. Es la solución correcta por varias razones:

1. **Arregla la causa raíz**: ComputeVisibleRanges no debe sobrestimar beats visibles. El ancho real de dibujo es `grid_w`, no `w`.
2. **Prevención**: X clipping como safety net previene cualquier overflow futuro, incluso si cambian los cálculos de beat range.
3. **Consistencia**: El Y clipping ya existe como patrón en DrawNoteBlocks — el X clipping es la contraparte faltante para completar el patrón.

### Risks

- **Riesgo bajo**: Los cambios son puramente en rendering (visual), no tocan lógica de estado, MIDI, ni interacción. No deberían introducir regresiones funcionales.
- **Riesgo de rendimiento mínimo**: Agregar checks de X clipping es O(1) por nota — negligible comparado con el costo de dibujar la nota.
- **Riesgo de overclipping**: Si los bounds de X clipping son muy restrictivos, notas parcialmente visibles en el borde izquierdo/derecho podrían desaparecer abruptamente. Solución: usar `math.max(x, nx)` para `nx` y `math.min(x + w, nx + nw)` para el ancho, igual que el Y clipping actual.

### Ready for Proposal

**Sí** — el análisis está completo. Los bugs están identificados con archivo, línea, severidad, y evidencia. El approach recomendado tiene effort bajo y riesgo mínimo.

### Next Recommended Phase

`sdd-propose` — para formalizar el alcance y enfoque de cada fix en una propuesta.

---

### Resumen de bugs priorizados para la propuesta

```
CRITICAL (debe arreglarse ahora):
  B1: No X clipping en DrawNoteBlocks (scroll overflow reportado)
  B2: ComputeVisibleRanges sobrestima beats visibles
  B3: No X clipping en ghost rendering
  B4: No X clipping en velocity bars

HIGH (debe arreglarse ahora):
  B5: _focus_pending es global (falta local)
  B6: Measure lines overflow 1-2px derecha

MEDIUM (considerar):
  B7: Keyboard strip no usa ref-counted notes
  B8: grid_x redeclarado en timeline.lua
  B9: OCTAVE_BUFFER = 12 procesamiento redundante

LOW (postergar):
  B10: beat_start sin clamp para beats negativos
  B11: min_grid_step con snap_resolutions no estándar
```
