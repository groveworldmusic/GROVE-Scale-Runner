-- Tests for state.preset-store: Init, getter/setter round-trips,
-- ClearBrowserState, edge cases (clamping, nil guards)
-- Scenarios PS1-PS5 per spec

local check = require("tests.helpers").check
local preset_store = require("state.preset-store")

io.write("=== preset-store ===\n")

-- ============================================================
-- PS2: Init({}) defaults match module initial state
-- ============================================================
io.write("-- PS2: Init defaults\n")
preset_store.Init({})
check(preset_store.GetCurrentDirectory() == "", "PS2: current_directory default ''")
check(preset_store.GetPresetRoot() == "", "PS2: preset_root default ''")
check(type(preset_store.GetPresetTree()) == "table", "PS2: preset_tree default table")
check(type(preset_store.GetPresetFiles()) == "table", "PS2: preset_files default table")
check(preset_store.GetSelectedPresetIdx() == nil, "PS2: selected_preset_idx default nil")
check(preset_store.GetBrowserScroll() == 0, "PS2: browser_scroll default 0")
check(preset_store.GetBrowserError() == nil, "PS2: browser_error default nil")
check(type(preset_store.GetFavorites()) == "table", "PS2: favorites default table")
check(type(preset_store.GetBookmarks()) == "table", "PS2: bookmarks default table")

-- ============================================================
-- PS3: Init applies provided defaults for current_directory and preset_root
-- ============================================================
io.write("-- PS3: Init with provided defaults\n")
preset_store.Init({ current_directory = "/presets", preset_root = "/root" })
check(preset_store.GetCurrentDirectory() == "/presets", "PS3: current_directory from Init")
check(preset_store.GetPresetRoot() == "/root", "PS3: preset_root from Init")
check(preset_store.GetBrowserScroll() == 0, "PS3: unprovided browser_scroll stays default 0")

-- ============================================================
-- PS1: 9 field round-trips
-- ============================================================
io.write("-- PS1: round-trips\n")

-- CurrentDirectory
preset_store.SetCurrentDirectory("/jazz")
check(preset_store.GetCurrentDirectory() == "/jazz", "PS1: CurrentDirectory round-trip")

-- PresetRoot
preset_store.SetPresetRoot("/my-presets")
check(preset_store.GetPresetRoot() == "/my-presets", "PS1: PresetRoot round-trip")

-- PresetTree
preset_store.SetPresetTree({ dir1 = {}, dir2 = {}, sub = { nested = true } })
local tree = preset_store.GetPresetTree()
check(tree.dir1 ~= nil, "PS1: PresetTree round-trip dir1")
check(tree.sub.nested == true, "PS1: PresetTree round-trip nested value")

-- PresetFiles
preset_store.SetPresetFiles({ "song1.grv", "song2.grv", "song3.grv" })
check(#preset_store.GetPresetFiles() == 3, "PS1: PresetFiles round-trip 3 entries")

-- SelectedPresetIdx (nil and number)
preset_store.SetSelectedPresetIdx(4)
check(preset_store.GetSelectedPresetIdx() == 4, "PS1: SelectedPresetIdx round-trip 4")
preset_store.SetSelectedPresetIdx(nil)
check(preset_store.GetSelectedPresetIdx() == nil, "PS1: SelectedPresetIdx round-trip nil")

-- BrowserScroll
preset_store.SetBrowserScroll(15)
check(preset_store.GetBrowserScroll() == 15, "PS1: BrowserScroll round-trip 15")

-- BrowserError
preset_store.SetBrowserError("test error")
check(preset_store.GetBrowserError() == "test error", "PS1: BrowserError round-trip string")
preset_store.SetBrowserError(nil)
check(preset_store.GetBrowserError() == nil, "PS1: BrowserError round-trip nil")

-- Favorites
preset_store.SetFavorites({ "jazz", "blues" })
check(#preset_store.GetFavorites() == 2, "PS1: Favorites round-trip 2 entries")

-- Bookmarks
preset_store.SetBookmarks({ "/root" })
check(#preset_store.GetBookmarks() == 1, "PS1: Bookmarks round-trip 1 entry")

-- ============================================================
-- PS4: ClearBrowserState resets browser fields, preserves others
-- ============================================================
io.write("-- PS4: ClearBrowserState\n")
-- Set distinct values for all fields
preset_store.SetCurrentDirectory("/temp")
preset_store.SetPresetTree({ temp = {} })
preset_store.SetPresetFiles({ "temp.grv" })
preset_store.SetSelectedPresetIdx(5)
preset_store.SetBrowserScroll(10)
preset_store.SetBrowserError("some error")
-- Non-browser fields (should survive ClearBrowserState)
preset_store.SetPresetRoot("/keep-me")
preset_store.SetFavorites({ "fav1" })
preset_store.SetBookmarks({ "bm1" })

preset_store.ClearBrowserState()

-- Reset browser fields
check(preset_store.GetCurrentDirectory() == "", "PS4: ClearBrowserState resets current_directory")
check(#preset_store.GetPresetTree() == 0, "PS4: ClearBrowserState resets preset_tree to {}")
check(#preset_store.GetPresetFiles() == 0, "PS4: ClearBrowserState resets preset_files to {}")
check(preset_store.GetSelectedPresetIdx() == nil, "PS4: ClearBrowserState resets selected_preset_idx")
check(preset_store.GetBrowserScroll() == 0, "PS4: ClearBrowserState resets browser_scroll")
check(preset_store.GetBrowserError() == nil, "PS4: ClearBrowserState resets browser_error")

-- Preserved fields
check(preset_store.GetPresetRoot() == "/keep-me", "PS4: ClearBrowserState preserves preset_root")
check(#preset_store.GetFavorites() == 1, "PS4: ClearBrowserState preserves favorites")
check(#preset_store.GetBookmarks() == 1, "PS4: ClearBrowserState preserves bookmarks")

-- ============================================================
-- PS5: SetBrowserScroll clamps negative to 0
-- ============================================================
io.write("-- PS5: BrowserScroll clamping + edge cases\n")
preset_store.SetBrowserScroll(-5)
check(preset_store.GetBrowserScroll() == 0, "PS5: SetBrowserScroll clamps -5 to 0")
preset_store.SetBrowserScroll(3)
check(preset_store.GetBrowserScroll() == 3, "PS5: SetBrowserScroll positive passes through")
preset_store.SetBrowserScroll(0)
check(preset_store.GetBrowserScroll() == 0, "PS5: SetBrowserScroll zero passes through")

-- Edge cases: nil guards
preset_store.SetCurrentDirectory(nil)
check(preset_store.GetCurrentDirectory() == "", "SetCurrentDirectory(nil) -> ''")

preset_store.SetPresetTree(nil)
check(type(preset_store.GetPresetTree()) == "table", "SetPresetTree(nil) -> table")
check(#preset_store.GetPresetTree() == 0, "SetPresetTree(nil) -> {}")
