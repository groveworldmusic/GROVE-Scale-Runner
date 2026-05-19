# Design: Separar estado global en stores (Phase 3d)

## Technical Approach

Extraer 5 stores module desde `config.state.*` manteniendo comportamiento idéntico. Cada store encapsula un dominio con getters/setters explícitos y `Init(defaults)` para arranque. Implementación en PR chain: compact → sequencer → drag → midi → ui (riesgo ascendente). `config.state` se reduce a 7 keys root (~84 refs remanentes).

## Architecture Decisions

### Decision: API pattern

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Metatables `__index/__newindex` | Menos código, pero debug imposible, magic | ❌ Rechazado |
| Raw getters/setters + Init | Verboso pero explícito, debuggeable | ✅ Elegido |
| Exponer tabla interna | Rápido pero rompe encapsulamiento | ❌ Solo `GetSnapshot()` |

### Decision: Cross-store dependency (volume)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| midi store duplica volume | Data inconsistency | ❌ Rechazado |
| midi store importa sequencer store | Dep explícita, single source of truth | ✅ Elegido |
| Volume en UI store | Ruptura semántica (volume es secuenciador) | ❌ Rechazado |

### Decision: lice.lua adaptation

lice.lua no recibe `config.state.compact` como parámetro para modificar — en vez de eso retorna recursos creados, y el caller (compact-init.lua) los persiste via setters del compact store. Esto preserva la independencia de lice.lua de cualquier store/config.

### Decision: PR Chain order

| PR | Store | LOC | Risk | Rationale |
|----|-------|-----|------|-----------|
| 1 | compact | ~60-80 | Low | Más aislado (7 files, solo compact-* + midi/main) |
| 2 | sequencer | ~120-160 | Low-Med | progression + sequencer ya son sub-tablas |
| 3 | drag | ~150-200 | Med | 62 refs distribuidos en 5 files |
| 4 | midi | ~100-150 | Med-High | active_notes, mouse_pad_state leídos desde UI |
| 5 | ui | ~250-350 | High | mouse_click = event bus, 24 refs, 2 GFX contexts |

## Data Flow

```
main.lua (Init)
  ├─ compact_store.Init(config.state)      ─→ state/compact.lua
  ├─ sequencer_store.Init(config.state)    ─→ state/sequencer.lua
  ├─ drag_store.Init(config.state)         ─→ state/drag.lua
  ├─ midi_store.Init(config.state)         ─→ state/midi.lua
  └─ ui_store.Init(config.state)           ─→ state/ui.lua

main.lua (MainLoop — GFX context 1)
  ├─ ui_store.SetMouseClick(edge)
  ├─ ui_store.SetMouseWheelDelta(gfx.mouse_wheel)
  └─ views.DrawFullView()
       ├─ reads ui_store.GetMouseClick()
       ├─ reads sequencer_store.GetVolume()
       └─ writes sequencer_store.SetIsPlaying(bool)

compact-init.lua (HandlePanel — GFX context 2)
  ├─ ui_store.SetMouseClick(edge)
  └─ reads/writes stores independently

midi.lua (core — no GFX context)
  ├─ imports sequencer_store for volume
  └─ imports compact_store for last_gfx_state
```

## File Changes

### New files (5)

| File | Description |
|------|-------------|
| `src/state/compact.lua` | Store: compact.* (4), compact_overlay_active, last_gfx_state |
| `src/state/sequencer.lua` | Store: sequencer.* (8), progression[16], current_page, page_override_timer, slot_flash.* |
| `src/state/drag.lua` | Store: drag.* (9 keys) |
| `src/state/midi.lua` | Store: use_velocity, last_note_played, active_note_draw_timer, key_states, active_notes, mouse_pad_state.* |
| `src/state/ui.lua` | Store: view_mode, mouse_click, mouse_wheel_delta, show_tooltips, color_mode, last_mouse_cap, auto_start_*, docked_mode, dock_id, slider_dragging, pad_flash.*, did_cleanup |

### Modified files (13) — per-store map below

## Store APIs

### state/compact.lua (~25 LOC)

