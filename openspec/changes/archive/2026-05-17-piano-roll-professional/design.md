# Design: Piano Roll Professional — Fase 1 (Editing UX Core)

## Technical Approach

4 features implementadas concurrentemente sobre la arquitectura existente: auto-scroll, quantize, Alt+drag clone, y tool switching+audition. Cada feature toca un subconjunto disjunto de módulos — sin acoplamiento entre features. La única superposición es `undo.lua` (recibe nuevo type "quantize") y `input.lua` (recibe tool "eraser" + Alt detection). Se persigue cero cambios en core/* salvo llamar `midi.SendMidi` para audition.

## Architecture Decisions

### Decision: Auto-scroll en island_state vs módulo-local

| Opción | Tradeoffs |
|--------|-----------|
| `island_store` flag + timer | Persiste entre frames, accesible desde input (para resetear timer en scroll manual). Timer como local en midi-island.lua — no necesita persistir. |
| `midi-island.lua` module-local only | Timer y flag viven en closure. Flag se pierde al toggle island (gfx.quit/reinit). |

**Decisión**: `follow_playhead` en `island_store` (getter/setter). Timer local `_auto_scroll_timer` en `midi-island.lua` — resetea en cada `SetScrollOffsetX` detectada manual. Toggle button en timeline ruler.

### Decision: Quantize como módulo puro separado

| Opción | Tradeoffs |
|--------|-----------|
| En `note-store.lua` | Mezcla lógica de dominio con CRUD. Añade dependencia a snap.lua desde un store. |
| En `ui/piano-roll/quantize.lua` | Sigue patrón barrel. Función pura que toma notas por referencia. Fácil de testear aislada. |

**Decisión**: `src/ui/piano-roll/quantize.lua`. `QuantizeNotes()` muta las notas in-place, llama `note_store.PushUndo()` con type `"quantize"`. Reusa `snap.SnapBeat` para target grid.

### Decision: Alt+drag detection en drag.lua

| Opción | Tradeoffs |
|--------|-----------|
| Detectar Alt en `StartNoteDrag` | Captura en el momento exacto de iniciar drag. gfx.mouse_cap & 16 disponible. |
| Detectar en `input.lua` y pasar flag | Añade parámetro a toda la cadena de drag. Propagación innecesaria. |

**Decisión**: `StartNoteDrag` checkea `gfx.mouse_cap & 16 == 16` al inicio. Si Alt held: salta a `_StartCloneDrag()` que copia notas y las inserta como nuevas.

## Data Flow

```
Auto-scroll:
  sequencer_store.GetIsPlaying() ──→ midi-island.lua Draw()
    → if follow_playhead && is_playing → clamp scroll_x
    → playhead in [scroll_x + visible/3, scroll_x + 2*visible/3]
    → grace timer reset on user scroll (input.lua wheel/scrollbar)

Quantize:
  Ctrl+Q (shortcuts.lua) ──→ quantize.QuantizeNotes(selected, strength, swing, snap)
    → for each note: snapped = SnapBeat(beat), new_beat = beat + (snapped - beat)*strength
    → swing offset on floor(beat) % 2 == 1
    → note_store.PushUndo({type="quantize", ...})

Alt+drag:
  drag.lua StartNoteDrag()
    → gfx.mouse_cap & 16? → TODO: copy notes → insert at delta pos → push "add" undo
    → gfx.mouse_cap & 16? no → existing move path

Tool switching + auditions:
  gfx.getchar() 49/50/51 (shortcuts.lua) → island_store.SetToolMode("paint|knife|eraser")
  input.lua eraser mode → left click = handlers.HandlePaintRightClick (delete)
  handlers.HandlePaintClick → after create: midi.SendMidi(pitch, true, 100) + reaper.defer(50ms note-off)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/piano-roll/quantize.lua` | **Create** | Pure quantize module: `QuantizeNotes(selected_indices, strength, swing, snap_res, snap_trip) → void` |
| `src/state/island.lua` | Modify | 4 new getter/setter pairs + snap_triplet init |
| `src/ui/piano-roll/undo.lua` | Modify | Add `"quantize"` type handlers in RestoreUndo/RestoreRedo |
| `src/ui/piano-roll/interaction/shortcuts.lua` | Modify | Add Ctrl+Q (337), tool switch keys (49,50,51) |
| `src/ui/piano-roll/interaction/handlers.lua` | Modify | Add note audition after note create/click in HandlePaintClick |
| `src/ui/piano-roll/interaction/drag.lua` | Modify | Add Alt+drag clone path in StartNoteDrag |
| `src/ui/midi-island.lua` | Modify | Auto-scroll clamp + grace timer in Draw(), around line 205 |
| `src/ui/midi-island/input.lua` | Modify | Add eraser tool dispatch + Alt scroll reset |
| `src/ui/timeline.lua` | Modify | Add auto-scroll toggle button near "BEATS" label |
| `src/ui/piano-roll/interaction.lua` | Modify | Re-export QuantizeNotes |
| `src/ui/piano-roll.lua` | Modify | Re-export QuantizeNotes via barrel |

## Interfaces / Contracts

### New: `src/ui/piano-roll/quantize.lua`

```lua
-- Quantize selected notes with strength, swing, and snap grid.
-- Mutates notes in-place. Pushes single undo entry on completion.
-- @param selected_indices table {[idx] = true} — which notes to quantize
-- @param strength number 0.0-1.0 (1.0 = perfect snap, 0.5 = half-way)
-- @param swing number 0.0-0.5 (offset fraction for even quarter-beats)
-- @param snap_res number subdivision per whole note (0,1,2,4,8,16)
-- @param snap_trip boolean triplet mode
-- @return number count of notes quantized
function QuantizeNotes(selected_indices, strength, swing, snap_res, snap_trip) → void
```

### New: island_store getter/setters

```lua
-- Auto-scroll
function m.GetFollowPlayhead() → boolean
function m.SetFollowPlayhead(v) → void

-- Quantize parameters
function m.GetQuantizeStrength() → number  -- 0..100 persisted as integer
function m.SetQuantizeStrength(v) → void
function m.GetQuantizeSwing() → number  -- 0..50 persisted as integer
function m.SetQuantizeSwing(v) → void
```

Default values: `follow_playhead = true`, `quantize_strength = 100`, `quantize_swing = 0`.

### New undo type: `"quantize"`

```lua
{
  type = "quantize",
  note_uuids = {uuid1, uuid2, ...},     -- All quantized notes
  prev_state = {{start_beat = old1}, ...}, -- Pre-quantize start_beats
  new_state = {{start_beat = new1}, ...},  -- Post-quantize start_beats
}
```

### Tool mode enum update

```lua
"paint" | "knife" | "eraser"   -- existing: paint + knife only
```

### Auto-scroll toggle button

Dibujado en `timeline.lua DrawTimelineRuler()` junto al label "BEATS". Icono vectorial: un símbolo de play/follow (triángulo con línea horizontal o un ojo). Toggle state visual: filled (on) vs outlined (off). Click handler via `ui_store.GetMouseClick()` + hit-test.

## GFX-specific Considerations

1. **Alt detection**: `gfx.mouse_cap & 16 == 16` en `drag.lua StartNoteDrag`. No hay estado "Alt held" frame-a-frame — se lee en el momento. gfx.mouse_cap se actualiza sincrónicamente.

2. **Note audition timing**: `reaper.defer(function() midi.SendMidi(pitch, false, 0) end)` — el note-off se programa para el SIGUIENTE frame (~30ms), no exactamente 50ms. REAPER no tiene timer preciso en GFX. ~1 frame es suficiente para preview audible.

3. **Auto-scroll smooth interpolation**: `lerp(current_scroll, target_scroll, 0.3)` por frame (~3 frames para 90% del recorrido). Sin `tween` libraries — GFX no las soporta. Interpolación lineal frame-a-frame vía closure local.

4. **Grace timer**: `_auto_scroll_timer = os.clock() + 2.0` — se resetea en input.lua cuando detecta scroll manual (mouse wheel delta !== 0, scrollbar drag, arrow nudge). Se verifica en midi-island.lua Draw() antes del clamp.

5. **Eraser tool mode**: Se agrega `"eraser"` a tool_mode. En input.lua, dentro del bloque `if tool_mode == "paint"` ... `elseif tool_mode == "knife"` se agrega `elseif tool_mode == "eraser"`. Eraser left-click → `HandlePaintRightClick()` (misma función que delete via right-click). No hay ghost ni drag en eraser mode — solo click-to-delete.

6. **Audition bypasses ref-count**: Las notas de audition NO se registran en `midi_store.SetActiveNote()`. Solo se llama `reaper.StuffMIDIMessage(0x90)` directamente + schedule de 0x80. Esto evita stuck notes si el note-off schedule falla (REAPER send all notes off en script stop).

## Undo/Redo Strategy

| Operación | Undo type | Datos guardados | Restore strategy |
|-----------|-----------|-----------------|------------------|
| Quantize | `"quantize"` | prev_state: pre-quantize start_beats. new_state: post-quantize start_beats. | RestoreUndo: retrocede a prev_state. RestoreRedo: avanza a new_state. |
| Alt+drag clone | `"add"` | new_state: cloned notes completos (pitch, beat, duration, vel, muted, uuid) | RestoreUndo: remove by uuid. RestoreRedo: re-insert. |
| Note audition | — | Ninguno. No es operación editable. | No aplica. |
| Tool switch | — | Ninguno. Estado efímero. | No aplica. |
| Auto-scroll toggle | — | Ninguno. Solo flag de UI. | No aplica. |

**Patrón de undo para quantize**: mismo formato que `"move"` (uuids + prev/new_state arrays), pero con type `"quantize"` para etiquetado en UI de undo stack (futuro). La lógica de restauración es idéntica a `"move"`.

## Risk Mitigation

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Auto-scroll flicker por cambio abrupto de scroll_x | Low | Smooth interpolation + grace period. Clamp solo cuando playhead sale del middle-third. |
| Grace timer race: scroll manual + auto-scroll mismo frame | Low | Timer se checkea AL INICIO de Draw(), scroll manual se detecta en input.HandleMouse() que corre ANTES en el mismo frame. Si ambos ocurren en el mismo frame, el clamp ve timer > now y skips. |
| Note audition schedule perdido si script se cierra | Low | REAPER envía All Notes Off automáticamente al cerrar script. Auditoría no persiste en active_notes. |
| Alt+drag en multi-selección con notas de distinta duración | Low | El clone copia `pitch, start_beat, duration, velocity, muted` exactas de cada nota. Multiplicar por delta es semánticamente correcto. |
| Quantize sin notas seleccionadas | None | No-op temprano: `if not next(selected) then return 0 end` — safe. |
| Eraser tool no debe tener right-drag sweep | Low | El dispatch de eraser en input.lua solo maneja left-click. Right-drag sweep sigue en paint mode (no dispatch para eraser). |
