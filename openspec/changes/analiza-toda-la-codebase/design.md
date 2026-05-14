# Design: Address Priority Technical Debt (4 items)

## Technical Approach

4 independent refactors on separate file sets. Items 3-4 share island.lua but modify disjoint sections (add delegations vs remove fields) — no conflict. Items 1-2 are fully isolated.

## Critical Discovery

`piano-roll-store.lua` (430 LOC) and `preset-store.lua` (72 LOC) are **dead code** — never required or initialized. All consumers use `state.island` (566 LOC) which has note CRUD + view state + preset browser state. The split targets are `island.lua`, not the dead files.

---

## Item 1: Fix `config.state` remnants in TriggerChord

### Architecture Decision

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Make prefs_state reference config.state | SyncFromState becomes identity, cleanest | ✗ Too invasive for narrow fix |
| Add read-through delegation | Getters read config.state if prefs_state is stale | ✗ Two sources of truth |
| **Insert preferences_store as fallback** | Minimal diff, no side effects | ✓ |

**Choice**: Add `require("state.preferences")` to midi.lua + sequencer.lua. Change reads to use preferences_store as fallback/canonical source. **preferences_store stays internal** — SyncFromState at init time keeps it in sync with config.state for all current code paths.

### Data Flow

```
keyboard.lua → reads prefs → temp_ctx → midi.TriggerChord(ctx) → c = ctx
                                                ↓
                                    inv = inversion_index or c.inversion_index
                                    or prefs.GetInversionIndex()
```

### Exact Changes

| File | Line | Change |
|------|------|--------|
| `core/midi.lua` | +1 (after line 5) | `local prefs = require("state.preferences")` |
| `core/midi.lua` | 101 | `local inv = inversion_index or c.inversion_index or prefs.GetInversionIndex()` |
| `core/sequencer.lua` | +1 (after line 3) | `local prefs = require("state.preferences")` |
| `core/sequencer.lua` | 90 | `local sub_idx = prefs.GetSubdivisionIndex() or 1` |

### Migration
One-shot replace, no rollout. Verify with `grep "config.state\." midi.lua sequencer.lua` → zero hits.

### Rollback
`git revert <commit>`. Single file changes, trivially revertible.

---

## Item 2: Move `slots.lua` from `core/` to `ui/`

### Exact Changes

| File | Action |
|------|--------|
| `src/core/slots.lua` | Move → `src/ui/slots.lua` |
| `src/ui/components.lua` line 10 | `require("core.slots")` → `require("ui.slots")` |
| `src/main.lua` line 28 | `src/core/slots.lua` → `src/ui/slots.lua` |

**AGENTS.md** path updates (4 files):
- root `AGENTS.md`: Circular Dependency Map + Init/Teardown + Issue Registry
- `src/AGENTS.md`: Directory structure + Dependency Graph
- `src/core/AGENTS.md`: File overview table (remove slots row)
- `src/ui/AGENTS.md`: Widgets file table (add slots row)

### Migration
Zero code changes in slots.lua itself. Single require path change in components.lua. Test: script loads without require error + progression slots render and drag works.

### Rollback
`git revert <commit>`. Single path change.

---

## Item 3: Extract note-store.lua from island.lua

### Architecture Decision

| Option | Tradeoff | Decision |
|--------|----------|----------|
| **Delegation in island.lua** | Zero consumer import changes, backward compat | ✓ |
| Update 6+ consumers to import both stores | More LOC changed, higher risk, but cleaner final state | ✗ |

**Choice**: Create `state/note-store.lua` (extracted from island.lua). island.lua gets delegation 1-liners. Consumers keep using `island_store.*` — zero import changes. Future cleanup can remove delegations.

### File Changes

| File | Action | LOC |
|------|--------|-----|
| `state/note-store.lua` | **Create** — note CRUD + UUID + undo/redo from island.lua | ~165 |
| `state/island.lua` | **Modify** — remove note CRUD/UUID/undo/redo fields + functions, add delegation requires + 1-liners | −180 |
| `src/main.lua` | Add `note_store = require("state.note-store")` + `note_store.Init(config.state)` after line 94 | +2 |

### Create: `state/note-store.lua`

