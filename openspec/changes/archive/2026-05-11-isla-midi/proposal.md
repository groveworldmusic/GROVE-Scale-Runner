# Proposal: Isla MIDI

## Intent

Replace the current "MIDI Island" (a CH selector popup via `gfx.quit()+gfx.init()` resize) with a full-featured production island: piano roll, timeline ruler, preset browser, and velocity editor — all in a dedicated view mode.

## Scope

### In Scope
- `VIEW_MODES.ISLAND = 3` — new view mode with dedicated window size (e.g. 1000×700)
- Piano roll grid: horizontal time×pitch rendering with note blocks, scroll, zoom
- Timeline ruler: beat markers, playback head sync, position display
- Note properties panel: velocity editor, mute/solo per-note
- Preset browser: folder tree, preset list, save/load from filesystem
- Wire into SwitchViewMode() and MainLoop routing

### Out of Scope
- MIDI note drawing/dragging in piano roll (deferred — Phase 1 renders static notes only)
- Audio waveform display
- MIDI file import/export beyond current ExportToMidi()
- Plugin VST hosting or inline MIDI FX editing
- Theme editor or per-note color customization

## Capabilities

### New
- **piano-roll**: horizontal note grid with pitch×time layout, virtual scrolling, beat grid lines, playback head
- **timeline-ruler**: beat/measure markers, position display, playback head sync to sequencer
- **velocity-editor**: per-note velocity bars, mute toggle, note property display
- **preset-browser**: filesystem tree navigation, favorites/tags/bookmarks, preset save/load dialogs
- **island-store**: new state store for island-specific state (scroll position, zoom level, preset list, edit buffer)

### Modified
- None — no existing spec files change; all capabilities are new

## Approach

**Recommendation: Approach 2 (Phase 0-driven).**

1. Add `VIEW_MODES.ISLAND = 3` to config.lua, create `state/island.lua` store
2. Wire island routing into `MainLoop` and `SwitchViewMode()` — window resizes to 1000×700
3. Build piano roll as new module `src/ui/piano-roll.lua` — horizontal grid using shared `DrawRoundedRect` + gfx.rect for cells, virtual scroll via `gfx.mouse_wheel` delta
4. Timeline ruler as `src/ui/timeline.lua` — reads sequencer store for beat/measure sync
5. Velocity editor as `src/ui/velocity.lua` — vertical bars per note, drag-to-edit
6. Preset browser as `src/ui/preset-browser.lua` — `io.*` + `reaper.GetResourcePath()`, tree panel + list panel
7. New MIDI data model in `state/island.lua`: notes with `{pitch, start_beat, duration, velocity, muted}`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/config.lua` | Modified | Add `VIEW_MODES.ISLAND = 3` |
| `src/main.lua` | Modified | Island routing in MainLoop, SwitchViewMode |
| `src/state/island.lua` | New | Island state store (scroll, zoom, notes, preset) |
| `src/ui/piano-roll.lua` | New | Horizontal note grid |
| `src/ui/timeline.lua` | New | Beat/measure ruler |
| `src/ui/velocity.lua` | New | Note property panel |
| `src/ui/preset-browser.lua` | New | Filesystem browser |
| `src/ui/views.lua` | Modified | DrawIslandView() entry point |
| `src/ui/compact-init.lua` | Modified | SwitchViewMode updated for island |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Piano roll perf: 73 rows × 64 beats = ~4672 cells, no GPU | High | Virtual scroll — only render visible rows + 2 octave buffer |
| gfx.quit()+gfx.init() destroys GFX context on resize | Med | Save/restore LastGfxState; island uses fixed 1000×700, no dynamic resize |
| Docked mode breaks island (current toggle exits early) | Med | Deferred to Phase 5; island mode disables dock toggle |
| No file I/O testable outside REAPER | Med | Wrap `io.*` + `reaper.GetResourcePath()` in a load/save module with fallback stubs |
| MIDI data model (progression) lacks duration/position/velocity | High | `state/island.lua` maintains separate note table: `{pitch, start, duration, velocity, muted}` |

## Rollback Plan

Revert `config.lua` VIEW_MODES, delete `src/state/island.lua` and `src/ui/piano-roll.lua`, `timeline.lua`, `velocity.lua`, `preset-browser.lua`. Revert MainLoop routing in `main.lua` and `compact-init.lua`.

## Dependencies

- js_ReaScriptAPI (already required)
- REAPER `io.*` + `reaper.GetResourcePath()` for preset browser filesystem access
- No external Lua libraries

## Success Criteria

- [ ] `VIEW_MODES.ISLAND` renders at 1000×700 with 3 panels visible
- [ ] Piano roll renders horizontal note blocks from progression data at correct pitch/time positions
- [ ] Timeline ruler shows beat markers aligned to sequencer position
- [ ] Velocity editor displays bars and accepts click-to-edit
- [ ] Preset browser navigates filesystem and loads/saves `.grove` files
- [ ] SwitchViewMode toggles FULL ↔ ISLAND without data loss