```lua
-- Defaults: transport_hwnd=nil, lice_bitmap=nil, lice_font=nil, gdi_font=nil
--             compact_overlay_active=false, last_gfx_state={dock=0,x=100,y=100,w=720,h=500}
function Init(defaults)
function GetTransportHwnd() / SetTransportHwnd(v)
function GetLiceBitmap() / SetLiceBitmap(v) / GetLiceFont() / SetLiceFont(v) / GetGdiFont() / SetGdiFont(v)
function GetCompactOverlayActive() / SetCompactOverlayActive(v)
function GetLastGfxState() / SetLastGfxState(v)  -- v is a table {dock,x,y,w,h}
function GetSnapshot()  -- {transport_hwnd, lice_bitmap, ...}
```

### state/sequencer.lua (~55 LOC)

```lua
-- Defaults: is_playing=false, current_step=0, last_measure=-1, midi_notes={}
--           progress=0, internal_beats=0, last_time=nil, volume=100
--           progression={[16]}, current_page=1, page_override_timer=0
--           slot_flash={idx=-1, timer=0}
function Init(defaults)
-- Sequencer sub-keys
function GetIsPlaying() / SetIsPlaying(v)
function GetCurrentStep() / SetCurrentStep(v)
-- ... (same for each of 8 sequencer sub-keys)
function GetVolume() / SetVolume(v)
-- Progression array (indexed)
function GetProgression(idx) / SetProgression(idx, slot)
function ClearProgression()
function GetLastFilled()      -- returns last non-nil index or 0
-- Page
function GetCurrentPage() / SetCurrentPage(v)
function GetPageOverrideTimer() / SetPageOverrideTimer(v)
function DecrementPageOverrideTimer()
-- Slot flash
function GetSlotFlashIdx() / SetSlotFlashIdx(v)
function GetSlotFlashTimer() / SetSlotFlashTimer(v)
```

### state/drag.lua (~40 LOC)

```lua
-- Defaults: is_dragging=false, source_degree=-1, source_slot_idx=-1
--           pending_degree=nil, pending_slot_idx=nil, start_x=0, start_y=0
function Init(defaults)
function GetIsDragging() / SetIsDragging(v)
function GetSourceDegree() / SetSourceDegree(v)
function GetSourceSlotIdx() / SetSourceSlotIdx(v)
function GetPendingDegree() / SetPendingDegree(v)
function GetPendingSlotIdx() / SetPendingSlotIdx(v)
function GetStartX() / SetStartX(v)
function GetStartY() / SetStartY(v)
function GetSnapshot()  -- all 7 active keys
function Reset()        -- is_dragging=false, source_degree=-1, source_slot_idx=-1
function ClearPending() -- pending_degree=nil, pending_slot_idx=nil
```

### state/midi.lua (~40 LOC)

```lua
-- Defaults: use_velocity=true, last_note_played="None", active_note_draw_timer=0
--           key_states={}, active_notes={}, mouse_pad_state={active_degree=-1, midi_notes={}}
function Init(defaults)
function GetUseVelocity() / SetUseVelocity(v)
function GetLastNotePlayed() / SetLastNotePlayed(v)
function GetActiveNoteDrawTimer() / SetActiveNoteDrawTimer(v)
function DecrementActiveNoteDrawTimer()
-- Key states
function GetKeyStates() / SetKeyStates(v)  -- full table set only at init
function GetKeyState(code)                 -- returns key_states[code]
-- Active notes (ref-counted)
function GetActiveNotes() / GetActiveNote(midi_note)
function NoteOn(midi_note)
function NoteOff(midi_note)
-- Mouse pad state
function GetMousePadStateActiveDegree() / SetMousePadStateActiveDegree(v)
function GetMousePadStateMidiNotes() / SetMousePadStateMidiNotes(v)
function ClearMousePadState()
-- Cross-store: midi imports sequencer store for GetVolume()
```

### state/ui.lua (~70 LOC)

