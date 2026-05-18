# Proposal: compact-bar-click-handling

## Intent

The compact transport bar currently treats ALL clicks as "toggle panel" — no right-click support, no distinction between content area and the "restore full view" button. This prevents users from accessing the context menu from the bar and makes the restore button require a separate UI path. Fixing this makes the bar a complete interaction surface.

## Scope

### In Scope
- Add `WM_RBUTTONDOWN` interception with `passthrough=false` (consume right-click, prevent REAPER transport context menu)
- Left-click on content area → `TogglePanel()` (preserve current)
- Right-click on content area → `ShowContextMenu()`
- Left/right-click on restore button → `SwitchViewMode()`
- Dynamic registration/release of right-click intercept based on hover state (only blocks transport when cursor on bar)
- Cleanup: release `WM_RBUTTONDOWN` in `Cleanup()`
- Add `IsOnRestoreButton()` hit-test helper

### Out of Scope
- Changes to the context menu content or structure
- Additional mouse messages (WM_MOUSEMOVE, WM_LBUTTONDBLCLK, etc.)
- Modifications to the floating panel UI

## Capabilities

### New Capabilities
- `compact-bar-click-handling`: Mouse interception for left/right click on compact bar, including restore button detection and dynamic hover-based activation

### Modified Capabilities
- None (no existing specs to modify)

## Approach

1. **Hit-test helper**: Add `compact.IsPointOnRestoreButton(client_x, client_y)` using `restore_btn_x`, `cv_y`, `BAR_H`, `RESTORE_BTN_SIZE` to determine if a click targets the restore button.

2. **Dynamic right-click intercept**: In `ProcessMouseInterception()`, each frame check cursor position relative to `(cv_x, cv_y, cv_w, cv_h)`. If cursor is over the bar and `WM_RBUTTONDOWN` is not registered, call `JS_WindowMessage_Intercept(hwnd, "WM_RBUTTONDOWN", false)`. If cursor leaves and intercept is active, call `JS_WindowMessage_Release`. Left-click (`WM_LBUTTONDOWN`, `passthrough=true`) stays always-active as before.

3. **Left-click routing**: In the existing `WM_LBUTTONDOWN` peek handler, check `IsOnRestoreButton()` first — if true, call `SwitchViewMode()` directly; otherwise call `TogglePanel()` as before.

4. **Right-click handler**: Add a `WM_RBUTTONDOWN` peek block. If cursor is over bar: check restore button → `SwitchViewMode()`, else → `ShowContextMenu()`.

5. **Cleanup**: Add `JS_WindowMessage_Release(hwnd, "WM_RBUTTONDOWN")` in `compact.Cleanup()` alongside the existing left-click release.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/compact.lua` | Modified | `ProcessMouseInterception()`, `Cleanup()`, new `IsOnRestoreButton()` helper |
| `src/main.lua` | None | No changes needed — intercept lifecycle is self-contained in `compact.lua` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Right-click context menu appears twice (ours + REAPER's) | Med | `passthrough=false` consumes the message; REAPER transport won't see it |
| Left-click restore button also toggles panel after SwitchViewMode | Low | `SwitchViewMode()` handles panel state; early return pattern after routing |
| Hover-state flickering at bar edge causes rapid register/release | Low | Add a 50ms debounce on release; don't toggle on every frame |
| Right-click on transport edge (near bar but not on it) blocked | Low | Dynamic release when cursor leaves bar area; conservatively compute bar rect |

## Rollback Plan

Revert changes to `ProcessMouseInterception()` and `Cleanup()` in `src/ui/compact.lua`. Remove `IsOnRestoreButton()` helper. The `WM_RBUTTONDOWN` intercept and restore-button routing will be gone — left-click behavior stays identical (restore button click = TogglePanel, same as any other area click).

## Dependencies

- `JS_WindowMessage_Intercept/Peek/Release` API (js_ReaScriptAPI) — already used for left-click, no new dependency

## Success Criteria

- [ ] Right-click on compact bar content shows Scale Runner context menu, NOT REAPER's transport menu
- [ ] Left-click on compact bar content toggles floating panel (unchanged)
- [ ] Left-click and right-click on restore button both call `SwitchViewMode()`
- [ ] Right-click on transport area outside the compact bar triggers normal REAPER transport behavior
