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
    selected_indices = {},
    _last_selected_idx = nil,
    browser_scroll = 0,
    folder_scroll = 0,
    browser_error = nil,
    favorites = {},
    bookmarks = {},
    preset_stats = {},
    _stats_dirty = false,
    _editing_metadata = {},  -- {bpm=120, genre="", difficulty=1, tags="", notes=""}
    _thumbnail_cache = {},  -- keyed by path: {grid=table[8][8] of bool}
    search_query = "",
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

-- Multi-select API: selected_indices is a sparse table {[idx] = true} for O(1) membership
function m.GetSelectedIndices() return state.selected_indices end
function m.SetSelectedIndices(t)
    state.selected_indices = t or {}
    -- Update _last_selected_idx from the new set
    local max_idx = 0
    for idx in pairs(state.selected_indices) do
        if idx > max_idx then max_idx = idx end
    end
    state._last_selected_idx = max_idx > 0 and max_idx or nil
end
function m.ClearSelection()
    state.selected_indices = {}
    state._last_selected_idx = nil
end
function m.IsPresetSelected(idx) return state.selected_indices[idx] == true end
function m.TogglePresetSelected(idx)
    if state.selected_indices[idx] then
        state.selected_indices[idx] = nil
    else
        state.selected_indices[idx] = true
        state._last_selected_idx = idx
    end
end
function m.GetPrimarySelectedIndex() return state._last_selected_idx end
function m.GetSelectionCount()
    local count = 0
    for _ in pairs(state.selected_indices) do count = count + 1 end
    return count
end
function m.RemoveSelectionFixup(removed_idx)
    local new_set = {}
    for idx in pairs(state.selected_indices) do
        if idx < removed_idx then
            new_set[idx] = true
        elseif idx > removed_idx then
            new_set[idx - 1] = true
        end
    end
    state.selected_indices = new_set
end

-- Backward-compat shims (used by external code: main.lua, io.lua, monolith)
function m.GetSelectedPresetIdx()
    local max = 0
    for idx in pairs(state.selected_indices) do
        if idx > max then max = idx end
    end
    return max > 0 and max or nil
end
function m.SetSelectedPresetIdx(v)
    if v then
        state.selected_indices = {[v] = true}
        state._last_selected_idx = v
    else
        state.selected_indices = {}
        state._last_selected_idx = nil
    end
end

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

-- Stats
function m.GetPresetStats() return state.preset_stats end
function m.SetPresetStats(t) state.preset_stats = t or {} end
function m.GetPresetStat(path) return state.preset_stats[path] end
function m.IncrementPresetLoadCount(path)
    state.preset_stats[path] = state.preset_stats[path] or {load_count=0, last_loaded=0, last_modified=0}
    state.preset_stats[path].load_count = state.preset_stats[path].load_count + 1
    state.preset_stats[path].last_loaded = os.time()
    m.MarkStatsDirty()
end
function m.MarkStatsDirty() state._stats_dirty = true end
function m.IsStatsDirty() local d = state._stats_dirty; state._stats_dirty = false; return d end
function m.SaveStats()
    local stats = state.preset_stats
    local parts = {}
    for path, data in pairs(stats) do
        table.insert(parts, string.format("[%q] = {load_count=%d,last_loaded=%d,last_modified=%d}",
            path, data.load_count or 0, data.last_loaded or 0, data.last_modified or 0))
    end
    local str = "{" .. table.concat(parts, ",") .. "}"
    pcall(reaper.SetExtState, "GROVE_Scale_Runner", "preset_stats", str, true)
end
function m.LoadStats()
    local ok, str = pcall(reaper.GetExtState, "GROVE_Scale_Runner", "preset_stats")
    if not ok or not str or #str == 0 then return end
    local fn, err = load("return " .. str)
    if fn then
        local ok2, result = pcall(fn)
        if ok2 and type(result) == "table" then
            state.preset_stats = result
        end
    end
end

-- Editing metadata (for metadata dialog)
function m.GetEditingMetadata() return state._editing_metadata end
function m.SetEditingMetadata(t) state._editing_metadata = t or {} end

-- Thumbnail cache
function m.GetThumbnail(path) return state._thumbnail_cache[path] end
function m.SetThumbnail(path, grid) state._thumbnail_cache[path] = grid end
function m.ClearThumbnailCache() state._thumbnail_cache = {} end

-- Search query (for live search in preset browser)
function m.GetSearchQuery() return state.search_query end
function m.SetSearchQuery(v) state.search_query = v or "" end
function m.ClearSearchQuery() state.search_query = "" end

-- Clear all browser state to defaults
function m.ClearBrowserState()
    state.current_directory = ""
    state.preset_tree = {}
    state.preset_files = {}
    state.selected_indices = {}
    state._last_selected_idx = nil
    state.browser_scroll = 0
    state.browser_error = nil
    state.search_query = ""
end

return m
