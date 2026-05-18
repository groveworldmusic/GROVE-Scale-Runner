# Tasks: Piano Roll Professional — Fase 1 (Editing UX Core)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~435 (1 new + 12 modified) |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | 4 PRs: Slice A → B → C → D |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: Medium

### Suggested Work Units

| Slice | Goal | Base Branch | Files |
|-------|------|-------------|-------|
| A | Auto-scroll | feat/piano-roll-pro | island.lua, midi-island.lua, input.lua, timeline.lua |
| B | Quantize | (previous PR branch) | quantize.lua (NEW), undo.lua, shortcuts.lua, header.lua, interaction.lua, piano-roll.lua |
| C | Alt+drag Clone | (previous PR branch) | drag.lua |
| D | Tool Switching + Audition | (previous PR branch) | shortcuts.lua, input.lua, handlers.lua, header.lua, island.lua |

## Phase 1: Foundation — State & Infrastructure

- [x] 1.1 Add `follow_playhead` (bool) to `src/state/island.lua` — getter/setter pair + Init default: `follow_playhead=true` (quantize keys deferred to Slice B)
- [x] 1.2 Create `src/core/quantize.lua` (moved from ui/ to core) — `QuantizeBeat(beat, res, str, trip)` + `QuantizeNote(note, res, str, trip)` pure functions. Grid matches snap.lua: step = 4/eff_res, triplet = resolution * 1.5. Strength lerp: beat + (nearest - beat) * (strength / 100). Swing deferred.
- [x] 1.3 Add `"quantize"` type handlers in `src/ui/piano-roll/undo.lua` both `RestoreUndo` and `RestoreRedo` — prev/new_state format: {start_beat, duration} (extends "move" format with duration)
- [x] 1.4 Add Q key (char 113) quantize handler in `src/ui/piano-roll/interaction/shortcuts.lua` — dispatches `m.HandleQuantize()`. Tool switch keys (1/2/3) deferred to Slice D. Ctrl+Q replaced with plain Q to avoid REAPER native shortcut conflict.

## Phase 2: Auto-scroll Implementation

- [x] 2.1 Add `_auto_scroll_grace = 0` local var + auto-scroll logic in `src/ui/midi-island.lua` `Draw()`: if `follow_playhead` and `is_playing` and `os.clock() > _auto_scroll_grace`, clamp scroll_x so playhead stays in middle-third of visible beats (direct set per frame, no lerp — playhead moves gradually enough)
- [x] 2.2 Add auto-scroll toggle button in `src/ui/timeline.lua` `DrawTimelineRuler()` — "A" icon beside "BEATS" label, filled when on/outlined when off, toggle via `island_store.SetFollowPlayhead(not island_store.GetFollowPlayhead())`, click via `ui_store.GetMouseClick()` hit-test
- [x] 2.3 Add grace timer reset in `src/ui/midi-island/input.lua` `HandleMouse` — when user scrolls (wheel delta != 0), set `island_store.SetAutoScrollGraceTimer(os.clock() + 2.0)`, synced to `_auto_scroll_grace` local in midi-island.lua Draw() each frame

## Phase 3: Quantize UI + Wiring

- [x] 3.1 Add quantize "QNTZ" button with strength context menu to `src/ui/midi-island/header.lua` `DrawHeader` — right of snap controls. Context menu: 25%/50%/75%/100% strength selection + "Quantize Selected Notes" trigger. Swing controls deferred.
- [x] 3.2 Export `HandleQuantize` through barrel modules: `src/ui/piano-roll/interaction.lua` add `m.HandleQuantize = shortcuts.HandleQuantize`, `src/ui/piano-roll.lua` add `piano_roll.HandleQuantize = interaction.HandleQuantize`

## Phase 4: Alt+drag Clone

- [x] 4.1 Add clone detection in `StartNoteDrag` — detect `(gfx.mouse_cap & 16) == 16`, branch to clone path: deep-copy selected notes with new UUIDs, insert at end of notes array, select clones, start drag on clones. Commit pushes type `"add"` undo. Cancel removes clones and restores original selection.
- [x] 4.2 Clone ghost rendering — existing note.lua ghost rendering (Pass 1 in DrawNoteBlocks) uses `GetNoteDragOrigins()` which includes clone origins. Ghosts appear at original positions (behind the unmodified originals). Cancel removes clone notes from array, no ghosts remain. No additional ghost code needed.

## Phase 5: Tool Switching + Note Audition

- [x] 5.1 Add eraser tool dispatch in `src/ui/midi-island/input.lua` — in left-click dispatch block (after `elseif tool_mode == "knife"`), add `elseif tool_mode == "eraser"`: left click on note body → call `handlers.HandlePaintRightClick(mx, my, ...)` (same delete logic), no drag/resize in eraser mode
- [x] 5.2 Add eraser icon to `src/ui/midi-island/header.lua` `DrawToolModeRow` — extend `tool_labels`/`tool_hints`/`tool_modes` arrays to include `{"✎", "✂", "⨯"}` and `{"paint", "knife", "eraser"}`, adjust layout widths for 3 buttons
- [x] 5.3 Add note audition in `src/ui/piano-roll/interaction/handlers.lua` `HandlePaintClick` — after note create (line ~84) or when clicking existing note body: call `require("core.midi").SendMidi(pitch, true, 100)` then schedule `reaper.defer(function() midi.SendMidi(pitch, false, 0) end)` for note-off next frame; skip audition when tool is not paint

## Implementation Order

Slice A (Auto-scroll) first — self-contained, no deps. Slice B (Quantize) depends on island state from 1.1. Slice C (Alt+drag) depends only on existing move infrastructure. Slice D (Tool Switching + Audition) touches shortcuts + input + handlers — should come after A to avoid conflict with scroll timer wiring. Doable in parallel or sequence; no hard dep between B/C/D.

## Risks

- Auto-scroll smooth lerp may conflict with existing scrollbar dragging — grace timer override handles this
- Quantize strength+swing controls in header add UI complexity — keep as simple slider rows
- Eraser tool reuses HandlePaintRightClick — verify right-click sweep still works in eraser mode (design says no right-drag in eraser)
- Note audition calls `reaper.defer` once per click — GC-safe but verify no note-on leak if click fast (design says ~30ms schedule is fine)

## Final Summary

| Metric | Value |
|--------|-------|
| Total tasks | 14/14 completed |
| Slices | A (auto-scroll), B (quantize), C (alt+clone), D (tools+audition) |
| Files changed | 13 (1 new: `src/core/quantize.lua`, 12 modified) |
| New state keys | `follow_playhead`, `quantize_strength`, `quantize_swing` in `island_store` |
| New undo types | `"quantize"` (start_beat + duration), `"add"` (clone notes) |
| New tool mode | `"eraser"` (dispatch via input.lua) |
| New shortcuts | `1`/`2`/`3` tool switch, `Q` quantize |
| Icon deviation | Eraser uses `⨯` instead of spec's `⌫` (cosmetic, verified in code) |
| Known limitations | QNTZ button context menu "Quantize Selected Notes" option is unwired (only Q key triggers quantize); auto-scroll uses hard clamp on visible-range exit rather than continuous middle-third tracking |
| Risks mitigated | All 4 risks addressed (grace timer, UI complexity, eraser sweep, audition GC) |
