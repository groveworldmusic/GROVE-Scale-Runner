# Tasks: MIDI Island — Header Icons, Save/Load, Scale Snap, Polish

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~165 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | single-pr |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: single-pr
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | All 9 items | Single PR | ~165 lines, well under 400-line budget |

## Phase 1: Triplet & Clip & Window (Independent)

- [ ] **1.1 — Move triplet to resolution menu** (`src/ui/midi-island/header.lua`). Remove triplet button block (lines 77-96, `stp_x`/`snap_trip_w`). Add separator + "Triplet: ON" | "Triplet: OFF" to `gfx.showmenu()` content (line 63). Redistribute freed width. ~±15 lines.
- [ ] **1.2 — Window position persistence** (`src/ui/gfx-window.lua`, `src/state/ui.lua`, `src/state/persist.lua`). Add `window_pos_x/y` to `ui_store` (get/set/init). Poll `gfx.w`/`gfx.x` via `JS_Window_GetRect` every ~60 frames in MainLoop. Register save key in `persist.PREF_KEYS`. Restore in `ToggleIsland()` expand path. ~25 lines.
- [ ] **1.3 — Horizontal scroll clip bounds** (`src/ui/piano-roll/note.lua`). Add defensive left clip at keyboard strip boundary (already clips at grid_x). Add right clip guard so notes don't render under vertical scrollbar track. ~10 lines.

## Phase 2: Header Batch (Icons + Save/Load)

- [ ] **2.1 — RELOAD/SYNC → glyph icons** (`src/ui/midi-island/header.lua`). Replace "RELOAD" text with `↺` glyph. Replace "SYNC" text with `⇄` glyph. Shrink button widths from `b_w` to `math.floor(b_w * 0.55)`. Keep existing dim/hover/tooltip logic. ~20 lines.
- [ ] **2.2 — SAVE/LOAD header buttons** (`src/ui/midi-island/header.lua`, `src/ui/preset-browser.lua`). Add two icon buttons after PRESETS toggle: SAVE (`⎙` glyph) calls `browser.SavePreset()` with `reaper.GetUserInputs` dialog. LOAD (`⬆` glyph) calls `browser.LoadPreset()`. Wire to same preset-store APIs. ~40 lines.

## Phase 3: Polish (Scale Snap, Heights, Titles)

- [ ] **3.1 — Scale snap highlight toggle** (`src/state/preferences.lua`, `src/ui/theme.lua`, `src/ui/piano-roll/grid.lua`). Add `scale_snap_highlight` field (bool, default `false`) + getter/setter + Init/SyncFromState in preferences_store. Add `grid_scale_beat_highlight` color to theme. In `grid.lua` DrawBeatTicks section, when toggle ON, render vertical beat lines at scale pitches with highlight color. ~30 lines.
- [ ] **3.2 — Velocity bar fixed height** (`src/ui/midi-island.lua`). Change line 284 from `ve_h = base_ve_h + excess` to `ve_h = base_ve_h`. Remove `excess` from velocity; the modulo remainder stays in the background gap. ~3 lines.
- [ ] **3.3 — PRESETS title larger** (`src/ui/preset-browser.lua`). Change `gfx.setfont(1, "Calibri", 11)` (line 765) to `gfx.setfont(1, "Calibri", 14)`. Verify no clipping at top/bottom. Adjust label position if needed. ~5 lines.
- [ ] **3.4 — BEATS title larger, numbers below line** (`src/ui/timeline.lua`). Change BEATS label from font 10 to font 14 (line 189). Move measure numbers from right-of-tick to below-tick at `y + h - lh` (bottom of ruler, line 72). Remove overlap guard if redundant. ~15 lines.

## Implementation Order

Phase 1 first (3 independent tasks, no inter-deps). Phase 2 next (header batch — both tasks modify header.lua, do 2.1 before 2.2 for clean git diff). Phase 3 last (4 independent polish items, smallest LOC).

## Next Step

Ready for implementation (sdd-apply). Single PR, no chaining needed — ~165 lines total.
