## Exploration: MIDI Island Professional Review

### Current State

The MIDI island is a **piano roll editor** integrated into the GROVE FL MIDI main view. It appears when the user clicks the "MIDI" button in the Command Stack island, which toggles the GFX window from 720×497 to 720×793 (and back) via `midi.ToggleIsland()` — a full GFX context destroy/recreate cycle.

The island renders BELOW the existing performance area (scale pads + progression slots) within the same DrawFullView call, using a CONSTANT scale factor (500/29162) to prevent content deformation when the island expands.

**Components:**

| Module | LOC | Role |
|--------|-----|------|
| `state/island.lua` | 367 | State store: notes, selection, lasso, scroll, zoom, tool mode, preset browser, velocity panel, progression→notes conversion |
| `ui/piano-roll.lua` | 1022 | Grid rendering, note blocks (gradient/velocity), keyboard strip, lasso, hit-testing, pencil/eraser |
| `ui/timeline.lua` | 193 | Beat/measure ruler, playhead, subdivision ticks, position sync from sequencer |
| `ui/velocity.lua` | 336 | Per-note velocity bars, click-drag editing, multi-selection delta, collapse toggle |
| `ui/preset-browser.lua` | 745 | Filesystem browser for `.grove` presets, save/load v2 format, favorites, rename |
| `ui/views.lua` (DrawMIDIIsland) | ~488 | Integration: layout, mouse routing, scrollbar, info bar, delete key detection |
| `core/midi.lua` (ToggleIsland) | 20 | GFX context toggle, early return if docked |

**Architecture:**

```
views.DrawFullView()
  ├── DrawHeader()
  ├── DrawIslands()           ← 4 control islands (SCALE, OCTAVE, CHORD, COMMAND)
  ├── DrawPerformanceArea()   ← scale pads + progression slots
  └── DrawMIDIIsland()        ← ONLY if midi.midi_island_expanded
        ├── Island header (CH + PRESETS + tool mode buttons)
        ├── Preset panel (collapsible, ~220px left)
        ├── Timeline ruler (28px top)
        ├── Piano roll (center, fills remaining)
        ├── Velocity editor (80px bottom, collapsible to 14px)
        ├── Scrollbar (horizontal, right_x area)
        └── Info bar (18px bottom)
```

**State flow:** Notes live in `island_store.GetNotes()` as a flat array `{pitch, start_beat, duration, velocity, muted}` — shared by REFERENCE from store. Mutations happen in-place (e.g., velocity drag directly mutates `notes[idx].velocity`). Selection uses `{[idx]=true}` table. Lasso uses pixel-space rect. Tool mode is a string.

**Data flow from progression:** When `sequencer_store.GetProgressionRevision()` changes, `DrawMIDIIsland` calls `island_store.LoadNotesFromProgression()` which converts 16 progression slots (with chord offsets + subdivisions) into a flat note list.

**Interaction flow per frame:**
1. Sync playback position from sequencer
2. Detect delete key (gfx.getchar for DEL/VK_DELETE)
3. Draw all sub-components (preset panel → timeline → piano roll → velocity)
4. Route mouse click by zone (timeline seek / piano roll tool-mode dispatch / velocity drag)
5. Handle lasso (update on mousemove, finalize on release)
6. Handle mouse wheel (horizontal scroll/zoom in timeline, vertical scroll/zoom in grid)
7. Draw horizontal scrollbar with thumb drag
8. Draw info bar

**Current tool modes:**
- **Pointer** (→): click to select/deselect single note, click empty space → start lasso, lasso on release
- **Pencil** (✎): click to create note at snapped half-beat, duration=1, velocity=100
- **Eraser** (✕): click to remove note

### Affected Areas

