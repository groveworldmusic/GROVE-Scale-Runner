# src/ui/ — Interfaz GFX

Componentes visuales, vistas, layout, helpers. Todo lo que renderiza en pantalla.
37 archivos fuente, ~7,226 LOC total (29 root + 6 piano-roll/ + 2 midi-island/).

## File Map

### Core UI (~4 files)
| Archivo | LOC | Propósito |
|---------|-----|-----------|
| `views.lua` | 879 | DrawFullView, DrawDockedTransportBar, DrawHeader, DrawIslands, DrawPerformanceArea, DrawMIDIIsland, DecrementPageOverrideTimer — orquestación de la vista completa |
| `midi-island.lua` | 216 | **Orchestrator** — orquestación del island MIDI expandido (Phase 5 refactor). Delega a `midi-island/header.lua` e `input.lua`. |
| `midi-island/header.lua` | 194 | Header rendering — tool modes, MIDI channel, snap, zoom controls. |
| `midi-island/input.lua` | 222 | Input dispatcher — mouse and keyboard event handling for the MIDI Island. |
| `components.lua` | 184 | **Barrel** — re-exporta widgets + inline DrawRoundedRect + DrawIsland |
| `layout.lua` | 20 | SetScale, UX, UY, US — sistema de coordenadas virtuales (canvas 39914×29162) |

### Widgets (~7 files)
| Archivo | LOC | Funciones |
|---------|-----|-----------|
| `buttons.lua` | 153 | DrawButton, DrawToolIcon, DrawTransportButton, DrawNoteDisplay — botones y tool icons |
| `paginator.lua` | 41 | DrawPaginator — dots de paginación |
| `dropdown.lua` | 76 | DrawDropdown — dropdown con scroll y menú contextual |
| `piano.lua` | 148 | DrawPianoKeyboard + PIANO_LAYOUT constants — teclado de piano GFX |
| `pads.lua` | 126 | DrawScalePad — pads de grado con drag-to-slot |
| `slots.lua` | 279 | DrawProgressionSlot + HandleSlotInteraction — slots de progresión |
| `drag.lua` | 87 | DrawDragPreview — preview flotante durante drag |

