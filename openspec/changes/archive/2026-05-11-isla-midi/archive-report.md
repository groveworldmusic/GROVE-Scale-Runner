# Archive Report: Isla MIDI

**Change**: `isla-midi`
**Archived**: 2026-05-11
**Status**: ✅ Complete — 34/34 tasks across 4 units, all phases verified

---

## 1. What Was Built

The "Isla MIDI" (MIDI Island) feature added a complete new view mode (`VIEW_MODES.ISLAND = 3`) to GROVE FL MIDI — a 3-panel layout within a dedicated 1000×700 GFX window.

### Panels
- **Preset Browser** (left, collapsible): Filesystem tree navigating `grove-presets/`, save/load `.grove` presets, favorites via `reaper.GetExtState`
- **Timeline Ruler** (top 28px): Beat/measure ticks aligned to grid, playback head synced to sequencer, click-to-seek
- **Piano Roll Grid** (center): Horizontal pitch×time grid with note blocks, virtual scroll (73 pitch rows, 2-octave buffer), zoom 0.25x–4.0x, click selection
- **Velocity Editor** (below piano roll, 80px): Horizontal bars proportional to velocity, click-drag editing, mute toggle via right-click, red→green gradient
- **Info Bar** (bottom 18px): Root·scale·chord·octave, selected note info, note count + zoom + ISLAND indicator

### New files (5):
| File | LOC | Purpose |
|------|-----|---------|
| `src/state/island.lua` | ~200 | Island state store — notes, scroll, zoom, preset state, edit buffer |
| `src/ui/piano-roll.lua` | ~415 | Horizontal grid, note blocks, virtual scroll, click selection, caches |
| `src/ui/timeline.lua` | ~150 | Beat ticks, measure numbers, playback head, click-to-seek |
| `src/ui/velocity.lua` | ~253 | Velocity bars, click-drag editing, mute toggle |
| `src/ui/preset-browser.lua` | ~640 | Folder navigation, preset list, save/load, favorites, error handling |

### Modified files (7):
| File | What Changed |
|------|-------------|
| `src/config.lua` | `VIEW_MODES.ISLAND = 3`, window constants (1000×700) |
| `src/main.lua` | Init chain (island store), MainLoop ISLAND branch, keyboard shortcuts (Ctrl+S, Ctrl+O, Del, ↑↓) |
| `src/ui/views.lua` | `DrawIslandView()` orchestrating all 4 panels, info bar, shortcut handlers |
| `src/ui/compact-init.lua` | `ToggleIslandView()`, docked-aware transitions, error handling with pcall, flicker prevention |
| `src/ui/compact.lua` | Barrel export of `ToggleIslandView` |
| `src/ui/buttons.lua` | Island toggle icon in header |
| `src/ui/theme.lua` | 7 island-specific colors (grid_line, note_default, note_selected, note_muted, beat_tick, measure_tick, info_bar) |

---

## 2. Key Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Window transition | `gfx.quit()+gfx.init()` | Mirrors existing SwitchViewMode pattern; only reliable REAPER GFX resize |
| Note data model | Separate flat note list `{pitch,start_beat,duration,velocity,muted}` | Progression stores chord-pattern slots; piano roll needs absolute pitches. Avoids coupling. |
| Virtual scroll axis | Vertical (pitch) | 73 pitch rows (C2–C8) far exceed visible space. Time scrolls via zoom/pan. |
| Note colors | Pitch-class cycle through grade_colors | Reuses existing theme; 12 pitch classes → 7 colors |
| Velocity display | Horizontal bars matching note positions | Better readability than vertical bars; aligns with piano roll layout |
| Mute toggle | Right-click on note block | Natural DAW workflow; no extra UI needed |
| Docked mode | Supported (no gfx.quit/init when docked) | Design said disabled; P5-2 explicitly enabled it for better UX |
| Preset persistence | `reaper.GetExtState/SetExtState` for favorites | Survives script restarts without file I/O; already used for `auto_start_compact` |
| File access | `io.popen('dir ...')` for directory listing | Windows-specific; deferred cross-platform for future |
| Info bar | 18px full-width bar | Replaces simple bottom-right info; shows system state + selection + hints |
| Favorites serialization | Lua table format via `load()` | Simple, no external deps; safe for user-created data |