Extract from island.lua:
- **Fields**: `notes{}`, `note_count`, `next_note_uuid`, `notes_dirty`, `undo_stack{}`, `redo_stack{}`, `undo_depth`, `redo_depth`, `_uuid_to_idx{}`, `TOTAL_PITCHES`, `MAX_UNDO`
- **Functions**: `Init`, `GetNotes`, `SetNotes`, `GetNoteCount`, `SetNoteCount`, `SetNotesDirty`, `GetNotesDirty`, `AddNote`, `RemoveNoteAtIndex`, `AllocNoteUUID`, `FindNoteByUUID`, `RebuildUUIDIndex`, `PushUndo`, `PopUndo`, `PushRedo`, `PopRedo`, `ClearUndoStacks`, `GetUndoDepth`, `GetRedoDepth`, `ProgressionToNotes`, `EntryToPitches`, `ProgressionEntryToPitch`, `LoadNotesFromProgression`, `GetVisibleNotes`
- **Imports**: `config`, `core.api-guard` (same as island.lua currently)
- **Init**: `if defaults.notes then state.notes = defaults.notes; state.note_count = #defaults.notes end`

### Modify: `state/island.lua`

Remove these fields from `island_state`:
```
notes, note_count, notes_dirty (piano-roll only, not in island),
next_note_uuid, undo_stack, redo_stack, undo_depth, redo_depth,
_uuid_to_idx (module-level)
```

Remove these functions (move to note-store.lua):
```
GetNotes, SetNotes, GetNoteCount, SetNoteCount,
SetNotesDirty, GetNotesDirty, AddNote, RemoveNoteAtIndex,
AllocNoteUUID, FindNoteByUUID, RebuildUUIDIndex,
PushUndo, PopUndo, PushRedo, PopRedo, ClearUndoStacks,
GetUndoDepth, GetRedoDepth,
ProgressionToNotes, EntryToPitches, ProgressionEntryToPitch,
LoadNotesFromProgression, GetVisibleNotes
```

Add to island.lua:
```lua
local note_store = require("state.note-store")
-- Delegation getters
function m.GetNotes() return note_store.GetNotes() end
function m.SetNotes(t) note_store.SetNotes(t) end
function m.GetNoteCount() return note_store.GetNoteCount() end
-- ... one 1-liner per delegated function
```

### Init Order (main.lua)
```
8.  note_store.Init(config.state)      ← NEW: handles notes
9.  island_store.Init(config.state)    ← modified: no longer handles notes
```

### Risk Mitigation
- **Init timing**: notes handled by note_store.Init BEFORE island_store.Init. Former island_store.Init lines for notes (`if defaults.notes then...`) are moved to note-store.Init.
- **Performance**: Delegation 1-liners add negligible call overhead.
- **DUAL state risk**: After split, note-store has the authoritative notes. island.lua's `state.notes` is removed. All functions in island.lua that referenced `island_state.notes` now call `note_store.GetNotes()`. Verify every function reference.

### Rollback
Remove note-store.lua, restore island.lua to original, revert main.lua Init addition. Single commit revert.

---

## Item 4: Consolidate island.lua + preset-store.lua overlap

### Architecture Decision

| Option | Tradeoff | Decision |
|--------|----------|----------|
| **Awaken preset-store.lua**, remove fields from island.lua | Clean separation, dead store becomes alive | ✓ |
| Keep everything in island.lua | Simpler but perpetuates 566 LOC blob | ✗ |

### File Changes

| File | Action |
|------|--------|
| `state/island.lua` | Remove 9 preset fields + their getters/setters + ClearBrowserState + folder_scroll |
| `ui/preset-browser.lua` | Change `require("state.island")` → `require("state.preset-store")` for preset fields |
| `src/main.lua` | Add `preset_store = require("state.preset-store")` + `preset_store.Init(config.state)` |

### Remove from island.lua

Fields to remove from `island_state`:
```
current_directory, preset_root, preset_tree, preset_files,
selected_preset_idx, browser_scroll, folder_scroll, browser_error,
favorites, bookmarks
```

Functions to remove:
```
Get/SetCurrentDirectory, Get/SetPresetRoot, Get/SetPresetTree,
Get/SetPresetFiles, Get/SetSelectedPresetIdx, Get/SetBrowserScroll,
Get/SetFolderScroll, Get/SetBrowserError, Get/SetFavorites,
Get/SetBookmarks, ClearBrowserState
```

Remove from island.lua `Init`:
```lua
if defaults.current_directory ~= nil then ... end
if defaults.preset_root ~= nil then ... end
```

### Modify: `ui/preset-browser.lua`

