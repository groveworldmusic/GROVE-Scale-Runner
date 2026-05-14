# Delta Spec: Address Priority Technical Debt — Architectural Refactor

**Change**: Analiza toda la codebase actual.
**Type**: Delta — structural refactor, zero behavior changes.
**Items covered**: 1 (config.state fix), 2 (slots move), 4 (island/preset consolidation).

## Discovery: piano-roll-store.lua is dead code

`state/piano-roll-store.lua` (430 LOC) is NEVER required by any module. The active piano-roll state store is `state/island.lua` (566 LOC), which has its own parallel implementation. All 6 piano-roll consumers + velocity.lua import `island_store = require("state.island")`. Item 3's implementation MUST extract note CRUD/UUID/undo-redo from island.lua (NOT piano-roll-store.lua), then delete the orphaned piano-roll-store.lua.

---

## Item 1 — Config.state → preferences_store

### What IS changing

| File | Before | After |
|------|--------|-------|
| `core/midi.lua` line 101 | `config.state.inversion_index` | `preferences_store.GetInversionIndex()` |
| `core/midi.lua` line 103 | `config.state.inversion_direction` | `preferences_store.GetInversionDirection()` |
| `core/sequencer.lua` line 90 | `config.state.subdivision_index` | `preferences_store.GetSubdivisionIndex()` |
| `core/midi.lua` + `core/sequencer.lua` | No import | Add `local prefs = require("state.preferences")` |

### What is NOT changing

- `midi.TriggerChord()` signature — optional `inversion_index` param still accepted as override
- `sequencer.Run()` subdivision resolution logic — identical behavior
- slots.lua config.state reads (lines 69, 185, 210, 239-242, 255-259) — out of scope

### Verification

- `grep "config.state.inversion_index" core/midi.lua` → zero hits
- `grep "config.state.subdivision_index" core/sequencer.lua` → zero hits
- Change inversion via UI → trigger chord → chord is inverted
- Change subdivision → play sequencer → sub-beat stepping works

---

## Item 2 — slots.lua core/ → ui/

### What IS changing

| Aspect | Before | After |
|--------|--------|-------|
| File location | `src/core/slots.lua` | `src/ui/slots.lua` |
| Import in `ui/components.lua:10` | `require("core.slots")` | `require("ui.slots")` |
| AGENTS.md entries (4 files) | Lists slots under `core/` | Lists slots under `ui/` |

### What is NOT changing

- Module API: `m.DrawProgressionSlot()`, `m.HandleSlotInteraction()`, internal `DrawSlotBackground()`, `DrawSlotLabel()` — zero changes
- Lazy require: each function still calls `require("ui.components")` at runtime
- Barrel re-export: `components.slots.*` unchanged
- All consumer imports via components.lua — unchanged

### Verification

- Script loads without error (no "module not found")
- Drag-from-pad to slot creates entry
- Drag-from-slot to another slot swaps
- Right-click deletes slot

---

## Item 4 — island.lua / preset-store.lua consolidation

### What IS changing

Remove these 9 fields and their getter/setter pairs from `state/island.lua`:

| Removed from island.lua | Consumer uses preset_store instead |
|------------------------|------------------------------------|
| `current_directory` | `preset_store.GetCurrentDirectory()` |
| `preset_root` | `preset_store.GetPresetRoot()` |
| `preset_tree` | `preset_store.GetPresetTree()` |
| `preset_files` | `preset_store.GetPresetFiles()` |
| `selected_preset_idx` | `preset_store.GetSelectedPresetIdx()` |
| `browser_scroll` | `preset_store.GetBrowserScroll()` |
| `browser_error` | `preset_store.GetBrowserError()` |
| `favorites` | `preset_store.GetFavorites()` |
| `bookmarks` | `preset_store.GetBookmarks()` |

Also remove:
- `ClearBrowserState()` from island.lua (consumer preset-browser.lua already uses `preset_store.ClearBrowserState()`)
- `Init()` lines 70-71 merging `current_directory` and `preset_root` from defaults
- `GetFolderScroll()` / `SetFolderScroll()` from island.lua if only used by preset browser (piano-roll-store.lua also has `folder_scroll` — check usage)

### What is NOT changing

- All 49 preset-browser.lua calls change only the module prefix: `island_store` → `preset_store`
- Init ordering: `preset_store.Init()` already runs at main.lua line 97 (before island_store.Init at line 95 — verify order)
- midi-island.lua:48 uses `island_store.GetPresetRoot()` — this MUST migrate to `preset_store.GetPresetRoot()`

### Verification

- `grep "island_store\.\(Get\|Set\)\(CurrentDirectory\|PresetRoot\|PresetTree\|PresetFiles\|SelectedPresetIdx\|BrowserScroll\|BrowserError\|Favorites\|Bookmarks\)" src/` → zero hits
- Preset browser: navigate directories, save, load, rename, favorites all work identically
