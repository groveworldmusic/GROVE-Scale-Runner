# Exploration: Chord Progression Island — Full System Review

## Current State

The Chord Progression Island is the most feature-rich and complex subsystem of GROVE FL MIDI. It integrates:

### Data Flow (End-to-End)

```
config.state.progression[]  →  sequencer_store.GetProgression()  →  note_store.ProgressionToNotes()
    ↓                                                                         ↓
progression.lua (CRUD)                                                  note-store (UUID + undo/redo)
    ↓                                                                         ↓
sequencer.lua (playback trigger) ←  island_store.LoadNotesFromProgression()  ←  
    ↓                                                                         ↓
midi.lua (SendMidi)                 midi-island.lua (orchestrator)        island_store.GetNotes()
    ↓                                                                         ↓
reaper.StuffMIDIMessage          view.lua → piano-roll (grid + note + interaction + coord + knife)
                                       ↓
                                  input.lua (mouse/keyboard dispatch)
                                       ↓
                                  header.lua (tools, MIDI CH, presets, snap)
                                       ↓
                                  timeline.lua (beat ruler + playhead)
                                       ↓
                                  velocity.lua (Glass Blade editor)
                                       ↓
                                  preset-browser.lua (filesystem presets)
```

### Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **Dual representation**: progression slots (16) ↔ piano-roll notes (flat list) | Progression is the input; piano-roll notes are the canvas. `notes_dirty` flag prevents overwrite |
| **UUID-based notes**: monotonic ID per note | Enables undo/redo even when indices shift due to insert/delete |
| **Ref-counted active MIDI notes** | Multiple triggers (keyboard + pads) can target same MIDI note safely |
| **notes_dirty flag** | Guards against progression auto-reload overwriting manual piano-roll edits |
| **Paint/Knife tool mode** (Phase 5) | Replaced 3-mode pointer/pencil/eraser — simplified UX |
| **Sub-pixel smooth scrolling** | Fractional `scroll_y` values for fluid vertical scroll |
| **Progression revision counter** | Increments on every mutation — drives periodic check in midi-island.lua |

### Module Responsibilities

| Module | Lines | Role | Dependencies |
|--------|-------|------|-------------|
| `island.lua` (state) | 348 | Facade over note-store + preset-store; island state (scroll, zoom, selection, lasso, drag, snap) | note-store, preset-store, config, api-guard |
| `note-store.lua` (state) | 318 | Note CRUD + undo/redo stacks (max 50) + UUID + ProgressionToNotes | config, api-guard |
| `midi-island.lua` | 299 | Orchestrator: draws preset panel + piano roll + timeline + velocity; scrollbar state | All piano-roll, timeline, velocity, preset-browser |
| `midi-island/header.lua` | 205 | Header: tool mode buttons (paint/knife), MIDI CH selector, PRESETS toggle, snap controls | Various stores |
| `midi-island/input.lua` | 435 | Mouse/keyboard dispatch: routes events to piano-roll, timeline, velocity; tool-mode-aware | Various stores |
| `piano-roll/grid.lua` | 579 | Grid background + beat lines + keyboard strip + scroll/zoom handlers | config, theme, midi |
| `piano-roll/note.lua` | 320 | Note rendering (gradient + ghosting), hit-testing, rect selection | config, theme, coord |
| `piano-roll/interaction/drag.lua` | 575 | Note drag/resize (left/right edge), arming, right-drag delete sweep | island-store, note, grid, snap |
| `piano-roll/interaction/handlers.lua` | 270 | Mouse click handlers (select, paint, right-click delete/mute), Ctrl+A, lasso drawing | island-store, note, grid, snap |
| `piano-roll/interaction/shortcuts.lua` | 206 | Keyboard shortcuts: Ctrl+Z/Y, Delete, Ctrl+A/X/C/V, arrow nudge | Various |
| `piano-roll/undo.lua` | 196 | RestoreUndo/RestoreRedo (6 entry types), HandleUndo/HandleRedo | island-store, note |
| `piano-roll/clipboard.lua` | 143 | Cut/Copy/Paste with undo support | island-store, note |
| `piano-roll/knife.lua` | 115 | Note split at beat, quantization to MIN_SNAP=0.25, undo support | island-store, note, coord, midi |
| `piano-roll/coord.lua` | 63 | Pure coordinate transforms (BeatToX, XToBeat, PitchToY, YToPitch) | None |
| `piano-roll/view.lua` | 60 | DrawPianoRoll coordinator: visible ranges → grid + notes + lasso | grid, note, interaction |
| `timeline.lua` | 198 | Beat/measure ruler, playback head with pulse, hit test | config, island-store, seq-store, theme |
| `velocity.lua` | 488 | Glass Blade velocity editor: bars, gradient, click-drag edit, multi-selection, undo | Various |
| `preset-browser.lua` | 843 | Filesystem browser: directory listing, favorites, save/load/rename/duplicate/delete | Various + io.* + reaper.* |
| `sequencer.lua` (core) | 136 | Playback: sync to REAPER transport or internal clock, measures, sub-step | config, seq_store, midi, progression |
| `progression.lua` (core) | 40 | Progression CRUD: Add/Remove/Swap/Clear/GetLastFilled | seq_store |
| `midi.lua` (core) | 261 | MIDI note calculation, SendMidi (ref-counted), TriggerChord, ExportToMidi | config, seq_store, midi_store, prefs |

