# Tasks: Compact Bar Click Handling

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~80–120 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: Foundation — State & Zone Helper

- [x] 1.1 Replace `intercept_active` (line 49) with `intercept_active_l` and `intercept_active_r`, rename `last_peek_time` → `last_l_time`, add `last_r_time`, `last_hover_time`, `HOVER_DEBOUNCE_MS` locals in `src/ui/compact.lua`
- [x] 1.2 Create `GetCompactZone(rel_x)` helper returning `"restore"`, `"content"`, or `nil` using `restore_btn_x` and `RESTORE_BTN_SIZE`

## Phase 2: Core — Rewrite ProcessMouseInterception

- [x] 2.1 Update left-click block: use `intercept_active_l`, route via `GetCompactZone(wx - cv_x)` → `"restore"` calls `SwitchViewMode()`, `"content"` calls `TogglePanel()`
- [x] 2.2 Add right-click block: hover-activate `WM_RBUTTONDOWN` (passthrough=false), release with 50ms debounce via `reaper.time_precise()`, manage `intercept_active_r`
- [x] 2.3 Add right-click peek: when intercept active, peek `WM_RBUTTONDOWN`, route via `GetCompactZone(wx - cv_x)` → `"restore"` calls `SwitchViewMode()`, `"content"` calls `ShowContextMenu()`

## Phase 3: Cleanup

- [x] 3.1 Release `WM_RBUTTONDOWN` intercept in `compact.Cleanup()` alongside existing `WM_LBUTTONDOWN` release
- [x] 3.2 Reset `intercept_active_l`, `intercept_active_r`, `last_l_time`, `last_r_time`, `last_hover_time` in cleanup