- `src/state/island.lua` — State store for all island data. Backward compat shims for selected_note_index remain.
- `src/ui/piano-roll.lua` — 1022 LOC, monolithic. Grid, note blocks, keyboard strip, hit-testing, pencil/eraser, lasso, scroll/zoom, ALL in one module.
- `src/ui/velocity.lua` — 336 LOC. Per-note velocity bars, click-drag, multi-selection delta. Module-local drag state that survives across frames (uses closures).
- `src/ui/timeline.lua` — 193 LOC. Ruler, playhead, subdivision ticks. Syncs from sequencer progress which is per-measure 0..1.
- `src/ui/preset-browser.lua` — 745 LOC. Full filesystem browser with io.popen('dir...') — Windows-only, fragile.
- `src/ui/views.lua` — 1180 LOC total, ~488 for DrawMIDIIsland. Hosts scrollbar drag logic, scrollwheel routing, delete key detection, lasso finalization.
- `src/core/midi.lua` — ToggleIsland destroys/recreates GFX context. Visual flash, no smooth transition.
- `src/main.lua` — Init order (island_store 7th), ToggleIsland guard after DrawFullView, midi_island_toggled flag reset.
- `src/ui/theme.lua` — Island-specific colors (island_grid_line, island_note_*, island_ruler_bg, island_velocity_bg, grid_* hierarchy, lasso colors).
- `tests/test_toggle_island.lua` — Only test for island: verifies docked early return, expand height, collapse height.
- `src/ui/compact-init.lua` — Imports island_store (line 10), used for potential compact-panel island reference.

### Feature Inventory