---

## Findings by Category

### 🐛 Bugs & Logic Errors

#### B1. Lasso right-edge cut off early
**Where**: `input.lua:394-408`, `note.lua:276-318`
**Issue**: The lasso hit test (GetNotesInRect) uses raw screen pixel coordinates stored in island_store for lasso start/end. When the lasso rect's right edge (x2) is near or at the scrollbar boundary (`right_x + right_w - SB_SIZE`), the hit-test in pixel→beat conversion may lose precision for notes at the rightmost column. The conversion `beat_end = (rx2 - grid_x) / zoom_x + scroll_x` at note.lua:301 can truncate the last few pixels.
**Severity**: Medium — notes at the far-right of the playable grid area may not be selectable via lasso.

#### B2. Lasso / right-drag sweep rect drawn in wrong coordinate space
**Where**: `handlers.lua:219-239` (DrawLassoRect), `drag.lua:557-573` (DrawRightDragSweepRect)
**Issue**: Both rects are drawn in raw screen coordinates without checking if they extend outside the grid area. The clipping is positional via `math.min/max`, but the lasso rect can visually overflow into the scrollbar area.
**Severity**: Low — visual only, no functional impact.

#### B3. Progression revision counter — silent mutation path
**Where**: `sequencer.lua:43` (SetProgression), `sequencer.lua:48-49`
**Issue**: `SetProgression(t)` replaces the entire table and increments revision. But external code can call `seq_store.GetProgression()` and mutate entries directly (table.insert, entry mutation) WITHOUT incrementing the revision counter. This means `midi-island.lua:92-99` may not detect the change and miss a reload.
**Actual mitigation**: Callers use `SetProgressionEntry(i,v)` which increments the revision. The GetProgression() ref is used by `preset-browser.lua:239-241` which iterates for serialization (read-only). So this is only a risk if new code mutates via GetProgression() directly.
**Severity**: Low (guarded by convention).

#### B4. `notes_dirty` never resets during island session
**Where**: `midi-island.lua:93-100`
**Issue**: `notes_dirty` is set to true when the user makes any manual edit via `MarkNotesDirty()`. It is only reset to false when the island is closed entirely (line 81: `SetNotesDirty(false)` when collapsed). This means once the user makes one manual edit, the progression auto-reload is permanently disabled for that session.
**Design intent**: This is deliberate — if the user edits notes manually, reloading from progression would destroy those edits. But there's no "sync back to progression" path, and no "force reload" button.
**Severity**: Medium — user can get stuck with stale notes if they want to reload from progression.

#### B5. Undo stack max-50 boundary — stale UUID references after FIFO eviction
**Where**: `note-store.lua:134-137`
**Issue**: When undo stack exceeds 50 entries, the oldest entry is `table.remove(state.undo_stack, 1)`. But the notes referenced by those stale undo entries may still have valid UUIDs in the notes table. If user undoes past the eviction boundary, the undo entry is simply gone — no corruption, but unexpected.
**Severity**: Low — standard FIFO behavior, expected. Not a bug per se.

#### B6. Clipboard paste anchor may produce wrong timing
**Where**: `clipboard.lua:89-141`
**Issue**: Paste anchor calculation chooses `scroll_beat` or `max_beat + 1`. If `scroll_beat` is 0 (start of grid) and there are existing notes, it places at `max_beat + 1`. But the user may expect paste-at-cursor instead of at-end. The `scroll_beat` from `input.lua:45` is `island_store.GetScrollOffsetX()` which is the scroll position, not cursor position.
**Severity**: Medium — paste position is non-obvious to the user.

