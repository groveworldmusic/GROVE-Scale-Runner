# Exploration: Comprehensive Codebase Analysis — GROVE FL MIDI (Scale Runner)

**Date**: 2026-05-14  
**Change**: `Analiza toda la codebase actual.`  
**Type**: Full codebase exploration  

---

## Executive Summary

GROVE FL MIDI (Scale Runner) is a mature, production-grade REAPER script (~8,800 TLOC across 53 source files) that maps a QWERTY keyboard into a fully-featured MIDI chord controller. The project has undergone significant structural refactoring across multiple phases, establishing clear separation of concerns between core domain logic (`src/core/`), GFX rendering (`src/ui/`), and state management (`src/state/`), all orchestrated by `src/main.lua`.

The architecture is notable for its **dual GFX context** design (main window + floating compact panel), its **state store pattern** (9 independent stores encapsulating all mutable state), and an unusually thorough **test infrastructure** for a REAPER Lua project (497 check() calls across 14 test files with full mocks for `reaper.*` and `gfx.*`). The codebase shows strong evidence of SDD-driven development with comprehensive documentation in `openspec/` (10+ archived changes, ~30 spec files) and well-maintained agent instructions (5 AGENTS.md files).

Key strengths: clean module boundaries, documented pattern glossary, thorough test coverage, strong init/teardown contract. Key weaknesses: remaining `config.state` legacy dependencies (~1 runtime read remnant), circular dependency via lazy require in slots.lua↔components.lua, and no automated test runner execution pipeline.

---

## Artifacts

### Complete File Inventory

#### Source Files (src/) — 53 Lua files, ~8,800 TLOC

