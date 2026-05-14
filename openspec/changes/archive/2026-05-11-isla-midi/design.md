# Design: Isla MIDI — Island Piano Roll View

## Technical Approach

Add `VIEW_MODES.ISLAND = 3` with a dedicated 1000×700 GFX window. Three panels: preset browser (left, collapsible), timeline (top), piano roll (center with velocity editor). Notes materialize from progression entries via a flat-note conversion into an island store. Virtual scrolling renders only ~20 of 73 visible pitch rows per frame.

---

## Architecture Decisions

| Decision | Options | Choice & Rationale |
|----------|---------|-------------------|
| Window transition | (a) `gfx.quit()+gfx.init()` (b) Single window resize | **(a)** — mirrors existing `SwitchViewMode()` and `ToggleIsland()` patterns. `gfx.init()` with new dims is the only reliable REAPER GFX resize. State preserved via `last_gfx_state` on `compact_store`. |
| Note data model | (a) Enrich progression entries (b) Separate flat note list | **(b)** — Progression stores chord-pattern slots `{degree,root,scale,octave,chord_mode}`. Piano roll needs absolute `{pitch,start_beat,duration,velocity,muted}`. Separate model avoids coupling. |
| Filesystem access | (a) `io.popen('dir')` (b) `reaper.EnumerateFiles()` (c) `reaper.GetResourcePath()` + raw `io.open` | **(c)** — `GetResourcePath()` is portable and already used in `main.lua` for startup scripts. `EnumerateFiles()` returns only REAPER resource files, not arbitrary presets. `io.open` for reading `.grove` files. |
| Virtual scroll axis | (a) Horizontal (time) (b) Vertical (pitch) | **(b)** — 73 pitch rows (C2–C8) far exceed visible space. Time axis scrolls via zoom/pan. Render visible pitch rows + 2-octave buffer. |
| Preset persistence | (a) `reaper.GetExtState/SetExtState` (b) File on disk | **(a)** — Favorites, bookmarks, last-browsed path. Already used for `auto_start_compact`. Survives script restarts without file I/O. |

## Data Flow

```
User Input (mouse/wheel/key)
        │
        ▼
  island_store ←── ProgressionToNotes() ←── seq_store.GetProgression()
        │                                          (chord slots 1-16)
        │
        ├──→ island_state.notes[]          ← flat note list
        ├──→ island_state.scroll_offset    ← vertical scroll
        ├──→ island_state.zoom_level       ← horizontal zoom
        └──→ island_state.preset_browser   ← folder/file tree
                │
                ▼
         Render Pipeline (per frame)
         ├── DrawPresetBrowser(x=0, w=200|0)
         ├── DrawTimeline(x=0, y=0, w=1000, h=40)
         │     └── beat markers synced to sequencer_store
         └── DrawPianoRoll(x, y=40, w=1000, h=660)
               ├── DrawGrid(pitch_rows × beat_columns)
               ├── DrawNoteBlocks(visible_notes only)
               ├── DrawPlaybackHead()
               └── DrawVelocityEditor(x, y, w, h)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/config.lua` | Modify | Add `VIEW_MODES.ISLAND = 3` |
| `src/state/island.lua` | Create | Island state store |
| `src/ui/piano-roll.lua` | Create | Piano roll grid + note blocks + virtual scroll |
| `src/ui/timeline.lua` | Create | Beat/measure ruler + playback head |
| `src/ui/velocity.lua` | Create | Per-note velocity bars + mute toggle |
| `src/ui/preset-browser.lua` | Create | Filesystem tree + preset list + load/save |
| `src/main.lua` | Modify | Island routing in MainLoop + SwitchViewMode |
| `src/ui/views.lua` | Modify | `DrawIslandView()` entry point |
| `src/ui/compact-init.lua` | Modify | `SwitchViewMode` handles ISLAND |

## Interfaces / Contracts

### `state/island.lua` (New Store)

```lua
-- Island state (module-local table)
local island_state = {
    notes = {},           -- {pitch, start_beat, duration, velocity, muted}[]
    notes_dirty = true,   -- recalculation flag after progression change
    scroll_offset = 0,    -- 0..56 (73-17 visible) — vertical scroll in pitch rows
    zoom_level = 1,       -- 1, 2, 4 — beats per pixel multiplier
    
    -- Preset browser
    preset_root = "",     -- reaper.GetResourcePath() .. "/grove-presets/"
    preset_tree = {},     -- {name, is_dir, children[]}[]
    preset_files = {},    -- {name, path, is_favorite}[]
    selected_preset = nil,-- currently selected preset name
    browser_open = true,  -- left panel collapsed/expanded
    
    -- Selection
    selected_notes = {},  -- {[pitch] = true} — for velocity editing
}
```

Key functions:
```lua
-- island.ProgressionToNotes() → void
--   Reads seq_store.GetProgression(), converts each slot's chord offsets
--   into absolute-pitch note entries. Sets island_state.notes.
--   slot i (1..16) → start_beat = (i-1) * 4
--   Each chord offset → pitch = GetMidiNote(slot.*, degree+off)
--   Duration = 4 beats, velocity = 100, muted = false

-- island.GetVisibleNotes(offset, visible_rows, start_beat, end_beat) → note[]
--   Filters island_state.notes by pitch range and time range.
--   Called each frame for rendering.

-- island.SetScrollDelta(delta) → void
--   Clamps: 0 ≤ scroll_offset ≤ 56 (73 rows − min 17 visible)

-- island.ToggleNoteMuted(pitch, start_beat) → void
--   Toggles muted flag on matching note entry.
```

### `piano-roll.lua` — Critical Rendering Path

