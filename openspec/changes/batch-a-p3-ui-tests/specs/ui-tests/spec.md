# UI Tests — Delta Spec

**Change**: `batch-a-p3-ui-tests`
**Domain**: ui-tests
**Type**: NEW (no existing spec — test coverage for previously untested UI modules)

## Requirement

Four test files SHALL be added to `tests/` targeting pure/logic functions in untested UI modules. Zero behavioral changes. All functions under test are either pure (no dependencies on `reaper.*`/`gfx.*`) or trivially mockable through existing mock infrastructure (`config.SCALES`, `config.CHORD_MODES`).

## Coverage Targets

### Target 1: piano-roll/grid.lua — 7 functions

| Function | Signature (actual) | Returns | Assertions |
|----------|-------------------|---------|-----------|
| `ComputeVisibleRanges(y, h, scroll_y, scroll_x, zoom_x, w)` | 6 params, returns 6 values: `visible_rows, pitch_start, pitch_end, top_pitch, beat_start, beat_end`. Cached when params unchanged. | visible range tuple | ~20 |
| `HandleMouseWheel(delta, scroll_x, zoom_x)` | Scroll speed = 4/(zoom_x/40). Clamps ≥ 0. | new_scroll: number | ~5 |
| `HandleZoomX(delta, zoom_x)` | factor = delta>0 ? 1.15 : 1/1.15. Clamp 10..200. | new_zoom: number | ~5 |
| `HandleZoomVertical(delta, row_h)` | Adjusts row height (NOT scroll_y). factor per delta sign. Clamp 6..24. | new_row_h: number | ~5 |
| `HandleMouseWheelVertical(delta, scroll_y)` | Inverted Y: new = scroll_y - delta*0.08. Clamp ≥ 0. | new_scroll_y: number | ~5 |
| `SetPitchRowH(h)` | Clamp 6..24. Invalidates cache when value changes. | void | ~5 |
| `InvalidateVisibleRangesCache()` | Sets all _cache fields to nil. Next call recomputes. | void | ~5 |

**Corrections from user brief**: `ComputeVisibleRanges` has 6 params `(y, h, scroll_y, scroll_x, zoom_x, w)` not 5; `HandleMouseWheel` has 3 params (no `canvas_w`); `HandleZoomVertical` adjusts `row_h` not `scroll_y`; `SetPitchRowH` minimum is 6 not 8.

**Mocks needed**: None — all pure functions, no `reaper.*`/`gfx.*` dependencies.

**Assertion count**: ~50

### Target 2: note-store.lua helpers — 2 functions

| Function | Signature (documented) | Returns | Assertions |
|----------|----------------------|---------|-----------|
| `ProgressionToNotes(progression, beats_per_slot?, velocity?)` | Converts progression entries → flat note list. Uses `config.SCALES`, `config.CHORD_MODES`. | table of note entries | ~10 |
| `GetVisibleNotes(notes, pitch_start, pitch_end, beat_start, beat_end)` | Filters notes within viewport bounds (pitch range + beat range). | table of filtered notes | ~10 |

⚠️ **Codebase issue**: `src/state/note-store.lua` has been overwritten with spec content (not Lua). These functions are documented in `src/state/AGENTS.md` (lines 155-157) but their actual Lua implementation is missing. Tests validate against documented contract; implementation recovery is a prerequisite.

**Mocks needed**: `config.SCALES` and `config.CHORD_MODES` tables only (already available via `require("config")`).

**Assertion count**: ~20

### Target 3: preset-browser/io.lua — 4 functions

| Function | Signature (actual) | Returns | Assertions |
|----------|-------------------|---------|-----------|
| `IsValidPresetFile(filename)` | Checks `filename:lower():match("%.grove$")` | boolean | ~5 |
| `GetPresetFilePath(directory, name)` | `path_utils.PathJoin(directory, name .. ".grove")` | string | ~3 |
| `HasLFS()` | Returns module-level `_has_lfs` (result of pcall require "lfs") | boolean | ~2 |
| `IsFavorite(path)` | Checks `favorites[path] == true` via `preset_store.GetFavorites()` | boolean | ~5 |

