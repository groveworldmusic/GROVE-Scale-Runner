# Tasks: Address Priority Technical Debt

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~885 (430 trivial dead-code deletion) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: Items 1+2 → PR 2: Item 3 → PR 3: Item 4 |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Items 1+2: config.state fix + slots move | PR 1 | base=tracker; ~15 LOC, zero risk, fully independent |
| 2 | Item 3: note-store.lua extraction + dead piano-roll deletion | PR 2 | base=PR 1 branch; ~365 review-worthy LOC + 430 dead-code deletion |
| 3 | Item 4: island/preset-store consolidation | PR 3 | base=PR 2 branch; ~55 LOC, depends on PR 2 (same file island.lua) |

## Phase 1: Foundation (Items 1 + 2)

- [x] 1.1 midi.lua: add `local prefs = require("state.preferences")`, replace `config.state.inversion_index` with `prefs.GetInversionIndex()`, replace `config.state.inversion_direction` with `prefs.GetInversionDirection()`
- [x] 1.2 sequencer.lua: add `local prefs = require("state.preferences")`, replace `config.state.subdivision_index` with `prefs.GetSubdivisionIndex()`
- [x] 1.3 main.lua: add `local preferences_store = require("state.preferences")` + `preferences_store.Init(config.state)` after island_store.Init; add `preferences_store.SyncFromState(config.state)` after `persist.Load()`; add `preferences_store.TickSaveDebounce()` in MainLoop
- [x] 1.4 git mv `src/core/slots.lua` → `src/ui/slots.lua`; update `components.lua:10` to `require("ui.slots")`
- [x] 1.5 Update 4 AGENTS.md files: root, src/, core/, ui/ — paths and file tables

## Phase 2: Note-store extraction (Item 3)

- [ ] 2.1 Create `src/state/note-store.lua` with note CRUD, UUID generation, undo/redo stacks extracted from island.lua (~165 LOC)
- [ ] 2.2 island.lua: remove notes/undo/uuid fields from `island_state` + function bodies; add `require("state.note-store")` + 1-liner delegation functions for backward compat
- [ ] 2.3 main.lua: add `note_store = require("state.note-store")` + `note_store.Init(config.state)` after island_store.Init
- [ ] 2.4 Delete `src/state/piano-roll-store.lua` (430 LOC dead code, zero consumers confirmed)

## Phase 3: Preset-store consolidation (Item 4)

- [ ] 3.1 island.lua: remove 9 preset fields + getters/setters + ClearBrowserState + folder_scroll from `island_state`
- [ ] 3.2 preset-browser.lua: change `require("state.island")` to `require("state.preset-store")`, replace all 50 `island_store.*` calls for preset fields with `preset_store.*`
- [ ] 3.3 midi-island.lua:48 change `island_store.GetPresetRoot()` → `preset_store.GetPresetRoot()`
- [ ] 3.4 main.lua: add `preset_store = require("state.preset-store")` + `preset_store.Init(config.state)` in Init chain after island_store.Init
- [ ] 3.5 Update AGENTS.md (4 files) for note-store + preset-store additions

## Phase 4: Verification

- [ ] 4.1 grep "config.state\." midi.lua sequencer.lua → zero hits
- [ ] 4.2 Script loads in REAPER without "module not found" error
- [ ] 4.3 Inversion + subdivision work correctly from UI and keyboard
- [ ] 4.4 Piano roll note editing + undo/redo works in REAPER
- [ ] 4.5 Preset browser: navigate dirs, save, load, rename, favorites all work
- [ ] 4.6 Progression slots render, drag-to-create, drag-to-swap, right-click-delete work
