# src/state/ — Stores de Estado

Estado global separado por dominio. Cada store encapsula su propia tabla de estado con getters/setters. Inicializadas desde `main.lua` con `config.state` como source de defaults.

## Store Overview

| Store | LOC | Fields | Functions | Init merge source |
|-------|-----|--------|-----------|-------------------|
| `compact.lua` | 37 | 6 | 12 (6 pairs) | `defaults.compact` sub-table + `compact_overlay_active` + `last_gfx_state` |
| `drag.lua` | 51 | 9 | 19 (9 pairs + Reset) | `defaults.drag` sub-table iterado key-by-key |
| `sequencer.lua` | 81 | 14 + progression[16] | 29 (14 pairs + 4 progression helpers + ClearProgression + Init) | `progression` (ref), `sequencer` sub-table, `current_page`, `page_override_timer`, `slot_flash.*` |
| `midi.lua` | 57 | 6 + 3 sub-tables | 15 (3 pairs + 6 indexed + ClearActiveNotes + Init) | `use_velocity`, `last_note_played`, `active_note_draw_timer`, `key_states` (ref), `active_notes` (merge), `mouse_pad_state` (merge) |
| `ui.lua` | 121 | 14 | 33 (14 pairs + 2 Consume* + 3 pad_flash + ClearPadFlash + Init) | ~15 root keys de `config.state.*` |
| `island.lua` | 136 | 20 + notes[] | 42 (20 pairs + ClearBrowserState + 2 conversion helpers + LoadNotesFromProgression + GetVisibleNotes + Init) | `island_active`, `preset_panel_visible`, `notes` (ref), `playback_pos`, `scroll_*`, `zoom_x`, `selected_note_index`, `current_directory`, `preset_root` |
| `piano-roll-store.lua` | 426 | 30+ | 50+ (pairs + CRUD + undo/redo + note helpers + Init) | `island_active`, `preset_panel_visible`, `notes` (ref), `playback_pos`, `scroll_*`, `zoom_x`, `selected_note_index` |
| `preset-store.lua` | 72 | 10 | 20 (10 pairs + ClearBrowserState + Init) | `current_directory`, `preset_root` |
| `preferences.lua` | 81 | 7 | 16 (7 pairs + Init + SyncFromState + TickSaveDebounce) | `root_index`, `scale_index`, `octave`, `chord_mode_index`, `inversion_index`, `inversion_direction`, `subdivision_index` |

## Store Module Pattern

```lua
local state = { key = default_value }
local m = {}
function m.Init(defaults)
    if defaults.key ~= nil then state.key = defaults.key end
    if defaults.subtable then
        for k, v in pairs(defaults.subtable) do state.subtable[k] = v end
    end
end
function m.GetKey() return state.key end
function m.SetKey(v) state.key = v end
function m.ClearAll() for k,_ in pairs(state) do state[k]=nil end end
return m
```

## Init Merge Semantics

Cada store procesa `config.state` de manera diferente:

- **compact**: itera `defaults.compact` key-by-key + asigna `compact_overlay_active` + `last_gfx_state` directamente.
- **drag**: itera `defaults.drag` key-by-key. 9 keys planas, sin sub-tablas anidadas.
- **sequencer**: `progression` se asigna por **REFERENCIA** (mutaciones afectan caller). `sequencer` sub-table se mergea key-by-key. `current_page`, `page_override_timer` directos. `slot_flash` mergea idx+timer.
- **midi**: `use_velocity`, `last_note_played`, `active_note_draw_timer` directos. `key_states` por **REFERENCIA**. `active_notes` mergea entry-by-entry (NO reemplazo completo). `mouse_pad_state` mergea sub-keys.
- **ui**: ~15 root keys directas. `pad_flash` mergea recursivamente (sub-tablas anidadas como `prev_active`).
- **island**: `island_active`, `preset_panel_visible`, `notes` por **REFERENCIA** (mutaciones afectan caller). `playback_pos`, `scroll_*`, `zoom_x`, `selected_note_index` directos. `current_directory`, `preset_root` directos.
- **piano-roll-store**: `island_active`, `preset_panel_visible`, `notes` (ref), `playback_pos`, `scroll_offset_y/x`, `zoom_x`, `selected_note_index` directos. Note CRUD functions maintain internal state (uuid index, note count).
- **preset-store**: Init solo recibe `current_directory` y `preset_root`. El resto (preset_tree, preset_files, etc.) se inicializan desde defaults internos.
- **preferences**: `root_index`, `scale_index`, `octave`, `chord_mode_index`, `inversion_index`, `inversion_direction`, `subdivision_index` directos. No hay sub-tablas.

**Regla**: las stores NUNCA crean nuevas keys durante Init. Solo actualizan valores existentes.

