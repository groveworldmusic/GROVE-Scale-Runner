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
local preview_mod = require("ui.preset-browser.preview")

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

-- Type filter state (Phase B: Progression-Only Presets)
-- Values: "all", "notes", "progression"
local _type_filter = "all"

function m.DrawPresetBrowser(x, y, w, h)
    -- 0a. Preview tick: auto-stop expired ghost-note previews
    preview_mod.TickPreview()

    -- 0b. Cross-session auto-refresh (T6)
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

    -- Apply type filter (Phase B)
    if _type_filter ~= "all" then
        local filtered = {}
        for _, f in ipairs(files) do
            local f_type = f.type or "notes"
            if f_type == _type_filter then
                table.insert(filtered, f)
            end
        end
        files = filtered
    end

    local scroll = preset_store.GetBrowserScroll()
    local selected = preset_store.GetSelectedPresetIdx()
    local last_cap = ui_store.GetLastMouseCap()

    -- Button bar: filter tabs + Save Progression + IMPORT + RANDOM
    local btn_h = 20
    local btn_y = list_y

    -- Filter tabs: All / Notes / Progression
    local TABS = {"all", "notes", "progression"}
    local TAB_LABELS = {all = "All", notes = "Notes", progression = "Prog."}
    local tab_x = list_x + 2
    local tab_gap = 2
    gfx.setfont(1, "Calibri", 10)
    for _, tab_key in ipairs(TABS) do
        local label = TAB_LABELS[tab_key]
        local lw = gfx.measurestr(label)
        local tw = lw + 10
        local t_hover = gfx.mouse_x >= tab_x and gfx.mouse_x <= tab_x + tw
                    and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
        if tab_key == _type_filter then
            helpers.SetColor({0.25, 0.45, 0.8, 0.5})
        elseif t_hover then
            helpers.SetColor({0.35, 0.35, 0.35, 0.4})
        else
            helpers.SetColor({0.2, 0.2, 0.2, 0.3})
        end
        gfx.rect(tab_x, btn_y, tw, btn_h, 1)
        helpers.SetColor(tab_key == _type_filter and {0.9, 0.9, 0.9, 0.95} or SEARCH_TEXT)
        gfx.setfont(1, "Calibri", 10)
        gfx.x, gfx.y = tab_x + 5, btn_y + 2
        gfx.drawstr(label)
        if t_hover and ui_store.GetMouseClick() then
            _type_filter = tab_key
        end
        tab_x = tab_x + tw + tab_gap
    end

    -- Save Progression button (Phase B)
    local save_prog_x = tab_x + 4
    local save_prog_w = 58
    local save_prog_hover = gfx.mouse_x >= save_prog_x and gfx.mouse_x <= save_prog_x + save_prog_w
                        and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
    if save_prog_hover then helpers.SetColor({0.3, 0.6, 0.3, 0.4})
    else helpers.SetColor({0.2, 0.4, 0.2, 0.3}) end
    gfx.rect(save_prog_x, btn_y, save_prog_w, btn_h, 1)
    helpers.SetColor(SEARCH_TEXT)
    gfx.setfont(1, "Calibri", 10)
    gfx.x, gfx.y = save_prog_x + 4, btn_y + 2
    gfx.drawstr("S-PROG")
    if save_prog_hover and ui_store.GetMouseClick() then
        local ret, csv = reaper.GetUserInputs("Save Progression Preset", 1, "Preset name:", "Untitled")
        if ret and csv and #csv > 0 then
            local dir = preset_store.GetCurrentDirectory()
            if not dir or #dir == 0 then dir = preset_store.GetPresetRoot() end
            local filename = csv:gsub("[^%w_%-%s]", ""):gsub("%.grove%-prog$", ""):gsub("%.grove$", "")
            if #filename > 0 then
                io_mod.SaveProgressionPreset(io_mod.GetProgressionPresetFilePath(dir, filename), filename)
            end
        end
    end
    if save_prog_hover and not ui_store.GetMouseClick() then
        helpers.DrawTooltip("Save progression-only preset (no notes)", 10)
    end

    -- IMPORT button (T4: Export/Import Packs)
    local import_w = 40
    local import_x = save_prog_x + save_prog_w + 4
    local import_hover = gfx.mouse_x >= import_x and gfx.mouse_x <= import_x + import_w
                    and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
    if import_hover then helpers.SetColor({0.35, 0.35, 0.5, 0.4})
    else helpers.SetColor({0.25, 0.25, 0.35, 0.3}) end
    gfx.rect(import_x, btn_y, import_w, btn_h, 1)
    helpers.SetColor(SEARCH_TEXT)
    gfx.setfont(1, "Calibri", 10)
    gfx.x, gfx.y = import_x + 4, btn_y + 2
    gfx.drawstr("IMPORT")
    if import_hover and ui_store.GetMouseClick() then
        local ret, path = reaper.GetUserInputs("Import Pack", 1, "Pack file path:", "")
        if ret and path and #path > 0 then
            local count = io_mod.ImportPresetsFromPack(path)
            if count > 0 then
                reaper.ShowConsoleMsg("Imported " .. count .. " presets from pack.\n")
            end
        end
    end

    -- RANDOM button (T5)
    local rnd_w = 48
    local rnd_x = import_x + import_w + 4
    if #files > 0 then
        local rnd_hover = gfx.mouse_x >= rnd_x and gfx.mouse_x <= rnd_x + rnd_w
                      and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h
        if rnd_hover then helpers.SetColor({0.35, 0.35, 0.5, 0.4})
        else helpers.SetColor({0.25, 0.25, 0.35, 0.3}) end
        gfx.rect(rnd_x, btn_y, rnd_w, btn_h, 1)
        helpers.SetColor(SEARCH_TEXT)
        gfx.setfont(1, "Calibri", 10)
        gfx.x, gfx.y = rnd_x + 4, btn_y + 2
        gfx.drawstr("RANDOM")
        if rnd_hover and ui_store.GetMouseClick() then
            local pick = math.random(#files)
            io_mod.LoadPreset(files[pick].path)
        end
    end

    list_y = btn_y + btn_h + 2
    list_h = list_h - btn_h - 2

    local new_scroll, result = list_mod.DrawPresetList(list_x, list_y, list_w, list_h, files, scroll, selected, last_cap, nil, _type_filter)

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
