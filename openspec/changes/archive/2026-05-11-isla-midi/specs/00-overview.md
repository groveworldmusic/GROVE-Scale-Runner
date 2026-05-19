# Isla MIDI — Change Overview

## Non-requirements

The following are explicitly OUT of scope for ALL phases of this change:

- **No MIDI recording**: The piano roll renders static notes only. No real-time MIDI note capture, no mouse drawing/placing notes on the grid.
- **No audio export**: No WAV/MP3 rendering. The preset file format is Lua-serialized data only.
- **No VST hosting**: No inline MIDI FX editing, no plugin parameter automation.
- **No theme editor**: Per-note color customization deferred. Uses existing theme colors.
- **No drag-and-drop notes**: Note blocks are rendered but not draggable. Editing is via the velocity editor panel only.
- **No multi-track**: The island operates on a single note sequence. No track lanes or mixer.
- **No dynamic resize**: The island window is fixed at 1000×700. `gfx.init()` re-creation is destructive; dynamic resize would lose GFX state.
- **No docked mode support**: Island mode disables dock toggle per the proposal risk mitigation. Docked mode remains FULL-only.

## Cross-Cutting Edge Cases

| Edge Case | Expected Behavior | Phases |
|-----------|-------------------|--------|
| **Window too small** (< 800×550) | Island mode SHALL NOT activate; `SwitchViewMode()` returns early with no-op | 0 |
| **Empty notes array** | Grid renders with background + beat lines only; no crash, no note blocks | 1 |
| **200+ note blocks** | Virtual scroll keeps draw count bounded; no frame-rate drop below ~30 fps | 1 |
| **Zero-velocity note** | Renders velocity bar at minimum height (2px); note plays but produces no audible MIDI velocity | 3 |
| **Extremely long progression** (1000+ beats) | Scroll-drag handles up to ~2^31 pixels internally; virtual scroll clips invisible regions | 1, 2 |
| **Empty preset library** | Browser shows "(No presets)" placeholder; save still works | 4 |
| **Malformed .grove file** | Load shows REAPER MB error; existing notes unchanged | 4 |
| **gfx.quit() mid-island** | CleanupAll releases MIDI notes; next Init restores island store from config.state defaults | 0, 5 |
| **Switch back to FULL mid-play** | Sequencer continues running; island store retains scroll/zoom state; no data loss | 0, 5 |
| **File path with spaces/unicode** | `io.open()` on REAPER Windows handles spaces; unicode path length limited to 260 chars | 4 |

## Phase Acceptance Criteria

### Phase 0 — Foundation (island-store + config + routing)
- [ ] `config.VIEW_MODES.ISLAND = 3` added
- [ ] `state/island.lua` exists with Init(), all getter/setter pairs, note data model
- [ ] `main.lua` routes `view_mode == 3` to `DrawIslandView()`
- [ ] `SwitchViewMode()` toggles FULL ↔ ISLAND via `gfx.quit() + gfx.init("...", 1000, 700, ...)`
- [ ] LastGfxState saved before island transition, restored on return to FULL
- [ ] Docked mode disables island toggle (early return)
- [ ] Window < 800×550 blocks island activation

### Phase 1 — Piano Roll
- [ ] Grid renders with pitch rows + beat columns at correct positions
- [ ] Note blocks from island store render at correct pitch/time
- [ ] Virtual scroll renders only visible rows + 2-octave buffer
- [ ] Mouse wheel scrolls horizontally; scroll consumed and zeroed per project pattern
- [ ] Zoom 0.25x–4.0x changes beat-to-pixel ratio without changing beat scroll offset
- [ ] Beat grid alternates strong/weak line weights

### Phase 2 — Timeline Ruler
- [ ] Beat ticks align with piano roll grid at all zoom levels
- [ ] Measure numbers display without overlap
- [ ] Playhead follows sequencer progress, hidden when stopped

### Phase 3 — Velocity Editor
- [ ] Vertical bars render with correct velocity height for visible notes
- [ ] Click-drag changes velocity, clamped 0-127, real-time update
- [ ] Mute toggle flips `note.muted`, dims bar rendering
- [ ] Edit buffer selects correct note on click

### Phase 4 — Preset Browser
- [ ] Folder tree navigates `grove-presets/` directory
- [ ] Preset list shows `.grove` files with metadata
- [ ] Save writes valid Lua data file; Load replaces notes
- [ ] Malformed files show error without data loss
- [ ] Empty directory shows placeholder

### Phase 5 — Polish & Edge Cases
- [ ] No stuck MIDI notes on island ↔ full transition
- [ ] Scroll position retained across view mode switches
- [ ] Keyboard shortcuts documented (Ctrl+S save, etc.)
- [ ] Frame rate stable (< 1ms draw time regression) against baseline
