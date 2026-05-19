-- Tests for midi.ToggleIsland() — docked early return, expand/collapse, gfx lifecycle
-- Requires mock reaper.* and gfx.* globals installed by run.lua
-- NOTE: midi_island_expanded/toggled state migrated to island_store (PR: midi-island-critical-fixes)

package.loaded["core.midi"] = nil
package.loaded["state.island"] = nil

local config = require("config")
local compact_store = require("state.compact")
local ui_store = require("state.ui")
local island_store = require("state.island")
local helpers = require("tests.helpers")
local check = helpers.check

io.write("=== ToggleIsland Tests ===\n")

-- ================================================================
-- Setup: init stores, set up gfx tracking
-- ================================================================

-- Init compact_store with last_gfx_state for position restoration
compact_store.Init({
    compact = {},
    compact_overlay_active = false,
    last_gfx_state = { dock = 0, x = 100, y = 200, w = 720, h = 497 },
})

-- Init island_store with known expand/toggle state
island_store.Init({
    midi_island_expanded = false,
    midi_island_toggled = false,
})

-- Init ui_store for GetDockedMode()
local ui_init = {
    view_mode = 1, show_tooltips = false, color_mode = "grade",
    use_scroll = true, last_mouse_cap = 0, slider_dragging = false,
    docked_mode = false, dock_id = 0,
    auto_start_compact = false, auto_start_reaper = false,
    did_cleanup = false, mouse_click = false, mouse_wheel_delta = 0,
    pad_flash = { degree = -1, timer = 0, prev_active = {} },
}
ui_store.Init(ui_init)

-- Now the midi module can be loaded (its deps are satisfiable)
local midi = require("core.midi")

-- Set up gfx call tracking (override mock no-ops)
local init_count = 0
local init_args = nil
local quit_count = 0
local setfont_count = 0

_G.gfx.init = function(...)
    init_count = init_count + 1
    init_args = { ... }
end
_G.gfx.quit = function()
    quit_count = quit_count + 1
end
_G.gfx.setfont = function(...)
    setfont_count = setfont_count + 1
end
-- gfx.dock(-1) remains as mock (returns 0 = undocked)
-- Ensure gfx.hwnd is nil so JS_Window_GetRect path is skipped
-- (previous test files may have left it non-nil)
gfx.hwnd = nil

-- Force known island_store state
island_store.SetMidiIslandExpanded(false)
island_store.SetMidiIslandToggled(false)

-- ================================================================
-- Scenario 1: Docked mode → early return, no gfx calls
-- ================================================================
io.write("\n-- Docked: early return\n")

ui_store.SetDockedMode(true)

init_count = 0; quit_count = 0; setfont_count = 0
midi.ToggleIsland()
check(quit_count == 0, "Docked: gfx.quit not called")
check(init_count == 0, "Docked: gfx.init not called")
check(setfont_count == 0, "Docked: gfx.setfont not called")
check(island_store.GetMidiIslandExpanded() == false, "Docked: flag unchanged")
check(island_store.GetMidiIslandToggled() == false, "Docked: toggled flag unchanged (early return)")

ui_store.SetDockedMode(false)

-- ================================================================
-- Scenario 2: Collapsed → expanded (nil/not → true)
-- ================================================================
io.write("\n-- Collapsed → Expanded\n")

-- midi_island_expanded starts as false (fresh store + explicit reset)
-- When toggled: not false → true → new_h = 793

init_count = 0; quit_count = 0; setfont_count = 0
island_store.SetMidiIslandToggled(false)  -- reset for fresh assertion
midi.ToggleIsland()

check(quit_count == 1, "Expand: gfx.quit called")
check(init_count == 1, "Expand: gfx.init called")
check(init_args[3] == 793, "Expand: height = 793, got " .. tostring(init_args[3]))
check(setfont_count == 1, "Expand: gfx.setfont called")
check(island_store.GetMidiIslandExpanded() == true, "Expand: flag = true")
check(island_store.GetMidiIslandToggled() == true, "Expand: toggled flag = true")

-- Verify other gfx.init args
check(init_args[1] == config.script_title, "Expand: title = '" .. config.script_title .. "'")
check(init_args[2] == 720, "Expand: width = 720, got " .. tostring(init_args[2]))
check(init_args[4] == 0, "Expand: dock = 0, got " .. tostring(init_args[4]))
-- x, y come from last_gfx_state (100, 200); no hwnd → no JS_Window_GetRect override
check(init_args[5] == 100, "Expand: x = 100, got " .. tostring(init_args[5]))
check(init_args[6] == 200, "Expand: y = 200, got " .. tostring(init_args[6]))

-- ================================================================
-- Scenario 3: Expanded → collapsed (true → not true → false)
-- ================================================================
io.write("\n-- Expanded → Collapsed\n")

-- midi_island_expanded is now true from scenario 2
-- When toggled: not true → false → new_h = 497

init_count = 0; quit_count = 0; setfont_count = 0
island_store.SetMidiIslandToggled(false)  -- reset for fresh assertion
midi.ToggleIsland()

check(quit_count == 1, "Collapse: gfx.quit called")
check(init_count == 1, "Collapse: gfx.init called")
check(init_args[3] == 497, "Collapse: height = 497, got " .. tostring(init_args[3]))
check(setfont_count == 1, "Collapse: gfx.setfont called")
check(island_store.GetMidiIslandExpanded() == false, "Collapse: flag = false")
check(island_store.GetMidiIslandToggled() == true, "Collapse: toggled flag = true")
