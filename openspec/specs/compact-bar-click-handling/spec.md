# Compact Bar Click Handling Specification

## Purpose

The compact transport bar must distinguish left-click from right-click, and content-area clicks from restore-button clicks, enabling context menu access and view-mode switching directly from the bar.

## Requirements

### Requirement: Hit-Test Zone Detection

The system MUST provide `compact.IsPointOnRestoreButton(client_x, client_y)` that returns `true` when the point is within the restore button rect defined by `restore_btn_x`, `cv_y`, `BAR_H`, and `RESTORE_BTN_SIZE`.

| Scenario | GIVEN | WHEN | THEN |
|----------|-------|------|------|
| Inside button | restore_btn_x=100, cv_y=50, BAR_H=26, RESTORE_BTN_SIZE=12 | IsPointOnRestoreButton(105, 58) | returns true |
| Outside horizontally | restore_btn_x=100, cv_y=50 | IsPointOnRestoreButton(80, 58) | returns false |
| Outside vertically | restore_btn_x=100, cv_y=50, BAR_H=26 | IsPointOnRestoreButton(105, 10) | returns false |

### Requirement: Left-Click Routing

WM_LBUTTONDOWN (passthrough=true, always active) MUST route left-clicks on the compact bar.

| Area | Action |
|------|--------|
| Content (not restore button) | `TogglePanel()` |
| Restore button | `SwitchViewMode()` |

- Scenario: Content area toggles panel — GIVEN cursor within bar rect but NOT on restore button, WHEN WM_LBUTTONDOWN intercepted, THEN TogglePanel() called.
- Scenario: Restore button switches view — GIVEN cursor on restore button, WHEN WM_LBUTTONDOWN intercepted, THEN SwitchViewMode() called (not TogglePanel()).

### Requirement: Right-Click Routing

WM_RBUTTONDOWN (passthrough=false, hover-activated) MUST route right-clicks on the compact bar. Outside the bar, right-clicks MUST reach REAPER transport normally.

| Area | Action |
|------|--------|
| Content (not restore button) | `ShowContextMenu()` |
| Restore button | `SwitchViewMode()` |
| Outside bar rect | Message passes through (intercept inactive) |

- Scenario: Content area shows menu — GIVEN cursor within bar rect but NOT on restore button, WHEN WM_RBUTTONDOWN intercepted, THEN ShowContextMenu() called.
- Scenario: Restore button switches view — GIVEN cursor on restore button, WHEN WM_RBUTTONDOWN intercepted, THEN SwitchViewMode() called.
- Scenario: Outside bar passes through — GIVEN cursor outside bar rect, WHEN right-click occurs, THEN REAPER transport handles it normally.

### Requirement: Dynamic Hover Interception

The WM_RBUTTONDOWN intercept MUST activate only while the cursor hovers within the compact bar rect (cv_x, cv_y, cv_w, cv_h). It MUST release when the cursor leaves. Release SHOULD be debounced by 50ms to prevent flickering at bar edges.

- Scenario: Activate on hover — GIVEN cursor enters bar rect, WHEN ProcessMouseInterception() runs, THEN JS_WindowMessage_Intercept(hwnd, "WM_RBUTTONDOWN", false) called.
- Scenario: Deactivate on leave — GIVEN cursor leaves bar rect and right-click intercept is active, WHEN ProcessMouseInterception() runs, THEN JS_WindowMessage_Release(hwnd, "WM_RBUTTONDOWN") called.
- Scenario: Debounce edge flicker — GIVEN cursor oscillates at bar edge within 50ms, THEN release SHOULD be deferred to avoid rapid register/release cycles.

### Requirement: Cleanup on Script Exit

compact.Cleanup() MUST release the WM_RBUTTONDOWN intercept.

- Scenario: Release on exit — GIVEN script is shutting down, WHEN compact.Cleanup() called, THEN JS_WindowMessage_Release(hwnd, "WM_RBUTTONDOWN") runs alongside the existing WM_LBUTTONDOWN release.

### Requirement: Existing Behavior Preserved

WM_LBUTTONDOWN interception MUST remain unchanged: always-active with passthrough=true, no new dependencies.

- Scenario: Left-click unchanged — GIVEN intercept_active is false, WHEN ProcessMouseInterception() first runs, THEN WM_LBUTTONDOWN is registered with passthrough=true (current behavior preserved).