Change line 9:
```lua
-- FROM:
local island_store = require("state.island")
-- TO:
local preset_store = require("state.preset-store")
```

Replace all `island_store.*` calls for preset fields:
```
island_store.GetCurrentDirectory()  →  preset_store.GetCurrentDirectory()
island_store.SetCurrentDirectory(v) →  preset_store.SetCurrentDirectory(v)
island_store.GetPresetRoot()        →  preset_store.GetPresetRoot()
island_store.SetPresetRoot(v)       →  preset_store.SetPresetRoot(v)
... (9 fields × getter+setter = ~18 replacements)
```

**IMPORTANT**: The `m.LoadNotesFromProgression()` and `m.ProgressionToNotes()` calls in preset-browser.lua still use `island_store` (which delegates to note-store after item 3). These stay unchanged — only preset-specific calls change.

### Init Order (main.lua)
```
9.  note_store.Init(config.state)      ← Item 3
10. island_store.Init(config.state)    ← modified: no notes, no preset
11. preset_store.Init(config.state)    ← NEW: handles preset fields
```

### Risk Mitigation
- **preset-store.lua already exists** with identical API — field names match perfectly. Zero structural risk.
- **preset-browser.lua** also uses `island_store.GetNotes()` for preset load/save. Since item 3 delegates `GetNotes` to `note-store`, this call still works via island_store delegation.
- **Run-time**: Ensure preset_store.Init is called BEFORE any preset-browser code runs (it runs in MainLoop drawing, so Init order is fine).

### Rollback
Remove preset_store requires from main.lua, restore island.lua fields, revert preset-browser.lua. Single commit revert.

---

## Dependency/Ordering Analysis

| Item | Depends On | Blocks |
|------|------------|--------|
| 1 — config.state fix | Nothing | Nothing |
| 2 — slots move | Nothing | Nothing |
| 3 — note-store split | Nothing (but same file as 4) | Nothing (4 if same edit) |
| 4 — island/preset | Nothing (but same file as 3) | Nothing (3 if same edit) |

Items 3 and 4 both modify `island.lua` on DIFFERENT sections:
- Item 3: REMOVEs `island_state.notes`, `note_count`, undo/redo fields → ADDs delegation requires + 1-liners
- Item 4: REMOVEs preset fields + ClearBrowserState

These are non-overlapping deletions. Can be done in sequence or parallel branches. Recommended sequence: Item 3 first (adds delegation), then Item 4 (removes preset fields + updates preset-browser.lua).

### Recommended Commit Order

1. **Item 1**: Fix config.state reads (midi.lua + sequencer.lua)
2. **Item 2**: Move slots.lua to ui/
3. **Item 3**: Split note-store.lua (create note-store.lua + island.lua delegation + main.lua init)
4. **Item 4**: Consolidate island/preset (wake preset-store.lua + remove island fields + update preset-browser.lua)

Each commit is independently revertible.

---

## Testing Strategy

| Item | What to Verify | How |
|------|---------------|-----|
| 1 | `grep "config.state\." midi.lua sequencer.lua` = 0 hits | Shell command |
| 1 | TriggerChord reads correct inversion from preferences_store | Code review + run in REAPER |
| 2 | `slots.lua` in `src/ui/`, not in `src/core/` | File system check |
| 2 | Script loads without "module not found" error | Load in REAPER |
| 2 | Progression slots render + drag works | Visual check in REAPER |
| 3 | `note-store.lua` exists, `piano-roll-store.lua` unchanged | File system |
| 3 | island.lua < 386 LOC (566 − 180), note-store.lua ~165 LOC | wc -l |
| 3 | Note editing + undo/redo works in piano roll | Visual check in REAPER |
| 4 | island.lua has zero `current_directory`/`preset_root` etc. | grep |
| 4 | Preset browser loads/saves correctly | Visual check in REAPER |
| ALL | 497 test checks pass | `lua tests/test_runner.lua` |

---

## Open Questions

- [ ] **Item 1 scope creep**: slots.lua also reads `config.state.inversion_index` (line 185) and `config.state.subdivision_index` (lines 69, 210). Should these be fixed in this change? Proposal says no (out of scope for TriggerChord fix).
- [ ] **Item 4 cleanup**: After removing preset fields from island.lua, should `m.Init(defaults)` also lose the `current_directory`/`preset_root` params? Yes — they move to `preset_store.Init(config.state)`.
