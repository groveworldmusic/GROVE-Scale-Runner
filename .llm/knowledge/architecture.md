# Arquitectura del Proyecto — GROVE FL MIDI

## Visión General

```
main.lua (entry point)
├── init: Config → stores (compact, drag, sequencer, midi, ui)
├── loop: views.DrawFullView / compact-init.Run
│   ├── widgets (buttons, dropdown, paginator, piano, pads, slots)
│   ├── drag preview
│   └── keyboard handling
└── cleanup: stores cleanup, keyboard cleanup
```

## Circular Dependencies

⚠️ **state.island → state.note-store → core.midi → ui.gfx-window → state.island**
- **Ciclo**: island.lua requiere note-store.lua que a su vez necesita core.midi (para GetMidiNote), y core.midi requiere ui.gfx-window que requiere state.island.
- **Break**: note-store.lua usa lazy require para core.midi dentro de ProgressionEntryToPitch() — la única función que lo necesita. El require se resuelve en runtime cuando core.midi ya está cargado.
- **Archivos**: `src/state/island.lua`, `src/state/note-store.lua`, `src/core/midi.lua`, `src/ui/gfx-window.lua`

## Estructura de Directorios

```
src/
├── config.lua          ← Constantes + root state (~72 refs restantes)
├── main.lua            ← Entry point: init, loop, cleanup
├── core/               ← Lógica de dominio (independiente de GFX)
│   ├── midi.lua        ← Envío MIDI, ExportToMidi, TriggerChord
│   ├── keyboard.lua    ← HandleKeyboard, VKEY_MAP
│   ├── sequencer.lua   ← Playback loop
│   ├── progression.lua ← Progression CRUD
├── ui/                 ← Interfaz GFX
│   ├── views.lua       ← Vista principal (~832 LOC) + DrawIslandView()
│   ├── components.lua  ← Barrel (55 LOC)
│   ├── slots.lua       ← Slot interaction + drawing (moved from core/)
│   ├── compact-*.lua   ← Compact view (7 módulos)
│   ├── widgets/        ← buttons, dropdown, paginator, piano, pads, drag
│   ├── utils/          ← helpers, theme, colors, format, layout, lice, positioning
│   ├── piano-roll.lua  ← Piano roll grid para modo ISLAND (~415 LOC)
│   ├── timeline.lua    ← Timeline ruler para modo ISLAND (~150 LOC)
│   ├── velocity.lua    ← Velocity editor para modo ISLAND (~253 LOC)
│   └── preset-browser.lua ← Preset browser para modo ISLAND (~640 LOC)
└── state/              ← Stores de estado (7 módulos + island.lua + note-store.lua)
    ├── compact.lua
    ├── sequencer.lua
    ├── drag.lua
    ├── midi.lua
    ├── ui.lua
    ├── island.lua      ← Island state (~380 LOC) — estado de MIDI island, delega notas a note-store
    └── note-store.lua  ← Note CRUD, UUID, undo/redo, progression→notes (~165 LOC)
```

## Flujo de Datos

```
config.state (root keys)
    ↓ Init
stores (state/*)  ←  getters/setters  ←  core/* + ui/*
    ↓                                ↓
midi.lua (envío MIDI)           views.lua (render GFX)
```

## Arquitectura de Stores

7 stores independientes, cada una con tabla local + getters/setters + Init().
Excepción: `midi.lua` (core) importa `sequencer_store` para leer volumen.
Excepción: `island.lua` importa `note-store.lua` para delegar funciones de notas.

## Patrón Barrel

`components.lua` (55 LOC) y `compact.lua` (28 LOC) son bariles que re-exportan submódulos.
Consumers (`views.lua`, `main.lua`) siempre importan via `components.*` o `compact.*`.

## View Modes (Dual Mode Architecture)

- **FULL** (`VIEW_MODES.FULL = 1`): Ventana principal 720×497, dockeable, con todos los widgets y pads
- **COMPACT** (`VIEW_MODES.COMPACT = 2`): Panel flotante compacto, dockeable
- **MIDI Island** (`midi.midi_island_expanded`): Toggle dentro de FULL mode que expande/colapsa la sección MIDI (piano roll, timeline, velocity editor, preset browser) — NO es un view mode separado, se renderiza dentro del canvas existente

## Dual GFX Context

- `main.lua` → GFX principal (ventana completa)
- `compact-init.lua` → GFX compacto (panel flotante)
- Cada contexto tiene su propio `gfx.mouse_wheel` que debe leerse Y zerearse independientemente.

## Dependencias Circulares Conocidas

- `midi.lua` NUNCA requiere `sequencer.lua` (crearía ciclo: sequencer → midi → sequencer). Usa `sequencer_store` (state) para leer volumen.
- `keyboard.lua` requiere `sequencer.lua` + `midi.lua` — seguro (flu jo: keyboard → sequencer → midi, keyboard → midi, sin ciclos)
- `progression.lua` requiere `sequencer_store` — seguro
- Módulos UI requieren `components.lua` via lazy require (dentro de función, no al cargar módulo)

## Ref-count Gate (midi.SendMidi)

`midi.SendMidi(note, on, velocity?, force?)` usa un sistema de ref-count para prevenir stuck notes:

- **Note-on**: siempre envía 0x90 e incrementa ref-count en `midi_store`
- **Note-off** (`on=false`): decrementa ref-count. Solo envía 0x80 si `cur <= 0` (último release) o `force=true`
- **force=true** (4to parámetro): bypassa el gate — usado por `sequencer.Stop()` y `midi.AllNotesOff(true)` en paths de cleanup
- **AllNotesOff(force)**: acepta `force` opcional y lo propaga a cada `SendMidi` interno

Esto evita que un note-off de un trigger (ej. teclado) silencie una nota que otro trigger (ej. pads) sigue sosteniendo.

## Auto Track Setup

En `main.lua`, `AutoSetupTrack()` se ejecuta una vez en Init (después de `gfx.init()`):

1. Checkea `GetExtState("GROVE_SCALE_RUNNER", "auto_track_setup_done")` — salta si ya se ejecutó
2. Escanea tracks con `GetMediaTrackInfo_Value()` buscando armado + monitoreo + entrada MIDI
3. Si no encuentra pista adecuada, muestra `reaper.MB()` de consentimiento
4. En aceptación: crea/configura pista con arm=1, monitor=1, I_RECINPUT=Virtual MIDI Keyboard
5. Persiste flag via `SetExtState` como "true" o "skipped"

**ExtState keys**:
| Key | Values | Propósito |
|-----|--------|-----------|
| `auto_track_setup_done` | "true" \| "skipped" \| "" | Previene prompts repetidos |

## Historia de Refactor

El proyecto pasó por 4 fases de refactor estructural:
1. Extracción de layout, keyboard, MIDI state
2. Extracción de colors, format, progression
3. Descomposición de components.lua (3a, 3b) y compact.lua (3c)
4. Separación de estado en 5 stores (3d)

### Isla MIDI (2026-05-11, archived)
- Feature: MIDI island expandida con 4 paneles (preset browser, timeline, piano roll, velocity) — toggle via `midi.ToggleIsland()`, NO es un VIEW_MODE separado
- 5 archivos nuevos, 7 modificados, ~1658 LOC agregados
- El view mode ISLAND=3 nunca llegó a `config.lua` (solo FULL=1, COMPACT=2). La funcionalidad sobrevive como expansión inline dentro de FULL mode
- Ver `openspec/changes/archive/2026-05-11-isla-midi/` para artefactos completos

Ver `openspec/specs/refactor/spec.md` para especificaciones detalladas.