### Island UI (~4 root + 6 sub-modules)
| Archivo | LOC | Propósito |
|---------|-----|-----------|
| `piano-roll.lua` | 83 | **Barrel** — re-exporta piano-roll/* submódulos |
| `piano-roll/grid.lua` | 450 | DrawGrid, DrawNote, note hit-test — grilla de piano roll con snapping, selección por lasso y click |
| `piano-roll/interaction.lua` | 1051 | Mouse handling completo: click-to-select, lasso drag, note drag/resize, tool switching, context menu, zoom/scroll wheel |
| `piano-roll/note.lua` | 284 | Note rendering (actual + ghosting), CRUD operations, note coloring. |
| `piano-roll/undo.lua` | 148 | Undo/redo stacks, snapshot-based state tracking, max 50 entries |
| `piano-roll/clipboard.lua` | 126 | Copy/paste notes, multi-note clipboard, paste-at-cursor |
| `piano-roll/view.lua` | 44 | Viewport state, scroll clamp helpers, visible range calculation |
| `timeline.lua` | 170 | DrawTimeline — timeline ruler con playhead sincronizado al sequencer |
| `velocity.lua` | 390 | DrawVelocityEditor — 'Glass Blade' aesthetic, velocity edit per note, multi-selection. |
| `preset-browser.lua` | 663 | DrawPresetBrowser — explorador de presets MIDI, favoritos, folder navigation. |

### Compact View (~6 files)
| Archivo | LOC | Propósito |
|---------|-----|-----------|
| `compact.lua` | 25 | **Barrel** — re-exporta compact-* submódulos (11 funciones) |
| `compact-init.lua` | 288 | SwitchViewMode, InitOverlay, HandlePanel, UpdateCompactView, FindTransportWindow, Cleanup |
| `compact-bar.lua` | 58 | CompactBar — render LICE de la barra de transporte compacta |
| `compact-panel.lua` | 99 | TogglePanel, IsPanelOpen, ClosePanel — panel flotante GFX |
| `compact-intercept.lua` | 129 | ProcessMouseInterception, CleanupIntercept — WM_LBUTTONDOWN/RBUTTONDOWN routing |
| `compact-menu.lua` | 119 | ShowContextMenu, GetMenuDismissTime — menú contextual right-click |

### Utilities (~7 files)
| Archivo | LOC | Propósito |
|---------|-----|-----------|
| `helpers.lua` | 107 | SetColor, DrawTooltip, AbbreviateScale, CompactAbbreviateScale |
| `theme.lua` | 69 | theme.colors — paleta completa (16 colores + grade_colors[7]) |
| `colors.lua` | 17 | DegreeColor(degree) → color table |
| `format.lua` | 29 | NoteName, ChordLabel, RomanNumeral |
| `positioning.lua` | 158 | Layout y posicionamiento de compact view (cv_x/y/w/h, auto-position, GetTransportScreenRect) |
| `lice.lua` | 122 | EnsureLICE, DrawRoundedRectFill, DrawArrowIcon, DrawProgressBar, DrawModeHint — wrappers LICE |
| `icons.lua` | 94 | DrawIcon, icon definitions (settings, help, scroll, clear, export, view, dock, midi) — iconos SVG-like vectoriales para tool icons |
| `gfx-safe.lua` | 47 | SafeGfxInit, SafeGfxQuit — wrappers GFX con protección de doble init/quit, manejo de errores |

## Dual GFX Context

`main.lua` y `compact-init.lua` operan contextos GFX **independientes**:

- **main.lua**: contexto GFX de la ventana principal (`gfx.init("GROVE SCALE RUNNER", 720, 497, ...)` en Init). Maneja FULL mode y overlay mode. Captura y zeroa `gfx.mouse_wheel` en MainLoop línea ~158.
- **compact-init.lua**: contexto GFX del panel flotante (`gfx.init("Scale Runner", PANEL_PW, PANEL_PH, ...)` en HandlePanel). Maneja el panel de piano/controles cuando está abierto. También zeroa `gfx.mouse_wheel` independientemente (línea 175).
- **SwitchViewMode()**: al cambiar FULL→COMPACT llama `gfx.quit()` (destruye contexto FULL). Al volver COMPACT→FULL restaura con `gfx.init()` usando `LastGfxState` guardado.

**Regla crítica**: cada contexto debe leer Y zeroar `gfx.mouse_wheel` por su cuenta. Un `gfx.quit()` sin guardar estado pierde la posición de la ventana.

## API Documentation

### views.lua

```lua
-- views.DrawFullView() → void
--   Calcula scale = min(gfx.w/39914, 500/29162)*1.025 contra altura BASE (500px)
--   para que expandir MIDI island no deforme el zoom. Llama SetScale + dibuja
--   background. Orquesta: DrawHeader → DrawIslands → DrawPerformanceArea → DrawMIDIIsland.
--   Llamado desde main.lua MainLoop (rama FULL mode).

-- views.DrawDockedTransportBar(dock_w, dock_h) → void
--   Compact horizontal strip (~50px high) cuando está dockeado en transport.
--   8 controles: ROOT, SCALE, OCT-, OCT+, CHORD, VEL, PLAY/STOP, CLR, UNDOCK.
--   Issue 6: el botón UNDOCK usa U+25C4 (glyph support limitado).

-- views.DrawHeader() → void
--   Título "GROVE SCALE RUNNER" + versión + state indicator (root/scale/chord/octave)
--   + scroll indicator + 3 tool icons (help, settings, view/compact toggle).

-- views.DrawIslands() → void
--   4 islands: Scale & Piano (piano + scale dropdown + note display),
--   Octava (dropdown + C3/C4/C5 quick buttons), Chord (NOTE/TRI/7MA/9NA),
--   Command Stack (VEL, PLAY/STOP, CLEAR+EXPORT, MIDI toggle, VOL slider).

-- views.DrawPerformanceArea() → void
--   7 scale pads + 4 progression slots + paginator + prev/next buttons.
--   Auto-page durante playback vía GetPageOverrideTimer.

-- views.DrawMIDIIsland() → void
--   Conditional: solo si midi.midi_island_expanded. Contenido completo dentro del
--   panel expandido de la isla MIDI. Phase 5: Delegado a midi-island.lua (orchestrator).
--   Draws: header → piano-roll → timeline → velocity → preset browser.

-- views.DecrementPageOverrideTimer() → void
--   Llamado desde ALL modes (Issue 8). Decrementa timer de override de página.
```

### layout.lua

```lua
-- CANVAS_W = 39914, CANVAS_H = 29162 — coordenadas virtuales (500px base height)
-- SetScale(s, ox, oy) → void
--   Establece scale y offset para el frame actual. Solo DrawFullView llama esto.
--   Interno: _S, _OX, _OY (no tocar desde fuera del módulo).
-- UX(v) → pixel X: math.floor(v * _S + _OX)
-- UY(v) → pixel Y: math.floor(v * _S + _OY)
-- US(v) → pixel size: math.floor(v * _S)
```

### components.lua (barrel + inline)

```lua
-- components.DrawRoundedRect(x, y, w, h, r, fill) → void
--   Dibuja rectángulo redondeado vía circle+rect (emula roundrect filled).
-- components.DrawIsland(x, y, w, h, title, font_size) → void
--   Fondo de island + título centrado.
```

**Re-exports from widgets**: DrawPianoKeyboard, DrawScalePad, HandleSlotInteraction, DrawProgressionSlot, DrawDragPreview, DrawButton, DrawToolIcon, DrawTransportButton, DrawNoteDisplay, DrawPaginator, DrawDropdown.

**piano-roll.lua** (barrel) — re-exports piano-roll/* submódulos: DrawGrid, DrawNote, InteractionHandler (from grid.lua, note.lua, interaction.lua).

### Widget API

```lua
-- buttons.DrawToolIcon(type, x, y, size, active?) → boolean (click)
--   type: "settings"|"view"|"help"|"scroll"|"clear"|"export". active? opcional.
-- buttons.DrawButton(x, y, w, h, label, active, font_size) → boolean (click)
--   5-layer rendering: bg, stroke, hover overlay, press shadow, active glow.
-- buttons.DrawTransportButton(label, x, y, w, h) → boolean (click)
--   Simple hover-highlight button para docked transport bar.
-- buttons.DrawNoteDisplay(x, y, w, h, note) → void
--   Muestra última nota tocada (o "-" si None).
--
-- paginator.DrawPaginator(x, y, total_pages) → void
--   Círculos de paginación (page_active/page_inactive). Tooltip en hover.
--
-- dropdown.DrawDropdown(x, y, w, h, label?, value, options, current_index,
--                       font_size, open_up?) → number|nil
--   Scroll wheel selection + gfx.showmenu en click. Adaptive text truncation.
--
-- piano.DrawPianoKeyboard(x, y, w, h, font_size) → void
--   73 teclas (C2-C8). White keys + black keys. Root highlight + scale indicators
--   + active note glow. Click para cambiar root_index.
--   PIANO_LAYOUT: white_keys_per_octave, black_key_specs, start_note C2, end_note C8.
--   Cached scale notes vía cached_scale_root/cached_scale_idx (Issue 13).
--   Active note lookup O(1) vía pre-computed pitch-class set active_mod12 (Issue 18).
--
-- pads.DrawScalePad(x, y, w, h, degree, main_font_size, sub_font_size,
--                   total_degrees) → void
--   Pad de grado con chord label + roman numeral + QWERTY key hint.
--   Drag-to-slot: 8px threshold antes de iniciar drag (Issue 5).
--   Mouse pad note release solo mouse-pad notes, no QWERTY-held notes.
--
-- drag.DrawDragPreview(w, h) → void
--   Preview flotante durante drag. Muestra chord label + roman numeral.
--   Aspect ratio mantenido, max 100×80px. Reset en mouse release.
```

### Compact View API

```lua
-- compact-init.SwitchViewMode() → void
--   FULL→COMPACT: guarda LastGfxState (dock, x, y, w, h), gfx.quit().
--   COMPACT→FULL: restaura vía gfx.init() + LastGfxState. SetOverlayActive(true).
-- compact-init.InitOverlay() → void
--   Compact bar alongside full view (auto-start). FindTransportWindow + EnsureLICE.
--   NO llama gfx.quit() — full view sigue visible.
-- compact-init.FindTransportWindow() → hwnd|nil
--   Busca ventana de transporte: "Transport"→"Transporte"→GetTransportHwnd (SWS, Issue 7).
-- compact-init.HandlePanel() → void
--   Ciclo de vida del panel flotante GFX. Inicia gfx.init(), maneja auto-reposición
--   si el transporte se movió >50px. Dibuja piano + scale/octave/chord dropdowns + VEL.
-- compact-init.UpdateCompactView() → void
--   Renderiza LICE bitmap + JS_Composite sobre la ventana de transporte.
-- compact-init.Cleanup() → void
--   ClosePanel → ReleaseIntercepts → DestroyLICE resources.
--
-- compact-intercept.ProcessMouseInterception() → void
--   WM_LBUTTONDOWN: passthrough=true (transporte procesa el click).
--   WM_RBUTTONDOWN: passthrough=false (transporte NO recibe el click).
--   Hit-test: "restore" zone → SwitchViewMode, "content" zone → TogglePanel.
--   Post-menu guard: ignora clicks por 200ms tras dismiss de menú contextual.
-- compact-intercept.CleanupIntercept(hwnd) → void
--   Libera intercepts de WM_LBUTTONDOWN + WM_RBUTTONDOWN + unlink composite.
--
-- compact-menu.ShowContextMenu() → void
--   Temp GFX window solo en COMPACT mode. En FULL mode usa gfx.showmenu directo
--   (crear temp window en FULL mode destruiría el contexto GFX existente).
--   Menú jerárquico: view mode toggle, root, scale, octave, chord, tools, position.
```

## Patterns

| Patrón | Cómo funciona |
|--------|---------------|
| **Dual GFX context** | main.lua y compact-init.lua tienen contextos GFX independientes. `gfx.quit()` en SwitchViewMode destruye solo el contexto FULL. Cada contexto zeroa su propio `gfx.mouse_wheel`. |
| **Delta lifecycle** | `gfx.mouse_wheel = 0` por frame en cada contexto + `ui_store.ConsumeMouseWheelDelta()` por widget. Doble zero para evitar acumulación. |
| **Scroll convention** | `delta > 0` → decremento (navegación a página anterior / valor menor). `delta < 0` → incremento. |
| **mouse_click event bus** | Evento de 1 frame. `ui_store.SetMouseClick(bool)` en MainLoop. `ui_store.GetMouseClick()` devuelve y resetea implícitamente. Varios widgets pueden leerlo pero solo uno debe consumirlo (cada widget checkea hover propio). |
| **Barrel pattern** | `components.lua` (84 LOC), `compact.lua` (25 LOC), y `piano-roll.lua` (93 LOC) re-exportan submódulos. Consumers (`views.lua`, `main.lua`) usan `components.*`, `compact.*`, o `piano-roll.*` — un solo require en vez de 6-7. |
| **Lazy require** | Widgets (`buttons.lua`, `piano.lua`, `pads.lua`, `paginator.lua`, `dropdown.lua`, `drag.lua`) requieren `components.lua` dentro de cada función, no al tope. Rompe la circularidad `components→widgets→components`. |
| **Note Ghosting** | Durante drag/resize, se renderizan siluetas semi-transparentes en la posición original (`island_store.GetNoteDragOrigins()`) antes de las notas reales. |
| **Glass Blade** | Estética premium para velocity bars: stems con glow glassy, pins redondeados con gradiente y border-glow en selección. |

## GFX Conventions

1. **mouse_wheel zeroing**: `gfx.mouse_wheel = 0` cada frame en CADA contexto GFX. REAPER acumula eventos si no se zeroa — causa scroll infinito.
2. **mouse_click**: evento de 1 frame. Se setea desde MainLoop via `ui_store.SetMouseClick((gfx.mouse_cap & 1) == 1 && last_mouse_cap == 0)`. Los widgets checkean con `ui_store.GetMouseClick()`.
3. **Consume pattern**: `ui_store.ConsumeMouseClick()` y `ui_store.ConsumeMouseWheelDelta()` devuelven el valor y lo resetean en un solo paso. NO llamar dos veces en el mismo frame.
4. **Config requires**: la mayoría de los componentes de UI requieren `config` directamente (buttons.lua, piano.lua, dropdown.lua) para acceder a `config.SCALES`, `config.CHORD_MODES`, `config.NOTE_NAMES`. Para estado mutable usan stores (`ui_store`, `drag_store`, `midi_store`, `sequencer_store`).
5. **Virtual coordinate system**: layout.lua mapea coordenadas virtuales (39914×29162) a píxeles. DrawFullView calcula scale una vez por frame. Docked mode usa píxeles directos (no virtual).
6. **Tooltip conditional**: helpers.DrawTooltip checkea `ui_store.GetShowTooltips()` antes de dibujar. No hay tooltips si están desactivados globalmente.
7. **MIDI island expand**: `midi.ToggleIsland()` usa `gfx.quit()` + `gfx.init()` para cambiar de 720×497 a 720×793 (y viceversa). `midi.midi_island_toggled` flag notifica a MainLoop. El flag `island_transitioning` evita renders incompletos durante la recreación de ventana. No soportado en docked mode.

## Dependencies

- `state/ui.lua` — mouse_click, mouse_wheel_delta, view_mode, show_tooltips, color_mode, slider_dragging, docked_mode, auto_start_compact, pad_flash
- `state/drag.lua` — is_dragging, pending_degree, source_degree, source_slot_idx, start_x/y
- `state/midi.lua` — use_velocity, key_states, active_notes, mouse_pad_state, last_note_played
- `state/sequencer.lua` — current_page, progression, is_playing, volume, page_override_timer
- `state/compact.lua` — transport_hwnd, lice_bitmap, lice_font, gdi_font, overlay_active, last_gfx_state
- `state/island.lua` — island_active, preset_panel_visible (consumido por midi-island.lua, preset-browser.lua)
- `state/piano-roll-store.lua` — notes, selection, zoom, scroll, tool_mode, lasso, undo/redo (consumido por piano-roll/*)
- `state/preset-store.lua` — current_directory, preset_tree, preset_files, favorites, bookmarks (consumido por preset-browser.lua)
- `core/midi.lua` — TriggerChord, SendMidi, midi_island_expanded, midi_channel, ExportToMidi
- `ui/slots.lua` — DrawProgressionSlot, HandleSlotInteraction (via lazy require en components.lua)
- `core/progression.lua` — Clear()
- `core/sequencer.lua` — Stop() (play/stop toggle en Command Stack + docked transport bar)
- `core/snap.lua` — SnapBeat (consumido por piano-roll/grid.lua)
- `core/api-guard.lua` — ClampIndex (consumido por piano-roll-store.lua internamente)

## Pitfalls

> ⚠️ **GFX context conflict en compact menu**: `ShowContextMenu()` en COMPACT mode crea temp `gfx.init("", 0, 0)`, pero en FULL mode NO debe crear temp window porque destruiría el GFX existente. El flag `is_full` controla este branching.

> ⚠️ **WM_RBUTTONDOWN passthrough=false**: el right-click intercept bloquea el click de REAPER en la zona del compact bar. Si el usuario clickea fuera de la barra, el intercept se libera (`is_on_bar == false` → release). Si no se libera, el menú contextual nativo de REAPER no funciona en esa zona.

> ⚠️ **mouse_wheel no zeroeado = scroll infinito**: si `gfx.mouse_wheel` no se zeroa en MainLoop o HandlePanel, el delta se acumula frame a frame. Los widgets que leen `ui_store.GetMouseWheelDelta()` verían valores antiguos y el scroll nunca se detiene.

> ⚠️ **Scale calculation con MIDI island expandida**: DrawFullView calcula scale contra `500 / 29162` (altura BASE), no contra `gfx.h`. Expandir MIDI island agrega canvas abajo pero NO cambia el zoom del contenido existente. Si se usara `gfx.h` en vez de constante, el contenido se encogería al expandir la isla.

> ⚠️ **Docked transport bar**: en docked mode NO hay layout virtual. DrawDockedTransportBar usa píxeles directos. ToggleIsland (MIDI) retorna early si docked — no soportado.

> ⚠️ **Panel auto-reposition**: HandlePanel checkea si el transporte se movió >50px. Si es así, llama `gfx.quit()` + reinicia `gfx.init()` en nueva posición. Esto causa un frame vacío (la ventana se cierra y reabre).

## Cross-References

| Archivo | Contenido relevante |
|---------|---------------------|
| `src/AGENTS.md` | main.lua MainLoop branches (COMPACT/overlay/FULL), Init order, CleanupAll |
| `src/state/AGENTS.md` | ui_store (14 pairs + consume), drag_store (9 pairs + Reset), midi_store (ref-counted), sequencer_store (16 slots + 8 playback), compact_store (6 pairs), piano-roll-store (50+ functions), preset-store (10 pairs), preferences (7 pairs + SyncFromState) |
| `src/core/AGENTS.md` | midi.TriggerChord/InvertChord, slots.DrawProgressionSlot/HandleSlotInteraction, snap.SnapBeat — firmas exactas |
| `AGENTS.md` (root) | Pattern glossary (barrel, lazy require, mouse_click event bus), Init/teardown contract, issue registry (#5, #6, #7, #8, #9, #10, #13, #18, #21, #22) |
