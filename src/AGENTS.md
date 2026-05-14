# src/ — Source Code Orchestrator

Orquesta los agentes de `core/`, `ui/` y `state/`. Punto de entrada para cambios en el código fuente.

## Directory Structure

```
src/
├── AGENTS.md         ← YOU ARE HERE — orchestrates core + ui + state
├── config.lua        ← Constants (SCALES[21], CHORD_MODES[4], VKEY_MAP[28], NOTE_NAMES[12],
│                       VIEW_MODES, DOCK_MIN_W/H) + config.state defaults
├── main.lua          ← Entry: Init() → MainLoop() → CleanupAll()
├── core/             ← Domain logic (7 files): midi, keyboard, sequencer, progression, slots,
│                       api-guard, snap
├── ui/               ← GFX interface (34 files): views, widgets, layout, compact-*, helpers,
│                       piano-roll (6 sub-modules), timeline, velocity, preset-browser,
│                       midi-island, icons, gfx-safe
└── state/            ← State stores (10 files): compact, drag, sequencer, midi, ui, island,
                        piano-roll-store, preset-store, preferences, persist
```

## main.lua Lifecycle

### Init Order (CRITICAL)

```
 1. config = require("config")
 2. core.api-guard = require("core.api-guard")   ← check APIs before state init
 3. compact_store.Init(config.state)              ← state/compact.lua
 4. drag_store.Init(config.state)                 ← state/drag.lua
 5. sequencer_store.Init(config.state)            ← state/sequencer.lua
 6. midi_store.Init(config.state)                 ← state/midi.lua
 7. ui_store.Init(config.state)                   ← state/ui.lua
 8. island_store.Init(config.state)               ← state/island.lua (inits piano-roll-store internamente)
 9. preset_store.Init(config.state)               ← state/preset-store.lua
10. preferences_store.Init(config.state)          ← state/preferences.lua
                      ── stores ready ──
11. require("ui.theme")                           ← depends on config only
12. require("core.midi")                          ← uses sequencer_store.GetVolume()
13. require("core.sequencer")                     ← uses midi.TriggerChord()
14. require("ui.views")                           ← uses midi, compact, sequencer
15. require("ui.compact")                         ← barrel for compact-*
16. require("core.keyboard")                      ← uses midi.TriggerChord + midi_store
17. require("state.persist")                      ← persistence (Load/Save)
18. require("ui.gfx-safe")                        ← safe GFX wrappers
                      ── modules loaded ──
19. persist.Load(config.state)                    ← load ExtState overlays
20. preferences_store.SyncFromState(config.state) ← push overlays into store
21. gfx.init("GROVE SCALE RUNNER", 720, 497, 0, offset_x, offset_y)
22. Auto-track setup + auto-start logic
23. keyboard.InterceptMappedKeys(false)           ← clean state
24. reaper.defer(MainLoop)
```

**Regla**: stores Init SIEMPRE antes que cualquier módulo. `persist.Load()` y `SyncFromState` ocurren DESPUÉS de todos los requires para que las stores existan antes de recibir datos overlays.

### MainLoop — 3 Branches

**a) COMPACT mode** (`view_mode == 2`, no GFX):
```
AutoTrackSetup → DecrementPageOverrideTimer → CheckFocus → sequencer.Run()
  → HandleKeyboard → preferences_store.TickSaveDebounce()
  → ProcessMouseInterception → UpdateCompactView → HandlePanel
  → defer(MainLoop)
```

**b) Overlay mode** (compact bar + full view):
```
AutoTrackSetup → DecrementPageOverrideTimer → CheckFocus → sequencer.Run()
  → HandleKeyboard → preferences_store.TickSaveDebounce()
  → ProcessMouseInterception → UpdateCompactView
  → if IsPanelOpen: SwitchViewMode() → goto COMPACT
  → (else: fall through to GFX drawing below)
```

