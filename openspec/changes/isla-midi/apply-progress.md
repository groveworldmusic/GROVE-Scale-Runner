# Apply Progress: Isla MIDI — Unit 1 (Foundation)

## Change
`isla-midi` | Phase 0 — Foundation | Unit 1 of 4

## Status
7/7 tasks complete (P0.1–P0.7). Ready for Unit 2.

## Completed Tasks

### P0.1 — Add VIEW_MODES.ISLAND to config.lua
- Added `ISLAND = 3` to `config.VIEW_MODES`
- Added `config.ISLAND_WINDOW_W = 1000`, `config.ISLAND_WINDOW_H = 700`
- Added `config.ISLAND_PRESET_PANEL_W = 220`

### P0.2 — Create state/island.lua store
- Full store with getter/setter pattern matching existing stores
- Schema: `island_active`, `preset_panel_visible`, `notes` (flat note list), `playback_pos`, `scroll_offset_y`, `scroll_offset_x`, `zoom_x`, `selected_note_index`, `note_count`
- Init function matching existing pattern (merge from config.state by key)
- Scroll clamping: scroll_offset_y clamped 0..56, scroll_offset_x clamped ≥0, zoom_x clamped 10..200
- `GetNotes()` returns internal table by reference (mutable)
- `SetNotes(t)` auto-updates note_count

### P0.3 — Wire island_store into main.lua Init chain
- Added `local island_store = require("state.island")` after ui_store
- Added `island_store.Init(config.state)` in Init sequence (after ui_store, before core modules)
- Follows exact existing pattern

### P0.4 — Expand view mode switching for ISLAND
- Modified `SwitchViewMode()` in compact-init.lua: ISLAND→FULL restores previous window size via `ui_store.GetLastWindowW/H()`
- Added `ToggleIslandView()` function: FULL→ISLAND saves current window dims, gfx.quit(), gfx.init() at 1000×700; ISLAND→FULL restores saved dims
- Guard: docked mode blocks ISLAND toggle (early return)
- Exported `ToggleIslandView` via compact.lua barrel
- Added `last_window_w/last_window_h` to ui_store with getters/setters

### P0.5 — Add ISLAND routing in MainLoop
- Early ISLAND branch in MainLoop before GFX mode: calls `views.DrawIslandView()`, handles gfx.getchar() for exit, defers
- F12 handling in ISLAND mode calls `compact.ToggleIslandView()`
- Re-check after DrawFullView for ISLAND mode transitions
- F12 handling in FULL mode's gfx.getchar() section

### P0.6 — Guards
- Docked mode guard in `ToggleIslandView()` — returns early if docked
- Window size guard in `DrawIslandView()` — returns early if gfx.w < 800 or gfx.h < 550

### P0.7 — Data integrity features (code)
- Scroll clamping on SetScrollOffsetY (0..56), SetScrollOffsetX (≥0), SetZoomX (10..200)
- selected_note_index supports nil-clear (setter accepts nil)
- Notes table returned by mutable reference from GetNotes()

## Additional Implementations

### Island toggle UI
- Added "island" tool icon type in buttons.lua (DrawToolIcon) — mini grid with note block
- Added 4th tool icon in DrawHeader (island toggle button next to view toggle)
- F12 keyboard shortcut in both ISLAND and FULL MainLoop branches

### DrawIslandView() stub
- Background fill
- Preset panel background (left panel, collapsible, 220px wide)
- "MIDI Island" title centered
- "Piano Roll View — Coming in Unit 2" subtitle
- "F12: Exit" hint bottom-right
- Window size guard (800×550 minimum)

## Deviations from Design
- Task description said "views.lua" for SwitchViewMode expansion; actual SwitchViewMode is in compact-init.lua (followed design doc which correctly identified compact-init.lua)
- Used ui_store.last_window_w/h instead of compact_store.last_gfx_state for ISLAND restoration (separate concern from compact mode GFX state)
- Did NOT modify the existing FULL↔COMPACT toggle behavior — ISLAND has its own dedicated ToggleIslandView() function

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `src/state/island.lua` | Created | Island state store (81 LOC) |
| `src/config.lua` | Modified | Added VIEW_MODES.ISLAND, ISLAND_WINDOW_W/H, ISLAND_PRESET_PANEL_W |
| `src/state/ui.lua` | Modified | Added last_window_w/last_window_h fields + getters/setters |
| `src/ui/compact-init.lua` | Modified | Added ISLAND→FULL to SwitchViewMode, new ToggleIslandView() |
| `src/ui/compact.lua` | Modified | Re-exported ToggleIslandView in barrel |
| `src/main.lua` | Modified | island_store require/Init, ISLAND MainLoop routing, F12 shortcut |
| `src/ui/views.lua` | Modified | Added DrawIslandView() stub, island icon in header |
| `src/ui/buttons.lua` | Modified | Added "island" type to DrawToolIcon |

