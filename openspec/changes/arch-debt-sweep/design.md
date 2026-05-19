# Design: arch-debt-sweep

## Technical Approach

Three independent architectural debt items: (P1) add missing save trigger for `view_offset_x/y` in `main.lua`, (P2) replace 881 LOC `preset-browser.lua` monolith with a barrel re-exporting 4 submodules, (P3) add 4 test files for pure functions across grid, note-store, I/O, and drag modules. All three are pure refactors/test-additions with zero behavioral change.

## Architecture Decisions

### Decision: Zero-debounce save for view offsets

**Choice**: Save `view_offset_x/y` every frame on change (same as `window_w/h`).
**Alternatives**: Debounced save (accumulate, flush after N frames), save-on-close only.
**Rationale**: Window-w/h uses no debounce and works fine (save only triggers on actual change, writes are O(1) ExtState calls). Save-on-close would miss position if REAPER crashes. No perf concern — same call rate as existing dimensions.

### Decision: IO.lua as single source for all I/O functions

**Choice**: Barrel routes `SavePreset`, `LoadPreset`, `RenamePreset`, etc. to `preset-browser/io.lua`.
**Rationale**: The submodule already has superior implementations (`safe.LoadSandboxed` instead of `dofile()`, `path_utils.PathJoin` instead of string concat). No compatibility risk — same signatures, same behavior, same error handling.

### Decision: Omit ToggleFavorite/DrawActionButtons from barrel

**Choice**: Do not re-export `ToggleFavorite` or `DrawActionButtons` in the barrel.
**Rationale**: Monolith exported these but grep shows ZERO external callers. Favorite toggling is handled inline in `main_mod.DrawPresetBrowser`. Removing dead exports simplifies API surface without affecting any consumer.

### Decision: Pure function tests only — no mocks

**Choice**: All 4 test files test deterministic arithmetic/data-transformation functions with zero `reaper.*`/`gfx.*` dependencies.
**Rationale**: The functions under test (`ComputeVisibleRanges`, `ProgressionToNotes`, `IsValidPresetFile`, `IsNoteRightEdge`) take scalar/table inputs and return scalar/table outputs. Adding mock imports would increase test complexity without coverage benefit.

## Data Flow

```
P1:
  gfx.hwnd → JS_Window_GetRect → ui_store.SetViewOffsetX/Y
    → [NEW] if changed: persist.Save("view_offset_x", vx)
    → reaper.SetExtState("GROVE_Scale_Runner", "view_offset_x", vx, true)

P2:
  require("ui.preset-browser") → barrel.lua
    → require("ui.preset-browser.io")      → io_mod.*
    → require("ui.preset-browser.folder")   → folder_mod.*
    → require("ui.preset-browser.main")     → main_mod.DrawPresetBrowser
    → require("ui.preset-browser.preset-list") → list_mod.*

P3:
  tests/run.lua → test_names[] → dofile(test_piano_roll_grid.lua)
                                → dofile(test_note_store.lua)
                                → dofile(test_preset_browser_io.lua)
                                → dofile(test_piano_roll_drag.lua)
```

## File Changes

| File | Action | LOC Δ | Description |
|------|--------|-------|-------------|
| `src/state/ui.lua` | Modify | +12 | Add `last_saved_vx`/`vy` state fields + 4 getter/setter pairs |
| `src/main.lua` | Modify | +12 | Save trigger after line 366, mirroring lines 334-341 |
| `src/ui/preset-browser.lua` | Rewrite | -801 | 881 LOC monolith → ~80 LOC barrel |
| `tests/test_piano_roll_grid.lua` | Create | +80 | ~40 check() for grid pure functions |
| `tests/test_note_store.lua` | Create | +70 | ~35 check() for note-store helpers |
| `tests/test_preset_browser_io.lua` | Create | +70 | ~35 check() for I/O pure functions |
| `tests/test_piano_roll_drag.lua` | Create | +80 | ~45 check() for edge detection |
| `tests/run.lua` | Modify | +4 | Add 4 filenames to `test_names` |

## Interfaces / Contracts

### P1 — new ui_store API
```lua
-- Sentinel state fields
ui_state.last_saved_vx = nil  -- number|nil
ui_state.last_saved_vy = nil  -- number|nil

-- Getters/setters (added to state/ui.lua)
function m.GetLastSavedX() return ui_state.last_saved_vx end
function m.SetLastSavedX(v) ui_state.last_saved_vx = v end
function m.GetLastSavedY() return ui_state.last_saved_vy end
function m.SetLastSavedY(v) ui_state.last_saved_vy = v end
```

### P2 — barrel function mapping
```
browser.Init             = io_mod.Init
browser.ScanDirectory    = io_mod.ScanDirectory
browser.RefreshPresets   = io_mod.RefreshPresets
browser.IsFavorite       = io_mod.IsFavorite
browser.SavePreset       = io_mod.SavePreset
browser.LoadPreset       = io_mod.LoadPreset
browser.RenamePreset     = io_mod.RenamePreset
browser.HasLFS           = io_mod.HasLFS
browser.GetPresetFilePath = io_mod.GetPresetFilePath
browser.LoadFavorites    = io_mod.LoadFavorites
browser.SaveFavorites    = io_mod.SaveFavorites
browser.DeletePreset     = io_mod.DeletePreset
browser.DrawPresetBrowser = main_mod.DrawPresetBrowser
browser.DrawFolderHeader  = folder_mod.DrawFolderHeader
browser.DrawFolderList    = folder_mod.DrawFolderList
browser.HandleFolderClick = folder_mod.HandleFolderClick
browser.HandleFolderWheel = folder_mod.HandleFolderWheel
browser.DrawPresetList    = list_mod.DrawPresetList
browser.DrawFavoriteStar  = list_mod.DrawFavoriteStar
browser.HandlePresetClick = list_mod.HandlePresetClick
browser.HandlePresetListWheel = list_mod.HandlePresetListWheel
browser.HandleContextMenu = list_mod.HandleContextMenu
```

## Testing Strategy

| File | What | Approach | check() |
|------|------|----------|---------|
| `test_piano_roll_grid.lua` | ComputeVisibleRanges, HandleMouseWheel/ZoomX/ZoomVertical/SetPitchRowH | Pure arithmetic, zero mocks | ~40 |
| `test_note_store.lua` | ProgressionToNotes, GroupNotesByBeat, DetectChordMode, GetVisibleNotes | Data transfo, no mocks | ~35 |
| `test_preset_browser_io.lua` | IsValidPresetFile, GetPresetFilePath, HasLFS, IsFavorite | Deterministic, no mocks | ~35 |
| `test_piano_roll_drag.lua` | IsNoteRightEdge, IsNoteLeftEdge | Coordinate math, no mocks | ~45 |

Total: ~155 `check()` assertions.

## Sequencing

All three are independent. Recommended execution order: P1 → P2 → P3.

- **P1 first** (12 LOC, trivial, builds confidence)
- **P2 second** (highest risk — barrel must match existing API surface; run `barrel-backward-compat.lua` after)
- **P3 third** (test files reference stable modules; P2 doesn't affect test targets)

Per delivery config: `delivery_strategy=auto-chain`, `chain_strategy=feature-branch-chain`. P1 is a single commit. P2 is a single commit (monolith → barrel). P3 is 4 test files that can be a single commit (all add to test_names). If review budget projection exceeds 400 lines, split P3 tests into individual commits.

## Open Questions

None. All three items are fully specified with no architectural ambiguity.

## Migration / Rollout

No migration required. P1 adds new ExtState writes to already-tracked keys. P2 is a pure refactor — submodules remain unchanged. P3 is new files only.
