# Tasks: agents-infra

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,295 (286 del + 1,009 add) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | 5 chained PRs via feature-branch-chain |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain (tracker: `feature/agents-infra`) |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Base | Notes |
|------|------|-----------|------|-------|
| 1 | Rewrite `src/core/AGENTS.md` (P0) | PR 1 | `feature/agents-infra` | ~227 changed lines. Fix critical circular-dependency lie. |
| 2 | Rewrite root `AGENTS.md` (P1) | PR 2 | PR 1 branch | ~249 changed lines. Metrics, patterns, issues registry. |
| 3 | Rewrite `src/AGENTS.md` + `src/state/AGENTS.md` (P1+P2) | PR 3 | PR 2 branch | ~377 changed lines. Lifecycle, config API, 5 stores. |
| 4 | Rewrite `src/ui/AGENTS.md` (P2) | PR 4 | PR 3 branch | ~278 changed lines. 19 files, GFX rules, widgets. |
| 5 | Rewrite `tests/AGENTS.md` (P3) | PR 5 | PR 4 branch | ~164 changed lines. Reality check, contradiction, roadmap. |

## Phase 1: Core Domain Logic Guide (P0) — PR 1

Target: `src/core/AGENTS.md` (27→200 LOC)

- [ ] 1.1 Write file overview table (5 modules: midi, keyboard, sequencer, progression, slots)
- [ ] 1.2 Write core dependency graph (ASCII + table) — document sequencer→midi→sequencer_store cycle
- [ ] 1.3 Document midi.lua: GetMidiNote, SendMidi, TriggerChord, AllNotesOff, ExportToMidi, ToggleIsland (7 functions)
- [ ] 1.4 Document keyboard.lua: HandleKeyboard, InterceptMappedKeys, IsPluginOrScriptFocused, CheckFocus, Cleanup (5 functions)
- [ ] 1.5 Document sequencer.lua: Run, Stop (2 functions)
- [ ] 1.6 Document progression.lua: Add, Remove, Swap, Clear, GetLastFilled (5 functions)
- [ ] 1.7 Document slots.lua: DrawProgressionSlot, HandleSlotInteraction (2 public + 3 private helpers)
- [ ] 1.8 Write Patterns section (ref-counted notes, temp_ctx, velocity humanization, AllNotesOff on focus loss, catch-up loop, auto-page, drag threshold 8px, swap vs overwrite)
- [ ] 1.9 Write Pitfalls section (sequencer→midi circular, GetMidiNote no clamp, ToggleIsland no docked, AllNotesOff no Stop, ExportToMidi 4/4, lazy require circular, temp_ctx shared)

**Correction**: Replace "sequencer.lua NO requiere midi.lua" with accurate dependency graph showing `sequencer.lua` requires `core.midi`, and `midi.lua` reads `sequencer_store` (not `sequencer.lua`).

**Cross-refs**: `AGENTS.md` (root), `src/AGENTS.md`, `src/state/AGENTS.md`

## Phase 2: Root Orchestration Guide (P1) — PR 2

Target: `AGENTS.md` (root, 69→180 LOC)

- [ ] 2.1 Add project metrics section (33 src files, ~3200 TLOC, 5 stores, 19 ui, 1 test)
- [ ] 2.2 Expand agent hierarchy table with delegation scope per agent
- [ ] 2.3 Write circular dependency MAP (ASCII graph: sequencer→midi→sequencer_store, components↔widgets via lazy require, compact-init↔compact-*)
- [ ] 2.4 Write init/teardown contract (store order: compact→drag→sequencer→midi→ui; main.lua Init→MainLoop→CleanupAll)
- [ ] 2.5 Write pattern glossary (ref-counted notes, barrel, lazy require, event bus, temp_ctx, consume — 2-3 sentences each)
- [ ] 2.6 Write remnant keys table (root_index, scale_index, octave, chord_mode_index, view_offset_x/y)
- [ ] 2.7 Write issue registry (Issues 5-21: drag release, glyph support, transport fallback, page override timer, dropdown open_up, auto-position cache, temp_ctx, piano cache, O(1) active notes, GetLastFilled cache, velocity humanization)
- [ ] 2.8 Write delegation protocol and knowledge auto-update rules

**Correction**: None (root skeleton is correct, just incomplete).

**Cross-refs**: all 5 child AGENTS.md files

## Phase 3: Entry Point + State Guides (P1+P2) — PR 3

Target: `src/AGENTS.md` (41→150 LOC) + `src/state/AGENTS.md` (46→140 LOC)

### src/AGENTS.md
- [ ] 3.1 Expand directory structure with file purposes
- [ ] 3.2 Write main.lua lifecycle: init order (stores→theme→midi→sequencer→views→compact→keyboard), 3 MainLoop branches (COMPACT/overlay/FULL), CleanupAll sequence
- [ ] 3.3 Write config.lua API: SCALES (21), CHORD_MODES (4), VKEY_MAP (28), NOTE_NAMES, VIEW_MODES, defaults
- [ ] 3.4 Write external requirements (js_ReaScriptAPI functions: JS_VKeys_GetState, JS_Window_*, JS_Composite, JS_LICE_*, LICE fonts)
- [ ] 3.5 Write init order contract + atexit guard (`did_cleanup` check)
- [ ] 3.6 Write pitfalls (init order, gfx.quit() overlay, ToggleIsland gfx.quit()+gfx.init(), JS_VKeys_GetState byte access, config.state reference mutation)