## Dependencies for Unit 2
- island_store with all getters/setters fully functional
- DrawIslandView() stub ready for piano roll rendering
- ToggleIslandView() for FULL↔ISLAND transitions
- Modular structure separates concerns cleanly

## Issues Found
- F12 key handling via gfx.getchar() (char==123) needs REAPER verification — GFX API behavior for function keys varies
- No automated test runner available — P0.7 tests require manual REAPER testing

---

# Unit 2 — Piano Roll + Timeline

## Change
`isla-midi` | Phase 1 (Piano Roll) + Phase 2 (Timeline Ruler) | Unit 2 of 4

## Status
11/11 tasks complete (P1-01 through P2-04). Ready for Unit 3.

## Completed Tasks

### P1-01 — Create `ui/piano-roll.lua` module
- Created new module with 7 functions:
  - `DrawPianoRoll(x, y, w, h)` — main entry point, orchestrates grid + note blocks + playback head + scrollbar
  - `DrawPianoRollGrid(x, y, w, h, scroll_y, scroll_x, zoom_x)` — draws horizontal pitch rows + vertical beat lines
  - `DrawNoteBlock(note, nx, ny, nw, nh, selected)` — draws a single note block as colored rounded rect
  - `DrawNoteBlocks(x, y, w, h, scroll_y, scroll_x, zoom_x)` — renders all visible notes from island_store
  - `NoteBlockHitTest(mx, my, notes, scroll_y, scroll_x, zoom_x, grid_x, grid_y)` — mouse hit test (returns index)
  - `HandleMouseClick(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)` — click handler sets selected_note_index
  - `HandleMouseWheel(delta, scroll_x, zoom_x)` — computes new horizontal scroll from wheel delta
- Module-local constants: PITCH_ROW_H=12, PITCH_LABEL_W=40, MIN_PITCH=36(C2), MAX_PITCH=108(C8)
- Note color scheme: pitch-class-based cycling through grade_colors (12 pitch classes → 7 grades)
- Grid colors: strong beat lines at measure boundaries, weak lines for inner beats
- White key rows get subtle background tint, black key rows are darker
- Playback head: red vertical line at island_store.GetPlaybackPos()
- Vertical scrollbar indicator on right edge of grid area
- Selected note gets white border emphasis via gfx.roundrect
- Muted notes render at reduced opacity via NOTE_MUTED color

### P1-02 — Horizontal grid rendering
- Y axis: 73 pitch rows (C2=36 to C8=108) with PITCH_ROW_H=12px each
- X axis: beat columns at (beat - scroll_x) * zoom_x pixels
- Horizontal lines at each pitch row boundary (lighter for white keys, darker for black keys match)
- Vertical lines at each beat boundary (strong at measure starts beat%4==0, weak for inner beats)
- Octave labels on left edge: "C2", "C#2", "D2", etc. for white keys (drawn in the PITCH_LABEL_W area)
- Beat grid background color: dark gray (GRID_BG)

### P1-03 — Note blocks rendering from island_store notes
- Reads `island_store.GetNotes()` each frame
- Calculates pixel position: x = (note.start_beat - scroll_x) * zoom_x, width = note.duration * zoom_x
- Y = (note.pitch - pitch_start) * PITCH_ROW_H, height = PITCH_ROW_H
- Each note block drawn as rounded rect with 3px corner radius via `components.DrawRoundedRect`
- Colors based on pitch class (note % 12), cycling through 7 grade_colors
- Selected note (matching island_store.GetSelectedNoteIndex()) gets white border overlay
- Muted notes (note.muted == true) render in grayed-out color

