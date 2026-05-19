# Delta for Refactor — Phases 3a–3d (Decompose Components, Desacoplar compact.lua, Separar estado global en stores)

## Nature of Change

**Pure structural refactor.** No behavioral changes. No new capabilities. No modified capabilities. Phases 3a–3c are internal code moves (extractions to new files). Phase 3d extracts global state into 5 domain stores with getter/setter APIs.

All existing behaviors MUST be preserved identically after each extraction/store refactor. The system SHALL behave exactly as before the refactor across all entry points, inputs, and UI states.

## Extractions

### Phase 3a — Buttons, Paginator, Dropdown

| # | Extract | Source | Target | Nature |
|---|---------|--------|--------|--------|
| 1a | `DrawButton` | `src/ui/components.lua` | `src/ui/buttons.lua` | Logic move, calls `DrawRoundedRect` internally |
| 1b | `DrawToolIcon` | `src/ui/components.lua` | `src/ui/buttons.lua` | Logic move, pure GFX drawing, no internal deps |
| 1c | `DrawTransportButton` | `src/ui/components.lua` | `src/ui/buttons.lua` | Logic move, calls `DrawRoundedRect` internally |
| 1d | `DrawNoteDisplay` | `src/ui/components.lua` | `src/ui/buttons.lua` | Logic move, calls `DrawRoundedRect` internally |
| 2 | `DrawPaginator` | `src/ui/components.lua` | `src/ui/paginator.lua` | Logic move, no internal deps |
| 3 | `DrawDropdown` | `src/ui/components.lua` | `src/ui/dropdown.lua` | Logic move, calls `DrawRoundedRect`, contains `GetFitText` closure |
| 4 | Barrel re-export | — | `src/ui/components.lua` | `components.lua` requires all 3 modules and re-exports their functions |
| 5 | Keep in place | `DrawRoundedRect`, `DrawIsland` | — | Remain in `components.lua`, unchanged |

### Phase 3b — Piano, Pads, Slots, Drag

| # | Extract | Source | Target | Nature |
|---|---------|--------|--------|--------|
| 1 | `PIANO_LAYOUT`, cache vars, `DrawPianoKeyboard` | `src/ui/components.lua` | `src/ui/piano.lua` | Logic move, calls DrawRoundedRect + helpers/theme/colors internally |
| 2 | `DEGREE_KEY_LABELS`, `DrawScalePad` | `src/ui/components.lua` | `src/ui/pads.lua` | Logic + constant move, calls DrawRoundedRect + helpers/theme/colors/format/midi internally |
| 3 | `DrawSlotBackground`, `DrawSlotLabel`, `HandleSlotInteraction`, `DrawProgressionSlot` | `src/ui/components.lua` | `src/core/slots.lua` | Logic move (includes 3 private + 1 public), calls DrawRoundedRect + helpers/theme/colors/format/midi/progression internally |
| 4 | `DrawDragPreview` | `src/ui/components.lua` | `src/ui/drag.lua` | Logic move, calls DrawRoundedRect + helpers/theme/colors/format internally |
| 5 | Barrel re-export | — | `src/ui/components.lua` | `components.lua` requires all 4 modules and re-exports their functions |
| 6 | Keep in place | `DrawRoundedRect`, `DrawIsland` | — | Remain in `components.lua`, unchanged |

### Phase 3c — Desacoplar compact.lua