#### B7. Knife: `split` flag visual gap but no MIDI off/on at split point
**Where**: `knife.lua:88-91`, `note.lua:100-106`
**Issue**: The knife sends MIDI note-off for the original note at split time (line 91), but does NOT send a MIDI note-on for the right half. This is correct for a static grid (notes only play during sequencer playback), but if the note is currently in MIDI playback (sustained from keyboard), the right half should continue sustaining. The MIDI off at line 91 could cause the right half to be silent.
**Severity**: Low — knife is for editing, not live performance. Notes only play during sequencer playback.

#### B8. `config.state.*` still written alongside `prefs.Set*()` in islands.lua
**Where**: `views/islands.lua:68, 85, 109, 131-134, 184-198`
**Issue**: The code writes to `config.state.scale_index = choice` AND calls `prefs.SetScaleIndex(choice)` AND `persist.Save(...)`. This triple-write is unnecessary since preferences_store was migrated. `config.state.*` writes are stale migration residue.
**Severity**: Low — no functional impact, just dead writes to a legacy table.

### 🕳️ Gaps & Missing Features

#### G1. No "force reload from progression" button/action
**When**: User makes manual edits, then wants to reload from progression (discarding edits).
**Current behavior**: Once `notes_dirty` is set, LoadNotesFromProgression is skipped until island reopens.
**Impact**: User must close and reopen the MIDI island to reload.

#### G2. No "sync piano-roll edits back to progression" path
**When**: User edits notes in piano roll (paint, move, resize, delete). These changes exist only in the notes array.
**Current behavior**: Progression slots remain unchanged. When user re-opens island or rev changes, progression notes reload to initial state.
**Impact**: Manual edits are ephemeral unless saved as a preset.

#### G3. Knife tool — no undo entry for "no split" case
**Where**: `knife.lua:42-43` — returns false if split point is too close to edge, no feedback
**Impact**: User clicks with knife at note edge — nothing happens, no visual feedback.

#### G4. No note preview/audio on hover
**Current behavior**: Only the keyboard strip in `grid.lua` plays notes on mouse-down. The piano roll grid doesn't preview notes on hover.
**Impact**: User can't audition a note before creating it (paint tool creates without preview).

#### G5. No "double-click to edit velocity value" on velocity bar
**Current behavior**: Velocity editor is click-drag only. No way to type a numeric value.
**Impact**: Precision velocity editing requires a REAPER MIDI editor.

#### G6. No beat/measure number overlay on grid
**Current behavior**: Timeline ruler shows measure numbers, but the grid itself doesn't overlay beat numbers.
**Impact**: User has to look up to the timeline ruler to see the beat position.

#### G7. No note grid quantization on creation (paint tool)
**Where**: `handlers.lua:136-143` — snap IS applied to beat, but NOT to pitch (note snaps to nearest 1 semitone, which is correct). Duration is hardcoded to 1 beat.
**Impact**: Duration is always 1 beat when painting — no way to create shorter/longer notes directly with paint.

### 🧹 Code Quality Issues

#### Q1. `velocity.lua:295-297` — duplicate GetSelectionCount()
**Where**: `velocity.lua:295-297`:
```lua
local sel_count = 0
for _ in pairs(selected) do sel_count = sel_count + 1 end
```
**Issue**: `island_store.GetSelectionCount()` exists (island.lua:147-151) with identical logic.
**Impact**: Code duplication. Should use the store function.

#### Q2. Module-level mutable drag state in velocity.lua and midi-island.lua
**Where**: `velocity.lua:31-34` (drag_active, drag_note_index, etc.), `midi-island.lua:56-62` (sb_dragging, vsb_dragging)
**Issue**: Fragile — if a mid-frame error occurs or focus is lost mid-drag, these locals can get stale.
**Mitigation**: velocity.lua has safety checks at lines 333-339. Scrollbar drags reset on mouse release.
**Severity**: Low (mitigated) but architecturally impure.

#### Q3. `preset-browser.lua:106` — io.popen for directory listing on Windows
**Where**: `preset-browser.lua:106, 121`
**Issue**: Uses `io.popen('dir "' .. dir_path .. '" /B /AD 2>nul')` — works on Windows only, fragile with non-ASCII paths, performance hit on every scan. Cache (`_scan_cache`) mitigates per-frame calls but initial scan is sync I/O.
**Severity**: Medium — platform dependency, but Windows-only target (REAPER).

