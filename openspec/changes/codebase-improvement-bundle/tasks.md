# Tasks: Codebase Improvement Bundle

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~900-1300 |
| 400-line budget risk | High |
| Chained PRs recommended | No |
| Suggested split | Single PR (size:exception accepted) |
| Delivery strategy | exception-ok |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

## Phase 1 — Independent Safe Removals (Items 5, 6, 7, 8)

- [x] 1.1 **Item 5** — views.lua: remove `DrawSnapControls` (lines 83–162) and `DrawToolModeRow` (lines 168–205), ~120 LOC removed
- [x] 1.2 **Item 6** — note-store.lua: replace `ProgressionEntryToPitch` body with `midi.GetMidiNote()` call; add `local midi = require("core.midi")` if missing
- [x] 1.3 **Item 7** — island_state: remove `use_legacy_tools` flag + Get/SetUseLegacyTools
- [x] 1.4 **Item 7** — midi-island/input.lua: remove legacy handler dispatch referencing GetUseLegacyTools
- [x] 1.5 **Item 7** — piano-roll/interaction/handlers.lua: remove legacy handlers (HandleMouseClick, HandleRightClickMute, etc.)
- [x] 1.6 **Item 8** — Bulk-fix SPDX encoding: `Andrik Sanz Cordoví` with proper UTF-8 `í` in all ~59 source files

## Phase 2 — Structural Changes (Items 3 → 2 → 1)

- [x] 2.1 **Item 3** — island.lua: remove ~35 pass-through proxies (~60 LOC removed): all preset-store, UUID, undo/redo, and note-helper pure delegates. Kept AddNote (note_count tracking), RemoveNoteAtIndex (selection fixup), GetNotes/SetNotes/GetNoteCount/SetNoteCount (core accessors), and LoadNotesFromProgression (wraps with notes_state)
- [x] 2.2 **Item 3** — Retarget 10 consumers: piano-roll/undo.lua, interaction/shortcuts.lua, interaction/handlers.lua, interaction/drag.lua, knife.lua, clipboard.lua, velocity.lua, preset-browser.lua, midi-island.lua, midi-island/header.lua — all retargeted to `note_store.*` where island-store proxies were removed. Added `local note_store = require("state.note-store")` where needed.
- [x] 2.3 **Item 2** — midi.lua: removed `gfx-window` require, removed `ToggleIsland()` and `ShowIsland()` functions. Views/islands.lua updated to call `gfx_window.ToggleIsland()` directly with new `require("ui.gfx-window")` import.
- [x] 2.4 **Item 2** — island toggle routing clean: gfx-window.lua now called directly from views/islands.lua, bypassing midi.lua entirely
- [x] 2.5 **Item 1** — ui_store.lua: added view_offset_x/y to local state (default 0), Init() parameters, getters SetViewOffsetX/Y() and GetViewOffsetX/Y()
- [x] 2.6 **Item 1** — persist.lua: added view_offset_x/y to PREF_KEYS table
- [x] 2.7 **Item 1** — Replaced all ~20 config.state.view_offset_x/y refs across 7 files with ui_store.GetViewOffsetX/Y() / SetViewOffsetX/Y(). Only init seeding reads remain (main.lua lines 98-99).

## Phase 3 — Preset-Browser Refactor (Item 4)

- [ ] 3.1 Create `src/ui/preset-browser/io.lua`: extract I/O functions (ScanDirectory, SavePreset, LoadPreset, RenamePreset); add `reaper.EnumerateSubdirectories()` fallback for cross-platform
- [ ] 3.2 Create `src/ui/preset-browser/folder.lua`: extract folder tree navigation logic
- [ ] 3.3 Create `src/ui/preset-browser/preset-list.lua`: extract preset list + favorites rendering logic
- [ ] 3.4 Shrink `preset-browser.lua` to barrel: re-export from sub-modules, keep orchestration glue only, target ≤ 20 LOC
- [ ] 3.5 Verify all `require("ui.preset-browser")` callers still resolve (grep all require sites)

## Phase 4 — Testing (Item 9)

- [ ] 4.1 Create `tests/test_note_store.lua`: test `ProgressionToNotes`, `SyncNotesToProgression`, `FindNearestScaleDegree`, `DetectChordMode`, `DetectChordModeFromDegrees`, `GroupNotesByBeat` using existing `test.check()` / `test.summary()` infrastructure

## Manual REAPER Testing Required

- Item 1 (view_offset): verify position persists after REAPER restart
- Item 2+3 (island + midi inversion): verify island toggle works from keyboard + pads
- Item 4 (preset-browser): verify load/save/rename still work
- Item 8 (encoding): verify UI text renders correctly (no mojibake)