### P1-04 — Virtual scrolling implementation
- Calculates visible pitch rows from scroll_offset_y and grid height: `visible_rows = ceil(h / PITCH_ROW_H) + 2`
- Calculates visible beat range from scroll_offset_x, grid width, and zoom_x: `beat_start = scroll_x - 1`, `beat_end = scroll_x + ceil(w / zoom_x) + 1`
- Notes outside pitch range OR time range are skipped via `goto continue` (efficient skipping)
- +1 octave buffer (12 rows) above and below visible range to prevent pop-in
- Scroll offset Y clamped 0..56 by island_store.SetScrollOffsetY()
- Total rows = 73, min visible rows ≈ 17 at 700px window height → max scroll = 56

### P1-05 — ProgressionToNotes conversion function
- Added to `state/island.lua`:
  - `ProgressionEntryToPitch(root_idx, scale_idx, degree_idx, octave_val)` — matches midi.GetMidiNote formula exactly
  - `EntryToPitches(entry)` — converts a progression slot entry to array of MIDI pitches via chord mode offsets
  - `m.ProgressionToNotes(progression, beats_per_slot, velocity)` — converts full 16-slot progression table to flat note list
  - `m.LoadNotesFromProgression(seq_store)` — reads from sequencer_store and populates island notes
  - `m.GetVisibleNotes(notes, pitch_start, pitch_end, beat_start, beat_end)` — filters by pitch + time range
- Each slot i produces notes starting at beat (i-1) * beats_per_slot
- Each chord offset becomes a separate note entry with duration = beats_per_slot
- Default velocity 100, muted false
- Pure functions — no external state mutation (except LoadNotesFromProgression)

### P1-06 — Click selection in piano roll
- `NoteBlockHitTest` iterates notes in reverse render order (topmost first via descending index)
- Converts mouse pixel position to beat + pitch row space
- Checks pitch match first, then beat range (start to start+duration)
- Returns index into notes array if hit, nil otherwise
- `HandleMouseClick` calls hit test and sets/clears selected_note_index
- Click on empty area deselects (SetSelectedNoteIndex(nil))
- Mouse event routing in DrawIslandView passes through correctly (timeline click consumed first, then piano roll)

### P1-07 — Integrate piano roll into DrawIslandView()
- Replaced stub with full implementation:
  - Synch playback position from sequencer each frame via `timeline.SyncPlaybackPosition()`
  - Preset panel: left panel (220px) with "PRESETS" header, "(coming in Unit 3)" placeholder
  - Collapse button (◄) at top-right of preset panel
  - Expand handle (►) on left edge when panel is collapsed — thin 12×60px handle, centered vertically
  - Timeline ruler at top of right area (28px height)
  - Piano roll fills remaining right area below timeline
  - Mouse event handling: timeline click → seek, piano roll click → select note, wheel → horizontal scroll
  - Exit hint bottom-left: "F12: Exit | Ctrl+I: Toggle"
  - Info bar bottom-right: "Notes: N | Zoom: Z px/beat"
  - Requires piano_roll and timeline at top of views.lua

### P2-01 — Create `ui/timeline.lua` module
- New module with 5 functions:
  - `DrawTimelineRuler(x, y, w, h, grid_h)` — main entry, draws background + labels + ticks + playhead
  - `DrawBeatTicks(x, y, w, h, zoom_x, scroll_x)` — draws measure/beat tick marks
  - `DrawPlaybackHead(x, y, h, grid_h, playback_pos, zoom_x, scroll_x, ruler_only)` — playhead line + triangle handle
  - `TimelineHitTest(mx, grid_x, scroll_x, zoom_x)` — converts click x to snapped beat position
  - `SyncPlaybackPosition()` — reads sequencer progress and updates island_store playback pos
- Constants: TIMELINE_H=28, PITCH_LABEL_W=40 (matching piano roll)

### P2-02 — Beat/measure ticks rendering
- Measure ticks (every 4 beats): taller (16px), bolder color, with measure number label ("1", "2", etc.)
- Beat ticks (every beat): shorter (8px), lighter color, no label
- Label overlap prevention: tracks last_label_end, skips if would overlap (4px padding)
- Label position: centered above tick, at ruler vertical midpoint
- Colors: MEASURE_TICK_COLOR bright, BEAT_TICK_COLOR muted, MEASURE_TEXT_COLOR readable
- Background: darker BG_COLOR with left LABEL_W area matching piano roll island_bg
- "BEATS" label in the left label area

