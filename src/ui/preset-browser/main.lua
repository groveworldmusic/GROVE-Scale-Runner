-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Preset Browser — Main Composition Module
-- Coordinates the layout and drawing of the various preset browser components.

local theme = require("ui.theme")
local helpers = require("ui.helpers")
local ui_store = require("state.ui")
local preset_store = require("state.preset-store")

-- Sub-modules
local io_mod = require("ui.preset-browser.io")
local folder_mod = require("ui.preset-browser.folder")
local list_mod = require("ui.preset-browser.preset-list")

local m = {}

-- Error banner constants
local ERROR_BG = {0.9, 0.3, 0.3, 0.8}
local ERROR_TEXT = {1, 1, 1, 0.9}
local ERROR_H = 24

-- Search bar constants
local SEARCH_BG = {0.18, 0.18, 0.18, 0.9}
local SEARCH_TEXT = {0.8, 0.8, 0.8, 0.9}
local SEARCH_H = 22

-- Cross-session sync timer
local _last_scan_time = 0

function m.DrawPresetBrowser(x, y, w, h)
    -- 0. Cross-session auto-refresh (T6)
    local now = reaper.time_precise()
    if now - _last_scan_time >= 3.0 then
        io_mod.RefreshPresets()
        _last_scan_time = now
    end

    -- 1. Error banner
    local err = preset_store.GetBrowserError()
    if err then
        helpers.SetColor(ERROR_BG)
        gfx.rect(x, y, w, ERROR_H, 1)
        helpers.SetColor(ERROR_TEXT)
        gfx.setfont(1, "Calibri", 11)
        local ew, eh = gfx.measurestr(err)
        gfx.x, gfx.y = x + 4, y + (ERROR_H - eh) / 2
        gfx.drawstr(err)
        y = y + ERROR_H
        h = h - ERROR_H
    end

    -- 2. Search bar (T3: Live Search)
    local search_active = ui_store.GetSearchActive()
    helpers.SetColor(SEARCH_BG)
    gfx.rect(x, y, w, SEARCH_H, 1)
    helpers.SetColor(SEARCH_TEXT)
    gfx.setfont(1, "Calibri", 11)
    local query = preset_store.GetSearchQuery()
    local display = (#query > 0) and query or "Search presets..."
    local _, sh = gfx.measurestr("|")
    gfx.x, gfx.y = x + 4, y + (SEARCH_H - sh) / 2
    gfx.drawstr(display)

    -- Cursor when active
    if search_active then
        local qw = gfx.measurestr(query)
        gfx.x = x + 4 + qw
        gfx.y = y + 2
        gfx.drawstr("|")
    end

    -- Search bar click to focus
    if ui_store.GetMouseClick() then
        local mx, my = gfx.mouse_x, gfx.mouse_y
        if mx >= x and mx <= x + w and my >= y and my <= y + SEARCH_H then
            ui_store.SetSearchActive(true)
        else
            ui_store.SetSearchActive(false)
        end
    end

    -- Char capture when search active
    if search_active then
        local char = ui_store.GetLastChar()
        if char >= 32 and char <= 126 then
            query = query .. string.char(char)
            preset_store.SetSearchQuery(query)
            preset_store.ClearSelection()
        elseif char == 8 then
            -- Backspace
            query = query:sub(1, -2)
            preset_store.SetSearchQuery(query)
            preset_store.ClearSelection()
        elseif char == 27 then
            -- Escape: clear and blur
            preset_store.SetSearchQuery("")
            preset_store.ClearSelection()
            ui_store.SetSearchActive(false)
        end
    end

    y = y + SEARCH_H + 2
    h = h - SEARCH_H - 2

    -- 3. Header / Path display
    local header_h = 24
    local current_dir = preset_store.GetCurrentDirectory() or preset_store.GetPresetRoot()
    local nav_result = folder_mod.DrawFolderHeader(x, y, w, current_dir)

    -- Handle ".." up navigation
    if nav_result == "up" then
        local parent = current_dir:match("^(.+)[\\/][^\\/]+$")
        if parent then
            preset_store.SetCurrentDirectory(parent)
            io_mod.ScanDirectory(parent)
        end
    end

    -- 4. Folder List (Left Column)
    local folder_w = 100
    local folder_h = h - header_h
    local folder_x = x
    local folder_y = y + header_h

    local dirs = {}
    local tree = preset_store.GetPresetTree()
    if tree and tree.dirs then dirs = tree.dirs end
    local folder_scroll = preset_store.GetFolderScroll()

    local new_folder_scroll, _ = folder_mod.DrawFolderList(folder_x, folder_y, folder_w, folder_h, dirs, folder_scroll)
    if new_folder_scroll ~= folder_scroll then
        preset_store.SetFolderScroll(new_folder_scroll)
    end

    local click_result = folder_mod.HandleFolderClick(folder_x, folder_y, folder_w, folder_h, dirs, new_folder_scroll)
    if click_result then
        local action, path = click_result:match("^(.-):(.+)$")
        if action == "navigate" and path then
            preset_store.SetCurrentDirectory(path)
            io_mod.ScanDirectory(path)
        end
    end

    local wheel_scroll = folder_mod.HandleFolderWheel(folder_x, folder_y, folder_w, folder_h, dirs, new_folder_scroll)
    if wheel_scroll ~= new_folder_scroll then
        preset_store.SetFolderScroll(wheel_scroll)
    end

    -- Vertical Divider
    helpers.SetColor({0.15, 0.15, 0.15, 0.6})
    gfx.line(folder_x + folder_w, folder_y, folder_x + folder_w, folder_y + folder_h)

    -- 5. Preset List (Right Column) — with search filter
    local list_x = folder_x + folder_w
    local list_y = folder_y
    local list_w = w - folder_w
    local list_h = folder_h

    local files = preset_store.GetPresetFiles()
    -- Apply search filter (T3)
    if query and #query > 0 then
        local filtered = {}
        local q_lower = query:lower()
        for _, f in ipairs(files) do
            if f.name:lower():find(q_lower, 1, true) then
                table.insert(filtered, f)
            end
        end
        files = filtered
    end

    local scroll = preset_store.GetBrowserScroll()
    local selected = preset_store.GetSelectedPresetIdx()
    local last_cap = ui_store.GetLastMouseCap()

    -- RANDOM button (T5)
    local btn_h = 20
    local rnd_x = list_x + list_w - 50
    local rnd_y = list_y
    if #files > 0 then
        local rnd_hover = gfx.mouse_x >= rnd_x and gfx.mouse_x <= rnd_x + 48
                      and gfx.mouse_y >= rnd_y and gfx.mouse_y <= rnd_y + btn_h
        if rnd_hover then helpers.SetColor({0.35, 0.35, 0.5, 0.4})
        else helpers.SetColor({0.25, 0.25, 0.35, 0.3}) end
        gfx.rect(rnd_x, rnd_y, 48, btn_h, 1)
        helpers.SetColor(SEARCH_TEXT)
        gfx.setfont(1, "Calibri", 10)
        gfx.x, gfx.y = rnd_x + 4, rnd_y + 2
        gfx.drawstr("RANDOM")
        if rnd_hover and ui_store.GetMouseClick() then
            local pick = math.random(#files)
            io_mod.LoadPreset(files[pick].path)
        end
    end
    list_y = list_y + btn_h + 2
    list_h = list_h - btn_h - 2

    local new_scroll, result = list_mod.DrawPresetList(list_x, list_y, list_w, list_h, files, scroll, selected, last_cap)

    if new_scroll ~= scroll then
        preset_store.SetBrowserScroll(new_scroll)
    end

    -- Handle results
    if result then
        if result:match("^multi_select:(%d+)") then
            -- Multi-select state already updated by DrawPresetList; no-op here
        elseif result:match("^select:(%d+)") then
            preset_store.SetSelectedPresetIdx(tonumber(result:match("^select:(%d+)")))
        elseif result:match("^fav:(.+)") then
            local path = result:match("^fav:(.+)")
            local favs = preset_store.GetFavorites()
            favs[path] = not favs[path]
            preset_store.SetFavorites(favs)
            io_mod.SaveFavorites()
        elseif result:match("^context:(%d+)") then
            local idx = tonumber(result:match("^context:(%d+)"))
            local dir = preset_store.GetCurrentDirectory()
            list_mod.HandleContextMenu(idx, files, dir)
        end
    end
end

return m