#### Q4. `preset-browser.lua:651-663` — File I/O in draw frame (duplicate)
**Where**: `preset-browser.lua:651-663` (Duplicate preset reads entire file in draw-frame context)
**Issue**: Inside the right-click context menu handler (called from draw), `io.open(path, "rb")` and `f_in:read("*all")` are synchronous file I/O. Can stall the frame.
**Severity**: Medium — noticeable lag with large files.

#### Q5. Double layout calculation in midi-island.lua
**Where**: `midi-island.lua:112-135` — layout calculations done BEFORE DrawPresetPanel at line 149, then again for sub-modules at lines 151+. The first layout block computes all dimensions, DrawPresetPanel uses `preset_w` and `island_x` which were computed, then the rendering section uses the same variables.
**Issue**: Not a bug but the layout is computed once and then all rendering uses it. Actually looking closer, the layout is computed once at lines 110-135, then used for both preset panel and main content.
**Severity**: None — correct, not duplicated.

#### Q6. Duplicate font measurement in grid.lua
**Where**: `grid.lua:238-254` — label font settings computed per row in PASS 2
**Issue**: `gfx.setfont(1, "Calibri", fs)` is called on every iteration even when fs doesn't change between rows.
**Severity**: Very low — font setting is cheap in GFX context.

### ⚡ Performance Concerns