| # | Module | Source | Target | Contents |
|---|--------|--------|--------|---------|
| 1 | LICE | `src/ui/compact.lua` (lines 75–115) | `src/ui/lice.lua` | `DrawRoundedRectFill`, `DrawArrowIcon`, `DrawProgressBar`, `DrawModeHint` — LICE wrappers that receive bitmap/font as parameters (no direct `require("config")`) |
| 2 | Positioning | `src/ui/compact.lua` (lines 121–203) | `src/ui/positioning.lua` | `FindTransportWindow`, `ResetAutoPosition`, `SetManualPosition`, `FindTransportEmptyArea`, `GetTransportScreenRect` — layout math, reads `config.state` via parameter; `cv_x/y/w/h` exposed via getters |
| 3 | CompactBar | `src/ui/compact.lua` (lines 470–588) | `src/ui/bar.lua` | `DrawCompactBar`, `UpdateCompactView` — header draw, progress bar, mode icons, JS_Composite render; `restore_btn_x` exposed via getter |
| 4 | CompactPanel | `src/ui/compact.lua` (lines 213–330) | `src/ui/panel.lua` | `ClosePanel`, `HandlePanel`, `TogglePanel`, `IsPanelOpen` — floating GFX window, keyboard, pads, dropdowns, VEL toggle |
| 5 | Intercept | `src/ui/compact.lua` (lines 596–681) | `src/ui/intercept.lua` | `GetCompactZone`, `ProcessMouseInterception` — WM_LBUTTONDOWN/WM_RBUTTONDOWN routing, hit-test, post-menu guard; reads `menu_dismiss_time` via getter |
| 6 | CompactMenu | `src/ui/compact.lua` (lines 336–406) | `src/ui/menu_compact.lua` | `ShowContextMenu`, `menu_dismiss_time` setter — context menu build, `gfx.showmenu`, `gfx.init`/`gfx.quit` lifecycle; `menu_dismiss_time` exposed via getter |
| 7 | Remains in compact.lua | — | `src/ui/compact.lua` | `SwitchViewMode`, `InitOverlay`, `Cleanup`, barrel re-exports, shared state (`cv_x`, `cv_y`, `cv_w`, `cv_h`) |

## Constraints

- Every extracted function MUST behave identically to its previous inline definition.
- No function signature MAY change.
- No constant value MAY change.
- No state initialization semantics MAY change.
- The Lua module system (`local m = {}` + `return m`) SHALL be used for all new files.
- `components.lua` MUST re-export all extracted functions so consumer imports remain unchanged.
- No consumer file (`views.lua`, `compact.lua`, etc.) MAY require the new modules directly — all access SHALL remain through `components.*`.
- `DrawRoundedRect` SHALL remain accessible to extracted modules — either via shared import or parameter passing (design decision).
- The `GetFitText` closure (inside `DrawDropdown`) SHALL remain local to the extracted module — no external references exist.
- `DEGREE_KEY_LABELS` SHALL reside in `pads.lua` (its sole consumer) — NOT in `piano.lua`.
- Cached scale note tables (`cached_scale_root`, `cached_scale_idx`, `cached_scale_notes`, `cached_note_to_degree`) SHALL move with `DrawPianoKeyboard` into `piano.lua`.
- `DrawIsland` and `DrawRoundedRect` SHALL NOT be moved in this refactor cycle.
- Each extraction SHALL be an independent commit with its own verification.

### Phase 3c-specific

- `compact.CompactInit(params_table)`, `compact.Run()`, and all existing public function signatures SHALL remain identical.
- `BAR_H=26`, `CV_W=156`, `RESTORE_BTN_SIZE=12`, panel dimensions, and all dropdown option tables SHALL remain identical.
- Panel state (`panel_open`, `panel_inited`, etc.), intercept state (`intercept_active_l/r`), and positioning cache (`cv_auto_x`, `use_auto_pos`) SHALL init at module load time exactly as before.
- `compact.lua` MUST re-export all extracted public functions so consumer imports (`main.lua`, `views.lua`) remain unchanged.
- No consumer file MAY require the new modules directly — all access SHALL remain through `compact.*`.
- `lice.lua` MUST NOT call `require("config")` — bitmap/font SHALL be received as function parameters to avoid circular dependency.
- `cv_x`, `cv_y`, `cv_w`, `cv_h` SHALL remain as shared state in `compact.lua`, exposed via getter functions.
- `menu_dismiss_time` SHALL reside in `menu_compact.lua` and be exposed via `menu_compact.GetLastDismissTime()`, read by `intercept.lua`.
- `restore_btn_x` SHALL reside in `bar.lua` and be exposed via `bar.GetRestoreBtnX()`, read by `intercept.lua`.
- The MainLoop call order (`ProcessMouseInterception` → `UpdateCompactView` → `HandlePanel`) MUST be preserved in `compact.Run()`.

## Phase 3d — State Stores (Separar estado global en stores)