**Mocks needed**: `path_utils.PathJoin` (pure, already mocked via require). `preset_store.GetFavorites()` needs a stub returning a simple table.

**Assertion count**: ~15

### Target 4: piano-roll/interaction/drag.lua — 2 functions

| Function | Signature (actual) | Returns | Assertions |
|----------|-------------------|---------|-----------|
| `IsNoteRightEdge(mx, my, notes, hit_idx, grid_x, grid_y, scroll_y, scroll_x, zoom_x)` | 9 params. Checks if mx is within 4px of right edge of note block at same pitch row. | boolean | ~5 |
| `IsNoteLeftEdge(mx, my, notes, hit_idx, grid_x, grid_y, scroll_y, scroll_x, zoom_x)` | 9 params. Checks if mx is within 4px of left edge of note block at same pitch row. | boolean | ~5 |

**Mocks needed**: `grid.PITCH_ROW_H`, `grid.MIN_PITCH`, `grid.MAX_PITCH` (constants, read-only). Simple note table fixture inline.

**Assertion count**: ~10

## Test files

| File path | Module under test | Check() calls |
|-----------|------------------|--------------|
| `tests/test_piano_roll_grid.lua` | `ui.piano-roll.grid` | ~50 |
| `tests/test_note_store_helpers.lua` | `state.note-store` (ProgressionToNotes, GetVisibleNotes) | ~20 |
| `tests/test_preset_browser_io.lua` | `ui.preset-browser.io` | ~15 |
| `tests/test_piano_roll_drag.lua` | `ui.piano-roll.interaction.drag` | ~10 |

**Total**: ~95 check() assertions across 4 test files.

## Related tasks

### Registration in tests/run.lua

Add the 4 filenames to the `test_names` table in `tests/run.lua` (line 28):

```lua
local test_names = {
    -- existing entries ...
    "test_piano_roll_grid.lua",
    "test_note_store_helpers.lua",
    "test_preset_browser_io.lua",
    "test_piano_roll_drag.lua",
}
```

### Prerequisite: Recover note-store.lua

`src/state/note-store.lua` currently contains spec markdown content (from `expansion-features` change) instead of Lua source. `ProgressionToNotes` and `GetVisibleNotes` must be recovered/restored before tests can be written against them. This is a codebase corruption issue, not a test issue — the spec documents the intended contract.

### Execution order

All 4 files are pure-function tests with no inter-test dependencies. They can run in any order after runner registration.

## Edge Cases

- **ComputeVisibleRanges**: scroll_y=0 (top), scroll_y=max (bottom), zoom_x=10 (min), zoom_x=200 (max), zero viewport (w=0 or h=0), negative scroll values
- **HandleZoomX/ZoomVertical**: clamp at both extremes (10 and 200 for zoom_x, 6 and 24 for row_h), delta=0 (identity)
- **HandleMouseWheel**: delta=0 (no change), large delta (fast scroll), scroll_x at 0 (clamp)
- **HandleMouseWheelVertical**: inverted Y direction, sub-pixel positioning
- **SetPitchRowH**: same value (no-op, cache preserved), value below 6 (clamp), value above 24 (clamp)
- **InvalidateVisibleRangesCache**: verify cache miss after invalidation, verify cache hit without invalidation
- **ProgressionToNotes**: empty progression (returns empty), single entry (Tri → 3 notes), velocity override, nil beats_per_slot (default)
- **GetVisibleNotes**: empty notes list, notes partially in viewport (filter boundary), full contained, no overlap
- **IsValidPresetFile**: nil/empty string, wrong extension (.txt), uppercase (.GROVE), dotted filename
- **IsNoteRightEdge/LeftEdge**: mx exactly at edge (boundary), mx 1px inside, mx 5px outside (outside hotzone), note at different pitch (false)