```lua
-- Defaults: view_mode=1, mouse_click=false, mouse_wheel_delta=0
--           show_tooltips=false, color_mode="grade", last_mouse_cap=0
--           auto_start_compact=false, auto_start_reaper=false
--           docked_mode=false, dock_id=0, slider_dragging=false
--           pad_flash={degree=-1, timer=0, prev_active={}}, did_cleanup=false
function Init(defaults)
function GetViewMode() / SetViewMode(v)
function GetMouseClick() / SetMouseClick(v)     -- edge detection via setter
function GetMouseWheelDelta() / SetMouseWheelDelta(v)
function ConsumeMouseWheelDelta()                -- read + zero atomically
function GetShowTooltips() / SetShowTooltips(v)
function GetColorMode() / SetColorMode(v)
function GetLastMouseCap() / SetLastMouseCap(v)
function GetAutoStartCompact() / SetAutoStartCompact(v)
function GetAutoStartReaper() / SetAutoStartReaper(v)
function GetDockedMode() / SetDockedMode(v)
function GetDockId() / SetDockId(v)
function GetSliderDragging() / SetSliderDragging(v)
function GetDidCleanup() / SetDidCleanup(v)
-- Pad flash (sub-table)
function GetPadFlashDegree() / SetPadFlashDegree(v)
function GetPadFlashTimer() / SetPadFlashTimer(v)
function GetPadFlashPrevActive() / SetPadFlashPrevActive(v)
```

## File Modification Maps (per PR)

### PR 1 — compact

| File | Changes |
|------|---------|
| `src/state/compact.lua` | **Create** (~25 LOC) |
| `src/ui/compact-init.lua` | `config.state.compact` → `compact_store.Get/Set*`, `config.state.compact_overlay_active` → Get/SetCompactOverlayActive, `config.state.last_gfx_state` → Get/SetLastGfxState, `lice.EnsureLICE(config.state.compact)` → resource return + setters |
| `src/ui/compact-intercept.lua` | `config.state.compact.*` → `compact_store.Get*`, `config.state.compact.lice_bitmap` → GetLiceBitmap |
| `src/ui/positioning.lua` | UpdatePositioning recibe compact snapshot + view_offset_x/y en vez de config.state |
| `src/ui/lice.lua` | EnsureLICE retorna recursos en vez de modificar tabla pasada |
| `src/core/midi.lua` | `config.state.last_gfx_state` → `compact_store.GetLastGfxState()` |
| `src/main.lua` | `config.state.compact_overlay_active` → `compact_store.GetCompactOverlayActive()` |

### PR 2 — sequencer

| File | Changes |
|------|---------|
| `src/state/sequencer.lua` | **Create** (~55 LOC) |
| `src/core/sequencer.lua` | `config.state.sequencer.*` → `seq_store.Get/Set*`, `config.state.progression[idx]` → Get/SetProgression, `config.state.current_page` → Get/SetCurrentPage |
| `src/core/progression.lua` | Same pattern |
| `src/core/slots.lua` | Same pattern + `config.state.slot_flash.*` → seq_store.Get/SetSlotFlash* |
| `src/ui/views.lua` | `config.state.sequencer.*` → Get/Set*, `config.state.current_page` → Get/SetCurrentPage, `config.state.page_override_timer` → Get/Set/Paginate |
| `src/ui/paginator.lua` | `config.state.current_page` → Get/SetCurrentPage |
| `src/core/midi.lua` | `config.state.progression[idx]` → `seq_store.GetProgression(idx)`, `config.state.sequencer.volume` → `seq_store.GetVolume()` (cross-store) |

### PR 3 — drag

| File | Changes |
|------|---------|
| `src/state/drag.lua` | **Create** (~40 LOC) |
| `src/ui/drag.lua` | `config.state.drag.*` → `drag_store.Get/Set*`, Reset(), ClearPending() |
| `src/ui/pads.lua` | Same pattern |
| `src/core/slots.lua` | Same pattern |
| `src/ui/views.lua` | `config.state.drag.is_dragging` → `drag_store.GetIsDragging()` |
| `src/ui/buttons.lua` | `config.state.drag.is_dragging` → `drag_store.GetIsDragging()` |

### PR 4 — midi