## API Documentation

### compact.lua — 6 pairs

```
Get/Set: TransportHwnd(userdata|nil), LiceBitmap(userdata|nil), LiceFont(userdata|nil),
         GdiFont(userdata|nil), OverlayActive(boolean), LastGfxState(table|nil)
```

`LastGfxState`: snapshot `{dock, x, y, w, h}` pre-SwitchViewMode. Init desde `defaults.compact` sub-table + `compact_overlay_active` + `last_gfx_state`.

### drag.lua — 9 pairs + Reset

```
Get/Set: IsDragging(boolean), SourceDegree(num), SourceSlotIdx(num),
         PendingDegree(num|nil), PendingSlotIdx(num|nil),
         StartX(num), StartY(num), X(num), Y(num)
Special: Reset() — clears all to defaults (is_dragging=false, source_degree=-1,
         source_slot_idx=-1, pending_degree=nil, pending_slot_idx=nil)
```

Init desde `defaults.drag` sub-table.

### sequencer.lua — 14 pairs + progression helpers + ClearProgression

```
Progression (ref): GetProgression() → table (REF), SetProgression(t),
                   GetProgressionLen(), GetProgressionEntry(i), SetProgressionEntry(i,v),
                   ClearProgression() — clears slots 1..16 to nil

Playback: Get/Set: IsPlaying(bool), CurrentStep(num), LastMeasure(num), MidiNotes(table),
                   Progress(num), InternalBeats(num), LastTime(num|nil), Volume(num 0-127)

Page: Get/Set: CurrentPage(1-4), PageOverrideTimer(num)

Slot flash: Get/Set: SlotFlashIdx(num), SlotFlashTimer(num)
```

Init: `progression` (ref), `sequencer` sub-table key-by-key, `current_page`, `page_override_timer`, `slot_flash.*`.

### midi.lua — 3 pairs + 6 indexed + ClearActiveNotes

```
Fields: Get/Set: UseVelocity(bool), LastNotePlayed(string), ActiveNoteDrawTimer(num)

Key states (ref): GetKeyStates() → table (REF), GetKeyState(i), SetKeyState(i,v)

Active notes (ref, ref-counted): GetActiveNotes() → table (REF), GetActiveNote(i),
                                 SetActiveNote(i, v=nil|num), ClearActiveNotes()

Mouse pad state (ref): GetMousePadState() → table (REF)
                       — {pad_hover, pad_selected, pad_timer, active_degree, midi_notes{}}
```

Init: `use_velocity`, `last_note_played`, `active_note_draw_timer`, `key_states` (ref), `active_notes` (merge entry-by-entry), `mouse_pad_state` (merge sub-keys).

### island.lua — 20 pairs + ClearBrowserState + ProgressionToNotes + GetVisibleNotes

```
Island state: Get/Set: IslandActive(bool), PresetPanelVisible(bool)

Notes (ref): GetNotes() → table (REF), SetNotes(t),
             GetNoteCount(), SetNoteCount(v)

Playback: Get/Set: PlaybackPos(num — beats)

Scroll: Get/Set: ScrollOffsetY(num — clamped 0..56), ScrollOffsetX(num — clamped ≥0)

Zoom: Get/Set: ZoomX(num — pixels per beat, clamped 10..200)

Selection: Get/Set: SelectedNoteIndex(num|nil)

Preset browser: Get/Set: CurrentDirectory(str), PresetRoot(str),
                PresetTree(table — REF), PresetFiles(table — REF),
                SelectedPresetIdx(num|nil), BrowserScroll(num),
                BrowserError(str|nil), Favorites(table — REF),
                Bookmarks(table — REF)
Special: ClearBrowserState() — resets browser fields to defaults
Helpers: ProgressionToNotes(progression, beats_per_slot?, velocity?) → table
         LoadNotesFromProgression(seq_store) → void (populates notes from sequencer)
         GetVisibleNotes(notes, pitch_start, pitch_end, beat_start, beat_end) → table
```

Init: `island_active`, `preset_panel_visible`, `notes` (ref), `playback_pos`, `scroll_offset_y/x`, `zoom_x`, `selected_note_index`, `current_directory`, `preset_root`. 14 keys in total.

### piano-roll-store.lua — 30+ pairs + note CRUD + undo/redo + selection + lasso + helpers

