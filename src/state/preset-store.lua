-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Preset Browser State Store
-- Encapsulates preset browser state with getters/setters.
-- Extracted from island.lua (PR 2 of critical-areas-refactor).

local m = {}

local state = {
    current_directory = "",
    preset_root = "",
    preset_tree = {},
    preset_files = {},
    selected_preset_idx = nil,
    browser_scroll = 0,
    folder_scroll = 0,
    browser_error = nil,
    favorites = {},
    bookmarks = {},
}

function m.Init(defaults)
    if defaults.current_directory ~= nil then state.current_directory = defaults.current_directory end
    if defaults.preset_root ~= nil then state.preset_root = defaults.preset_root end
end

-- Current directory
function m.GetCurrentDirectory() return state.current_directory end
function m.SetCurrentDirectory(v) state.current_directory = v or "" end

-- Preset root directory
function m.GetPresetRoot() return state.preset_root end
function m.SetPresetRoot(v) state.preset_root = v or "" end

-- Preset tree (dir structure)
function m.GetPresetTree() return state.preset_tree end
function m.SetPresetTree(t) state.preset_tree = t or {} end

-- Preset files list
function m.GetPresetFiles() return state.preset_files end
function m.SetPresetFiles(t) state.preset_files = t or {} end

-- Selected preset index
function m.GetSelectedPresetIdx() return state.selected_preset_idx end
function m.SetSelectedPresetIdx(v) state.selected_preset_idx = v end

-- Browser scroll offset
function m.GetBrowserScroll() return state.browser_scroll end
function m.SetBrowserScroll(v) state.browser_scroll = math.max(0, v or 0) end

-- Folder scroll offset (for preset browser folder navigation)
function m.GetFolderScroll() return state.folder_scroll end
function m.SetFolderScroll(v) state.folder_scroll = math.max(0, v or 0) end

-- Browser error message
function m.GetBrowserError() return state.browser_error end
function m.SetBrowserError(v) state.browser_error = v end

-- Favorites
function m.GetFavorites() return state.favorites end
function m.SetFavorites(t) state.favorites = t or {} end

-- Bookmarks
function m.GetBookmarks() return state.bookmarks end
function m.SetBookmarks(t) state.bookmarks = t or {} end

-- Clear all browser state to defaults
function m.ClearBrowserState()
    state.current_directory = ""
    state.preset_tree = {}
    state.preset_files = {}
    state.selected_preset_idx = nil
    state.browser_scroll = 0
    state.browser_error = nil
end

return m
