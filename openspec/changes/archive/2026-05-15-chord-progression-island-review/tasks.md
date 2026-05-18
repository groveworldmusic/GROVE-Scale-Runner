# Tasks: Chord Progression Island — Targeted Bug Fixes

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~250 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Dead code + precision + lfs + cache + button + cleanup | PR 1 | Single PR, all fixes independent or trivial |

## Phase 1: Dead Code Removal (Zero Risk)

- [x] 1.1 **velocity.lua:295-297** — replace inline `sel_count` loop with `island_store.GetSelectionCount()` (island_store already imported at L7)
- [x] 1.2 **views/islands.lua** — strip all 12 `config.state.*` writes from dropdown/button handlers; keep `prefs.Set*()` and `persist.Save()` calls intact

## Phase 2: Precision & Platform Fixes

- [x] 2.1 **piano-roll/note.lua:301** — add `epsilon = 0.5px` to `beat_end` pixel→beat conversion for lasso right-edge precision
- [x] 2.2 **preset-browser.lua** — replace `io.popen('dir ...')` at L106+L121 with `lfs.dir()` + `lfs.attributes()`; wrap in `pcall` with `io.popen` fallback

## Phase 3: Caching & New UI

- [x] 3.1 **midi-island.lua** — add `_total_beats` module-local cache with lazy compute in DrawScrollbars; invalidated after LoadNotesFromProgression and when notes length changes
- [x] 3.2 **midi-island/header.lua** — add "RELOAD" button in header row (after PRESETS PANEL toggle); handler calls `island_store.LoadNotesFromProgression(seq_store)` with confirmation prompt (`gfx.showmenu`), bypassing `notes_dirty` guard

## Phase 4: Documentation Cleanup

- [x] 4.1 **AGENTS.md** (root) — remove stale INVESTIGATING marker for `ve_h=0`

## Implementation Order

Dead code removal first (no risk). Then precision + lfs (pcall-guarded). Then cache + button (slightly more involved, but independent of each other). AGENTS.md cleanup last.

### Key Dependencies
- Item 3.2 (Reload button) is independent of 3.1 (cache) — the button calls LoadNotesFromProgression which already invalidates the cache
- No circular or blocking dependencies between phases
