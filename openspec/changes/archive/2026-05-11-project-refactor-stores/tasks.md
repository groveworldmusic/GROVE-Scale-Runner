# Tasks: Separar estado global en stores (Phase 3d)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~680-940 LOC |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | 5 PRs (compact → sequencer → drag → midi → ui) |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Compact state store | PR 1 | Base = feature/tracker branch; ~60-80 LOC |
| 2 | Sequencer state store | PR 2 | Base = PR 1 branch; cross-dep midi→sequencer; ~120-160 LOC |
| 3 | Drag state store | PR 3 | Base = PR 2 branch; ~150-200 LOC |
| 4 | MIDI state store | PR 4 | Base = PR 3 branch; medium-high risk; ~100-150 LOC |
| 5 | UI state store | PR 5 | Base = PR 4 branch; highest risk (mouse_click event bus); ~250-350 LOC |

## Phase 1: Compact State Store (PR 1)

- [x] 1.1 Create `src/state/compact.lua` — store with getters/setters for `compact.*` (transport_hwnd, lice_bitmap, lice_font, gdi_font), `compact_overlay_active`, `last_gfx_state`
- [x] 1.2 Update `src/ui/compact-init.lua`, `src/ui/compact-intercept.lua`, `src/ui/positioning.lua` — replace `config.state.compact.*` with `compact_store.Get*()/Set*()`
- [x] 1.3 Update `src/ui/lice.lua`, `src/core/midi.lua`, `src/main.lua` — replace remaining `config.state.compact_overlay_active/last_gfx_state` refs
- [x] 1.4 Also updated `src/ui/compact-bar.lua` — required because it read `lice_bitmap`/`lice_font` via `config.state.compact` directly
- [ ] 1.5 Strip extracted keys from `config.state` in `src/config.lua` (optional — deferred)

## Phase 2: Sequencer State Store (PR 2)

- [x] 2.1 Create `src/state/sequencer.lua` — store with getters/setters for `progression[]`, `sequencer.*` (is_playing, current_step, last_measure, midi_notes, progress, internal_beats, last_time, volume), `current_page`, `page_override_timer`, `slot_flash.*`
- [x] 2.2 Update `src/core/sequencer.lua`, `src/core/slots.lua`, `src/core/progression.lua` — import sequencer store, replace refs
- [x] 2.3 Update `src/ui/views.lua`, `src/ui/paginator.lua` — replace progression/page refs
- [x] 2.4 Update `src/core/midi.lua` — import sequencer store, call `sequencer_store.GetVolume()` (cross-store dep)

## Phase 3: Drag State Store (PR 3)

- [x] 3.1 Create `src/state/drag.lua` — store with getters/setters for `drag.*` (is_dragging, source_degree, source_slot_idx, pending_degree, pending_slot_idx, start_x, start_y, x, y)
- [x] 3.2 Update `src/ui/drag.lua`, `src/ui/pads.lua` — import drag store, replace all `config.state.drag.*` refs
- [x] 3.3 Update `src/core/slots.lua`, `src/ui/views.lua`, `src/ui/buttons.lua` — replace remaining drag refs

## Phase 4: MIDI State Store (PR 4)

- [x] 4.1 Create `src/state/midi.lua` — store with getters/setters for `use_velocity`, `last_note_played`, `active_note_draw_timer`, `key_states{}`, `active_notes{}`, `mouse_pad_state.*`
- [x] 4.2 Update `src/core/midi.lua`, `src/core/keyboard.lua`, `src/ui/pads.lua` — import midi store, replace refs
- [x] 4.3 Update `src/ui/compact-init.lua`, `src/ui/compact-bar.lua`, `src/main.lua`, `src/ui/views.lua` — replace remaining refs
- [x] 4.4 Update `src/ui/piano.lua` — replace `config.state.active_notes` ref

## Phase 5: UI State Store (PR 5)

- [x] 5.1 Create `src/state/ui.lua` — store with getters/setters for all 14 UI keys + ConsumeMouseClick(), ConsumeMouseWheelDelta(), ClearPadFlash()
- [x] 5.2 Update `src/main.lua`, `src/ui/views.lua`, `src/ui/compact-init.lua` — replace view_mode/mouse/wheel refs (handle GFX context separation for mouse_click & mouse_wheel_delta). compact-intercept.lua had no UI refs.
- [x] 5.3 Update `src/ui/helpers.lua`, `src/ui/buttons.lua`, `src/ui/dropdown.lua`, `src/ui/paginator.lua` — replace remaining refs
- [x] 5.4 Update `src/ui/piano.lua`, `src/ui/pads.lua`, `src/core/slots.lua`, `src/ui/colors.lua` — replace remaining refs; also updated compact-menu.lua and core/midi.lua (found via grep)