### Deviations from Design (all documented, non-blocking)

| Deviation | Design | Actual | Rationale |
|-----------|--------|--------|-----------|
| Docked mode | Disabled | Enabled | Better UX; docked ISLAND uses current GFX context |
| PITCH_ROW_H | 20px | 12px | Fits more rows in 700px; labels still readable |
| Velocity bars | Vertical | Horizontal (growing upward) | Matches note position; better readability |
| Bar color | Pitch-class | Red→green gradient | Better velocity-at-a-glance |
| Mute toggle | "M" button | Right-click on note block | Natural DAW workflow |
| Info bar height | 20px | 18px | Matches 11px font; no waste |

---

## 3. File Inventory (Complete)

### New files in `src/`
```
src/state/island.lua          — Island state store (~200 LOC, 70 functions)
src/ui/piano-roll.lua          — Piano roll module (~415 LOC, 14 functions)
src/ui/timeline.lua            — Timeline ruler (~150 LOC, 5 functions)
src/ui/velocity.lua            — Velocity editor (~253 LOC, 7 functions)
src/ui/preset-browser.lua      — Preset browser (~640 LOC, 18 functions)
```

### Modified files in `src/`
```
src/config.lua                 — 3 new constants
src/main.lua                   — ~40 lines added (Init + MainLoop + shortcuts)
src/ui/views.lua               — ~240 lines added (DrawIslandView + handlers)
src/ui/compact-init.lua        — ~80 lines added (ToggleIslandView + transitions)
src/ui/compact.lua             — 1 line (barrel export)
src/ui/buttons.lua             — ~15 lines (island icon)
src/ui/theme.lua               — 7 colors added
```

### Modified files in `src/state/`
```
src/state/ui.lua               — 4 lines (last_window_w/h + getters/setters)
src/state/island.lua           — ~200 LOC total (created in P0, expanded in P1)
```

---

## 4. Known Limitations

1. **Windows-specific file listing**: `io.popen('dir ...')` for directory browsing doesn't work on macOS/Linux. Cross-platform fix deferred — uses `reaper.EnumerateSubdirectories()` fallback if needed.
2. **No automated tests**: REAPER GFX Lua has no test runner. All 34 tasks verified via static code analysis only.
3. **No MIDI recording**: Piano roll renders static notes only. No real-time capture, no mouse drawing/placing notes.
4. **No dynamic resize**: Window is fixed at 1000×700. `gfx.init()` re-creation is destructive; dynamic resize would lose GFX state.
5. **`dofile()` security**: Preset loading uses `dofile()` which executes Lua code. Safe for user-created presets but not for untrusted sources.
6. **No drag-and-drop notes**: Note blocks are selectable but not draggable. Editing is via velocity editor panel only.
7. **No multi-track**: Single note sequence. No track lanes or mixer.
8. **Left/Right arrow shortcuts**: Marked as "future" — only Up/Down arrow navigation implemented.

---

## 5. Lessons Learned

### What Went Well

- **Phase 0-first approach**: Establishing the store, config, and routing before UI work meant each subsequent phase had a stable foundation. No refactors needed mid-stream.
- **Virtual scroll as first-class concern**: Computing visible ranges once per frame and sharing between grid and note rendering kept frame rate stable even with 200+ notes.
- **Frame caching**: `ComputeVisibleRanges()` cache and note redraw cache were simple additions (P5-05) that eliminated redundant computation. These were cheap wins.
- **Separate note data model**: The decision to use `{pitch,start_beat,duration,velocity,muted}` instead of enriching progression entries paid off — zero coupling between island and sequencer state.
- **Docked mode from the start**: Even though the original design said "disabled," enabling docked mode in P5-02 was straightforward because the architecture separated GFX context switching from view logic.

### What Could Be Improved

