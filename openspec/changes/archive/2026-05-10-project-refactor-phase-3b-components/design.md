# Design: Project Refactor — Phase 3b (Piano, Pads, Slots, Drag)

## Technical Approach

Pure structural refactor: extract 4 widget groups from `components.lua` into dedicated modules, re-exported via barrel pattern (same as Phase 3a). Each module uses `local m = {}; return m`. `DrawRoundedRect` and `DrawIsland` stay in `components.lua` — extracted modules call them via `require("ui.components")` inside function bodies (lazy require, avoids circular deps at load time). Zero signature or behavior changes.

## Architecture Decisions

### Decision: Explicit barrel re-exports

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `pairs(m)` iteration | Silently exports module-internals — no API contract | ❌ |
| Explicit `m.fn = module.fn` | Visible intentional API surface | ✅ |

### Decision: PIANO_LAYOUT stays private to piano.lua

Grep-confirmed: zero external consumers. Becomes a module-level constant (not exported). Only `DrawPianoKeyboard` references it.

### Decision: DEGREE_KEY_LABELS moves to pads.lua

Sole consumer is `DrawScalePad`. No piano code references it. Grouping with its consumer avoids cross-module imports.

### Decision: slots.lua in src/core/ (not src/ui/)

Slots have bidirectional coupling with `core.progression` (render progression state AND mutate it via drag/drop/right-click-delete). Placing slots in `core/` avoids the circular dependency that would arise if `core/progression.lua` imported from `ui/`. Exception to the Phase 3a pattern — justified by the interaction-heavy nature of slots (they're not pure renderers like buttons/paginator).

## Data Flow

```
views.lua / compact.lua
  → require("ui.components") (unchanged barrel)
    → components.DrawPianoKeyboard → delegates to piano.lua
      → components.DrawRoundedRect (via lazy require)
      → helpers, theme, colors, config (direct require)
    → components.DrawScalePad → delegates to pads.lua
      → components.DrawRoundedRect (via lazy require)
      → helpers, theme, colors, format, midi, config (direct require)
    → components.DrawProgressionSlot → delegates to slots.lua (core/)
      → DrawSlotBackground, DrawSlotLabel, HandleSlotInteraction (local)
      → components.DrawRoundedRect (via lazy require)
      → helpers, theme, colors, format, midi, progression, config (direct require)
    → components.DrawDragPreview → delegates to drag.lua
      → components.DrawRoundedRect (via lazy require)
      → helpers, theme, colors, format, config (direct require)
```

Cross-module state flows through `config.state.drag.*` (same as current) — no import dependency between slots and drag.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/piano.lua` | **Create** (PR 3b-a) | `PIANO_LAYOUT`, `cached_*` vars, `DrawPianoKeyboard` (~124 LOC) |
| `src/ui/pads.lua` | **Create** (PR 3b-a) | `DEGREE_KEY_LABELS`, `DrawScalePad` (~114 LOC) |
| `src/core/slots.lua` | **Create** (PR 3b-b) | `DrawSlotBackground`, `DrawSlotLabel`, `HandleSlotInteraction`, `DrawProgressionSlot` (~170 LOC) |
| `src/ui/drag.lua` | **Create** (PR 3b-b) | `DrawDragPreview` (~87 LOC) |
| `src/ui/components.lua` | Modify (PR 3b-a + 3b-b) | Remove ~524 lines, add 4 requires + 4 barrel re-exports |
| `src/main.lua` | Modify (PR 3b-a + 3b-b) | Add 4 files to `@provides` section |

## Interfaces / Contracts

All signatures preserved verbatim. No changes:

```lua
-- src/ui/piano.lua
function DrawPianoKeyboard(x, y, w, h, font_size) → nil

-- src/ui/pads.lua
function DrawScalePad(x, y, w, h, degree, main_font_size, sub_font_size, total_degrees) → nil

-- src/core/slots.lua (module-private helpers + 1 public)
-- (private:) DrawSlotBackground(global_idx, x, y, w, h, slot, play, seq) → nil
-- (private:) DrawSlotLabel(global_idx, x, y, w, h, slot) → nil
-- (private:) HandleSlotInteraction(global_idx, x, y, w, h, slot, hover) → nil
function DrawProgressionSlot(global_idx, x, y, w, h) → nil

-- src/ui/drag.lua
function DrawDragPreview(w, h) → nil
```

### Module internals moved (no external access change)

- `PIANO_LAYOUT` table → module-level in piano.lua (not exported)
- `cached_scale_root`, `cached_scale_idx`, `cached_scale_notes`, `cached_note_to_degree` → module-level upvalues in piano.lua
- `DEGREE_KEY_LABELS` → module-level in pads.lua (not exported)
- `DrawSlotBackground`, `DrawSlotLabel`, `HandleSlotInteraction` → module-local functions in slots.lua (not exported)

### Dependencies per module

| Module | Requires | Lazy requires |
|--------|----------|---------------|
| piano.lua | `config`, `helpers`, `theme`, `colors` | `components` (for DrawRoundedRect) |
| pads.lua | `config`, `helpers`, `theme`, `colors`, `format`, `midi` | `components` |
| slots.lua | `config`, `helpers`, `theme`, `colors`, `format`, `midi`, `progression` | `components` |
| drag.lua | `config`, `helpers`, `theme`, `colors`, `format` | `components` |

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Static | No syntax errors | `luac -p` or manual review |
| Load | No "attempt to call nil" errors | REAPER script startup |
| Visual | 4 widget groups render identically | Side-by-side git snapshot vs after |
| Interaction | Click, hover, drag, drop all preserved | Per spec verification scenarios |

No test runner available — verification is manual REAPER testing + code review per spec's 12 scenarios.

## Migration / Rollout

2 chained PRs (same split strategy as proposal):

- **PR 3b-a**: `piano.lua` + `pads.lua` — modify `components.lua` (remove piano/pads, add barrel) + `main.lua` @provides
- **PR 3b-b**: `slots.lua` + `drag.lua` — modify `components.lua` (remove slots/drag, add barrel) + `main.lua` @provides

Each PR is a single commit. Rollback per PR: delete new files + `git checkout` the modified ones.

## Open Questions

None. All decisions resolved from Phase 3a precedent + grep-verified usage patterns.