| Feature | Status | Quality | Notes |
|---------|--------|---------|-------|
| Piano roll grid rendering | ✅ Implemented | ⚠️ Good | 4-tier grid lines (measure/beat/1/8/1/16), pitch row backgrounds, vertical keyboard strip. Uses theme colors. Virtual scrolling via ComputeVisibleRanges with frame cache. |
| Note block creation | ✅ Implemented | ⚠️ Basic | Pencil tool creates notes at mouse position, snaps to half-beat, duration=1, velocity=100. No note-on playback when created. |
| Note block editing (properties) | ✅ Implemented | ⚠️ Partial | Velocity editable via drag. Duration/pitch/position NOT editable — fixed at creation. Can delete (eraser tool or DEL key). |
| Note block deletion | ✅ Implemented | ⚠️ Basic | Eraser tool removes single note. DEL key in pointer/eraser mode removes ALL selected notes with sorted-index deferred deletion. |
| Selection (single) | ✅ Implemented | ⚠️ Basic | Click selects (deselects others), click same deselects. No shift-click for range, no ctrl-click for toggle. |
| Selection (multi - lasso) | ✅ Implemented | ⚠️ Basic | Drag on empty space creates lasso rect. On release, selects all notes in pixel rect. Hit-test uses note pitch + beat overlap. |
| Tool modes (pointer/pencil/eraser) | ✅ Implemented | ⚠️ Basic | Three buttons with icons. Clean separation in mouse dispatch via if-else chain. Tools only affect left-click. |
| Horizontal scrolling | ✅ Implemented | ⚠️ Basic | Mouse wheel on timeline = horizontal zoom. Ctrl+wheel in grid = horizontal zoom (same function). Scrollbar thumb drag for horizontal pan. |
| Vertical scrolling | ✅ Implemented | ⚠️ Basic | Mouse wheel in grid area = vertical scroll (pitch rows). Clamped to 0..TOTAL_ROWS. |
| Vertical zoom (pitch row height) | ✅ Implemented | ⚠️ Basic | Alt+wheel in grid = row height 6..24px. Modifies mutable module field PITCH_ROW_H. |
| Horizontal zoom | ✅ Implemented | ⚠️ Basic | Zoom_x 10..200 px/beat. Mouse wheel on timeline = zoom by factor 1.15. Ctrl+wheel in grid = same. |
| Velocity editing | ✅ Implemented | ⚠️ Good | Click-drag on velocity bars. Multi-selection delta tracking. Gradient color red→yellow→green. Collapse toggle. Bar overlap offset for simultaneous notes at same beat. |
| Timeline ruler | ✅ Implemented | ⚠️ Basic | Beat/measure ticks with measure numbers. Subdivision ticks (1/8, 1/16). Measure number label overlap prevention. |
| Playhead | ✅ Implemented | ⚠️ Basic | Red vertical line + triangle top. Extends through ruler + piano roll. Synced from sequencer progress. Only visible during playback. |
| Preset browser | ✅ Implemented | ⚠️ Good | Full filesystem .grove browser. Folder navigation, favorite stars (persisted via ExtState), rename, save/load v2 format with progression + context. Error handling with banner. Action buttons. |
| Preset save (v2 format) | ✅ Implemented | ⚠️ Good | Serializes notes + root/scale/octave/chord + progression. Uses Lua table syntax for dofile() reload. |
| Preset load | ✅ Implemented | ⚠️ Good | dofile() loading with validation (pitch, notes array). Full context restoration on v2. |
| MIDI note-on playback for island | ❌ Not implemented | — | No sound preview when creating/selecting notes. Notes only play via sequencer or keyboard. |
| Note resizing | ❌ Not implemented | — | Duration fixed at creation. No edge drag to resize. |
| Note moving | ❌ Not implemented | — | No drag-to-move notes to new pitch/position. |
| Snap grid / snap toggle | ❌ Not implemented | — | Pencil snaps to half-beat hardcoded. No configurable snap resolution or toggle. |
| Undo / Redo | ❌ Not implemented | — | Every edit (delete, velocity change, add) is permanent. |
| MIDI CC lanes | ❌ Not implemented | — | Only velocity. No modulation, pitch bend, expression, sustain. |
| Automation lanes | ❌ Not implemented | — | No volume/pan/parameter automation. |
| Quantization | ❌ Not implemented | — | No quantize selected notes to grid. |
| Copy/cut/paste | ❌ Not implemented | — | No clipboard operations for notes. |
| Step input / MIDI recording | ❌ Not implemented | — | No real-time or step-based MIDI input to island. |
| Note ghosting / ghost notes | ❌ Not implemented | — | Can't see notes from other clips or takes. |
| Fold to scale mode | ❌ Not implemented | — | All 108 pitches always visible. No non-scale pitch hiding. |
| Arpeggiator panel | ❌ Not implemented | — | Common integrated arp in DAW piano rolls. |
| MIDI file import | ❌ Not implemented | — | Only .grove preset format (.mid/.midi not supported). |
| Keyboard shortcuts | ❌ Not implemented | — | DEL key is the only shortcut. No Ctrl+Z/C/V/X, no arrow keys for nudge. |

### Industry Standards Comparison

Compared against **FL Studio Piano Roll**, **Ableton Live MIDI Editor**, and **Logic Pro MIDI Editor**:

