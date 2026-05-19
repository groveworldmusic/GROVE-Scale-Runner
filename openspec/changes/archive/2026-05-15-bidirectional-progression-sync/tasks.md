# Tasks: Bidirectional Progression Sync

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 350–450 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | All 6 phases | PR 1 | Tightly coupled: helpers→sync→state→button. Scrollbar and cleanup included as minor scope. |

## Phase 1: Foundation — Note-Store Helpers

- [x] 1.1 Add `GroupNotesByBeat(notes, snap_resolution)` to note-store.lua — groups notes by 4-beat slot column
- [x] 1.2 Add `FindNearestScaleDegree(pitch, root_idx, scale_idx)` to note-store.lua — returns closest degree (1-7) using SCALES intervals with wraparound
- [x] 1.3 Add `DetectChordModeFromDegrees(sorted_degrees)` to note-store.lua — matches degree offset pattern against config.CHORD_MODES

## Phase 2: Core — SyncNotesToProgression

- [x] 2.1 Add `SyncNotesToProgression(seq_store, prefs_store, beats_per_slot?)` to note-store.lua — iterates 16 slots, groups notes by beat range, detects degree+chord_mode+octave per group, writes via SetProgressionEntry. Algorithm per design.md:98-196.

## Phase 3: State Machine — notes_dirty → Tri-State

- [x] 3.1 Add `NOTES_STATE` enum constants (`LOADED=0, EDITED=1, SYNCED=2`) + `GetNotesState()`/`SetNotesState(v)` + `ResetNotesState()` to island_store; remove `notes_dirty` field + old getters/setters (kept backward-compat shims: GetNotesDirty/SetNotesDirty map true→EDITED, false→LOADED)
- [x] 3.2 Replace 14 `SetNotesDirty(true)` call sites across note.lua, drag.lua (×7), handlers.lua (×2), knife.lua with `SetNotesState(NOTES_STATE_EDITED)`
- [x] 3.3 Replace 4 `GetNotesDirty()`/`SetNotesDirty(false)` sites in midi-island.lua (lines 86, 99, 126) and main.lua (line 303) with tri-state equivalents; update auto-reload guard (midi-island.lua:99) to only reload when `GetNotesState() == NOTES_STATE_LOADED`

## Phase 4: UI — SYNC Button

- [x] 4.1 Add SYNC button in header.lua after RELOAD; update `DrawHeader` signature to return `(cur_x, reload_requested, sync_requested)`
- [x] 4.2 Add SYNC handler in midi-island.lua Draw(): calls `island_store.SyncNotesToProgression(seq_store, prefs)`, transitions state to `NOTES_STATE_SYNCED`

## Phase 5: Scrollbar Drag → Store

- [x] 5.1 Add 6 scrollbar drag getters/setters + `ResetScrollbarDragState()` to island_store (`sb_dragging`, `sb_drag_start_x`, `sb_scroll_at_drag_start`, `vsb_dragging`, `vsb_drag_start_y`, `vsb_scroll_at_drag_start`)
- [x] 5.2 Replace module-level `_sb_dragging`/`_vsb_dragging` locals (midi-island.lua lines 61-68 and 17 usage sites) with store getters/setters; update line 84 reset to call `ResetScrollbarDragState()`

## Phase 6: Audit & Cleanup

- [x] 6.1 Verify all SetProgressionEntry call sites increment `progression_revision` (progression.lua: Add, Remove, Swap, Clear) — confirmed all call sites (SetProgression, SetProgressionEntry, ClearProgression) increment revision
- [x] 6.2 Fix preset-browser.lua:65 — remove `pcall(reaper.GetResourcePath, preset_dir)` no-op
- [x] 6.3 Grep codebase for surviving `notes_dirty`/`SetNotesDirty`/`GetNotesDirty` references; clean up any missed sites — only backward-compat shims remain (intentional)
