# Design: Project Refactor — Phase 3a (Decompose Components)

## Technical Approach

Pure structural refactor: extract 3 independent widget groups from `components.lua` into standalone modules, re-exported via barrel pattern. Zero behavioral or signature changes. `DrawRoundedRect` stays in components as shared foundation — sub-modules access it via `require("ui.components")` (Lua returns the same table by reference, so
`components.DrawRoundedRect` is available at render time even though the table was partially populated during load).

## Architecture Decisions

### Decision 1: Keep ACTUAL function signatures (user-proposed sigs do not match)

The proposed APIs in the design request do NOT match current `components.lua`.

| Function | Proposed (from design request) | Actual (current code) |
|----------|-------------------------------|-----------------------|
| `DrawButton` | `(ctx, x, y, w, h, label, color, is_active, degree?)` | `(x, y, w, h, label, active, font_size)` |
| `DrawTransportButton` | `(ctx, x, y, w, h, label, is_active)` | `(label, x, y, w, h)` — label is FIRST |
| `DrawToolIcon` | `(ctx, x, y, w, h, icon, color)` | `(type, x, y, size, active)` — uses `size`, not `w/h` |
| `DrawNoteDisplay` | `(ctx, x, y, w, h, label)` | `(x, y, w, h, note)` — no ctx |
| `DrawPaginator` | `(ctx, x, y, w, h, total_pages, current_page, label)` | `(x, y, total_pages)` — reads `current_page` from config internally |
| `DrawDropdown` | `(ctx, x, y, w, h, items, selected_index)` | `(x, y, w, h, label, value, options, current_index, font_size, open_up)` |

**Choice**: Keep current signatures. This is a pure structural refactor — spec says "No function signature MAY change."
**Rationale**: Changing signatures would break all ~32 call sites across views.lua and compact.lua, contradicting the refactor's purpose.

### Decision 2: Explicit barrel delegation

```lua
-- components.lua (barrel)
local m = {}
m.DrawIsland = function(ctx, ...) end  -- kept inline
m.DrawRoundedRect = function(ctx, ...) end  -- kept inline
m.DrawButton = buttons.DrawButton
m.DrawTransportButton = buttons.DrawTransportButton
m.DrawToolIcon = buttons.DrawToolIcon
m.DrawNoteDisplay = buttons.DrawNoteDisplay
m.DrawPaginator = paginator.DrawPaginator
m.DrawDropdown = dropdown.DrawDropdown
return m
```

**Choice**: Explicit per-function delegation (option 2).
**Rationale**: `pairs` iteration (option 1) would silently re-export module-internal state like `inject()` or `draw_rounded_rect` upvalues. Explicit lines form a visible API contract — each export is intentional.

### Decision 3: Sub-modules import `components` for DrawRoundedRect

**Choice**: Each sub-module does `local components = require("ui.components")` inside the module body.
**Rationale**: Lua's `require` returns the same table by reference. At the time sub-modules are loaded, the components table exists (may be partially populated), and by render time `components.DrawRoundedRect` is fully defined. No circular dependency at call time. No injection boilerplate needed.

### Decision 4: `GetFitText` → module-local in dropdown.lua

**Choice**: The inline closure becomes a module-local function. No signature change.
**Rationale**: Grep-confirmed: zero external references. It's only called by `DrawDropdown`.

## Data Flow

Unchanged from current architecture. All functions read/write `config.state` directly and render via `gfx.*` context. The only difference is which file the bytecode lives in.

```
views.lua / compact.lua
    → require("ui.components")  (unchanged)
        → DrawButton / DrawToolIcon / etc.  (barrel delegates to buttons.lua, etc.)
            → components.DrawRoundedRect  (via shared table reference)
            → config.state / helpers / theme  (direct require)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/buttons.lua` | **Create** | DrawButton, DrawTransportButton, DrawToolIcon, DrawNoteDisplay (~156 LOC) |
| `src/ui/paginator.lua` | **Create** | DrawPaginator (~28 LOC) |
| `src/ui/dropdown.lua` | **Create** | DrawDropdown + module-local GetFitText (~65 LOC) |
| `src/ui/components.lua` | Modify | Remove ~249 lines, add 3 requires + ~10 barrel re-exports + DrawIsland stays inline |
| `src/main.lua` | Modify | Add 3 new files to `@provides` section |

## Interfaces / Contracts

All extracted signatures are verbatim from the current codebase — no changes:

```lua
-- src/ui/buttons.lua
function DrawButton(x, y, w, h, label, active, font_size) → bool
function DrawTransportButton(label, x, y, w, h) → bool
function DrawToolIcon(type, x, y, size, active) → bool
function DrawNoteDisplay(x, y, w, h, note) → nil

-- src/ui/paginator.lua
function DrawPaginator(x, y, total_pages) → nil

-- src/ui/dropdown.lua
function DrawDropdown(x, y, w, h, label, value, options, current_index, font_size, open_up) → int|nil
```

Internal deps per new module:
- All: `helpers`, `theme`, `components` (for DrawRoundedRect)
- `DrawDropdown` additionally needs `config` (scroll state)

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Static | No syntax errors in new files | `luac -p` (if available) or manual review |
| Integration | All consumers load without error | Run script in REAPER: no "attempt to call nil" errors |
| Visual | Buttons, paginator, dropdown render identically | Side-by-side comparison with git snapshot |
| Functional | Click/hover/scroll interactions preserved | Manual REAPER testing per spec verification checklist |

No test runner available — verification is manual REAPER testing + code review.

## Migration / Rollout

Single commit per extraction (4 commits total: buttons, paginator, dropdown, barrel cleanup). Atomic: rollback = checkout previous components.lua + delete 3 new files.

## Open Questions

- [ ] **BLOCKER**: Proposed signatures in the design request do NOT match current code (see Architecture Decision 1). Are the proposed APIs a future cleanup the user wants INCLUDED in this phase, or should the design proceed with the existing signatures as a pure refactor? **The spec says pure refactor — proceeding with current signatures.**