**c) FULL mode** (`view_mode == 1`, GFX active):
```
AutoTrackSetup → DecrementPageOverrideTimer → CheckFocus → sequencer.Run()
  → HandleKeyboard → preferences_store.TickSaveDebounce()
  → gfx.mouse_wheel → SetMouseClick + SetMouseWheelDelta
  → Dirty-flag check (redraw on timer/state changes)
  → CheckDockState()
  → if DockedMode: DrawDockedTransportBar(w,h) else DrawFullView()
  → SetLastMouseCap(gfx.mouse_cap)
  → gfx.getchar() → Ctrl+D = ToggleDock, Esc/-1 = CleanupAll + gfx.quit()
  → defer(MainLoop)
```

Mouse wheel delta se zeroea manualmente en MainLoop para evitar acumulación entre frames. Preferencias se flushean via `TickSaveDebounce()` una vez por frame.

### Cleanup — CleanupAll()

```
 1. midi.AllNotesOff(true)    ← force=true bypasses ref-count gate on cleanup
 2. sequencer.Stop()           ← note-offs + reset step/progress/clock
 3. keyboard.Cleanup()         ← release intercept
 4. compact.Cleanup()          ← close panel, destroy LICE resources, release intercepts
```

### Guard

```lua
reaper.atexit(function()
    if ui_store.GetDidCleanup() then return end
    ui_store.SetDidCleanup(true); CleanupAll()
end)
```

`did_cleanup` se checkea en atexit Y en `gfx.getchar(char == -1)`. CleanupAll es idempotente.

## config.lua API Reference

| Constante | Tipo | Detalle |
|-----------|------|---------|
| `NOTE_NAMES` | `table[12]` | `{"C","C#",...,"B"}` |
| `SCALES` | `table[21]` | `{name: string, intervals: number[]}` — Major, Minor Harmonic, Blues, etc. |
| `CHORD_MODES` | `table[4]` | `{name, offsets}` — Off `{0}`, Tri `{0,2,4}`, 7ma `{0,2,4,6}`, 9na `{0,2,4,6,8}` |
| `INVERSION_MODES` | `table[4]` | `{"Base", "1st", "2nd", "3rd"}` |
| `SUBDIVISION_MODES` | `table[6]` | `{1, 2, 3, 4, 8, 16}` — resoluciones de snap grid |
| `SUBDIVISION_LABELS` | `table[6]` | `{"1/1", "1/2", "1/3", "1/4", "1/8", "1/16"}` |
| `VKEY_MAP` | `table[28]` | `{deg: 1..7, oct: -2..1}` — 4 filas × 7 grados |
| `VIEW_MODES` | `table` | `{ FULL = 1, COMPACT = 2 }` |
| `DOCK_MIN_W/H` | `number` | 400 / 50 — docked transport bar min size |
| `PREF_KEYS` | `table[7]` | Keys persistidas via ExtState |

**VKEY_MAP physical rows**: Row1 (0x31-0x37, oct+1), Row2 QWERTYU (0x51/57/45/52/54/59/55, oct 0), Row3 ASDFGHJ (0x41/53/44/46/47/48/4A, oct-1), Row4 ZXCVBNM (0x5A/58/43/56/42/4E/4D, oct-2). Grado wrappea si > scale length.

**config.state remnants**: `root_index`(1-12), `scale_index`(1-21), `octave`(0-8), `chord_mode_index`(1-4), `inversion_index`(1-4), `inversion_direction`(0-1), `subdivision_index`(1-6), `view_offset_x/y`, `use_scroll`. ~1 runtime read remanente: `midi.lua:94` — `local c = ctx or config.state` en `TriggerChord`. El resto de accesos vía stores.

## External Requirements

| API | Funciones clave |
|-----|----------------|
| **js_ReaScriptAPI** | Requerido (checkeado en Init via api-guard) |
| `JS_VKeys_GetState(state)` | String con byte indexing (no char) |
| `JS_VKeys_Intercept(vk, enable)` | 28 teclas |
| `JS_Window_Find/GetRect/GetClientSize` | HWND transporte |
| `JS_Window_ClientToScreen/ScreenToClient` | Coordenadas |
| `JS_WindowMessage_Intercept/Peek/Release` | Hook WM para compact |
| `JS_Composite` | Composición transport bar |
| `JS_LICE_CreateBitmap/RoundRect/FillRect/Circle` | LICE drawing |
| `JS_LICE_LoadFont/DrawText` | Texto LICE |
| `reaper.StuffMIDIMessage` | Envío MIDI |
| `reaper.MIDI_InsertNote/Sort/Delete` | Exportación |
| `reaper.GetFocusedFX2()` | Detección de foco (bitmask) |
| `reaper.TimeMap2_timeToBeats` | Sincronía sequencer |
| `reaper.GetExtState/SetExtState` | Preferencias (auto_start_*, persist) |

