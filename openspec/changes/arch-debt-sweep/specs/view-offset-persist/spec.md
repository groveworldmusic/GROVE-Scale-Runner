# Delta for Position — Window View Offset Persistence

## Context

`src/main.lua` captures the REAPER window screen position via `JS_Window_GetRect(gfx.wnd)` each frame
(lines 360–366) and stores it in `ui_store.view_offset_x/y`. A subsequent gfx-safety call
(`gfx_safe.RecreateMainWindow`) reads those store values to restore position when the window is
recreated for size enforcement or island toggle.

Window dimensions (`window_w`, `window_h`) already persist to ExtState via the `persist.Save`
dirty-flag pattern (lines 334–341). The offset counterpart currently lives only in volatile store
memory — on REAPER restart it re-initialises from `config.state.view_offset_x/y` defaults, losing
the user's preferred placement.

This change adds the same persistence pattern for the X and Y offset values, mirroring the
dimension path exactly: compare current store value against last-saved store value on each frame;
write only on change. No callers require any modification.

## ADDED Requirements

### Requirement: Window Position X Persistence to ExtState

`ui_store.view_offset_x` SHALL be written to ExtState (key `"view_offset_x"`) every frame via
`persist.Save`, using the same dirty-flag pattern as `window_w`/`window_h`.

#### Scenario: Position X persisted when window moves

- GIVEN `ui_store.SetLastSavedX(vx)` was called for the last-saved value (initially `nil`)
- AND `ui_store.GetViewOffsetX()` returns the current window left edge captured this frame
- WHEN the current value is a number AND differs from the last-saved value
- THEN `persist.Save("view_offset_x", current_vx)` SHALL be called synchronously
- AND `ui_store.SetLastSavedX(current_vx)` SHALL update the sentinel

#### Scenario: No redundant write when position unchanged

- GIVEN the last-saved X value equals the current captured value
- WHEN the dirty-flag check runs this frame
- THEN `persist.Save` SHALL NOT be called
- AND `reaper.SetExtState` SHALL NOT be invoked

#### Scenario: Last-saved sentinel initialises on first frame

- GIVEN the script has just started and no position has been saved yet
- WHEN the first frame captures a valid numeric window position
- THEN the sentinel initialises to the captured value
- AND `persist.Save` records the position to ExtState

#### Scenario: Invalid screen rect values are not persisted

- GIVEN `JS_Window_GetRect` returns non-numeric coordinates (stale booleans or out-of-range)
- WHEN the validity check fails (`type(l) ~= "number"` or range guard fails)
- THEN `persist.Save` SHALL NOT be called
- AND the last-saved sentinel SHALL NOT be updated

### Requirement: Window Position Y Persistence to ExtState

`ui_store.view_offset_y` SHALL be written to ExtState (key `"view_offset_y"`) via the same
dirty-flag path as requirement X, triggered at the same frame iteration.

#### Scenario: Position Y persisted alongside X on first move

- GIVEN the window has moved vertically since last launch
- WHEN the frame Y-capture completes
- THEN `persist.Save("view_offset_y", current_vy)` SHALL be called
- AND `persist.Save("view_offset_x", current_vx)` SHALL also be called (both axes saved together)

### Requirement: Position Restored on Script Restart

On script restart, `persist.Load` reads ExtState and overlays `config.state.view_offset_x/y`.
`gfx.init()` uses these values as the window starting position. This flow SHALL NOT change.

#### Scenario: Window opens at previously saved position after restart

- GIVEN the window was at screen position (x=300, y=200) before REAPER shutdown
- AND ExtState keys `view_offset_x=300`, `view_offset_y=200` are present
- WHEN `persist.Load(config.state)` overlays `config.state.view_offset_x/y`
- AND `gfx.init("GROVE SCALE RUNNER", 720, 497, 0, 300, 200)` is called
- THEN the window SHALL appear at approximately (300, 200) on screen

## Non-Goals

- This spec does not change the `config.state.view_offset_x/y` getters/setters or any store API.
- This spec does not modify the window size enforcement dimension path.
- This spec does not cover automatic window repositioning on multi-monitor changes.
- This spec does not add new state keys; it controls when existing keys are flushed to ExtState.

## Incompatibilities

None. `persist.Save` already writes to ExtState; this spec extends its call sites. Existing
ExtState consumers continue to read the same keys with the same schema.

## Dependencies

- Architecture debt sweep presets-browser-barrel — independent, no prerequisite

## Relevant Files

- `src/main.lua` — lines 333–366: dirty-flag pattern; dirty-flag X + Y added after line 364
- `src/state/persist.lua` — `Save(key, value)` writes via `reaper.SetExtState`
- `src/state/ui.lua` — `GetLastSavedX() / SetLastSavedX()` added to sentinel getters/setters
