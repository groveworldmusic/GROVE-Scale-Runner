# Tasks: Phase 3 — LOW Priority Items

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~50 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Decision needed before apply | No |

## Phase 3 Tasks

- [x] **3.1** `src/ui/piano.lua` — Cache `active_mod12` table with revision counter. Add `_active_note_revision` counter, only rebuild `active_mod12` when revision changes.
- [x] **3.2** `src/ui/dropdown.lua` — Hoist `GetFitText` closure to module level. Define as module-level function instead of per-draw closure.
- [x] **3.3** `src/core/midi.lua` — Pre-allocate chord array slots in `TriggerChord`. Pre-allocate array with known max size. Make `midi_channel` configurable via `GetMidiChannel()`/`SetMidiChannel()`.
- [x] **3.4** `src/core/slots.lua` — Add revision tracking for subdivision dots. Track revision with `_dots_revision` counter, skip `gfx.circle` calls when state unchanged.
- [x] **3.5** `src/ui/layout.lua` — Guard module-level `_S`, `_OX`, `_OY` against stale values. Add nil/zero guards, return 0 when scale is stale.
- [x] **3.6** `src/core/api-guard.lua` — Silent clamp. Remove `ShowConsoleMsg` from `ClampIndex` (clamping on boundary scrolling is normal behavior, not an error).
