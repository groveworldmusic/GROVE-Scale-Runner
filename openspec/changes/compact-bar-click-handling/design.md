# Design: Compact Bar Click Handling

## Technical Approach

Add right-click interception and zone-based routing to the compact transport bar. Replace the single `intercept_active` flag with two independent flags, add a `GetCompactZone()` hit-test helper, and manage the right-click intercept via hover detection with 50ms debounce on release. Left-click passthrough semantics are unchanged — only the routing logic expands.

## Architecture Decisions

### Decision: Unified zone helper over two separate predicates

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `IsOnRestoreButton()` + separate content check | Two calls per click, slightly more implicit logic | Rejected |
| `GetCompactZone(rel_x)` → `"restore"`, `"content"`, or `nil` | One call, one switch, trivially extensible for future zones | **Chosen** |

`restore_btn_x` is in bitmap-local coordinates (set by `DrawCompactBar`). The client-relative `wx` from `JS_Window_ScreenToClient` normalises via `rel_x = wx - cv_x`, which maps to bitmap coordinates. One helper, one coordinate system.

### Decision: Hover debounce via `reaper.time_precise()`

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Frame counter | Frame-rate dependent, inconsistent debounce at variable fps | Rejected |
| `reaper.time_precise()` | Real-time ms, frame-rate independent, same timer used elsewhere in REAPER ecosystem | **Chosen** |

50ms matches the proposal's flicker mitigation. Activation is immediate (no debounce on enter), only release is debounced.

### Decision: Separate last-click timestamps per button

Renaming `last_peek_time` → `last_l_time` + `last_r_time`. A single variable would collide if both left and right clicks are ever queued in the same frame — unlikely today, but incorrect by design.

## Data Flow

```
ProcessMouseInterception() — every frame
    │
    ├── 1. Left-click intercept (passthrough=true, always active)
    │        │
    │        └── Peek WM_LBUTTONDOWN
    │             └── New msg? → GetCompactZone(wx - cv_x)
    │                  ├── "restore" → SwitchViewMode()
    │                  └── "content" → TogglePanel()
    │
    └── 2. Right-click intercept (passthrough=false, hover-activated)
             │
             ├── Cursor over bar? → last_hover_time = now
             │    └── Intercept inactive? → JS_WindowMessage_Intercept(hwnd, "WM_RBUTTONDOWN", false)
             │
             ├── Cursor NOT over bar AND intercept active
             │    └── (now - last_hover_time) > 50ms? → JS_WindowMessage_Release(hwnd, "WM_RBUTTONDOWN")
             │
             └── Peek WM_RBUTTONDOWN (only if intercept active)
                  └── New msg? → GetCompactZone(wx - cv_x)
                       ├── "restore" → SwitchViewMode()
                       └── "content" → ShowContextMenu()
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/compact.lua` | Modify | Add state vars, `GetCompactZone`, rewrite `ProcessMouseInterception`, update `Cleanup` |

## Interfaces / Contracts

```lua
-- NEW local state (replaces intercept_active, last_peek_time)
local intercept_active_l = false    -- WM_LBUTTONDOWN registered
local intercept_active_r = false    -- WM_RBUTTONDOWN registered
local last_l_time = 0               -- last left-click timestamp
local last_r_time = 0               -- last right-click timestamp
local last_hover_time = 0           -- ms timestamp of last hover (reaper.time_precise)
local HOVER_DEBOUNCE_MS = 50

-- NEW helper
-- rel_x = wx - cv_x (0 at bitmap left edge)
-- Returns "restore", "content", or nil
local function GetCompactZone(rel_x)
    if rel_x >= restore_btn_x and rel_x <= restore_btn_x + RESTORE_BTN_SIZE + 5 then
        return "restore"
    elseif rel_x >= 0 and rel_x < restore_btn_x then
        return "content"
    end
    return nil
end
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `GetCompactZone` boundary conditions | Extract to testable module or manual logging: verify restore_btn_x=100 returns correct zones at x=99,100,112,117,0,-1 |
| Manual | Right-click on bar → context menu | Visual: transport context menu MUST NOT appear |
| Manual | Right-click on restore button → SwitchViewMode | Visual: switches to full view |
| Manual | Right-click outside bar → REAPER transport menu | Visual: normal transport right-click menu appears |
| Manual | Hover in/out edge rapidly → no flicker | Visual: no rapid register/release cycles (check with reaper.ShowConsoleMsg logging) |

No automated test infrastructure exists for REAPER GUI code. Acceptance criteria from the spec must be verified manually.

## Migration / Rollout

No migration required. The change is purely additive in a single file, no data or config migration needed. Rollback: revert `compact.lua` changes.

## Open Questions

- [ ] None — spec, proposal, and codebase analysis cover the design space completely.
