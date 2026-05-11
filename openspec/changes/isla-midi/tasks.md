# Tasks: Isla MIDI — Island Piano Roll View

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~700 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: Foundation → PR 2: Piano Roll + Timeline → PR 3: Velocity + Presets → PR 4: Polish |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Base |
|------|------|-----------|------|
| 1 | Foundation (P0) | PR 1 → | feature/isla-midi-tracker |
| 2 | Piano Roll + Timeline (P1+P2) | PR 2 → PR 1 | PR-1 branch |
| 3 | Velocity + Presets (P3+P4) | PR 3 → PR 2 | PR-2 branch |
| 4 | Polish (P5) | PR 4 → PR 3 | PR-3 branch |

## Phase 0 — Foundation

- [x] P0.1 `config.lua`: add `VIEW_MODES.ISLAND = 3`
- [x] P0.2 `state/island.lua`: create store with Init(), notes `{pitch,start_beat,duration,velocity,muted}`, scroll/zoom/preset state, edit buffer, all getter/setter pairs
- [x] P0.3 `main.lua`: add island store Init, route `view_mode==3` to `DrawIslandView()`
- [x] P0.4 `compact-init.lua`: extend SwitchViewMode — ISLAND↔FULL via `gfx.quit()+gfx.init()` with LastGfxState save/restore
- [x] P0.5 `views.lua`: add `DrawIslandView()` entry point w/ panel layout (preset|grid+velocity|timeline)
- [x] P0.6 Guard: docked blocks island (ToggleIslandView); window<800×550 returns early (DrawIslandView)
- [ ] P0.7 Test: scroll clamp 0..56, edit buffer nil-clear, notes table mutable by reference (code supports all — requires manual REAPER test)

## Phase 1 — Piano Roll

- [x] P1.1 `ui/piano-roll.lua`: `DrawPianoRoll(x,y,w,h)` — horizontal grid, 73 pitch rows, beat columns, strong/weak lines
- [x] P1.2 `ProgressionToNotes()`: convert seq_store progression to flat note list, set `notes_dirty` flag
- [x] P1.3 Virtual scroll: render only visible pitch rows + 2-octave buffer from `scroll_offset`
- [x] P1.4 Note blocks: `DrawNoteBlocks()` — colored rounded rects, muted dimmed, playback head line
- [x] P1.5 Mouse wheel scrolls horizontal; zoom 0.25x-4.0x changes pixel ratio, preserves beat offset
- [x] P1.6 Click selection: set `edit_buffer` on note click, clear on empty area
- [ ] P1.7 Test: empty notes no crash; note pitch=60 at correct y; scroll changes visible region

## Phase 2 — Timeline Ruler

- [x] P2.1 `ui/timeline.lua`: `DrawTimeline(x,y,w,h)` — beat ticks aligned to piano roll grid/zoom
- [x] P2.2 Measure numbers above measure-start ticks; skip labels at low zoom to prevent overlap
- [x] P2.3 Playback head: red vertical line at `sequencer_store.GetProgress()`; hidden when stopped
- [ ] P2.4 Test: tick positions match grid; playhead hidden when `!GetIsPlaying()`

## Phase 3 — Velocity Editor

- [x] P3.1 `ui/velocity.lua`: `DrawVelocityEditor(x,y,w,h)` — horizontal bars for visible notes, height ∝ velocity/127, red→green gradient
- [x] P3.2 Click-drag: set selected_note_index on click, drag changes velocity 0-127 in real-time
- [x] P3.3 Mute toggle: right-click note block in piano roll → flips `note.muted`; muted bars render dimmer
- [x] P3.4 Test: zero-velocity bar min 2px; drag changes note velocity; mute flag persists (manual REAPER test required)

## Phase 4 — Preset Browser

- [x] P4.1 `ui/preset-browser.lua`: folder tree at `reaper.GetResourcePath()/grove-presets/`; creates dir on first access
- [x] P4.2 Preset list: show .grove files; "(No presets)" placeholder; collapsible panel; scrollable list
- [x] P4.3 Save: serialize notes as `return {notes={...}}` via `io.open(w)`; user-input dialog for filename
- [x] P4.4 Load: `dofile()` → validate `notes` field; error handling via in-panel error display, keeps existing notes
- [x] P4.5 Favorites via `reaper.GetExtState/SetExtState`; toggle via star icon on preset items
- [x] P4.6 Test: round-trip save/load; malformed file preserves notes; empty dir shows placeholder (manual REAPER test required)

## Phase 5 — Polish & Edge Cases

- [ ] P5.1 Window transition: ISLAND↔FULL preserves scroll/zoom on return, sequencer keeps running
- [ ] P5.2 Docked mode: ISLAND toggle disabled (early return per existing guard)
- [ ] P5.3 Keyboard shortcuts: Ctrl+S save, Ctrl+W close island
- [ ] P5.4 Frame rate: virtual scroll keeps draw bound under 1ms regression vs baseline
- [ ] P5.5 gfx.quit() mid-island: CleanupAll releases notes; Init restores defaults
- [ ] P5.6 Integration: FULL→ISLAND→FULL cycle with no stuck notes, no data loss