| Area | Industry DAW Standard | GROVE MIDI Island | Gap |
|------|---------------------|-------------------|-----|
| **Grid/Snap** | Multiple snap modes (beat/1/2/1/4/1/8/1/16/1/32, triplet, swing, dotted). Snap toggle. Custom grid per project. | Hardcoded half-beat snap for pencil. Grid subdivision via config.SUBDIVISION_MODES. No snap toggle or per-tool snap. | 🚨 Critical |
| **Note Editing** | Drag to move, edge-drag to resize, trim, split, glue. Ctrl+drag to clone. Double-click to edit properties. | Fixed duration=1 on creation. No move. No resize. No split/glue. | 🚨 Critical |
| **Velocity Editing** | Drag bars up/down. Draw tool for freehand velocity curve. Velocity ramp (linear/exponential). Note-off velocity. | Click-drag, delta-tracking for multi-select. Gradient coloring. No curve tool, no ramp. | ⚠️ Medium |
| **Automation / CC** | MIDI CC lanes for all 128 controllers. Automation clips linked to parameters. LFO/envelope generators. | Only velocity (which is note property, not CC). No CC lanes. | 🚨 Critical |
| **Quantization** | Quantize to grid (1/4, 1/8, 1/16, 1/32). Swing quantize. Groove quantize from templates. | None. | 🚨 Critical |
| **Pattern/Clip** | Multiple clips per track, clip launcher, arrangement view, pattern groups. | Single flat note array from one progression. No clip boundaries or regions. | 🚨 Critical |
| **Keyboard Shortcuts** | Ctrl+C/V/X for edit, Ctrl+Z/Y for undo/redo, arrows to nudge, Alt+scroll for zoom, Ctrl+A select all. | Only DEL key (inconsistent: gfx.getchar() which is non-ideal in GFX loop). | 🚨 Critical |
| **Accessibility** | Tab navigation, screen reader support, high contrast themes, scalable UI. | Hardcoded pixel layout. No tab stops. No accessibility whatsoever. | ⚠️ Medium |
| **Multi-editing** | Simultaneous editing of multiple MIDI clips. Ghost notes show other clips. Note colors by pitch/velocity/channel. | Single clip only. No ghosting. White/black key coloring only. | Major |
| **Preview** | Note preview on click (MIDI note-on while holding). Drag preview before commit. | No sound on note create/select. | Major |
| **MIDI Learn** | Right-click any parameter → MIDI learn. | No MIDI learn at all. | Major |
| **Swing/Groove** | Per-note swing, groove templates, humanize. | No swing. Velocity humanization only on keyboard input (85+random(30)). | Major |
| **Step Sequencer** | Integrated step sequencer in piano roll (FL Studio). | Separate sequencer (progression) external to island. | ⚠️ Medium |

### Gaps and Opportunities

**Critical Gaps (blockers for professional use):**
1. **No note move or resize** — the single most fundamental piano roll operation. Users cannot adjust note position or duration after creation.
2. **No snap grid control** — no snap toggle, no configurable resolution, no swing/triplet support.
3. **No undo/redo** — every operation is irreversible. This is table-stakes for any editor.
4. **No MIDI CC lanes** — velocity-only. Modulation, expression, sustain, pitch bend are inaccessible.
5. **No keyboard shortcuts** — editor is mouse-only. No copy/paste, no nudge, no select-all.

**Major Gaps (differentiators from basic tools):**
6. **No note preview audio** — user can't hear notes while editing.
7. **No quantize** — can't align notes to grid after creation.
8. **No multi-clip support** — only one "pattern" visible at a time.
9. **No ghost notes** — no reference from other clips/takes.
10. **No fold to scale** — visible pitches always 108, no way to hide non-scale notes.

**Improvement Opportunities (what exists is good but could be better):**
11. **Piano-roll is 1022 LOC** — should be broken into: grid-renderer, note-block, keyboard-strip, hit-testing, zoom/scroll
12. **Preset browser uses io.popen('dir...')** — switch to `reaper.EnumerateFiles()` or `reaper.GetDirectoryForPath()`
13. **Note iteration O(n)** per frame — add spatial index (grid/quadtree) for note counts >50
14. **Delete key detection fragile** — gfx.getchar() is meant for char input, not key state
15. **Lasso only on empty click** — should support shift/ctrl modifiers for additive selection
16. **velocity.HandleVelocityMouse uses module-level state** — fragile across mode switches
17. **ToggleIsland destroys GFX context** — should resize gfx window instead
18. **No horizontal zoom animation** — instant zoom is disorienting
19. **Playback position sync** — sequencer progress is per-measure 0..1, but total beat position needed

### Architectural Assessment

**State Management (Good):**
- island_store follows the established store pattern (getters/setters, Init from config.state)
- Notes shared by reference enables efficient in-place mutation
- Selection uses `{[idx]=true}` for O(1) lookup
- Backward compat shims for selected_note_index preserve velocity.lua consumers
- ProgressionToNotes() correctly handles subdivided slots and chord offsets