#### P1. O(N) full note scan in hot paths (multiple per frame)
**Where**: 
- `note.lua:`191-210` (DrawNoteBlocks) — full scan of all notes, filtered by visible range
- `note.lua:229-258` (NoteBlockHitTest) — reverse scan
- `note.lua:304-317` (GetNotesInRect) — full scan
- `velocity.lua:184-211` — pre-cull full scan + group scan
- `midi-island.lua:224` — scrollbar total_beats computation scans all notes

**Impact**: For a typical preset with 16-64 notes, O(N) is fine. For large presets (200+ notes), unnecessary scanning in DrawNoteBlocks could be optimized via spatial index.
**Severity**: Low for typical use cases. Medium for very large presets.

#### P2. `midi-island.lua:224` — scrollbar total_beats scans all notes each frame
**Where**: `midi-island.lua:222-224`
**Issue**: Every frame during island rendering, the horizontal scrollbar iterates ALL notes to compute `total_beats`:
```lua
local total_beats = 64
for _, n in ipairs(notes) do total_beats = math.max(total_beats, (n.start_beat or 0) + (n.duration or 4) + 4) end
```
**Impact**: O(N) scan per frame for scrollbar that changes only when notes change. Could cache `total_beats` and invalidate on note mutation.
**Severity**: Low.

#### P3. GC pressure from table allocations in hot paths
**Where**: Multiple locations:
- `handlers.lua:157-171` — new_note table + undo entry tables on every paint click
- `drag.lua:143-154, 220-253` — per-frame table creation in UpdateNoteDrag (drag_indices, origins tables created each frame during active drag)
- `velocity.lua:436-470` — undo entry tables on velocity drag release
- `input.lua:177-181` — ctx table created each frame in midi-island.lua

**Impact**: LuaJIT's GC handles small tables well, but creating tables every frame in hot paths adds GC pressure. The latency is invisible on modern hardware but could spike with 200+ notes during drag.
**Severity**: Low for current usage. Monitor if notes exceed 500+.

### 🏗 Architecture Concerns

#### A1. Notes table returned by reference — temporal coupling
**Where**: `note-store.lua:42-43`
**Issue**: `GetNotes()` returns the internal `state.notes` table by reference. Piano-roll interaction modules mutate entries in-place (e.g., `drag.lua:188-191`). If a module stores the reference beyond the current frame and the notes array is replaced (SetNotes), the reference becomes stale.
**Severity**: Low — all callers use it synchronously within the same frame. But no protection against misuse.

#### A2. Facade pattern in island.lua — 37+ proxy functions
**Where**: `island.lua:68-346`
**Issue**: `island.lua` proxies ~37 functions to `note-store.lua` and `preset-store.lua`. This creates a central bottleneck and increases the surface area of `island.lua`. Any new note-store function needs an island.lua proxy.
**Impact**: Medium — maintenance burden grows linearly. Alternative: modules could require note-store directly for note CRUD, but that would break the encapsulation pattern.

#### A3. Progression revision counter — fragile invariant
**Where**: `sequencer.lua:43-48`
**Issue**: The revision counter only increments when `SetProgressionEntry` or `SetProgression` is called. Direct mutation of `GetProgression()` entries (which returns a ref) does NOT increment the counter. Currently no code does this, but it's an unenforced contract.
**Severity**: Low — established convention but no compile-time guard.

#### A4. `double-write (config.state + prefs + persist.Save*)` migration residue
**Where**: `views/islands.lua` — every dropdown change writes to `config.state.*`, `prefs.Set*()`, AND `persist.Save()`
**Impact**: `config.state.*` writes are dead code. Should be cleaned up.

#### A5. Init order dependency: note-store initialized via island_store.Init()
**Where**: `island.lua:55` calls `note_store.Init(defaults)` inside `m.Init()`
**Issue**: `main.lua` line 8 calls `island_store.Init(config.state)` which inits note-store internally. Other modules that require note-store directly (like `piano-roll/undo.lua:6`) must be loaded AFTER island_store.Init(). Currently this works because all requires happen after Init.
**Severity**: Low — works today but fragile if require order changes.

---

## Affected Areas

| File | Lines | Role | Issues |
|------|-------|------|--------|
| `src/state/island.lua` | 348 | Store facade | A2, B3, B4 |
| `src/state/note-store.lua` | 318 | Note CRUD + undo | B5, A1, P1 |
| `src/state/sequencer.lua` | 91 | Progression state | B3, A3 |
| `src/core/sequencer.lua` | 136 | Playback engine | — |
| `src/core/progression.lua` | 40 | Progression CRUD | — |
| `src/ui/midi-island.lua` | 299 | Orchestrator | B4, Q2, P2 |
| `src/ui/midi-island/header.lua` | 205 | Header toolbar | — |
| `src/ui/midi-island/input.lua` | 435 | Event dispatch | B1, B2 |
| `src/ui/piano-roll.lua` | 106 | Barrel | — |
| `src/ui/piano-roll/grid.lua` | 579 | Grid + keyboard | Q6 |
| `src/ui/piano-roll/view.lua` | 60 | View coordinator | — |
| `src/ui/piano-roll/note.lua` | 320 | Note rendering + hit-test | P1, B1 |
| `src/ui/piano-roll/interaction.lua` | 81 | Interaction barrel | — |
| `src/ui/piano-roll/interaction/handlers.lua` | 270 | Click handlers | B2, G7, P3 |
| `src/ui/piano-roll/interaction/drag.lua` | 575 | Drag/resize/sweep | B2, P3 |
| `src/ui/piano-roll/interaction/shortcuts.lua` | 206 | Keyboard shortcuts | — |
| `src/ui/piano-roll/undo.lua` | 196 | Undo/redo restore | — |
| `src/ui/piano-roll/clipboard.lua` | 143 | Cut/copy/paste | B6 |
| `src/ui/piano-roll/knife.lua` | 115 | Note split | B7, G3 |
| `src/ui/piano-roll/coord.lua` | 63 | Coordinate transforms | — |
| `src/ui/timeline.lua` | 198 | Timeline ruler | — |
| `src/ui/velocity.lua` | 488 | Velocity editor | Q1, G5, P3 |
| `src/ui/preset-browser.lua` | 843 | Preset browser | Q3, Q4 |
| `src/ui/slots.lua` | 301 | Progression slots | — |
| `src/ui/views/islands.lua` | 430 | Main view islands (inv, oct, chord, cmd) | B8, A4 |
| `src/core/midi.lua` | 261 | MIDI engine | — |
| `src/state/ui.lua` | 143 | UI store | — |
| `src/state/drag.lua` | 57 | Drag store | — |

---

## Approaches

### Approach A: Targeted Bug-Fix Sprint (Immediate Fixes)

**Focus**: Fix concrete bugs with surgical precision. No architecture changes.

**Work items**:
1. Fix `GetSelectionCount` duplication in velocity.lua → use island_store.GetSelectionCount()
2. Clean up `config.state.*` dead writes in views/islands.lua
3. Add lasso right-edge precision fix in note.lua:301 (add epsilon)
4. Add "force reload from progression" button in header or menu
5. Remove stale investigation markers (`ve_h=0`, `dragged`) from root AGENTS.md if resolved
6. Cache `total_beats` in midi-island.lua scrollbar (invalidate on note mutation)
7. Add `io.popen`→`lfs` migration for preset-browser directory listing (platform safety)

**Pros**: Quick wins, low risk, clear user-visible improvements, deliverable in 1-2 PRs
**Cons**: Doesn't address architecture gaps (no sync-back, no undo-split feedback)
**Effort**: Low (~200-300 lines changed across 6-8 files)

### Approach B: Data Flow Overhaul (Systematic)

**Focus**: Fix the dual-representation problem — make progression ↔ notes bidirectional.

**Work items**:
1. Add `SyncNotesToProgression()` — convert piano-roll notes back to progression slots (with degree detection)
2. Add "Reload from Progression" button + "Sync to Progression" button in midi-island header
3. Remove `notes_dirty` as single guard — add explicit state: `LOADED_FROM_PROGRESSION`, `USER_EDITED`, `SYNCED_TO_PROGRESSION`
4. Cache `total_beats` with dirty flag + invalidation on note mutation
5. Fix all targeted bugs from Approach A
6. Add `progression_revision` audit — verify all mutation paths increment it
7. Remove dead `config.state.*` writes
8. Extract scrollbar drag state into island_store (remove module-local `_sb_dragging`, `_vsb_dragging`)

**Pros**: Fixes root cause of data loss (G1, G2), clean architecture, no more mystery state
**Cons**: More complex, more files touched, risk of regression in undo/paste
**Effort**: Medium (~500-800 lines across 12-15 files)

### Approach C: Architecture Extraction (Ambitious)

**Focus**: Extract piano-roll editing into its own module with clear boundaries.

**Work items**:
1. Create `src/core/pianoroll-engine.lua` — pure-logic module for note CRUD, undo/redo orchestration, progression↔notes conversion
2. Refactor `island.lua` to remove note-store/preset-store proxies — modules require their stores directly
3. Move selection state from island_store to note-store (it belongs with the data)
4. Create `src/ui/piano-roll/render-coord.lua` — merge coord.lua + viewport calc + scrollbar cache
5. Fix Approach B items 5, 6, 7
6. Fix Approach A items 1, 2

**Pros**: Cleanest separation of concerns, easier to test, future-proof
**Cons**: High effort, risks regression across 20+ files, pure-logic module can't be tested without REAPER anyway
**Effort**: High (~1200-1500 lines across 20+ files)

---

## Recommendation

**Start with Approach A (targeted bug fixes) as PR 1, then evaluate if Approach B is warranted.**

Rationale:
- The system is functional and mature — most users won't hit the dual-representation issue immediately
- The bugs listed in Approach A are concrete and reproducible: dead writes, potential lasso imprecision, missing buttons
- Approach B's "Sync to Progression" feature requires UX design decisions (how to detect degree from arbitrary notes? what if notes span non-chord pitches?)
- Approach C is premature — the facade pattern in island.lua works fine, and creating a pure-logic engine for a GFX-only project provides no testability benefit

**Phasing suggestion**:
1. **PR 1**: Bug fixes (A items 1-5) + cache total_beats (A6)
2. **PR 2**: Platform-safe directory listing (A7) + remove dead config.state writes
3. **Evaluate**: After PR 2, if users report data loss from notes_dirty, proceed with Approach B
4. **PR 3 (if needed)**: Sync-to-progression path + reload button

---

## Risks

1. **Lasso fix (B1)**: The right-edge precision issue may be in pixel→beat conversion rounding. Fixing this could shift existing behavior by 1px — verify with snapshot tests.
2. **Removing `config.state.*` writes**: Other modules may still read these values (e.g., `config.state.subdivision_index` in snap-grid rendering). Audit ALL reads before removal.
3. **Approach B sync-back**: Converting arbitrary piano-roll notes to progression degrees is non-trivial — a note at arbitrary pitch may not map to any scale degree. Need a "nearest scale degree" heuristic.
4. **Scrollbar cache (A6)**: If total_beats is cached and not invalidated after specific operations (paste, split, load preset), the scrollbar may show wrong range. Must invalidate on every note mutation.
5. **`ve_h=0` investigation**: The marker says root cause unknown. If it's still present, fixing it could break the velocity editor layout. Needs careful testing.

---

## Ready for Proposal

**Yes** — the choreography for this change can proceed.

What the orchestrator should tell the user:

> "We've completed an in-depth review of the Chord Progression Island system. Found 8 bugs (mostly lasso edge precision, stale notes_dirty, dead config writes), 7 gaps (no force-reload, no sync-back, missing preview/feedback), 6 quality issues, 3 performance notes, and 5 architecture concerns. The system is solid for typical use but has rough edges in data synchronization between progression slots and piano-roll notes.
>
> **My recommendation**: Start with a targeted bug-fix sprint (Approach A) — quick, low-risk wins. Then evaluate whether the bidirectional sync (Approach B) is needed based on user feedback. The full architecture extraction (Approach C) is premature.
>
> Can I proceed with a proposal for the first round of fixes?"
