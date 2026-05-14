# Delta for Refactor — Phase 3d (Separar estado global en stores)

## Nature of Change

**0 ADDED / 0 MODIFIED / 0 REMOVED behavioral requirements.** Pure structural refactor. 375 refs a `config.state.*` in 13 files redirected to 5 store modules. Every existing behavior SHALL be preserved identically across both GFX contexts.

## Stores

| Store | Keys | Affected files | Risk |
|-------|------|----------------|------|
| `state/compact.lua` | `compact.*` (4), `compact_overlay_active`, `last_gfx_state` | compact-init, compact-intercept, positioning, lice, midi, main | Low |
| `state/sequencer.lua` | `progression[]`, `sequencer.*` (8), `current_page`, `page_override_timer`, `slot_flash.*` | sequencer, slots, progression, midi, views, paginator | Low-Med |
| `state/drag.lua` | `drag.*` (9: is_dragging, source_degree, source_slot_idx, pending_degree, pending_slot_idx, start_x, start_y, x, y) | drag, pads, slots, views, buttons | Med |
| `state/midi.lua` | `use_velocity`, `last_note_played`, `active_note_draw_timer`, `key_states`, `active_notes`, `mouse_pad_state.*` | midi, keyboard, pads, compact-init, compact-bar, main, views | Med-High |
| `state/ui.lua` | `view_mode`, `show_tooltips`, `color_mode`, `last_mouse_cap`, `mouse_click`, `mouse_wheel_delta`, `auto_start_compact`, `auto_start_reaper`, `docked_mode`, `dock_id`, `did_cleanup`, `slider_dragging`, `pad_flash.*` | main, views, compact-init, compact-intercept, helpers, buttons, dropdown, paginator, piano, pads, slots, colors | High |

## Structural Requirements

### Requirement: Store module pattern

Each store MUST define a local `the_state = {}` with default values for all managed keys, plus `GetX()`, `SetX(val)` per key, and `Init(defaults)` that merges defaults into `the_state` without overwriting existing keys.

#### Scenario: Getter returns last Setter value
- GIVEN a store instance with default state
- WHEN `SetX(val)` is called
- THEN `GetX()` MUST return `val`

#### Scenario: Init merges without overwrite
- GIVEN a store with default `foo = 1`
- WHEN `Init({foo = 99, bar = 2})` is called
- THEN `GetFoo()` MUST return 1 (existing default preserved)
- AND `GetBar()` MUST return 2 (new key added)

### Requirement: Sub-table access

Sub-tables (`progression[]`, `mouse_pad_state.*`, `slot_flash.*`, `pad_flash.*`, `drag.*`, `compact.*`, `sequencer.*`) SHALL use key-level getters/setters: `GetProgression(idx)`, `SetProgression(idx, val)`, `GetMousePadStateActiveDegree()`, `SetSlotFlashTimer(n)`, etc. No direct table reference mutation — callers MUST go through getters/setters.

#### Scenario: Slot flash indexed access
- GIVEN `sequencer_store`
- WHEN `SetSlotFlashIdx(3)` then `SetSlotFlashTimer(10)` is called
- THEN `GetSlotFlashIdx()` MUST return 3
- AND `GetSlotFlashTimer()` MUST return 10

### Requirement: Behavioral preservation — mouse_click

`mouse_click` SHALL use edge detection identically in both GFX contexts. The setter replaces `config.state.mouse_click = ...`; the getter replaces `config.state.mouse_click`.

#### Scenario: Single-frame edge in main context
- GIVEN main.lua run loop where `gfx.mouse_cap&1=1` and `last_mouse_cap=0`
- WHEN `SetMouseClick(true)` is called
- THEN `GetMouseClick()` MUST return true
- AND on next frame (no new edge) `GetMouseClick()` MUST return false

### Requirement: Behavioral preservation — mouse_wheel_delta

`mouse_wheel_delta` SHALL preserve the zeroing pattern: written once per frame per GFX context, consumed via `GetMouseWheelDelta()`, zeroed via `SetMouseWheelDelta(0)` after each widget read.

#### Scenario: Per-context independence
- GIVEN two GFX contexts (main, compact-init)
- WHEN `SetMouseWheelDelta(5)` is called in main context
- THEN compact-init's `GetMouseWheelDelta()` MUST return 0 (no cross-contamination)
- AND main's `GetMouseWheelDelta()` MUST return 5

### Requirement: Cross-store dependency

`sequencer.volume` is set by `views.lua` (UI) and read by `midi.lua` (core). The midi store MUST import the sequencer store and call `sequencer_store.GetVolume()`.

#### Scenario: Volume read from sequencer by midi store
- GIVEN midi store requires sequencer store
- WHEN `sequencer_store.SetVolume(75)` and then midi.lua calls `sequencer_store.GetVolume()`
- THEN it MUST return 75

## Remaining in config.state

`root_index`, `scale_index`, `octave`, `chord_mode_index`, `view_offset_x`, `view_offset_y`, `use_scroll` — 7 keys (~72 refs) stay in `config.state` unchanged.

## Verification

### Scenario: Runtime behavior preservation
- GIVEN all 5 stores created and consumer imports updated (13 files)
- WHEN the script runs in REAPER (both main and compact GFX contexts)
- THEN all UI interactions, MIDI output, drag-and-drop, pagination settings, and compact panel behavior SHALL be identical to pre-refactor
- AND no runtime errors SHALL occur during init, run loop, or cleanup

### Scenario: No config.state references for extracted keys
- GIVEN the refactor is applied
- WHEN grepping `config.state\.` for all extracted keys
- THEN there SHALL be zero matches — all access goes through store getters/setters