| Store | Keys | Affected files | Risk |
|-------|------|----------------|------|
| `state/compact.lua` | `compact.*` (4), `compact_overlay_active`, `last_gfx_state` | compact-init, compact-intercept, positioning, lice, midi, main | Low |
| `state/sequencer.lua` | `progression[]`, `sequencer.*` (8), `current_page`, `page_override_timer`, `slot_flash.*` | sequencer, slots, progression, midi, views, paginator | Low-Med |
| `state/drag.lua` | `drag.*` (9: is_dragging, source_degree, source_slot_idx, pending_degree, pending_slot_idx, start_x, start_y, x, y) | drag, pads, slots, views, buttons | Med |
| `state/midi.lua` | `use_velocity`, `last_note_played`, `active_note_draw_timer`, `key_states`, `active_notes`, `mouse_pad_state.*` | midi, keyboard, pads, compact-init, compact-bar, main, views | Med-High |
| `state/ui.lua` | `view_mode`, `show_tooltips`, `color_mode`, `last_mouse_cap`, `mouse_click`, `mouse_wheel_delta`, `auto_start_compact`, `auto_start_reaper`, `docked_mode`, `dock_id`, `did_cleanup`, `slider_dragging`, `pad_flash.*` | main, views, compact-init, compact-intercept, helpers, buttons, dropdown, paginator, piano, pads, slots, colors | High |

### Structural Requirements

#### Requirement: Store module pattern

Each store MUST define a local `the_state = {}` with default values for all managed keys, plus `GetX()`, `SetX(val)` per key, and `Init(defaults)` that merges defaults into `the_state` without overwriting existing keys.

##### Scenario: Getter returns last Setter value
- GIVEN a store instance with default state
- WHEN `SetX(val)` is called
- THEN `GetX()` MUST return `val`

##### Scenario: Init merges without overwrite
- GIVEN a store with default `foo = 1`
- WHEN `Init({foo = 99, bar = 2})` is called
- THEN `GetFoo()` MUST return 1 (existing default preserved)
- AND `GetBar()` MUST return 2 (new key added)

#### Requirement: Sub-table access

Sub-tables (`progression[]`, `mouse_pad_state.*`, `slot_flash.*`, `pad_flash.*`, `drag.*`, `compact.*`, `sequencer.*`) SHALL use key-level getters/setters: `GetProgression(idx)`, `SetProgression(idx, val)`, `GetMousePadStateActiveDegree()`, `SetSlotFlashTimer(n)`, etc. No direct table reference mutation — callers MUST go through getters/setters.

##### Scenario: Slot flash indexed access
- GIVEN `sequencer_store`
- WHEN `SetSlotFlashIdx(3)` then `SetSlotFlashTimer(10)` is called
- THEN `GetSlotFlashIdx()` MUST return 3
- AND `GetSlotFlashTimer()` MUST return 10

#### Requirement: Behavioral preservation — mouse_click

`mouse_click` SHALL use edge detection identically in both GFX contexts. The setter replaces `config.state.mouse_click = ...`; the getter replaces `config.state.mouse_click`.

##### Scenario: Single-frame edge in main context
- GIVEN main.lua run loop where `gfx.mouse_cap&1=1` and `last_mouse_cap=0`
- WHEN `SetMouseClick(true)` is called
- THEN `GetMouseClick()` MUST return true
- AND on next frame (no new edge) `GetMouseClick()` MUST return false

#### Requirement: Behavioral preservation — mouse_wheel_delta

`mouse_wheel_delta` SHALL preserve the zeroing pattern: written once per frame per GFX context, consumed via `GetMouseWheelDelta()`, zeroed via `SetMouseWheelDelta(0)` after each widget read.

##### Scenario: Per-context independence
- GIVEN two GFX contexts (main, compact-init)
- WHEN `SetMouseWheelDelta(5)` is called in main context
- THEN compact-init's `GetMouseWheelDelta()` MUST return 0 (no cross-contamination)
- AND main's `GetMouseWheelDelta()` MUST return 5

#### Requirement: Cross-store dependency

`sequencer.volume` is set by `views.lua` (UI) and read by `midi.lua` (core). The midi store MUST import the sequencer store and call `sequencer_store.GetVolume()`.

##### Scenario: Volume read from sequencer by midi store
- GIVEN midi store requires sequencer store
- WHEN `sequencer_store.SetVolume(75)` and then midi.lua calls `sequencer_store.GetVolume()`
- THEN it MUST return 75

### Remaining in config.state

`root_index`, `scale_index`, `octave`, `chord_mode_index`, `view_offset_x`, `view_offset_y`, `use_scroll` — 7 keys (~72 refs) stay in `config.state` unchanged.

## Verification

### Phase 3a Scenarios