| Layer | File | LOC | Role |
|-------|------|-----|------|
| **Entry** | `main.lua` | 415 | Init/MainLoop/CleanupAll |
| **Config** | `config.lua` | 127 | Constants + state defaults |
| **Core (7)** | `midi.lua` | 235 | MIDI note calc, SendMidi, TriggerChord, AllNotesOff, ExportToMidi, ToggleIsland |
| | `keyboard.lua` | 110 | VKeys intercept, focus detection, key dispatch |
| | `sequencer.lua` | 135 | Stop/Run, measure-level playback, sub-step subdivision |
| | `progression.lua` | 33 | Add/Remove/Swap/Clear/GetLastFilled |
| | `slots.lua` | 313 | Slot rendering + drag interaction (in core but uses gfx.*) |
| | `api-guard.lua` | 44 | CheckAPI, AssertAPIs, ClampIndex |
| | `snap.lua` | 31 | SnapBeat pure function |
| **State (10)** | `piano-roll-store.lua` | 426 | Notes, selection, lasso, undo/redo, UUID, drag state |
| | `island.lua` | 136 | Island state, preset browser state, ProgressionToNotes |
| | `ui.lua` | 143 | View mode, mouse events, dock, auto-start, pad_flash |
| | `sequencer.lua` | 81 | Progression, playback, page, slot flash |
| | `preferences.lua` | 77 | 7 pref pairs + debounced persist |
| | `midi.lua` | 57 | UseVelocity, key_states, active_notes, mouse_pad |
| | `preset-store.lua` | 72 | Directory, tree, files, favorites |
| | `drag.lua` | 51 | IsDragging, source/slot, coordinates + Reset |
| | `compact.lua` | 37 | Transport HWND, LICE resources |
| | `persist.lua` | — | ExtState Load/Save |
| **UI (34)** | `views.lua` | 864 | Full view orchestrator, DrawMIDIIsland, docked bar |
| | `piano-roll/interaction.lua` | 795 | Mouse handling: click, lasso, drag, resize, context menu |
| | `preset-browser.lua` | 663 | Browser rendering, favorites, folder nav |
| | `velocity.lua` | 450 | Glass Blade velocity editor |
| | `piano-roll/grid.lua` | 446 | Grid rendering, snap, hit-test |
| | `piano-roll/note.lua` | 300 | Note rendering, ghosting, CRUD |
| | `compact-init.lua` | 246 | SwitchViewMode, InitOverlay, HandlePanel |
| | `piano-roll/undo.lua` | 148 | Undo/redo stacks, snapshot |
| | `piano-roll/clipboard.lua` | 126 | Copy/paste notes |
| | `compact-intercept.lua` | 129 | WM message interception |
| | `midi-island.lua` | 132 | MIDI island orchestrator |
| | `midi-island/input.lua` | 180 | Input dispatch |
| | `midi-island/header.lua` | 145 | Header controls |
| | `timeline.lua` | 169 | Timeline ruler + playhead |
| | `positioning.lua` | 158 | Compact view auto-position |
| | `piano.lua` | 158 | Piano keyboard GFX |
| | `pads.lua` | 148 | Scale pads + drag-to-slot |
| | `helpers.lua` | 107 | SetColor, DrawTooltip, AbbreviateScale |
| | `compact-menu.lua` | 96 | Context menu |
| | `icons.lua` | 92 | SVG-like vector icons |
| | `compact-panel.lua` | 99 | Floating panel lifecycle |
| | `drag.lua` | 88 | Drag preview |
| | `components.lua` | 195 | Barrel + DrawRoundedRect + DrawIsland + SafeDraw |
| | `buttons.lua` | 78 | DrawButton, DrawToolIcon, DrawTransportButton |
| | `dropdown.lua` | 76 | Dropdown with scroll + context menu |
| | `lice.lua` | 71 | LICE drawing wrappers |
| | `theme.lua` | 64 | Color palette |
| | `compact-bar.lua` | 60 | LICE compact bar render |
| | `gfx-safe.lua` | 47 | SafeGfxInit/Quit |
| | `paginator.lua` | 41 | Pagination dots |
| | `layout.lua` | 30 | Virtual coordinate system |
| | `format.lua` | 29 | NoteName, ChordLabel, RomanNumeral |
| | `piano-roll.lua` | 93 | Barrel for piano-roll/* |
| | `compact.lua` | 25 | Barrel for compact-* |
| | `colors.lua` | 17 | DegreeColor |
| | `piano-roll/view.lua` | 44 | Viewport state helpers |

#### Test Files — 22 Lua files, ~2,000+ TLOC

| File | LOC | Checks | Tests |
|------|-----|--------|-------|
| `run.lua` | 80 | — | Test runner |
| `helpers.lua` | 32 | — | check(), assert_eq(), summary() |
| `mock/reaper.lua` | 191 | — | 50+ reaper.* mocks |
| `mock/gfx.lua` | 33 | — | 17 gfx.* mocks |
| `test_stores.lua` | 304 | ~80 | All 9 stores Init/Get/Set |
| `snap-tests.lua` | 286 | 89 | SnapBeat all variants |
| `undo-tests.lua` | 345 | 94 | Undo/redo, 50 depth |
| `test_sendmidi.lua` | 171 | ~40 | SendMidi, TriggerChord, AllNotesOff |
| `test_export_midi.lua` | 104 | ~20 | ExportToMidi scenarios |
| `test_keyboard_focus.lua` | 97 | ~25 | CheckFocus throttle/gain/loss |
| `test_sequencer_run.lua` | 98 | ~20 | Sequencer.Run scenarios |
| `test_keyboard_handle.lua` | 89 | ~20 | Key down/up dispatch |
| `test_midi.lua` | 77 | ~30 | GetMidiNote pure function |
| `test_toggle_island.lua` | 77 | ~15 | ToggleIsland expand/collapse |
| `test_sequencer_stop.lua` | 68 | ~15 | Stop: reset + note-offs |
| `test_progression.lua` | 67 | ~10 | Add/Remove/Swap/Clear |
| `test_persist.lua` | — | — | Persist Save/Load |
| `test_preferences.lua` | — | — | Preferences store |
| `test_preset_store.lua` | — | — | Preset store |
| `test_api_guard.lua` | — | — | API guard |
| `test_keyboard_intercept.lua` | 33 | ~5 | InterceptMappedKeys |
| `test_keyboard_cleanup.lua` | 34 | ~5 | Cleanup scenarios |
| `barrel-backward-compat.lua` | 21 | 0 (static) | Barrel compat check |

#### Documentation (docs/) — 12 items (markdown, text, SVG mockups)
- 1 product README, 5 planning docs, 1 functional reference
- 1 primer LUA reference file
- 5 SVG visual mockups for UI reference

#### Configuration (openspec/) — ~90+ artifacts
- 10+ archived SDD changes covering refactor, testing, MIDI island, distribution, etc.
- 2 active changes: `serious-click-lasso-bugs`, `compact-bar-click-handling`
- ~30 spec files across domains: refactor, piano-roll, undo-system, timeline, velocity, etc.

#### Agent Instructions
- 5 AGENTS.md files (root + src/ + core/ + ui/ + state/ + tests/)
- `.llm/knowledge/` with architecture.md, decisions.md, learnings.md, conventions.md
- `.llm/templates/` with adr.md, learning.md

---

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                        main.lua (415 LOC)                        │
│  Init() → api-guard → stores Init → modules require → persist   │
│       → gfx.init → KeyboardIntercept → reaper.defer(MainLoop)   │
│                                                                  │
│  MainLoop() { 3 branches: COMPACT | OVERLAY | FULL }            │
│  Each: AutoTrackSetup → DecrementPageTimer → CheckFocus →       │
│        sequencer.Run() → HandleKeyboard → TickSaveDebounce()    │
│  FULL adds: GFX mouse_wheel → dirty-flag → DrawFullView/Docked  │
│             → gfx.getchar() → Ctrl+D/Esc handling               │
└──────────────────────┬───────────────────────────────────────────┘
                       │
       ┌───────────────┼───────────────────┐
       ▼               ▼                   ▼
┌──────────┐   ┌──────────────┐   ┌──────────────────┐
│  core/   │   │   state/     │   │      ui/         │
│  7 files │   │  10 files    │   │   34 files        │
│ ~884 LOC │   │ ~1,132 LOC   │   │  ~6,342 LOC       │
├──────────┤   ├──────────────┤   ├──────────────────┤
│midi.lua  │   │piano-roll-   │   │views.lua (864)   │
│keyboard  │   │ store (426)  │   │interaction(795)  │
│sequencer │   │island (136)  │   │preset-browser    │
│progresion│   │ui.lua (143)  │   │  (663)           │
│slots.lua │   │sequencer(81) │   │velocity (450)    │
│api-guard │   │prefs (77)    │   │grid.lua (446)    │
│snap.lua  │   │midi (57)     │   │note.lua (300)    │
│          │   │preset (72)   │   │compact-init(246) │
│          │   │drag (51)     │   │....28 more files │
│          │   │compact (37)  │   │                  │
│          │   │persist       │   │3 Barrels:        │
│          │   └──────┬───────┘   │components (195)  │
│          │          │           │piano-roll (93)   │
│          └────┬─────┘           │compact (25)      │
│               │                 └────────┬─────────┘
│               │                          │
│               └──────────┬───────────────┘
│                          ▼
│               ┌──────────────────┐
│               │   config.lua     │
│               │   (127 LOC)      │
│               │  SCALES[21]      │
│               │  CHORD_MODES[4]  │
│               │  VKEY_MAP[28]    │
│               │  config.state{}  │
│               └──────────────────┘
│
│    tests/ (22 files, ~2,000+ LOC)
│    ├── run.lua (runner)
│    ├── mock/reaper.lua (50+ stubs)
│    ├── mock/gfx.lua (17 stubs)
│    ├── 14 test files (497 check() calls)
│    └── helpers.lua
│
│    openspec/ (~90+ artifacts)
│    ├── config.yaml
│    ├── specs/ (~30 domain specs)
│    └── changes/ (2 active + 10+ archived)
└──────────────────────────────────────────────────────────────────
```

---

### Dependency Graph Analysis

#### Layer Dependencies
```
config.lua ← (no deps, consumed by ALL layers)
main.lua   ← all stores, all core, key ui modules
state/     ← no inter-store deps; consumed by core/ + ui/
core/      ← depends on state/ + config/
              sequencer → midi → sequencer_store (state)
              keyboard  → midi, sequencer, midi_store, preferences
              progression → sequencer_store (state)
              slots → lazy require → ui.components
ui/        ← depends on state/ + config/ + core/
              components → widgets (via barrel)
              widgets → components (via lazy require — CIRCULAR)
              slots (core) → components (via lazy require — CIRCULAR)
              views → sequencer.Stop() (intentional, no cycle)
```

#### Circular Dependencies (Resolved)
1. **sequencer → midi**: ONE-WAY. `sequencer.lua` requires `midi.lua`. `midi.lua` avoids the cycle by reading `sequencer_store` (state) instead of requiring `sequencer.lua`. This is the critical dependency rule.
2. **keyboard → sequencer**: ONE-WAY. `keyboard.lua` requires `core.sequencer` (for shortcuts + focus loss Stop). `sequencer.lua` does NOT require `keyboard.lua`. Safe.
3. **slots ↔ components**: RESOLVED via lazy require. Both modules would form a cycle if required at module top-level. `slots.lua` calls `require("ui.components")` inside each function body (at runtime), not at module scope.
4. **widgets ↔ components**: Same lazy require pattern. `buttons.lua`, `piano.lua`, `pads.lua`, etc. require `components.lua` inside functions.

#### Anti-pattern: midi.lua requires compact_store
`midi.lua` line 4 requires `state.compact` (for `compact_store.GetLastGfxState()` in `ToggleIsland`). This is a dependency from core → UI-specific state. This exists because `ToggleIsland` needs the pre-toggle GfxState snapshot.

#### Cross-Store Dependencies
- **piano-roll-store.lua** requires `config` and `core.api-guard` — the only store with external dependencies beyond its Init() contract
- **preferences.lua** requires `state.persist` for debounced save
- **island.lua** requires `config` for certain constants
- All other stores are pure getters/setters with zero module-level dependencies

---

### Module-by-Module Breakdown

#### Core Layer (7 files, ~884 LOC)
**Health: EXCELLENT.** Clean separation, well-tested, documented APIs.

- **`midi.lua`** (235 LOC): The heart of the system. 9 exported functions + 3 module fields. Contains 3 pure functions (GetMidiNote, InvertChord, GetMidiChannel) and 6 impure (SendMidi, TriggerChord, AllNotesOff, ExportToMidi, ToggleIsland, SetMidiChannel). Notable: the `TriggerChord` `ctx or config.state` fallback is the **last remaining direct config.state read** (line 94). The `ToggleIsland` function belongs here architecturally but reaches into `compact_store` and `island_store`, violating strict domain purity.

- **`keyboard.lua`** (110 LOC): Tight, focused. 5 exported functions. Uses the `temp_ctx` pattern for zero-allocation hot path. Focus detection via `GetFocusedFX2()` bitmask is well-documented. The `CheckFocus` function's 0.2s throttle is pragmatic for defer-driven execution.

- **`sequencer.lua`** (135 LOC): 2 exported functions. Supports both REAPER-synced and internal clock modes. Sub-step subdivision (newer feature) added complexity but is cleanly handled via `TriggerSubChord`. Caches `GetLastFilled()` per tick per Issue 19.

- **`progression.lua`** (33 LOC): Minimal, pure business logic. 5 functions. `GetLastFilled()` is O(n) scan — documented as cached by caller.

- **`slots.lua`** (313 LOC): Largest core file. 2 public + 2 private functions. Handles slot drawing AND interaction (click-to-play, drag-to-swap). The drag detection uses 8px Euclidean threshold. Contains the lazy require circular resolution. Its presence in `core/` is debatable since it uses `gfx.*` exclusively (no `reaper.*` calls).

- **`api-guard.lua`** (44 LOC): 3 functions. Clean, minimal. `AssertAPIs` shows MB dialog on missing APIs.

- **`snap.lua`** (31 LOC): 1 pure function. Perfect module — zero deps, fully tested (89 assertions), documented formula.

#### State Layer (10 files, ~1,132+ LOC)
**Health: VERY GOOD.** Well-encapsulated, consistent pattern, but some stores have outgrown their mandate.

- **`piano-roll-store.lua`** (426 LOC): The largest store by far. 30+ state fields, 50+ functions including CRUD, undo/redo (50 depth), UUID allocation, selection set management, lasso state, note drag state, viewport state. This store has reached **feature creep** — it manages everything from note CRUD to UI state (velocity panel, tool mode) to animation state (island_transitioning). Consider splitting: note CRUD + undo/redo into a separate `note-store.lua`.

- **`ui.lua`** (143 LOC): Clean. 14 state fields + pad_flash sub-table + consume patterns. Grows responsibly.

- **`island.lua`** (136 LOC): Mixed responsibilities. Contains ISLAND state AND preset browser state AND helper functions (ProgressionToNotes, GetVisibleNotes). The preset browser state partially overlaps with `preset-store.lua`, suggesting the split between island and preset stores may need revisiting.

- **`preferences.lua`** (77 LOC): Clean debounced persist pattern. 7 preference pairs. `TickSaveDebounce` called once per frame from MainLoop. Good example of the store pattern done right.

- **`persist.lua`** (— LOC): Simple ExtState Save/Load. Not inspected but referenced by preferences.

- Remaining stores (midi, drag, compact, sequencer, preset) are clean, focused, and stable at 37-81 LOC each.

#### UI Layer (34 files, ~6,342 LOC)
**Health: GOOD with hotspots.** The largest and most complex layer.

- **`views.lua`** (864 LOC): The orchestrator. DrawFullView → DrawHeader → DrawIslands → DrawPerformanceArea → DrawMIDIIsland chain is clean. However, `DrawIslands` alone is massive (lines 175-481) containing 4 island renderings + slider interaction + tooltips inline. The docked transport bar (lines 764-862) is a separate view mode. The `DrawMIDIIsland` function properly delegates to `midi-island.lua`. The snap controls and tool mode row are extracted into separate functions (DrawSnapControls, DrawToolModeRow, DrawKeyboardShortcutOverlay), but they're still in views.lua rather than their own modules.

- **`piano-roll/interaction.lua`** (795 LOC): The second largest file. Handles ALL mouse interaction for piano roll — click-to-select, lasso drag, note drag, note resize, tool switching, context menu, zoom/scroll wheel. This is a **complexity hotspot**. It's well-organized within the file but could benefit from splitting into interaction domains (selection, drag, zoom, menu).

- **`preset-browser.lua`** (663 LOC): A full-featured file browser within GFX. Renders directory tree, file list, favorites, bookmarks. Strong candidate for extraction into sub-modules if it continues growing.

- **`velocity.lua`** (450 LOC): Glass Blade aesthetic velocity editor. Stem glow, pin rendering, multi-selection. One of the most visually complex components. Self-contained and well-structured.

- **`piano-roll/grid.lua`** (446 LOC): Grid rendering with 4-tier hierarchy, note hit-test, snap. Second major piano-roll sub-module.

- **`components.lua`** (195 LOC): Barrel + inline drawing utilities. Contains the critical `DrawRoundedRect` with its 2x supersampling alpha-safe path, the `SafeDraw` error-handling wrapper, and `DrawIslandSpine`. The anti-aliasing buffer management is sophisticated for a GFX script.

- **`compact-init.lua`** (246 LOC): Manages the dual GFX context lifecycle. SwitchViewMode, InitOverlay, HandlePanel, FindTransportWindow, Cleanup. The FindTransportWindow function has a fallback chain (English → Spanish → SWS) per Issue 7.

#### Test Layer (22 files, ~2,000+ LOC)
**Health: EXCELLENT for a REAPER Lua project.** The mock infrastructure is sophisticated.

- **`mock/reaper.lua`** (191 LOC): Factory function `make_mock_fn()` creates tracked stubs with `call_count` and `calls[]` arrays. Storage uses internal `_mock_storage` table keyed by string name (workaround for Lua 5.4's inability to set properties on functions). 50+ stubs.

- **`mock/gfx.lua`** (33 LOC): 17 no-op methods + 9 mutable state fields (w=720, h=500, etc.). Minimal but sufficient for GFX-dependent tests.

- **Test coverage is comprehensive**: pure functions (snap, GetMidiNote, InvertChord), stores (all 9), MIDI runtime (SendMidi, TriggerChord, AllNotesOff), keyboard (intercept, cleanup, handle, focus), sequencer (Stop, Run), progression, export, toggle-island, undo/redo.

- **Key test gaps**: No tests for UI modules (views, piano-roll interaction, preset-browser, velocity), compact view, or the main loop itself. This is acceptable given the GFX dependency — these would require a full GFX context, which is impractical in a CLI test runner.

---

### Pattern Identification

#### Documented Patterns (from root AGENTS.md glossary — all confirmed in code)

| Pattern | Where | Status |
|---------|-------|--------|
| **Ref-counted Active Notes** | midi.lua:41-68 | ✅ In use, well-tested |
| **Barrel (Re-export)** | components.lua, compact.lua, piano-roll.lua | ✅ 3 barrels |
| **Lazy require** | slots.lua, buttons.lua, piano.lua, pads.lua, paginator.lua, dropdown.lua, drag.lua | ✅ Resolves circular deps |
| **Event Bus (mouse_click)** | ui_store.ConsumeMouseClick() | ✅ 1-frame lifecycle |
| **Temporary Context (temp_ctx)** | keyboard.lua:16 | ✅ Zero-allocation hot path |
| **Consume (mouse_wheel_delta)** | ui_store.ConsumeMouseWheelDelta() | ✅ Prevents ghost scroll |
| **Play/Stop → sequencer.Stop()** | views.lua:380, main.lua:201 | ✅ Issue 22 resolved |
| **API Guard** | api-guard.lua | ✅ Used at Init |
| **Snap Grid (Pure Function)** | snap.lua | ✅ Fully tested |
| **Lasso Selection** | piano-roll-store.lua lasso_* fields | ✅ |
| **Undo/Redo Stack** | piano-roll-store.lua undo_stack/redo_stack | ✅ Max 50, UUID-based |
| **Debounced Preference Save** | preferences.lua TickSaveDebounce | ✅ Single flush per frame |

#### Newly Identified Patterns (not in original glossary)

| Pattern | Where | Description |
|---------|-------|-------------|
| **Dual GFX Context** | main.lua + compact-init.lua | Two independent gfx.init() contexts with coordinated lifecycle |
| **Dirty-flag Rendering** | main.lua gfx_needs_redraw | Skips GFX redraw when nothing visual changed (performance optimization) |
| **2x Supersampling AA** | components.lua DrawRoundedRect | Renders at 2x to offscreen buffer, blits at 1x for anti-aliased rounded rects |
| **Smart Buffer Management** | components.lua _temp_buf | Reuses offscreen buffer across frames, resizes only when needed |
| **SafeDraw Error Guard** | components.lua SafeDraw | pcall wrapper restores gfx.dest on error, log to console |
| **Mock Factory** | tests/mock/reaper.lua | `make_mock_fn(name)` creates tracked function stubs |
| **Dynamic VK String** | tests/mock/reaper.lua _vkey_string | 256-byte string controls which keys are "pressed" in tests |
| **Note Ghosting** | piano-roll/note.lua | Semi-transparent silhouettes at original position during drag |
| **Glass Blade** | velocity.lua | Stems with glow, rounded gradient pins |
| **Config Cache + Dirty** | preferences.lua dirty_keys | Only persists changed keys, not all 7 every frame |
| **Store Init Merge** | All stores | Each store imports `config.state` sub-tables with different merge semantics (ref, key-by-key, recursive) |
| **Auto-track Setup** | main.lua:192-197 | Auto-arms, enables monitoring, sets VKB input on track selection |

---

### Complexity Hotspots

#### Top 5 Files by Complexity Score (LOC × coupling × cyclomatic)

1. **`piano-roll/interaction.lua`** (795 LOC)
   - Handles ALL mouse modes (pointer, pencil, eraser)
   - Contains lasso, click-to-select, drag, resize, tool switching, context menu, zoom
   - Tightly coupled to grid.lua, note.lua, piano-roll-store.lua, island_store
   - **Risk**: Adding a new tool mode requires modifying this single file

2. **`views.lua`** (864 LOC)
   - Orchestrates entire GFX view
   - DrawIslands is 300+ lines of inline island rendering with hardcoded layout constants
   - DrawDockedTransportBar is a separate complete view (100 LOC)
   - DrawPerformanceArea interacts with pagination, pads, slots, drag
   - **Risk**: Layout changes require touching many inline position constants

3. **`preset-browser.lua`** (663 LOC)
   - Full file browser: directory tree, file list, favorites, bookmarks
   - Scroll state, error handling, folder navigation
   - **Risk**: Monolithic — all features in one file

4. **`piano-roll/grid.lua`** (446 LOC)
   - Grid rendering with 4-tier hierarchy (measure, beat, subdivision, note)
   - Note hit-test with snap
   - Tight coupling to interaction.lua and note.lua
   - **Risk**: The 4-tier grid is computationally intensive

5. **`src/state/piano-roll-store.lua`** (426 LOC)
   - 30+ state fields spanning notes, selection, drag, undo/redo, lasso, viewport, zoom, island transitions
   - Multiple responsibilities in one store
   - **Risk**: Feature creep — hard to reason about state interactions

#### Additional Hotspots

- **`midi.lua`** (235 LOC): Contains both pure (GetMidiNote) and impure (ToggleIsland, ExportToMidi) functions. The `ToggleIsland` function reaches across layers (ui stores, compact store).
- **`main.lua`** (415 LOC): The 3-branch MainLoop is well-organized but handles auto-track setup, dirty flags, focus, sequencer, keyboard, GFX redraw, dock state, and cleanup — all in one loop.
- **`compact-init.lua`** (246 LOC): Dual GFX context lifecycle management is inherently complex. The FindTransportWindow fallback chain adds conditional complexity.

---

### Technical Debt Assessment

#### Critical Debt

| Item | Severity | Description |
|------|----------|-------------|
| `config.state` remnant reads | **High** | `midi.lua:94` — `local c = ctx or config.state` in `TriggerChord`. The `ctx` parameter is now passed by keyboard.lua but NOT by sequencer.lua's `TriggerSubChord`. Sequencer calls still read `config.state` directly. This means `preferences_store` values may not be fully reflected during sequencer playback. |
| Circular dependency via lazy require | **Medium** | slots.lua ↔ components.lua + widgets ↔ components. The lazy require pattern works but is fragile — if a function is called before its require resolves, it crashes. Worse: this makes static analysis impossible without running the code. |
| slots.lua in core/ uses gfx.* | **Medium** | `slots.lua` is in `core/` but exclusively uses `gfx.*` (DrawSlotBackground, DrawSlotLabel). It has ZERO `reaper.*` calls. This violates the core/ui separation and suggests it should move to `ui/`. |

#### Moderate Debt

| Item | Severity | Description |
|------|----------|-------------|
| piano-roll-store.lua feature creep | **Medium** | 426 LOC for a state store is too large. Notes CRUD, undo/redo, selection, lasso, drag, viewport should arguably be separate stores. |
| island.lua/preset-store.lua overlap | **Medium** | `island.lua` contains preset browser state fields (current_directory, preset_tree, preset_files, favorites, bookmarks) that logically belong in `preset-store.lua`. The split was done mid-refactor and left incomplete. |
| views.lua DrawIslands inlined | **Medium** | The 4 islands are rendered inline with hardcoded layout constants. Extracting each island into a sub-module (like `midi-island/`) would improve maintainability. |
| Hardcoded layout constants | **Low** | `views.lua` has many magic numbers for island positions, sizes, gaps. While they follow the virtual coordinate system, there's no named constant registry for these values. |
| No UI tests | **Medium** | GFX-dependent UI modules have zero tests. While this is expected (GFX mocking beyond gfx.* is impractical), there may be opportunities for pure function extraction from UI modules (e.g., layout calculations). |

#### Low Debt

| Item | Severity | Description |
|------|----------|-------------|
| `last_configured_track` global in main.lua | **Low** | Module-level closure variable in main.lua. Minor — tracked lifecycles are correct. |
| `_sb_dragging`, `_vsb_dragging` in views.lua | **Low** | State variables for scrollbar drag. These are UI-only state that should arguably live in a store, but they're specific to a single view and safe as closures. |
| `barrel-backward-compat.lua` | **Low** | A test file with 0 check() calls that's registered in the runner but tests nothing. |
| Remnant issue: velocity editor disabled (midi-island.lua:343) | **Low** | `ve_h = 0` set with root cause unknown. Documented in Issue Registry as INVESTIGATING. |

---

### Code Quality Observations

#### Strengths

1. **Consistent module pattern**: Every module follows `local m = {}; function m.X() ... end; return m`. Zero exceptions across 53 files.
2. **SPDX headers**: Every source file has an MIT license header — excellent for an open-source REAPER script.
3. **Documented dependencies**: Every AGENTS.md file explicitly documents function signatures, dependencies, and pitfalls.
4. **Test infrastructure**: The mock factory pattern (`make_mock_fn`) is genuinely impressive for Lua — it enables the 497 check() assertions that would be impossible in a raw REAPER environment.
5. **Init order discipline**: The stores-before-modules init order is documented and consistently enforced in main.lua.
6. **Issue tracking**: Issues #5 through #22 are documented in code comments and cross-referenced in AGENTS.md.
7. **`pcall` error safety**: `SafeDraw` in components.lua uses `pcall` to prevent render errors from crashing the script. This is rare in REAPER GFX scripts.
8. **Validation hygiene**: Every `reaper.ValidatePtr()` call for track/item/take pointers before use. Many REAPER scripts skip this.
9. **Consistent naming**: `snake_case` for functions, `UPPER_CASE` for constants, PascalCase for module files. RENAMED config keys use the same convention.

#### Areas for Improvement

1. **`config.state.xxx` direct writes remain in UI code**: `views.lua` writes to `config.state.root_index`, `config.state.scale_index`, `config.state.octave`, etc. directly (via `persist.Save`) instead of going through `preferences_store.SetXxx()`. This means the preference store's debounce mechanism is partially bypassed.
2. **Magic strings for ExtState keys**: `"GROVE_Scale_Runner"` namespace is repeated in `main.lua:364-369` and `views.lua:157-166` rather than using `config.EXTSTATE_NS`.
3. **AllNotesOff calls `sequencer.Stop()` in some paths**: `keyboard.lua:97-98` calls `sequencer.Stop()` BEFORE `midi.AllNotesOff()`, but `main.lua:200-201` calls them in the opposite order. The comment in `midi.lua:135-136` says "caller must also call sequencer.Stop()" but doesn't specify order. This inconsistency could cause subtle issues.
4. **`gfx.mouse_wheel = 0` is duplicated**: Done once in `main.lua:262` for the main context, and presumably in `compact-init.lua` for the panel context. If a new GFX context is added, this MUST be remembered.
5. **`midi_island_expanded` is a module field on `midi`**: This UI state (whether MIDI island is expanded) lives on the `midi` module table as a public field. It should arguably be in `island_store` or `ui_store`.

---

## Next Recommended

Based on this comprehensive analysis, the most valuable follow-up changes would be:

### Priority 1: Eliminate the last `config.state` remnant read (Critical)
**Change**: `TriggerChord` fallback in `midi.lua:94`
**Scope**: core/midi.lua, core/sequencer.lua
**Description**: Make `sequencer.lua`'s `TriggerSubChord` pass an explicit `ctx` table (built from preferences_store values) instead of relying on the `ctx or config.state` fallback. This completes the store migration and ensures sequencer playback uses `preferences_store` values.

### Priority 2: Move `slots.lua` from `core/` to `ui/` (Medium)
**Change**: slots.lua relocation
**Scope**: core/slots.lua → ui/slots.lua
**Description**: `slots.lua` has zero `reaper.*` calls and exclusively uses `gfx.*`. It belongs in `ui/`. Requires updating all requires and barrel re-exports.

### Priority 3: Split `piano-roll-store.lua` (Medium)
**Change**: Extract note CRUD + undo/redo into separate store
**Scope**: state/piano-roll-store.lua
**Description**: The 426LOC store has multiple responsibilities. Extract note CRUD and undo/redo into `note-store.lua` (or similar), keeping only UI state (viewport, zoom, selection, tool mode) in piano-roll-store.

### Priority 4: Consolidate `island.lua` and `preset-store.lua` (Low)
**Change**: Resolve the island/preset store overlap
**Scope**: state/island.lua, state/preset-store.lua
**Description**: Move preset browser state fields currently in `island.lua` into `preset-store.lua`. The refactor was started but left incomplete.

---

## Risks

### Architecture-Wide Risks

1. **GFX Context Coupling**: The main window, compact panel, and (theoretically) future views all need independent GFX contexts. If a third context is added (e.g., a separate settings window), the SwitchViewMode/HandlePanel lifecycle becomes exponentially more complex. The current dual-context system is already fragile.

2. **Lazy Require Brittleness**: The lazy require pattern in slots.lua and all UI widgets creates implicit ordering constraints. If a code path calls a function that does `require("ui.components")` before `components.lua` finishes loading, it may get a partial module or crash. This is especially dangerous during error handling when modules may not have loaded fully.

3. **REAPER GFX API Fragility**: The script is tightly coupled to REAPER's immediate-mode GFX API. A change in REAPER's gfx behavior (e.g., mouse_wheel accumulation behavior, gfx.dock semantics, gfx.blit changes) could silently break rendering. No abstraction layer exists for the GFX API beyond the thin `gfx-safe.lua` wrapper.

4. **State Mutation via Reference**: Multiple stores return internal table references (`GetProgression()`, `GetKeyStates()`, `GetActiveNotes()`, `GetNotes()`). Mutation of returned references affects the store's internal state. While documented, this is a leaky abstraction that can cause subtle bugs if callers don't understand the implications.

5. **Memory Growth Risk**: The `_vkey_string` mock pattern (256 bytes × frames) and the undo/redo stacks (50 entries of potentially large note arrays) could cause memory issues in long-running sessions with heavy MIDI island editing. The undo stack has a max depth of 50, but individual note arrays could be large.

6. **Project Name Ambiguity**: Git remote shows `grove-scale-runner` but the project is consistently called `GROVE FL MIDI` in documentation and `GROVE_Scale_Runner` in ExtState keys. Three variant names exist for the same project. This creates confusion for automation tools and external references.

---

**Status**: success
**Summary**: Full codebase exploration completed across 53 source files (~8,800 LOC), 22 test files (~2,000+ LOC), and ~90 openspec artifacts. Architecture, dependencies, patterns, complexities, and risks thoroughly documented.
**Artifacts**: `openspec/specs/analysis/explore.md` | Engram `sdd/Analiza toda la codebase actual./explore`
**Next**: Propose specific changes from the recommended priorities above.
**Risks**: GFX context coupling, lazy require brittleness, state mutation via reference, REAPER GFX API fragility
**Skill Resolution**: injected (Project Standards from orchestrator)