**Rendering Performance (Adequate for small note counts, risky for large):**
- ComputeVisibleRanges caches until scroll/zoom/dimensions change (frame-level cache)
- DrawNoteBlocks skips rendering if note count + selection count unchanged (P5-05 optimization)
- BUT: iterates ALL notes for hit-testing (O(n)), lasso rect check (O(n)), velocity grouping (O(n))
- No spatial data structure — each hit-test scans the entire note array
- DrawNoteWithGradient recomputes colored strips per note per frame

**Code Organization (Needs refactoring):**
- piano-roll.lua is a 1022-line monolith combining: grid rendering, note blocks, keyboard strip, hit-testing, pencil/eraser, lasso, scroll/zoom calculations
- views.lua hosts scrollbar drag logic and mouse wheel routing that belong in piano-roll
- velocity.lua has module-level drag state (closures) instead of store-based
- preset-browser.lua is self-contained but uses OS-specific commands

**Coupling (Some concerns):**
- piano-roll.lua reads config.state directly for root_index, scale_index, subdivision_index — bypasses stores
- views.lua imports 18 modules directly — could benefit from barrel pattern
- timeline.lua syncs playback position from sequencer progress — progress is 0..1 per measure, timeline expects absolute beats
- DrawFullView -> DrawMIDIIsland is sequential, but ToggleIsland mid-frame causes gfx.quit() + defer() restart — means one frame is lost

**Testing Coverage (Critical gap):**
- Only `test_toggle_island.lua` exists — tests docked early return and expand/collapse heights
- piano-roll.lua: 0 tests (no mock for gfx drawing, no unit tests for hit-testing/lasso)
- velocity.lua: 0 tests
- timeline.lua: 0 tests
- preset-browser.lua: 0 tests
- island_store.lua: store tests are in test_stores.lua (basic getter/setter roundtrips)
- Core functions like ProgressionToNotes, EntryToPitches, GetVisibleNotes have NO tests despite being pure functions

**Maintainability (Moderate):**
- Good module naming and consistent pattern usage
- Piano-roll module-level state (_cache, _last_note_count, etc.) resets on module reload — could cause issues
- Velocity module-level drag state is fragile (survives across frames, not reset on mode switch — though ResetDrag() exists)
- No TypeScript or static analysis — refactoring is manual
- 72+ remnant references to config.state.* remain scattered across UI

### Approaches

1. **Progressive Enhancement (Low risk, Medium effort)** — Focus on the highest-impact improvements one by one without architectural change
   - Pros: User sees incremental value quickly. Low risk. Can ship each improvement independently.
   - Cons: Leaves architectural debt (monolithic piano-roll, GFX context destroy). Takes longer to reach "professional."
   - Effort: Medium (estimating 2-3 sprints for critical gaps)

2. **Architecture-first Refactor + Feature Add (High risk, High effort)** — Break piano-roll into sub-modules, fix GFX context toggle, add spatial index, THEN add features
   - Pros: Clean foundation enables faster feature development later. Proper separation of concerns. Testable modules.
   - Cons: Months before user sees improvements. High risk of regression on existing 382 tests. Over-engineered for current scale.
   - Effort: High (estimating 4+ sprints before visible user benefit)

3. **Targeted Feature Expansion (Medium risk, Medium-High effort)** — Add the most critical missing features (note move/resize, snap, undo, keyboard shortcuts) within existing architecture, deferring refactors
   - Pros: Quickest path to professional-grade editing. Users see major capability jumps. Existing patterns guide new code.
   - Cons: Working in monolithic piano-roll.lua will increase its size. Technical debt accumulates. GFX context destroy remains.
   - Effort: Medium-High (3-4 sprints for critical mass of features)