- After each extraction commit, the script SHALL start without runtime errors (REAPER load + GFX init).
- All button interactions (hover, click, active state) SHALL render and respond identically before and after.
- All toolbar icons (settings, view, help, scroll, clear, export) SHALL render identically before and after.
- Note display SHALL render label, octave, and MIDI note number identically before and after.
- Paginator dots SHALL render, highlight, and respond to click identically before and after.
- Dropdown SHALL render label, value, arrow, respond to click menu and scroll wheel identically before and after.
- Transport buttons SHALL render and respond to click identically before and after.
- `DrawRoundedRect` SHALL render identically in all contexts (buttons, dropdown, note display, islands).
- Both expanded and collapsed UI modes SHALL work without errors.

### Phase 3b Scenarios

- After each extraction commit, the script SHALL start without runtime errors (REAPER load + GFX init).
- Piano keyboard SHALL render all 73 keys, respond to click (root note change), and show scale note indicators identically before and after.
- Scale pads SHALL render chord labels and roman numerals, respond to hover, click-to-play, and QWERTY shortcuts identically before and after.
- Progression slots SHALL render background, label, slot number, progress bar, and flash overlay identically before and after.
- Drag-from-pad → drop-on-slot SHALL create a new slot entry identically before and after.
- Drag-from-slot → drop-on-another-slot SHALL swap slots identically before and after.
- Drag preview (compact floating card) SHALL follow cursor and display correct label identically before and after.
- Right-click delete on slots SHALL work identically before and after.
- Slot flash on drop SHALL render identically before and after.
- Pad flash on activation SHALL render identically before and after.
- Both expanded and collapsed UI modes SHALL work without errors.
- `DrawRoundedRect` and `DrawIsland` SHALL render identically in all remaining contexts.

### Phase 3c Scenarios

- After each extraction, the script SHALL start without runtime errors (REAPER load + GFX init).
- The compact bar (JS_Composite) SHALL render key/scale/octave/chord text and restore button identically before and after.
- Left-click on bar content SHALL toggle the floating panel identically before and after.
- Left-click on restore button SHALL switch view mode identically before and after.
- Right-click on bar content SHALL show context menu identically before and after.
- Right-click on restore button SHALL switch view mode identically before and after.
- Context menu SHALL set root/scale/octave/chord, export MIDI, panic, adjust position identically before and after.
- Floating panel SHALL init, render piano + dropdowns + VEL toggle, auto-reposition, and close identically before and after.
- `compact.Cleanup()` SHALL release all intercepts, destroy LICE resources, close panel, and reset state identically before and after.
- `compact.InitOverlay()` SHALL set up overlay mode identically before and after.
- All 7 sub-modules SHALL export the correct functions as specified in the Extractions table.
- The barrel (`compact.lua`) SHALL re-export all public functions so consumers (`main.lua`, `views.lua`) continue to work unchanged.
- No circular requires SHALL exist in the module dependency graph.

### Phase 3d Scenarios

- Runtime behavior preservation: GIVEN all 5 stores created and consumer imports updated (13 files), WHEN the script runs in REAPER (both main and compact GFX contexts), THEN all UI interactions, MIDI output, drag-and-drop, pagination settings, and compact panel behavior SHALL be identical to pre-refactor AND no runtime errors SHALL occur during init, run loop, or cleanup.
- No config.state references for extracted keys: GIVEN the refactor is applied, WHEN grepping `config.state\.` for all extracted keys, THEN there SHALL be zero matches — all access goes through store getters/setters.

## Review Workload (Phase 3c)

- Estimated extraction: ~620 LOC across 6 new files + compact.lua reduction (~721→~80 LOC)
- **400-line budget risk**: High — 2 chained PRs recommended:
  - **PR 1**: lice + positioning + bar (~300 LOC, zero circular deps)
  - **PR 2**: panel + intercept + menu_compact + compact.lua wiring (~355 LOC)

## Review Workload (Phase 3d)

- Estimated store creation: ~700–950 LOC across 5 new store files + 13 file updates for imports
- **400-line budget risk**: High — 5 PRs in chain (menor a mayor riesgo):
  - **PR 1**: compact store (~60–80 LOC)
  - **PR 2**: sequencer store (~120–160 LOC)
  - **PR 3**: drag store (~150–200 LOC)
  - **PR 4**: midi store (~100–150 LOC)
  - **PR 5**: ui store (~250–350 LOC)