**package.path**: se extiende desde `main.lua` vía `debug.getinfo(1,'S')`. Requires usan dots.

## Dependency Graph (src-level)

```
config.lua ←─── (no deps, consumed by all)
main.lua   ←─── all stores, all core, key ui modules
state/     ←─── no inter-store deps; consumed by core/ + ui/
core/      ←─── depends on state/ + config/ (sequencer→midi→sequencer_store;
                 keyboard→midi, keyboard→sequencer, keyboard→preferences_store)
ui/        ←─── depends on state/ + config/ + core/ (slots↔components via lazy require)
```

Ver `core/AGENTS.md` → Dependency Graph y `AGENTS.md` (root) → Circular Dependency Map para grafos detallados.

## Delegación

| Ruta | Cuándo |
|------|--------|
| `core/AGENTS.md` | Lógica de dominio: MIDI, keyboard, sequencer, progression, slots, api-guard, snap |
| `ui/AGENTS.md` | Interfaz GFX: vistas, widgets, layout, compact, helpers, LICE, piano-roll (6 sub-modules), midi-island, icons, gfx-safe, preset-browser, timeline, velocity |
| `state/AGENTS.md` | Stores: getters/setters, Init semantics, consumables, persist, piano-roll-store, preset-store, preferences |
| Todos | Coordinar vía `src/AGENTS.md` si toca múltiples áreas |

**Regla**: NO modificar `config.lua` a menos que sea estrictamente necesario. Nuevas keys de estado van a stores.

## Pitfalls

> ⚠️ **Init order**: stores DEBEN inicializarse antes que cualquier require de core/ui. Si un módulo se carga antes de su store, lee valores default.

> ⚠️ **persist.Load + SyncFromState**: deben ocurrir después de que todas las stores existen. `persist.Load()` escribe en `config.state` (no en stores), luego `preferences_store.SyncFromState()` sincroniza stores desde `config.state`.

> ⚠️ **gfx.quit() en SwitchViewMode**: destruye el contexto GFX. El flag `view_mode == COMPACT` previene dibujo en contexto muerto.

> ⚠️ **ToggleIsland no soporta docked**: retorna early si `ui_store.GetDockedMode()`.

> ⚠️ **JS_VKeys_GetState byte indexing**: `string.byte(state, vk_code)` — el VK code es el byte index (1-based). Funciona para valores ASCII porque coinciden.

> ⚠️ **config.state mutation**: stores comparten sub-tablas (progression, key_states, active_notes) por referencia. Mutación in-place afecta a `config.state`. Usar setters para reemplazos completos.

> ⚠️ **gfx.mouse_wheel debe zeroearse**: REAPER acumula wheel events. `gfx.mouse_wheel = 0` después de capturar el delta.

> ⚠️ **AllNotesOff(true) en cleanup**: `force=true` bypasses ref-count gate para asegurar note-offs incluso si algún trigger no liberó su referencia.

## Cross-References

| Archivo | Contenido relevante |
|---------|---------------------|
| `AGENTS.md` (root) | Jerarquía, dependency map, pattern glossary, issue registry, init/teardown contract |
| `src/core/AGENTS.md` | API de midi, keyboard, sequencer, progression, slots, api-guard, snap — firmas exactas |
| `src/ui/AGENTS.md` | GFX: views, widgets, layout, compact lifecycle, LICE, piano-roll, icons |
| `src/state/AGENTS.md` | Stores: todos los getters/setters, Init semantics, mutable tables, persist |
| `tests/AGENTS.md` | Testing infra: inventory, mocks, coverage gaps |