```lua
-- DrawPianoRoll(x, y, w, h) → void
--   local visible_rows = math.ceil(h / ROW_H)      -- ~17-20 rows
--   local pitch_start = 60 + island.scroll_offset    -- C4 = 60
--   local pitch_end = pitch_start + visible_rows + 8 -- +2 octave buffer
--   
--   -- Draw grid lines (beats × pitch)
--   for beat = visible_start, visible_end do
--       DrawVerticalLine(x + beat * col_w, y, y + h, beat_color)
--   end
--   for row = 0, visible_rows do
--       local py = y + row * ROW_H
--       DrawPitchLabel(pitch_start + row, x - LABEL_W, py, LABEL_W, ROW_H)
--       DrawHorizontalLine(x, py, x + w, grid_color)
--   end
--   
--   -- Draw note blocks (virtual-scrolled)
--   local visible = island.GetVisibleNotes(pitch_start, pitch_end, beat_start, beat_end)
--   for _, note in ipairs(visible) do
--       local nx = x + (note.start_beat - beat_start) * col_w
--       local ny = y + (note.pitch - pitch_start) * ROW_H
--       local nw = note.duration * col_w
--       DrawRoundedRect(nx + 1, ny + 1, nw - 2, ROW_H - 2, 3,
--           note.muted and muted_color or active_color)
--   end
--
--   -- Playback head (reads seq_store.GetProgress())
--   local hx = x + seq_store.GetProgress() * total_beats * col_w
--   DrawVerticalLine(hx, y, y + h, playback_color)
```

### `preset-browser.lua` — File Access

```lua
-- preset.RefreshTree() → void
--   local root = reaper.GetResourcePath() .. "/grove-presets/"
--   -- Build directory tree via io.popen("dir " .. root .. " /B /AD")
--   -- or iterative reaper.EnumerateFiles() for .grove files
--   
-- preset.SavePreset(name) → void
--   -- Serialize island_state.notes[] and seq_store state
--   -- Write via io.open(path, "w")
--   
-- preset.LoadPreset(name) → table
--   -- Read file, parse, populate island_state.notes[]
--   -- Also restore seq_store state (root, scale, etc.)
```

### Window Transition: FULL ↔ ISLAND

```lua
-- Modified SwitchViewMode in compact-init.lua:
--   ISLAND → FULL: 
--     island_store.SetLastGfxState({x,y,w,h})  -- save current geometry
--     gfx.quit()
--     gfx.init(720, 497, dock, gs.x, gs.y)     -- restore FULL dims
--
--   FULL → ISLAND:
--     compact_store.SetLastGfxState({...})       -- save FULL geometry
--     gfx.quit()
--     gfx.init("GROVE SCALE RUNNER", 1000, 700, 0, gs.x, gs.y)
--
-- Isolation guarantee: ISLAND mode disables dock toggle,
-- same as ToggleIsland() does for MIDI island currently.
```

### Virtual Scrolling Algorithm

```
Given: 73 pitch rows total (C2=36 to C8=108)
Viewport: h pixels, ROW_H = 20px → max_visible = floor(h / ROW_H) ≈ 35

Each frame:
  1. pitch_start = 36 + island_state.scroll_offset
     pitch_end   = pitch_start + max_visible
     
  2. note_filter = [n for n in island_state.notes
                    if n.pitch >= pitch_start
                    and n.pitch <= pitch_end + 12]   -- +1 octave buffer

  3. beat_range calculation:
     beat_start = floor(x_scroll / col_w)
     beat_end   = beat_start + floor(w / col_w)
     
  4. final = [n for n in note_filter
              if n.start_beat + n.duration >= beat_start
              and n.start_beat <= beat_end]

  Performance: O(N) over ~73×16 entries → N < 1200, well within budget
  for immediate-mode GFX at 30fps.
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `ProgressionToNotes()` conversion | Static: verify slot `{degree=1,root=1,scale=1,octave=4}` → correct pitch list. No REAPER needed. |
| Unit | `island_store.SetScrollDelta()` clamping | Bounds check: 0, max, negative |
| Unit | `GetVisibleNotes()` filtering | Pitch range + time range intersection |
| Manual | Piano roll rendering | Open REAPER, switch to ISLAND mode, verify note blocks align to grid |
| Manual | Preset browser `io.open` | Check path resolution, error handling for missing directories |

## Open Questions

- [ ] `gfx.init()` at 1000×700 — does REAPER constrain max window size based on screen resolution? Should we compute from `gfx.w/gfx.h` or hard-code?
- [ ] Progression→Notes conversion: should each slot produce a single block covering the full measure, or 4 quarter-note blocks per chord note for visual clarity?
- [ ] Preset file format: minimal Lua table `return {}` (evaled via `dofile`) or custom token-based parser (safer but more code)? Existing `io.open` startup wrapper uses `dofile`.
- [ ] Velocity editor Phase 2: drag-to-edit or click-to-set? Proposal defers to Phase 2.

## Phase Breakdown

| Phase | Modules | Scope |
|-------|---------|-------|
| P0 | config.lua, island.lua | VIEW_MODES.ISLAND constant, island store, empty `DrawIslandView()`, window transition wiring, MainLoop routing |
| P1 | piano-roll.lua | Grid rendering, note blocks from `ProgressionToNotes()`, virtual scroll, playback head |
| P2 | timeline.lua | Beat markers, measure numbers, position display, synced to sequencer_store |
| P3 | velocity.lua | Velocity bars per note, mute toggle, note property display |
| P4 | preset-browser.lua | File tree, preset list, load/save dialogs, favorites, collapsible left panel |
| P5 | Edge cases | Docked mode guard, switch back from ISLAND preserves FULL state, collision with MIDI island expand |