4. **Phased Hybrid: Refactor piano-roll only, add features in parallel** — Break piano-roll into 3-4 sub-modules, add note move/resize and snap simultaneously, defer CC/quantize/undo
   - Pros: Architectural improvement in most problematic module + user-visible features in same sprint. Best ROI balance.
   - Cons: Requires careful planning to avoid thrashing. Piano-roll refactor touches every island interaction point.
   - Effort: Medium (2-3 sprints for piano-roll split + note move/resize + snap + undo)

### Recommendation

**Approach 4: Phased Hybrid — Split piano-roll + add note move/resize + snap + undo**

The piano-roll monolith (1022 LOC) is the single biggest obstacle to professional quality. Breaking it into 4 modules (grid-renderer, note-block, keyboard-strip, interaction) is essential before adding features — otherwise the module becomes unmanageable.

In parallel, add the **three critical missing features** that are blockers for professional use:
1. **Note move + resize** — click-drag to move, edge-drag to resize. This is THE fundamental piano roll operation.
2. **Snap grid control** — snap toggle button, configurable resolution (1/1, 1/2, 1/4, 1/8, 1/16, triplet, swing), indicator showing current snap.
3. **Undo system** — command pattern with undo stack. Each operation (create, delete, move, resize, velocity change, mute) pushes reversibility data.

These three additions transform the island from a "progression viewer" into a genuine MIDI editor. Everything else (CC lanes, quantization, copy/paste, ghost notes) is secondary polish.

**Sequence:**
- Sprint 1: Split piano-roll.lua into sub-modules + fix GFX context toggle (resize instead of destroy)
- Sprint 2: Note move + resize + snap grid control
- Sprint 3: Undo/redo system + keyboard shortcuts (Ctrl+Z/Y/X/C/V)
- Sprint 4 (optional): Note preview audio + shift-click additive selection + fold to scale

### Risks

- **Risk 1: Piano-roll refactor regression** — Splitting 1022 LOC touches every interaction point (hit-testing, lasso, pencil, eraser, scroll/zoom, selection, rendering). Every existing interaction must work identically. Mitigation: comprehensive test suite before/after refactor.
- **Risk 2: Undo system memory growth** — Each undo entry stores a deep copy of selected note state. With large note counts, undo stack grows fast. Mitigation: limit undo depth to 50-100, use shallow diffs instead of full state snapshots.
- **Risk 3: Note move/resize coordinate transform complexity** — Converting pixel drag deltas to beat/pitch changes requires precise handling of inverted Y, zoom levels, scroll offsets, and lasso state interaction. Mitigation: extract coordinate math into pure functions with unit tests.
- **Risk 4: Snap grid interactions with existing tools** — Pencil snap, lasso hit-testing, timeline seek, and velocity positioning all use different snap assumptions. Mitigation: centralize snap as a pure function (`SnapBeat(beat, resolution) → snapped_beat`).
- **Risk 5: GFX context resize stability** — REAPER's `gfx.init` after `gfx.quit` can lose HWND or clip region. Current destroy-recreate is proven stable. Moving to resize introduces unknown edge cases. Mitigation: test on multiple REAPER versions.
- **Risk 6: No note data model change** — The flat array `{pitch, start_beat, duration, velocity, muted}` with 1-based indexed access is fragile for undo (indices shift on delete). Mitigation: consider UUID-based note IDs for undo operations, or use stable secondary lookup.

### Ready for Proposal
**Yes** — The exploration is comprehensive. The orchestrator should tell the user:
1. Current island is a solid foundation with good architecture patterns (store, virtual scrolling, frame caching, multi-selection)
2. Three critical gaps make it "demo-quality" rather than "professional": no note move/resize, no snap control, no undo
3. The piano-roll monolith (1022 LOC) is the primary architectural bottleneck
4. Recommended approach: refactor piano-roll into sub-modules + add note move/resize + snap + undo across 3 sprints
5. Everything else (CC lanes, quantization, ghost notes) is secondary polish after the core editor is solid