```
Island state: Get/Set: IslandActive(bool), PresetPanelVisible(bool)

Notes (ref): GetNotes() → table (REF), SetNotes(t) → clears selection + rebuilds UUID index,
             GetNoteCount(), SetNoteCount(v)
             AddNote(note) — inserts note with UUID, auto-alloc if missing
             RemoveNoteAtIndex(idx) — removes + adjusts selection indices

Selection: GetSelectedIndices() → table (REF), SetSelectedIndices(t),
           ClearSelection(), IsNoteSelected(idx), ToggleNoteSelected(idx),
           GetPrimarySelectedIndex(), GetSelectionCount()
Shims: SetSelectedNoteIndex(v), GetSelectedNoteIndex() — legacy shims for backward compat

Lasso: Get/Set: LassoActive(bool), LassoStartX/Y(num), LassoEndX/Y(num)

Playback: Get/Set: PlaybackPos(num — beats)

Scroll: Get/Set: ScrollOffsetY(num — clamped 0..108), ScrollOffsetX(num — clamped ≥0)

Zoom: Get/Set: ZoomX(num — pixels per beat, clamped 10..200)

Tool: Get/Set: ToolMode("pointer"|"pencil"|"eraser")

Snap: Get/Set: SnapEnabled(bool), SnapResolution(num), SnapTriplet(bool)

Note drag: Get/Set: NoteDragActive(bool), NoteDragIndices(table),
           NoteDragStartPitch(num), NoteDragStartBeat(num),
           NoteDragOriginMx/My(num), NoteResizeEdge(string|nil),
           ResetNoteDrag() — clears all drag state

Velocity: Get/Set: VelocityPanelExpanded(bool)

Island transition: Get/Set: IslandTransitioning(bool),
                   Get/SetPreToggleDock(num), Get/SetPreToggleRect(table)

Undo/Redo: PushUndo(entry), PopUndo() → entry|nil,
           PushRedo(entry), PopRedo() → entry|nil,
           ClearUndoStacks(), GetUndoDepth(), GetRedoDepth()
           Max 50 entries per stack. Pushing undo clears redo stack.

UUID: AllocNoteUUID() → auto-increment ID
      FindNoteByUUID(uuid) → index|nil
      RebuildUUIDIndex() — rebuilds uuid→index lookup

Helpers: ProgressionToNotes(progression, beats_per_slot?, velocity?) → table
         LoadNotesFromProgression(seq_store) → void
         GetVisibleNotes(notes, pitch_start, pitch_end, beat_start, beat_end) → table
```

Init: `island_active`, `preset_panel_visible`, `notes` (ref), `playback_pos`, `scroll_offset_y/x`, `zoom_x`, `selected_note_index`, `velocity_panel_expanded`. Approximately 10 keys.

### preset-store.lua — 10 pairs + ClearBrowserState

```
Directory: Get/Set: CurrentDirectory(str), PresetRoot(str)
Tree: Get/Set: PresetTree(table — REF), PresetFiles(table — REF)
Selection: Get/Set: SelectedPresetIdx(num|nil)
Scroll: Get/Set: BrowserScroll(num — clamped ≥0)
Error: Get/Set: BrowserError(str|nil)
Favorites: Get/Set: Favorites(table — REF), Bookmarks(table — REF)
Special: ClearBrowserState() — resets all to defaults (directory stays)
```

Init: `current_directory`, `preset_root`. Solo 2 keys.

### preferences.lua — 7 pairs + SyncFromState + TickSaveDebounce

```
Getters: GetRootIndex(), GetScaleIndex(), GetOctave(),
         GetChordModeIndex(), GetInversionIndex(), GetInversionDirection(),
         GetSubdivisionIndex() → number

Setters: SetRootIndex(v), SetScaleIndex(v), SetOctave(v),
         SetChordModeIndex(v), SetInversionIndex(v), SetInversionDirection(v),
         SetSubdivisionIndex(v) → void (marks save_pending = true)

Sync: SyncFromState(state_table) — batch-copies all 7 keys from config.state
Flush: TickSaveDebounce() — if save_pending, calls persist.Save() for all 7 keys
```

Init: all 7 keys from defaults. SyncFromState es llamado DESPUÉS de persist.Load() en main.lua para propagar valores guardados a la store.

### ui.lua — 14 pairs + 2 Consume* + pad_flash helpers

```
View: Get/SetViewMode(num) — 1=FULL, 2=COMPACT

Mouse (event bus): Get/SetMouseClick(bool), ConsumeMouseClick() → bool (clears)
                   Get/SetMouseWheelDelta(num), ConsumeMouseWheelDelta() → num (zeros)

Preferences: Get/Set: ShowTooltips(bool), ColorMode("grade"|"flat"), UseScroll(bool)

State: Get/Set: LastMouseCap(num), SliderDragging(bool)

Pad flash: Get/SetPadFlashDegree(num), Get/SetPadFlashTimer(num),
           GetPadFlashPrevActive() → table (REF), ClearPadFlash() — degree=-1, timer=0

Dock: Get/Set: DockedMode(bool), DockId(num)

Auto-start: Get/Set: AutoStartCompact(bool), AutoStartReaper(bool)

Guard: Get/SetDidCleanup(bool)
```