### P2-03 — Playback head
- Red vertical line from ruler through piano roll grid
- Reads island_store.GetPlaybackPos() for position
- Updates each frame via SyncPlaybackPosition() called at start of DrawIslandView()
- Triangular handle at top of playhead (inverted triangle, 5px half-width)
- Only renders when sequencer is playing (seq_store.GetIsPlaying())
- Playback position synced from sequencer: `total_beats = current_step * 4 + progress * 4`

### P2-04 — Click-to-seek in timeline
- Mouse click in ruler area: calls `TimelineHitTest(mx, grid_x, scroll_x, zoom_x)`
- Converts pixel x to beat: `beat = (mx - grid_x) / zoom_x + scroll_x`
- Snaps to nearest whole beat: `math.floor(beat + 0.5)`
- Clamped to minimum 0
- Sets island_store.SetPlaybackPos(snapped_beat)
- Event priority: timeline click consumed first, prevents note selection on same frame

## Additional Implementations
- Auto-populate notes from progression when entering island mode: added `island_store.LoadNotesFromProgression(seq_store)` call in `ToggleIslandView()` (compact-init.lua line ~131)
- Preset panel collapse/expand: ◄ button when visible, ► handle when collapsed
- Window size guard preserved (800×550 minimum)
- Mouse wheel scroll speed proportional to zoom level

## Deviations from Design
- Used PITCH_ROW_H=12 instead of design's 20px — 12px fits more rows in 700px window while keeping labels readable
- Implemented note color via pitch-class cycle through grade_colors instead of static colors — reuses existing theme
- Timeline ruler explicitly draws the playhead line through both ruler AND grid height (design showed only ruler)
- SyncPlaybackPosition uses simple formula `step*4 + progress*4` rather than sequencer's internal beat tracking — avoids coupling with sequencer internals
- Scrollbar added on right edge of piano roll grid for vertical scroll affordance
- Info bar at bottom-right shows note count and zoom level (not in original spec but useful for debugging)

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `src/ui/piano-roll.lua` | Created | Piano roll module (296 LOC) — grid, note blocks, virtual scroll, hit testing |
| `src/ui/timeline.lua` | Created | Timeline ruler module (150 LOC) — beat ticks, playhead, seek |
| `src/state/island.lua` | Modified | Added ProgressionToNotes, LoadNotesFromProgression, GetVisibleNotes, +config require |
| `src/ui/views.lua` | Modified | Expanded DrawIslandView() with piano roll + timeline integration, mouse/wheel handling |
| `src/ui/compact-init.lua` | Modified | Added seq_store require, LoadNotesFromProgression call on island entry |

---
# Unit 3 — Velocity Editor + Preset Browser

## Change
`isla-midi` | Phase 3 (Velocity Editor) + Phase 4 (Preset Browser) | Unit 3 of 4

## Status
10/10 tasks complete (P3-01 through P4-06). Ready for Unit 4 (Polish).

## Completed Tasks

### P3-01 — Create `ui/velocity.lua` module
- Created new module with 7 functions/entries:
  - `DrawVelocityBar(x, y, w, h, velocity, selected, muted)` — draws a single velocity bar
  - `DrawVelocityEditor(x, y, w, h, notes, scroll_x, zoom_x, selected_idx)` — draws velocity bars below piano roll
  - `VelocityHitTest(mx, my, notes, grid_x, ed_y, ed_h, scroll_x, zoom_x)` — hit test for click detection
  - `HandleVelocityMouse(mx, my, grid_x, ed_y, ed_h, scroll_x, zoom_x, click, mouse_down)` — click-drag handler
  - `ResetDrag()` — reset drag state on mode switch
  - `VelocityGradient(velocity)` — red→green color gradient based on velocity value
- Module constants: `EDITOR_H=80`, `VELOCITY_MIN_H=2`, `VELOCITY_MAX_H=60`
- Bar colors: red (low vel) → green (high vel), muted notes in gray
- Selected bar: white border + velocity value label
- Drag state: module-local (not in store) — `drag_active`, `drag_note_index`
- Velocity mapping: mouse Y → 0-127, clamped, real-time update during drag