| File | Changes |
|------|---------|
| `src/state/midi.lua` | **Create** (~40 LOC) |
| `src/core/midi.lua` | `config.state.use_velocity` → midi_store.Get/Set*, `config.state.last_note_played` → Get/Set, `config.state.active_note_draw_timer` → Get/Set/Decrement, `config.state.active_notes` → Get/NoteOn/NoteOff, `config.state.mouse_pad_state.*` → Get/Set/Clear, `config.state.key_states` → Get/Set/GetKeyState |
| `src/core/keyboard.lua` | `config.state.use_velocity` → midi_store.GetUseVelocity(), `config.state.key_states` → midi_store.GetKeyStates()/GetKeyState(code) |
| `src/ui/pads.lua` | `config.state.mouse_pad_state.*` → midi_store.Get/Set*, `config.state.key_states` → midi_store.GetKeyStates() |
| `src/ui/piano.lua` | `config.state.active_notes` → midi_store.GetActiveNotes() |
| `src/ui/compact-bar.lua` | `config.state.active_note_draw_timer` → midi_store.GetActiveNoteDrawTimer(), `config.state.last_note_played` → GetLastNotePlayed() |
| `src/ui/views.lua` | `config.state.use_velocity` → midi_store.GetUseVelocity(), `config.state.last_note_played` → GetLastNotePlayed() |
| `src/ui/compact-init.lua` | `config.state.use_velocity` → midi_store.Get/SetUseVelocity() |
| `src/main.lua` | `config.state.active_note_draw_timer` → midi_store.Get/SetActiveNoteDrawTimer() |

### PR 5 — ui

| File | Changes |
|------|---------|
| `src/state/ui.lua` | **Create** (~70 LOC) |
| `src/main.lua` | `config.state.mouse_click` → ui_store.SetMouseClick(), `config.state.mouse_wheel_delta` → SetMouseWheelDelta(), `config.state.last_mouse_cap` → SetLastMouseCap(), `config.state.docked_mode` → Get/SetDockedMode, `config.state.dock_id` → Get/SetDockId, `config.state.view_mode` → Get/SetViewMode, `config.state.compact_overlay_active` → GetCompactOverlayActive (already migrated), `config.state.did_cleanup` → Get/SetDidCleanup |
| `src/ui/views.lua` | `config.state.mouse_click` → ui_store.GetMouseClick(), `config.state.mouse_wheel_delta` → ConsumeMouseWheelDelta(), `config.state.show_tooltips` → Get/SetShowTooltips, `config.state.color_mode` → Get/SetColorMode, `config.state.slider_dragging` → Get/SetSliderDragging, `config.state.auto_start_*` → Get/SetAutoStart*, `config.state.docked_mode` → Get/SetDockedMode |
| `src/ui/compact-init.lua` | Same pattern (HandlePanel mouse_click/mouse_wheel_delta) |
| `src/ui/compact-intercept.lua` | (no ui state changes) |
| `src/ui/helpers.lua` | `config.state.show_tooltips` → ui_store.GetShowTooltips() |
| `src/ui/buttons.lua` | `config.state.mouse_click` → ui_store.GetMouseClick() |
| `src/ui/dropdown.lua` | `config.state.mouse_click` → GetMouseClick(), `config.state.mouse_wheel_delta` → ConsumeMouseWheelDelta() |
| `src/ui/paginator.lua` | `config.state.mouse_click` → GetMouseClick(), `config.state.show_tooltips` → GetShowTooltips() |
| `src/ui/piano.lua` | `config.state.mouse_click` → GetMouseClick(), `config.state.root_index` → stays in config.state |
| `src/ui/pads.lua` | `config.state.pad_flash.*` → ui_store.Get/SetPadFlash*, `config.state.slider_dragging` → GetSliderDragging(), `config.state.mouse_click` → GetMouseClick() |
| `src/core/slots.lua` | `config.state.last_mouse_cap` → ui_store.GetLastMouseCap(), `config.state.slider_dragging` → GetSliderDragging() |
| `src/ui/colors.lua` | `config.state.color_mode` → ui_store.GetColorMode() |

## Remaining in config.state

```lua
config.state = {
    root_index, scale_index, octave, chord_mode_index,  -- musical context (67 refs)
    view_offset_x, view_offset_y,                        -- window position (12 refs)
    use_scroll                                           -- UI preference (5 refs)
}
```

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Static | 0 refs to extracted keys via `config.state\.` | grep verification per PR |
| Manual | Runtime behavior preservation in REAPER | Smoke test: all UI interactions, MIDI output, drag-drop, pagination, compact panel |
| Per-PR | Import correctness | Verify each consumer file imports correct store module |

## Open Questions

None. All decisions documented in proposal, spec, and exploration.

## Next Step

Ready for tasks (sdd-tasks).
