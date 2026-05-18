# Tasks: Window Repositioning Fix

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~60-70 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: feature-branch-chain
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | RecreateMainWindow + 3 call sites | PR 1 | Single PR — under 100 lines, pure refactor |

## Phase 1: Foundation

- [x] 1.1 Add `RecreateMainWindow(w, h, x, y, dock?)` to `src/ui/gfx-safe.lua`:
  - Capture position via `gfx.hwnd` → `JS_Window_GetRect` (safety-clamped like main.lua:359-365)
  - Fallback to `ui_store.GetViewOffsetX/Y()` if HWND unavailable
  - Unique temp title (`config.script_title .. reaper.time_precise()`)
  - `gfx.quit()` → `gfx.init(uid, w, h, dock or 0, x, y)` → `gfx.setfont(1, "Calibri", 16)`
  - If `JS_Window_SetPosition` exists (CheckAPI): force position, then restore title
  - Persist new offset + `persist.Save("view_offset_x")` + `persist.Save("view_offset_y")`
  - `pcall` wrapped, returns `(ok, err)`

## Phase 2: Core Implementation

- [x] 2.1 Replace inline `gfx.quit()` + `gfx.init()` block at `src/main.lua:371-379` with `gfx_safe.RecreateMainWindow(720, min_h, ox, oy, 0)`
- [x] 2.2 Replace inline block at `src/ui/gfx-window.lua:51-57` with `gfx_safe.RecreateMainWindow(720, new_h, ox, oy, 0)`
- [x] 2.3 Replace `gfx_safe.SafeGfxInit(...)` at `src/ui/compact-init.lua:97` with `gfx_safe.RecreateMainWindow(gs.w, gs.h, gs.x, gs.y, gs.dock)`

## Phase 3: Verification

- [ ] 3.1 Load script in REAPER; toggle MIDI Island expand/collapse — window position must NOT jump
- [ ] 3.2 Trigger window size enforcement at minimum bounds — position must stay stable
- [ ] 3.3 Switch COMPACT↔FULL mode — position must stay stable
- [ ] 3.4 Remove js_ReaScriptAPI (simulate missing API) — silent fallback, no crash, window opens at stored position
- [ ] 3.5 Dock window (Ctrl+D) — docked mode positioning must be no-op (no regression)
- [ ] 3.6 Confirm all 3 sites now use `RecreateMainWindow` — zero duplicate inline patterns