### P3-02 — Velocity bars rendering integration
- Bars drawn below piano roll in a dedicated 80px area
- Each bar: X = note.start_beat position, W = note.duration * zoom_x, H = proportional to velocity
- Vertical beat grid lines matching piano roll above
- Label area with "VEL" text (matching piano roll's PITCH_LABEL_W=40)
- Baseline drawn at bottom of editor area
- Only bars for notes in visible time range are rendered (efficient)
- Selected bar gets white border and velocity number label

### P3-03 — Click-drag velocity editing
- On fresh left-click on a bar: hit test → set `selected_note_index` → immediate velocity update
- On drag (mouse_cap & 1 held): map mouse Y to 0-127 → update note.velocity in-place via GetNotes() ref
- On mouse release: drag_active reset, velocity value finalized
- Clamp: velocity clamped 0-127 (min 0 gives 2px bar via VELOCITY_MIN_H)
- No new store fields needed — uses existing selected_note_index + inline notes mutation

### P3-04 — Mute toggle per note (right-click on piano roll)
- Added `piano_roll.HandleRightClickMute(mx, my, grid_x, grid_y, scroll_y, scroll_x, zoom_x)` function
- Right-click detection: `(gfx.mouse_cap & 2) == 2 and (last_cap & 2) == 0` for fresh right-click press
- On right-click hit test on note block: toggles `note.muted`, sets selected_note_index
- Right-click on empty area: no-op (does not show context menu)
- Muted notes already rendered dimmer in piano roll (existing NOTE_MUTED color)
- Muted notes render with gray color in velocity editor
- Muted notes still respond to click/drag for velocity editing

### P4-01 — Create `ui/preset-browser.lua` module
- Created new module with 15+ functions:
  - `Init()` — sets up root directory, creates grove-presets/ on first access, scans directory, loads favorites
  - `ScanDirectory(dir_path)` — scans for subdirs (via `io.popen`) and .grove files, builds tree + file list
  - `SavePreset(file_path, preset_name)` — serializes notes as `return {name=..., notes={...}, version=1}`
  - `LoadPreset(file_path)` — reads via `dofile()`, validates notes array, handles errors
  - `ToggleFavorite(file_path)` / `IsFavorite(file_path)` / `LoadFavorites()` / `SaveFavorites()`
  - `DrawPresetBrowser(x, y, w, h)` — main entry for the left panel
  - `DrawFolderList(x, y, w, h, dirs, scroll_offset)` — draws directory navigation list
  - `DrawPresetList(x, y, w, h, files, scroll_offset, selected_idx)` — draws preset file list with stars
- State stored in island_store (current_directory, preset_root, preset_tree, preset_files, etc.)
- Error handling via `browser_error` field displayed as error banner

### P4-02 — Filesystem tree with `io.*` + REAPER API
- Root directory: `reaper.GetResourcePath() .. "/grove-presets/"`
- First access: creates directory via `reaper.RecursiveCreateDirectory()`
- Directory listing: `io.popen('dir "path" /B /AD 2>nul')` for subdirectories
- File listing: `io.popen('dir "path\\*.grove" /B 2>nul')` for .grove files
- Files sorted alphabetically, directories sorted alphabetically
- Tree structure: `{path, dirs=[{name, path, type, expanded}], files_count}`
- Graceful error handling: all file ops wrapped in pcall, errors displayed as in-panel banners

### P4-03 — Preset list display with scroll
- Preset list shown below folder navigation in the left panel
- Each item: preset name (truncated to 20 chars), favorite star icon (★/☆)
- Selected preset highlighted with blue background
- Scroll via mouse wheel (up/down changes browser_scroll)
- Scrollbar indicator on right edge
- "(No presets)" placeholder when directory is empty
- Header shows count: "PRESETS (N)"

### P4-04 — Save/load presets
- Save: via Save button → `reaper.GetUserInputs("Save Preset", ...)` dialog → serializes notes → `io.open(filepath, "w")`
  - File format: `return {name="...", version=1, notes={{pitch=..., start_beat=..., ...}}}`
  - Sanitizes filename: removes special chars, ensures .grove extension
  - Default save to current directory
- Load: via Load button → reads selected preset → `dofile(filepath)` → validates `notes` is a table
  - Validates each note entry has pitch field
  - Replaces island_store notes with loaded notes
  - Error handling: malformed files show error banner, existing notes unchanged
  - Empty preset warning: "Preset contains no valid notes"

### P4-05 — Favorites and bookmarks persistence
- Favorites stored via `reaper.GetExtState("GROVE_FL_MIDI", "preset_favorites")`
- Format: Lua-serialized table of paths (`{"path1","path2",...}`)
- `reaper.SetExtState(...)` for saving with `persist=true` flag
- Toggle via star icon click on each preset item
- Favorites loaded in `Init()` and saved after each toggle
- State stored as `favorites` table in island_store (path→true hash for O(1) lookup)
- Bookmarks: `reaper.GetExtState("GROVE_FL_MIDI", "preset_bookmarks")` (defined but not UI-integrated in this unit)

### P4-06 — Error handling for file operations
- All file operations wrapped in pcall (`io.open`, `io.popen`, `dofile`, `reaper.*`)
- Error cases handled:
  - Missing REAPER resource path → error banner "Could not get REAPER resource path"
  - Cannot create directory → error banner "Could not create grove-presets directory"
  - Malformed .grove file (not a table) → error banner "Invalid preset file: expected table"
  - Missing `notes` field → error banner "Invalid preset: missing 'notes' array"
  - Empty notes array → error banner "Preset contains no valid notes"
  - File write failure → error banner "Could not write file: path"
  - Empty directory → "(No presets)" placeholder (no crash)
- Errors displayed as red banner in the browser panel area
- All errors are non-fatal — UI continues to render

## Deviations from Spec/Design
- **Velocity bars are HORIZONTAL (growing upward)** per the task description, not vertical as mentioned in the spec. The spec said "vertical bar" for each velocity entry, but the task explicitly describes horizontal bars matching note position. This matches the piano roll integration pattern better.
- **Bar colors use red→green gradient** instead of pitch-class colors specified in the spec. The task explicitly requests this gradient, and it provides better velocity-at-a-glance readability.
- **Mute toggle via right-click on note block** instead of a standalone "M" button in the velocity editor. This was the explicit task requirement (P3-04). Right-click is natural for toggle operations in DAW workflows.
- **Folder list is flat** (single-level navigation with ".." parent button) instead of a deep expandable tree. Simplifies the first implementation and avoids complexity with lazy-loading subtrees.
- **Files listed without size/date** as mentioned in the spec. The task code focuses on name + favorite star. Size/date can be added in Unit 4 if needed.
- **Error display uses in-panel banner** instead of `reaper.MB()` dialogs for non-critical errors. Less intrusive, doesn't require user dismiss. Critical errors (malformed file) still show via the banner.
- **Save dialog uses `reaper.GetUserInputs()`** instead of `reaper.GetUserFileNameForRead()`. The former is simpler and doesn't require a file-selection dialog for a simple text input.

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `src/ui/velocity.lua` | Created | Velocity editor module (195 LOC) — bars, click-drag editing, red→green gradient |
| `src/ui/preset-browser.lua` | Created | Preset browser module (410 LOC) — folder navigation, file list, save/load, favorites |
| `src/state/island.lua` | Modified | Added preset browser state fields + getters/setters (current_directory, preset_tree, etc.) |
| `src/ui/piano-roll.lua` | Modified | Added HandleRightClickMute() for right-click → mute toggle |
| `src/ui/views.lua` | Modified | Integrated velocity editor + preset browser + right-click mute + click-drag handling + layout adjustments |

## Dependencies for Unit 4 (Polish)
- velocity.lua with working click-drag + red→green gradient bars
- preset-browser.lua with save/load + favorites + error handling
- piano-roll.lua with mute toggle via right-click
- DrawIslandView() with full layout (preset panel + timeline + piano roll + velocity editor)

## Issues Found
- `io.popen("dir ... /B /AD 2>nul")` is Windows-specific — cross-platform future work would need `reaper.EnumerateSubdirectories()` fallback
- Favorites serialization uses Lua table format parsed via `load()` — safe for user data but could be more robust with JSON
- `dofile()` for loading presets is fast but has security implications if untrusted files are loaded (presets are user-created, so risk is minimal)
- No automated test runner available — tasks P3.4 and P4.6 require manual REAPER testing
