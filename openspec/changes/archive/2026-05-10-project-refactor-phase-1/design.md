# Design: Project Refactor — Phase 1

## Technical Approach

4 sequential extractions, each as a separate commit, moving pure-functional and domain logic out of monolithic files into dedicated modules. Every extraction preserves exact function bodies — no behavioral changes.

## Architecture Decisions

### Decision: Coordinate system → `ui/layout.lua` with named canvas constants

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep UX/UY/US in views.lua | Monolithic file stays monolithic | Rejected |
| Extract to `ui/layout.lua` | Zero deps, pure functions, named constants replace magic numbers | **Chosen** |

`CANVAS_W = 39914` and `CANVAS_H = 29162` extracted from inline magic numbers in DrawFullView/DrawIslands. Views currently has ~90 UX/UY/US calls — all in `views.lua` only, so no cascade.

### Decision: Keyboard functions exported as module table from `core/keyboard.lua`

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep in main.lua | main.lua is 319 lines and growing | Rejected |
| Extract to `core/keyboard.lua` | `is_intercepting` encapsulated; needs cleanup helper | **Chosen** |

`is_intercepting` + `last_focus_check` + `temp_ctx` move as module-level closures. A `keyboard.Cleanup()` method wraps the `is_intercepting` check + `InterceptMappedKeys(false)` for main.lua's CleanupAll.

### Decision: MIDI state lives in `core/midi.lua` return table

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep in config.state | config.lua accumulates unrelated state | Rejected |
| Module-level fields on midi table | views.lua/main.lua access via `midi.midi_channel`; one import | **Chosen** |

3 fields move: `midi.island_expanded`,`midi.midi_channel`,`midi.island_toggled`. `config.state.last_gfx_state` stays — it's also used by compact.lua and isn't MIDI-specific.

### Decision: ToggleMIDIIsland → `core/midi.lua` method

Moves with current body — reads `config.state.docked_mode` + `config.state.last_gfx_state` (still in config) and writes to `midi.island_expanded` + `midi.island_toggled`.

## Data Flow

```
Before:
  config.state.midi_*   ← views.lua / midi.lua / main.lua
  views.lua UX/UY/US     ← (internal only)
  main.lua keyboard      ← (internal only)

After:
  midi.midi_*            ← views.lua / midi.lua / main.lua (via midi require)
  layout.UX/UY/US        ← views.lua (via layout require)
  keyboard.*             ← main.lua (via keyboard require)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/layout.lua` | **Create** | SetScale, UX, UY, US, CANVAS_W, CANVAS_H |
| `src/core/keyboard.lua` | **Create** | HandleKeyboard, InterceptMappedKeys, IsPluginOrScriptFocused, CheckFocus, Cleanup |
| `src/core/midi.lua` | Modify | Add ToggleMIDIIsland() + 3 state fields (island_expanded, channel, island_toggled) |
| `src/ui/views.lua` | Modify | Remove lines 14-26 (coords), 29-46 (ToggleMIDIIsland), update ~94 refs to use layout.\* and midi.\* |
| `src/main.lua` | Modify | Remove keyboard functions + local vars, add keyboard require, replace ~8 calls |
| `src/config.lua` | Modify | Remove 3 MIDI state fields from config.state table |

No changes to `components.lua` or `compact.lua` — neither file references the moving functions/fields.

## Interfaces / Contracts

```lua
-- ui/layout.lua
local layout = {}
layout.CANVAS_W = 39914
layout.CANVAS_H = 29162
function layout.UX(v) end
function layout.UY(v) end
function layout.US(v) end
function layout.SetScale(s, ox, oy) end
return layout

-- core/keyboard.lua
local keyboard = {}
function keyboard.HandleKeyboard() end
function keyboard.InterceptMappedKeys(state) end
function keyboard.IsPluginOrScriptFocused() end
function keyboard.CheckFocus() end
function keyboard.Cleanup() end  -- wraps InterceptMappedKeys(false) if intercepting
return keyboard

-- core/midi.lua additions
midi.midi_island_expanded = false  -- was config.state.midi_island_expanded
midi.midi_channel = 1              -- was config.state.midi_channel
midi.midi_island_toggled = false   -- was config.state.midi_island_toggled
function midi.ToggleMIDIIsland() end
```

## Import Path Changes

| File | Removes | Adds |
|------|---------|------|
| `views.lua` | local UX/UY/US/SetScale | `local layout = require("ui.layout")` |
| `main.lua` | lines 37-40, 82-161 | `local keyboard = require("core.keyboard")` |

## Testing Strategy

Manual (no Lua test infra exists for REAPER GFX scripts):

- Run script after each extraction commit — verify no errors on load
- Toggle MIDI island expanded/collapsed → window resizes correctly
- Keyboard input → notes play, VKeys intercept toggles on focus
- All mode switches work (compact ↔ full, docked ↔ floating)

## Migration / Rollout

Each extraction is a separate commit — `git revert` undoes individual slices. Branch: `refactor/project-refactor-phase-1`.

## Open Questions

- None — spec, proposal, and codebase analysis cover all 4 slices completely.