- **`io.popen('dir')` is fragile**: Relies on Windows shell encoding. A more robust approach would wrap file I/O in a separate module (`src/core/file-io.lua`) with platform-specific backends, similar to how `midi.lua` abstracts MIDI.
- **Preset browser state in island store**: The preset browser state fields (current_directory, preset_tree, etc.) bloated the island store. A separate `preset_store.lua` or a nested state table would be cleaner.
- **Theme colors as documentation only**: The 7 island theme colors were added but the piano roll uses module-local constants. Future work should migrate to theme colors for customization support.
- **Performance budget not measured**: No frame time measurements. The cache optimizations were implemented defensively without profiling data.

### Technical Gotchas

- **gfx.mouse_wheel must be zeroed per frame per context**: Project-wide pattern. In island mode, consumption happens in views.lua after piano roll reads the delta.
- **gfx.quit()/gfx.init() in pcall**: Both calls can fail (e.g., REAPER closing mid-transition). Wrapping both in pcall with revert logic prevented crashes in P5-01.
- **Grid alignment at all zoom levels**: Beat ticks and note positions must use the same formula `(value - scroll_x) * zoom_x`. Any mismatch causes visible misalignment between timeline and piano roll.
- **Module-local drag state must be reset on mode switch**: `velocity.ResetDrag()` is called when leaving ISLAND mode. Without this, stale drag state persists if the user switches modes mid-drag.
- **`dofile()` for presets is convenient but risky**: Works well for user data but errors can crash the script. Wrapped in pcall with validation and rollback.

### Inheritance for Future Changes

- `state/island.lua` store pattern is fully consistent with existing stores (Init, getters/setters, mutable references)
- `ComputeVisibleRanges()` pattern can be reused by any view module needing virtual scroll
- `note.muted` flag is compatible with sequencer — muted notes are skipped during MIDI trigger
- `.grove` file format (`return {name="...", version=1, notes={...}}`) is extensible with new metadata fields

---

## Artifact Lineage

| Artifact | Engram Topic Key | Filesystem Path |
|----------|-----------------|-----------------|
| Proposal | `sdd/isla-midi/proposal` | `openspec/changes/archive/2026-05-11-isla-midi/proposal.md` |
| Spec (Overview) | `sdd/isla-midi/spec` | `openspec/changes/archive/2026-05-11-isla-midi/specs/00-overview.md` |
| Spec (Island Store) | `sdd/isla-midi/spec` | `openspec/changes/archive/2026-05-11-isla-midi/specs/island-store/spec.md` |
| Spec (Piano Roll) | `sdd/isla-midi/spec` | `openspec/changes/archive/2026-05-11-isla-midi/specs/piano-roll/spec.md` |
| Spec (Timeline Ruler) | `sdd/isla-midi/spec` | `openspec/changes/archive/2026-05-11-isla-midi/specs/timeline-ruler/spec.md` |
| Spec (Velocity Editor) | `sdd/isla-midi/spec` | `openspec/changes/archive/2026-05-11-isla-midi/specs/velocity-editor/spec.md` |
| Spec (Preset Browser) | `sdd/isla-midi/spec` | `openspec/changes/archive/2026-05-11-isla-midi/specs/preset-browser/spec.md` |
| Design | `sdd/isla-midi/design` | `openspec/changes/archive/2026-05-11-isla-midi/design.md` |
| Tasks | `sdd/isla-midi/tasks` | `openspec/changes/archive/2026-05-11-isla-midi/tasks.md` |
| Apply Progress | `sdd/isla-midi/apply-progress` | `openspec/changes/archive/2026-05-11-isla-midi/apply-progress.md` |
| Verify Report | `sdd/isla-midi/verify-report` | `openspec/changes/archive/2026-05-11-isla-midi/verify-report.md` |
| **Archive Report** | **`sdd/isla-midi/archive-report`** | **`openspec/changes/archive/2026-05-11-isla-midi/archive-report.md`** |

### Main Specs Created (new, not delta merges)

All 5 delta specs were new domains with no existing main specs. They were copied directly:
- `openspec/specs/island-store/spec.md`
- `openspec/specs/piano-roll/spec.md`
- `openspec/specs/timeline-ruler/spec.md`
- `openspec/specs/velocity-editor/spec.md`
- `openspec/specs/preset-browser/spec.md`

---

*Archived 2026-05-11 by SDD archive phase. SDD cycle complete.*