### src/state/AGENTS.md
- [ ] 3.7 Write store overview table (5 stores, ~90 getters/setters total)
- [ ] 3.8 Write store module pattern with template
- [ ] 3.9 Document init merge semantics (what's shared by ref vs copied per store)
- [ ] 3.10 Document compact store (6 pairs: transport_hwnd, lice_bitmap, lice_font, gdi_font, overlay_active, last_gfx_state)
- [ ] 3.11 Document drag store (8 pairs + Reset)
- [ ] 3.12 Document sequencer store (progression[16], is_playing, current_step, last_measure, midi_notes, progress, internal_beats, last_time, volume, current_page, page_override_timer, slot_flash.*)
- [ ] 3.13 Document midi store (use_velocity, last_note_played, active_note_draw_timer, key_states, active_notes, mouse_pad_state, ClearActiveNotes)
- [ ] 3.14 Document ui store (13 pairs + ConsumeMouseClick, ConsumeMouseWheelDelta + pad_flash sub-table)
- [ ] 3.15 Write consume pattern docs + mutable table warnings + remnant keys

**Correction**: None currently.

**Cross-refs**: `AGENTS.md` (root), `src/core/AGENTS.md`, `src/ui/AGENTS.md`

## Phase 4: UI Guide (P2) — PR 4

Target: `src/ui/AGENTS.md` (58→220 LOC)

- [ ] 4.1 Write file map (~19 files grouped: core UI, widgets, compact view, utilities)
- [ ] 4.2 Write dual GFX context rules (main vs compact-init, never both open)
- [ ] 4.3 Document views.lua: DrawFullView, DrawHeader, DrawIslands, DrawPerformanceArea, DrawMIDIIsland, DrawDockedTransportBar, DecrementPageOverrideTimer (7 functions)
- [ ] 4.4 Document layout.lua: CANVAS_W/H, UX/UY/US formulas, SetScale lifecycle
- [ ] 4.5 Document compact view lifecycle: SwitchViewMode, InitOverlay, HandlePanel, UpdateCompactView, Cleanup
- [ ] 4.6 Document widget APIs: buttons (DrawToolIcon, DrawNoteDisplay, DrawButton, DrawTransportButton), pads (DrawScalePad with full side effects), piano (DrawPianoKeyboard, root_index mutation), dropdown (DrawDropdown, open_up param), paginator (DrawPaginator, page mutation), drag (DrawDragPreview)
- [ ] 4.7 Document LICE API (EnsureLICE, DrawRoundedRectFill, DrawArrowIcon, DrawProgressBar, DrawModeHint)
- [ ] 4.8 Document intercept rules (WM_LBUTTONDOWN passthrough=true, WM_RBUTTONDOWN passthrough=false, zone hit-testing)
- [ ] 4.9 Write patterns section (dual GFX context, delta lifecycle, scroll convention, mouse_click event bus, barrel, lazy require)
- [ ] 4.10 Write pitfalls section (dual GFX context, gfx.mouse_wheel zeroed, lazy require circular, DrawFullView scale formula, HandlePanel first frame skip, post-menu guard, WM_RBUTTONDOWN passthrough=false, ToggleIsland no docked, docked mode pixel coords)

**Correction**: None currently.

**Cross-refs**: `src/AGENTS.md`, `src/state/AGENTS.md`, `AGENTS.md` (root)

## Phase 5: Testing Guide (P3) — PR 5

Target: `tests/AGENTS.md` (44→120 LOC)

- [ ] 5.1 Write reality-check inventory: only `tests/test_midi.lua` EXISTS; `tests/run.lua`, `tests/helpers.lua`, `tests/mock/*`, `test_stores.lua`, `test_progression.lua` are FICTIONAL
- [ ] 5.2 Analyze test_midi.lua: document what it tests (GetMidiNote only), what it doesn't (SendMidi, TriggerChord, AllNotesOff, ExportToMidi, ToggleIsland)
- [ ] 5.3 Document contradiction: test_midi.lua copies GetMidiNote logic + mock config tables instead of requiring `src.core.midi`
- [ ] 5.4 Write coverage gaps table (module × function × testability)
- [ ] 5.5 Propose mock architecture (reaper.lua mock, gfx.lua mock — minimum needed functions)
- [ ] 5.6 Write refactor roadmap (4 steps: create mock infra, refactor test_midi.lua to require real module, add store tests, add core tests)
- [ ] 5.7 Write test writing guidelines (mock minimum, deterministic, self-contained tests, exit code convention)
- [ ] 5.8 Remove ALL references to non-existent files from delegation rules and cross-refs

**Corrections**:
- Replace fictional file table with reality-check inventory
- Document test_midi.lua logic-copy contradiction as KNOWN ISSUE + roadmap to fix
- Remove all references to tests/run.lua, helpers.lua, mock/*, test_stores.lua, test_progression.lua

**Cross-refs**: `src/core/AGENTS.md`, `AGENTS.md` (root)