Init desde ~15 root keys de `config.state.*`. `pad_flash` mergeado recursivamente.

## Consume Pattern Docs

- **`ConsumeMouseClick()`**: event bus de 1 frame. Seteado en MainLoop via `(gfx.mouse_cap & 1) == 1 && last_mouse_cap == 0`. ConsumeMouseClick retorna el valor Y lo resetea a false.
- **`ConsumeMouseWheelDelta()`**: mismo patrón. Seteado desde `gfx.mouse_wheel`. Retorna delta Y lo zeroea a 0. `gfx.mouse_wheel` se zeroea manualmente en MainLoop.
- **Regla**: NO llamar Consume* dos veces en el mismo frame — segunda llamada siempre retorna false/0.

## Mutable Table Warnings

> ⚠️ **IMPORTANTE**: estas funciones devuelven REFERENCIA a la tabla interna, no copia:

| Store | Función | Tabla |
|-------|---------|-------|
| `sequencer` | `GetProgression()` | `seq_state.progression` — entries slot[1..16]. Usar `SetProgressionEntry(i,v)` para escritura. |
| `midi` | `GetKeyStates()` | `midi_state.key_states` — `{[vk] = {is_pressed, midi_notes, code}}`. Mutar sub-entries es seguro, no reasignar. |
| `midi` | `GetActiveNotes()` | `midi_state.active_notes` — `{[note] = count}` ref-counted. Mutar directamente puede desincronizar. Preferir `SetActiveNote()`. |
| `midi` | `GetMousePadState()` | `midi_state.mouse_pad_state` — mutación directa de sub-campos es intencional (pads.lua). |
| `ui` | `GetPadFlashPrevActive()` | `ui_state.pad_flash.prev_active` — solo lectura, ClearPadFlash no lo toca. |
| `piano-roll-store` | `GetNotes()` | `state.notes` — array de notas con UUID. Mutar entries in-place es seguro, no reasignar el array. |
| `piano-roll-store` | `GetSelectedIndices()` | `state.selected_indices` — `{[idx] = true}` set. Mutar directamente es seguro. |
| `preset-store` | `GetPresetTree/Files/Favorites/Bookmarks()` | Tablas internas referenciadas. Mutar sub-entries es seguro, reasignar requiere Set* correspondiente. |

**Convención**: REFERENCIA MUTABLE en la descripción de la función. Setters como `SetProgression(t)` son para reemplazo completo. Para mutación in-place, usar la referencia directamente.

## Cross-Store Dependencies

- **Ninguna store requiere otra store directamente** — cada store es completamente independiente.
- `midi.lua` (core) requiere `sequencer_store` para leer volumen — pero esto es desde el módulo de dominio, no desde la store.
- `progression.lua` (core) requiere `sequencer_store` — mismo caso.
- `piano-roll-store.lua` directamente importa `config` para ProgressionToNotes (usa SCALES, CHORD_MODES) y `core.api-guard` para ClampIndex — es el módulo de store con más dependencias externas.
- `preferences.lua` importa `state.persist` para el debounced save (TickSaveDebounce llama persist.Save).
- `island.lua` importa `config` para ciertas constantes.
- Las stores solo reciben `config.state` en Init y son consumidas por core/ y ui/.

## Remnant Keys (config.state)

Keys que persisten como root keys de `config.state` por compatibilidad con código legacy. La mayoría ahora se leen vía `preferences_store.*` para escritura, pero el almacenamiento subyacente sigue siendo `config.state`. Migración completa pendiente (Phase 2, PR #2 del cambio que-ves-incompleto).

| Key | Rango | Propósito |
|-----|-------|-----------|
| `root_index` | 1-12 | Nota raíz seleccionada |
| `scale_index` | 1-21 | Escala seleccionada |
| `octave` | 0-8 | Octava base |
| `chord_mode_index` | 1-4 | Modo de acorde (Off/Tri/7ma/9na) |
| `inversion_index` | 1-4 | Inversión seleccionada |
| `inversion_direction` | 0-1 | Dirección de inversión (UP/DN) |
| `subdivision_index` | 1-6 | Subdivisión de grilla |
| `view_offset_x` | number | Posición X de ventana GFX |
| `view_offset_y` | number | Posición Y de ventana GFX |
| `use_scroll` | boolean | Scroll habilitado |

~1 runtime read remanente: `midi.lua:94` — `local c = ctx or config.state` en `TriggerChord`. El resto de accesos son vía stores. **NO agregar nuevas keys a `config.state`** — las stores son el mecanismo correcto.
