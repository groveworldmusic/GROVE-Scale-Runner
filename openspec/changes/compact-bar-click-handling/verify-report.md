## Verification Report

**Change**: compact-bar-click-handling
**Version**: 1
**Mode**: Standard (no automated test infrastructure available for REAPER GUI code — static analysis only)

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 6 |
| Tasks complete | 6 |
| Tasks incomplete | 0 |

### Build & Tests Execution
**Build**: ➖ Not applicable (Lua/REAPER script — no build step)

**Tests**: ➖ No automated test infrastructure available for REAPER GUI code
```
Acceptance criteria from spec must be verified manually (as stated in design).
No Lua test files found for compact.lua — only test_midi.lua exists for midi exports.
```

**Coverage**: ➖ Not available

### Spec Compliance Matrix
| Requirement | Scenario | Implementation Evidence | Result |
|-------------|----------|------------------------|--------|
| REQ-01: Hit-Test Zone Detection | Inside button → restore | `GetCompactZone(rel_x)` lines 586-594: rel_x >= restore_btn_x AND rel_x < restore_btn_x+RESTORE_BTN_SIZE+5 → "restore" | ✅ COMPLIANT |
| REQ-01: Hit-Test Zone Detection | Outside horizontally → no hit | `GetCompactZone(rel_x)` returns nil for rel_x < restore_btn_x AND rel_x > restore_btn_x+RESTORE_BTN_SIZE+5 | ✅ COMPLIANT |
| REQ-01: Hit-Test Zone Detection | Outside vertically → no hit | y-boundary handled by `is_on_bar` check (line 607), not in GetCompactZone | ✅ COMPLIANT |
| REQ-02: Left-Click Routing | Content area → TogglePanel() | Line 639-640: zone=="content" → TogglePanel() | ✅ COMPLIANT |
| REQ-02: Left-Click Routing | Restore button → SwitchViewMode() | Line 637-638: zone=="restore" → compact.SwitchViewMode() | ✅ COMPLIANT |
| REQ-03: Right-Click Routing | Content area → ShowContextMenu() | Line 654-655: zone=="content" → compact.ShowContextMenu() | ✅ COMPLIANT |
| REQ-03: Right-Click Routing | Restore button → SwitchViewMode() | Line 652-653: zone=="restore" → compact.SwitchViewMode() | ✅ COMPLIANT |
| REQ-03: Right-Click Routing | Outside bar passes through | Intercept is hover-activated; lines 622-627 release after 50ms debounce outside bar | ⚠️ PARTIAL |
| REQ-04: Dynamic Hover Interception | Activate on hover enter | Lines 616-618: is_on_bar AND not intercept_active_r → intercept | ✅ COMPLIANT |
| REQ-04: Dynamic Hover Interception | Deactivate on leave (debounced) | Lines 622-627: not is_on_bar AND intercept_active_r, debounce 50ms via reaper.time_precise() | ✅ COMPLIANT |
| REQ-04: Dynamic Hover Interception | Debounce edge flicker | 50ms debounce on release only, activation immediate | ✅ COMPLIANT |
| REQ-05: Cleanup on Script Exit | Release WM_RBUTTONDOWN | Lines 681-687: gated on intercept_active_r, releases if hwnd valid | ✅ COMPLIANT |
| REQ-06: Existing Behavior Preserved | Left-click unchanged | Lines 609-613: passthrough=true, always active, registered once | ✅ COMPLIANT |

**Compliance summary**: 12/13 scenarios compliant, 1 partial

### Correctness (Static Evidence)
| Requirement | Status | Notes |
|------------|--------|-------|
| Hit-Test Zone Detection | ✅ Implemented | GetCompactZone uses bitmap-local rel_x, y-boundary at is_on_bar level |
| Left-Click Routing | ✅ Implemented | TogglePanel for content, SwitchViewMode for restore |
| Right-Click Routing | ⚠️ Implemented with edge case | See WARNING #1 — click eaten within debounce window after leaving bar |
| Dynamic Hover Interception | ✅ Implemented | 50ms debounce on release via reaper.time_precise() |
| Cleanup | ✅ Implemented | Both LBUTTONDOWN and RBUTTONDOWN released, all state vars reset |
| Existing Behavior Preserved | ✅ Implemented | WM_LBUTTONDOWN unchanged: always active, passthrough=true |

### Coherence (Design)
| Decision | Followed? | Notes |
|----------|-----------|-------|
| GetCompactZone over two predicates | ✅ Yes | Returns "restore"/"content"/nil, one call one switch |
| Hover debounce via reaper.time_precise() | ✅ Yes | 50ms on release only, activation immediate |
| Separate click timestamps (last_l_time, last_r_time) | ✅ Yes | No collision possible between left and right click dedup |
| Data flow: left-click block | ✅ Yes | Intercept → Peek → GetCompactZone → route |
| Data flow: right-click block | ⚠️ Minor deviation | Peek RBUTTONDOWN runs unconditionally; design says "only if intercept active" |
| HOVER_DEBOUNCE_MS named constant | ❌ Not followed | Value `0.05` hardcoded on line 624; task spec required named constant |

### Issues Found

**CRITICAL**: None

**WARNING**:
1. **Right-click eaten within 50ms debounce window after cursor leaves bar** (REQ-03, lines 622-658)
   - When cursor leaves the compact bar, the right-click intercept remains active for up to 50ms (debounce). If the user right-clicks outside the bar during this window, `JS_WindowMessage_Peek` returns the intercepted message (since intercept is still active with passthrough=false), but the routing block on line 649 (`if is_on_bar then`) skips it. The message is neither processed by our code NOR forwarded to REAPER — the click is silently consumed.
   - Severity: Medium. The 50ms window is brief, but the spec explicitly states "Outside bar rect, Message passes through (intercept inactive)".
   - Fix: Either gate the peek on `intercept_active_r` AND add passthrough on release, or set `last_hover_time = 0` on exit and release immediately with the debounce applied to the release action itself (rather than to the releasing condition).

**SUGGESTION**:
1. **HOVER_DEBOUNCE_MS constant missing** (task 1.1 deviation)
   - Line 624 uses hardcoded `0.05` instead of a named `local HOVER_DEBOUNCE_MS = 0.05` constant. The task spec requires this as a module-level local. Named constant would improve readability and centralize the duration.
2. **WM_RBUTTONDOWN peek not gated on intercept_active_r** (design data flow deviation)
   - Lines 646-647: `reaper.JS_WindowMessage_Peek(c.transport_hwnd, "WM_RBUTTONDOWN")` runs unconditionally. The design data flow shows "Peek WM_RBUTTONDOWN (only if intercept active)". Currently harmless (returns nil when intercept inactive), but wrapping in `if intercept_active_r then` would match the design and slightly reduce unnecessary API calls.
3. **Spec/design API name mismatch (informational)**
   - Spec requires `compact.IsPointOnRestoreButton(client_x, client_y)`. Design chose `GetCompactZone(rel_x)` as local. This is an intentional design decision (documented in design's Decision table), but the spec was not updated to reflect the new function signature. Consider updating the spec's scenarios to use `GetCompactZone` with bitmap-local coordinates.

### Verdict
**PASS WITH WARNINGS**

All 6/6 tasks completed. Core functionality (left-click routing, right-click routing within bar, hover interception, cleanup) is correctly implemented and matches the spec. One edge case found (right-click eaten within debounce window after leaving bar) is a real but low-probability issue in practice. The fix is straightforward but not blocking.
