# Tasks: Project Refactor — Phase 1

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~192 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single feature branch, 4 sequential commits |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: feature-branch-chain
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Extract layout system | PR 1 (single) | Create `ui/layout.lua`, update `views.lua` imports |
| 2 | Extract keyboard handling | PR 1 | Create `core/keyboard.lua`, update `main.lua` imports |
| 3 | Move MIDI state | PR 1 | Relocate 3 fields from `config.state` to `core/midi.lua` |
| 4 | Move ToggleMIDIIsland | PR 1 | Relocate function to `core/midi.lua` as `midi.ToggleIsland()` |

## Phase 1: Extract Layout System (Commit 1)

- [x] 1.1 Create `src/ui/layout.lua` — export table with `SetScale`, `UX(v)`, `UY(v)`, `US(v)`, `CANVAS_W = 39914`, `CANVAS_H = 29162`
- [x] 1.2 In `src/ui/views.lua`: remove local UX/UY/US/SetScale definitions, add `local layout = require("ui.layout")`, replace all `UX/UY/US/SetScale` calls with `layout.*` prefix
- [x] 1.3 Verify: script loads without error, all views draw at correct coordinates

## Phase 2: Extract Keyboard Handling (Commit 2)

- [x] 2.1 Create `src/core/keyboard.lua` — export table with `HandleKeyboard`, `InterceptMappedKeys`, `IsPluginOrScriptFocused`, `CheckFocus`, `Cleanup()`; encapsulate `is_intercepting`, `last_focus_check`, `temp_ctx` as module-level closures
- [x] 2.2 In `src/main.lua`: remove the 4 function definitions + their local vars (lines ~37-40, ~82-161), add `local keyboard = require("core.keyboard")`, replace call sites with `keyboard.*` prefix; replace CleanupAll's `InterceptMappedKeys` check with `keyboard.Cleanup()`
- [x] 2.3 Verify: script loads without error, keyboard input works, VKeys intercept toggles on focus

## Phase 3: Move MIDI State (Commit 3)

- [x] 3.1 In `src/core/midi.lua`: add 3 module-level fields to return table — `midi_island_expanded = false`, `midi_channel = 1`, `midi_island_toggled = false`
- [x] 3.2 In `src/config.lua`: remove `midi_island_expanded`, `midi_channel`, `midi_island_toggled` from `config.state`
- [x] 3.3 Update all references: replace `config.state.midi_island_expanded` → `midi.midi_island_expanded`, `config.state.midi_channel` → `midi.midi_channel`, `config.state.midi_island_toggled` → `midi.midi_island_toggled` across `views.lua`, `main.lua`, `compact.lua`
- [x] 3.4 Verify: script loads, MIDI channel selector works, island toggle doesn't error

## Phase 4: Move ToggleMIDIIsland (Commit 4)

- [x] 4.1 In `src/core/midi.lua`: add `ToggleIsland()` function with exact body from `views.lua`'s `ToggleMIDIIsland` — reads `config.state.docked_mode`, `config.state.last_gfx_state`, writes to `midi.island_expanded` + `midi.island_toggled`
- [x] 4.2 In `src/ui/views.lua`: remove `ToggleMIDIIsland` function definition, replace call site with `midi.ToggleIsland()`
- [x] 4.3 Verify: script loads, island toggle toggles correctly in both docked/floating modes
