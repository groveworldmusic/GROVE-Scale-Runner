## Exploration: Separar estado global en stores (Phase 3d)

### Current State

Todo el estado global vive en `config.state.*` como una tabla plana en `src/config.lua`. **375 referencias** en toda la codebase repartidas en **13 archivos .lua** (src/core/*.lua y src/ui/*.lua).

Actualmente hay 6 sub-tables anidadas (`drag`, `sequencer`, `compact`, `mouse_pad_state`, `pad_flash`, `slot_flash`, `key_states`) pero el acceso sigue siendo `config.state.drag.is_dragging` — el namespace `config.state` es el único punto de acoplamiento.

---

### Key Inventory — Tabla completa

#### Keys planas en `config.state`

| Clave | Tipo | Escritores | Lectores | Total refs | Dominio propuesto |
|-------|------|------------|----------|-----------|-------------------|
| `root_index` | number | compact-menu, piano.lua, views.lua | pads, piano, compact-bar, compact-init, compact-menu, views, drag, slots, keyboard, midi | 18 | **root** (se queda) |
| `scale_index` | number | compact-init, compact-menu, views.lua | pads, piano, compact-bar, compact-init, compact-menu, views, drag, slots, keyboard, midi | 18 | **root** (se queda) |
| `octave` | number | compact-init, compact-menu, views.lua | compact-bar, compact-init, compact-menu, views, drag, slots, keyboard | 16 | **root** (se queda) |
| `chord_mode_index` | number | compact-init, compact-menu, views.lua | compact-bar, compact-init, compact-menu, views, drag, slots, keyboard | 15 | **root** (se queda) |
| `use_velocity` | boolean | compact-init, views.lua | compact-init, views, keyboard | 9 | **midi** |
| `last_note_played` | string | midi.lua | compact-bar, views.lua | 3 | **midi** |
| `active_note_draw_timer` | number | main.lua, midi.lua | main.lua, compact-bar | 4 | **midi** |
| `key_states` | table | config.lua (init), keyboard | pads, midi, keyboard | 4 | **midi** |
| `mouse_pad_state` | table | pads, midi | pads, midi | 13 | **midi** |
| `active_notes` | table | midi.lua | midi, piano | 7 | **midi** |
| `view_mode` | number | compact-init, compact-menu | main, compact-init, compact-menu | 9 | **ui** |
| `use_scroll` | boolean | views.lua | views, dropdown | 5 | **ui** |
| `show_tooltips` | boolean | views.lua | views, helpers, paginator | 3 | **ui** |
| `color_mode` | string | views.lua | views, colors | 3 | **ui** |
| `last_mouse_cap` | number | main.lua | main, slots | 2 | **ui** |
| `mouse_click` | boolean | main, compact-init | main, compact-init, views, buttons, dropdown, paginator, piano | 24 | **ui** |
| `mouse_wheel_delta` | number | main, compact-init, views, dropdown | views, dropdown | 9 | **ui** |
| `view_offset_x` | number | compact-init, views | main, compact-menu, views | 8 | **root/ui** |
| `view_offset_y` | number | compact-menu, views | main, compact-menu, views | 4 | **root/ui** |
| `auto_start_compact` | boolean | main, views | main, views | 5 | **ui** |
| `auto_start_reaper` | boolean | main, views | main, views | 5 | **ui** |
| `docked_mode` | boolean | main, views | main, midi | 9 | **ui** |
| `dock_id` | number | main, views | main | 10 | **ui** |
| `did_cleanup` | boolean | main.lua | main.lua | 5 | **ui** |
| `slider_dragging` | boolean | views.lua | pads, slots, views | 3 | **ui** |
| `pad_flash.*` | table | pads.lua | pads.lua | 9 | **ui** |
| `page_override_timer` | number | views.lua | views.lua | 3 | **sequencer** |
| `current_page` | number | paginator, sequencer, views | paginator, views | 11 | **sequencer** |

#### Sub-tables (ya agrupadas)

| Sub-tabla | Claves internas | Total refs | Escritores | Lectores | Dominio propuesto |
|-----------|----------------|-----------|------------|----------|-------------------|
| `drag.*` | is_dragging(34), source_degree(10), source_slot_idx(11), pending_degree(6), pending_slot_idx(8), start_x(4), start_y(2) | **62** | drag, pads, slots | drag, pads, slots, buttons, views | **drag** |
| `sequencer.*` | is_playing(7), current_step(5), last_measure(6), midi_notes(5), progress(3), internal_beats(4), last_time(6), volume(4) | **38** | sequencer, views | sequencer, slots, views, midi | **sequencer** |
| `compact.*` | transport_hwnd(2), lice_bitmap(1), lice_font(0), gdi_font(0) | **15** | compact-init, lice | compact-init, compact-intercept, compact-bar, positioning, lice | **compact** |
| `progression[]` | (array indexed access) | **15** | progression, sequencer | progression, midi, drag, slots, sequencer | **sequencer** |
| `slot_flash.*` | idx(1), timer(1) | 3 | progression, slots | slots | **sequencer** |
| `last_gfx_state` | dock, x, y, w, h | 3 | compact-init | compact-init, midi | **compact** |
| `compact_overlay_active` | boolean | 5 | compact-init | main, compact-init | **compact** |

---

### Análisis de Riesgo por Clave

#### Claves MÁS referenciadas (top 10)

| # | Clave | Ref count | Peligro |
|---|-------|-----------|---------|
| 1 | `drag.*` (total) | 62 | ⚠️ ALTO — 5 archivos lectores, 3 escritores |
| 2 | `sequencer.*` (total) | 38 | ⚠️ MEDIO — mayormente en sequencer.lua |
| 3 | `mouse_click` | 24 | 🔴 CRÍTICO — 2 escritores, 7 lectores en UI y pads |
| 4 | `root_index` | 18 | 🔴 CRÍTICO — lectura ubicua en toda la codebase |
| 5 | `scale_index` | 18 | 🔴 CRÍTICO — lectura ubicua en toda la codebase |
| 6 | `octave` | 16 | 🔴 CRÍTICO — lectura ubicua en toda la codebase |
| 7 | `chord_mode_index` | 15 | 🔴 CRÍTICO — lectura ubicua en toda la codebase |
| 8 | `compact.*` + `progression` | 15 c/u | ⚠️ MEDIO — bounded a 4-5 archivos |
| 9 | `mouse_pad_state.*` | 13 | ⚠️ MEDIO — solo pads y midi |
| 10 | `current_page` + `dock_id` | 11/10 | ✅ BAJO |

#### Claves con más escritores vs lectores

| Clave | Writers | Readers | Desbalance |
|-------|---------|---------|-----------|
| `mouse_click` | 2 (main, compact-init) | 22+ (7 archivos) | 🔴 Casi todo lee, pocos escriben |
| `root_index` | 3 | 10+ archivos | 🔴 Muchos lectores, escritores concentrados |
| `octave` | 3 | 8 archivos | 🔴 Similar a root_index |
| `sequencer.volume` | 1 (views) | 3 (sequencer, views, midi) | ⚠️ Escritor es UI, lector es core |
| `drag.is_dragging` | 4 | 5 archivos | ⚠️ Reset en drag cleanup pero escrito en pads/slots |

#### Claves con lectores/escribientes DISTANTES

| Clave | Escrito en | Leído en | Distancia |
|-------|-----------|----------|-----------|
| `sequencer.volume` | views.lua (UI) | midi.lua (core) | core depende de UI para volumen |
| `mouse_pad_state.midi_notes` | pads.lua | midi.lua (TriggerAllOff) | UI escribe, core lee para cleanup |
| `docked_mode` | main.lua, views.lua | midi.lua (SkipIsland) | main/view escribe, midi lee condicional |
| `last_gfx_state` | compact-init.lua | midi.lua | compact init escribe, midi lee para cleanup |
| `progression[]` | progression.lua, sequencer.lua | midi.lua (ExportToMidi) | core escribe (progression/sequencer), core lee (midi) |

---

### Agrupación por Dominio Propuesto

#### `state/drag.lua` — Total ~62 refs
**Claves**: `drag.*` (is_dragging, source_degree, source_slot_idx, pending_degree, pending_slot_idx, start_x, start_y)

| Archivo | Rol |
|---------|-----|
| `src/ui/drag.lua` | Lector + escritor (DrawDragPreview cleanup) |
| `src/ui/pads.lua` | Escritor (drag start desde pads) |
| `src/core/slots.lua` | Escritor (drag start desde slots, drop logic) |
| `src/ui/views.lua` | Lector (guards: `not config.state.drag.is_dragging`) |
| `src/ui/buttons.lua` | Lector (guards) |
| `src/ui/colors.lua` | NO reference (solo lee color_mode) |

**Independencia**: ✅ ALTA — es un sub-sistema autocontenido. Solo `views.lua` y `buttons.lua` lo leen como guard condicional.

---

#### `state/sequencer.lua` — Total ~53 refs
**Claves**: `sequencer.*`, `progression[]`, `current_page`, `page_override_timer`, `slot_flash.*`

| Archivo | Rol |
|---------|-----|
| `src/core/sequencer.lua` | Escritor + lector (playback engine) |
| `src/core/progression.lua` | Escritor (Add/Remove/Swap/Clear) |
| `src/core/midi.lua` | Lector (ExportToMidi recorre progression) |
| `src/ui/views.lua` | Escritor (toggle play, volume slider, page nav) + lector |
| `src/ui/paginator.lua` | Escritor + lector (page dots) |
| `src/core/slots.lua` | Lector (slot rendering, seq.current_step highlight) |
| `src/ui/drag.lua` | Lector (progression en slot drag preview) |

**Independencia**: ✅ MEDIA-ALTA — progression y sequencer ya están en core/. La UI (views) necesita acceso, pero es principalmente lectura + 2 escrituras (toggle play, volume).

---

#### `state/midi.lua` — Total ~38 refs
**Claves**: `use_velocity`, `last_note_played`, `active_note_draw_timer`, `key_states`, `mouse_pad_state`, `active_notes`

| Archivo | Rol |
|---------|-----|
| `src/core/midi.lua` | Escritor + lector (TriggerChord, TriggerAllOff) |
| `src/core/keyboard.lua` | Lector (QWERTY keyboard handler) |
| `src/ui/pads.lua` | Escritor + lector (mouse pad interaction) |
| `src/ui/piano.lua` | Lector (active_notes visual) |
| `src/ui/compact-bar.lua` | Lector (last_note_played, active_note_draw_timer) |
| `src/ui/views.lua` | Lector (vel label, last_note_played) |
| `src/ui/compact-init.lua` | Lector + escritor (use_velocity toggle) |
| `src/main.lua` | Escritor (active_note_draw_timer decrement) |

**Independencia**: ⚠️ MEDIA — estado de MIDI output está disperso. `active_notes` y `mouse_pad_state` se leen desde piano y pads (UI).

---

#### `state/compact.lua` — Total ~23 refs
**Claves**: `compact.*`, `compact_overlay_active`, `last_gfx_state`

| Archivo | Rol |
|---------|-----|
| `src/ui/compact-init.lua` | Escritor + lector (init, switch mode) |
| `src/ui/compact-intercept.lua` | Lector (lice_bitmap) |
| `src/ui/compact-bar.lua` | Lector (compact table ref) |
| `src/ui/positioning.lua` | Lector (transport_hwnd) |
| `src/ui/lice.lua` | Escritor (bitmap/font creation) |
| `src/core/midi.lua` | Lector (1 ref: last_gfx_state) |
| `src/main.lua` | Lector (compact_overlay_active) |

**Independencia**: ✅ MUY ALTA — es el dominio más aislado. Solo `midi.lua` y `main.lua` tienen 1 ref cada uno fuera de compact-*.

---

#### `state/ui.lua` — Total ~110 refs
**Claves**: `view_mode`, `use_scroll`, `show_tooltips`, `color_mode`, `last_mouse_cap`, `mouse_click`, `mouse_wheel_delta`, `view_offset_x/y`, `auto_start_*`, `docked_mode`, `dock_id`, `did_cleanup`, `slider_dragging`, `pad_flash.*`, `page_override_timer`

| Archivo | Rol |
|---------|-----|
| `src/main.lua` | Escritor + lector (run loop: mouse, cleanup, init) |
| `src/ui/views.lua` | Escritor + lector (settings, toolbars) |
| `src/ui/buttons.lua` | Lector (mouse_click, drag.is_dragging) |
| `src/ui/dropdown.lua` | Lector (mouse_click, mouse_wheel_delta) |
| `src/ui/paginator.lua` | Lector (mouse_click, show_tooltips) |
| `src/ui/piano.lua` | Lector (mouse_click) |
| `src/ui/helpers.lua` | Lector (show_tooltips) |
| `src/ui/colors.lua` | Lector (color_mode) |
| `src/ui/pads.lua` | Lector (pad_flash, slider_dragging) |
| `src/core/slots.lua` | Lector (last_mouse_cap, slider_dragging) |
| `src/ui/compact-init.lua` | Escritor (mouse_click, mouse_wheel_delta, view_offset) |

**Independencia**: ⚠️ MEDIA-BAJA — `mouse_click` y `mouse_wheel_delta` son el sistema de eventos principal. Están acoplados al run loop.

---

#### Qué queda en `config.state` (root)
**Claves**: `root_index`, `scale_index`, `octave`, `chord_mode_index`, `view_offset_x`, `view_offset_y`

Son las 4 referencias musicales (root + scale + octave + chord) que se leen en **todos lados**, más `view_offset` (posición de ventana).

---

### Recomendación de Orden de Separación

Basado en: (1) aislamiento del dominio, (2) cantidad de archivos afectados, (3) riesgo de coupling.

| Orden | Store | Archivos afectados | Refs | Riesgo | LOC estimadas |
|-------|-------|-------------------|------|--------|---------------|
| **1°** | `state/compact.lua` | compact-init, compact-intercept, compact-bar, positioning, lice, midi, main | ~23 | ✅ Mínimo | ~60-80 |
| **2°** | `state/sequencer.lua` | sequencer, progression, midi, views, paginator, slots, drag | ~53 | ⚠️ Bajo-Medio | ~120-160 |
| **3°** | `state/drag.lua` | drag, pads, slots, views, buttons | ~62 | ⚠️ Medio | ~150-200 |
| **4°** | `state/midi.lua` | midi, keyboard, pads, piano, compact-bar, views, compact-init, main | ~38 | ⚠️ Medio-Alto | ~100-150 |
| **5°** | `state/ui.lua` | main, views, buttons, dropdown, paginator, helpers, colors, pads, piano, compact-init, slots | ~110 | 🔴 Alto | ~250-350 |

#### Por qué este orden:

1. **Compact primero**: Es el más aislado. Solo 7 archivos lo tocan, la mayoría dentro del mismo dominio `ui/compact-*`. `midi.lua` tiene 1 ref, `main.lua` tiene 1 ref. Ideal como primer PR — bajo riesgo, genera confianza.

2. **Sequencer segundo**: `progression` y `sequencer.*` ya son sub-tablas y están mayormente en `core/`. El acoplamiento con UI está acotado: `views.lua` escribe `is_playing` y `volume`. `midi.lua` lee `progression` para ExportToMidi. Un store unificado aquí tiene sentido lógico.

3. **Drag tercero**: Ya es sub-tabla, lo que facilita la extracción. Pero tiene 62 refs y está muy entretejido con pads.lua y slots.lua (drag-start desde pads, drag-drop en slots). La lógica de drag está distribuida.

4. **Midi cuarto**: `use_velocity`, `active_notes`, `mouse_pad_state` son semánticamente MIDI pero están leídos desde UI (piano, pads, compact-bar). Hay que decidir si `active_notes` y `mouse_pad_state` van a midi o a ui.

5. **UI último**: `mouse_click` y `mouse_wheel_delta` son el SISTEMA DE EVENTOS del framework. Separarlos implica cambiar cómo todo el input loop funciona. Además `view_mode` está muy acoplado con compact-init (switch view). Es el store más riesgoso y el que más archivos toca.

---

### Riesgos Específicos

1. **🔴 R1: `mouse_click` como sistema de eventos**. Se escribe en main.lua y compact-init.lua (dos GFX contexts distintos). 7 archivos lo leen. Es el "event bus" del framework. Cualquier refactor de este key debe ser quirúrgico.

2. **🔴 R2: `mouse_wheel_delta` zeroing pattern**. Se resetea a 0 después de leer en cada widget (patrón documentado en openspec/config.yaml). Si el store se separa, el patrón debe preservarse exactamente.

3. **🔴 R3: `sequencer.volume` es UI→core dependency**. `views.lua` (UI) escribe el volumen, pero `midi.lua` (core) lo lee para escalar velocity. Si sequencer y midi son stores separados, pueden depender ambos de un `midi_state` separado.

4. **🔴 R4: `root_index/scale_index/octave/chord_mode_index` son el "contexto musical global"**. Se leen en ~67 refs combinados. Son el punto más caliente de la codebase. La decisión de si quedan en `config.state` o van a `state/music.lua` es estratégica.

5. **⚠️ R5: `view_offset_x/y` están entre root y ui**. main.lua los usa para gfx.init (posición de ventana), y compact-menu/views los usan para settings. Si van a ui, main necesita importar ui state. Si quedan en root, es más simple.

6. **⚠️ R6: `progression` es un array compartido**. progression.lua escribe slots, sequencer.lua itera, midi.lua exporta, drag.lua/slots.lua renderizan. Es el contrato central del secuenciador.

7. **✅ R7: Compact store tiene mínimo riesgo**. Lo único delicado: `lice.lua` ya evita ciclo require con config accediendo a `config.state.compact` como parámetro — ese patrón se mantiene.

8. **✅ R8: Drag store ya es sub-tabla**. La estructura de datos ya está encapsulada. El riesgo está en la lógica distribuida (drag.start en pads, drag.drop en slots).

---

### Ready for Proposal

**Sí**. El análisis está completo. Datos clave:

- **375 referencias** a `config.state.*` en 13 archivos
- **6 dominios** identificados (compact, sequencer, drag, midi, ui, root)
- **5 stores propuestos** (compact → sequencer → drag → midi → ui, en ese orden)
- **~700-950 LOC total estimadas de cambio**
- **El budget de 400 líneas requiere PRs encadenados** (mínimo 2, recomendado 3-4)
- **Mayor riesgo**: `mouse_click` como sistema de eventos, y el contexto musical (`root_index`/`scale_index`/`octave`/`chord_mode_index`) como el punto más caliente
- **Store más seguro para empezar**: `state/compact.lua`
