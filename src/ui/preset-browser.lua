-- GROVE FL MIDI: Preset Browser
-- Filesystem-based preset browser for saving/loading island note configurations.
-- Uses io.* for file I/O and reaper.GetResourcePath() for base directory.
-- Supports folder tree, preset list, favorites, and save/load.

local config = require("config")
local island_store = require("state.island")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local ui_store = require("state.ui")

local browser = {}

-- Configuration
local ITEM_H = 22                 -- Height per list item in pixels
local FOLDER_ICON_W = 16         -- Width of folder/file icons
local STAR_SIZE = 14             -- Size of favorite star icon
local HEADER_H = 28              -- Height of the browser header row
local BTN_H = 24                 -- Height of action buttons
local FONT_SIZE = 11             -- Base font size

-- Colors
local HEADER_BG = {0.22, 0.22, 0.22, 1}
local ITEM_HOVER = {0.35, 0.35, 0.35, 0.4}
local ITEM_SELECTED = {0.25, 0.45, 0.8, 0.3}
local FOLDER_COLOR = {0.6, 0.6, 0.7, 0.9}
local FILE_COLOR = {0.8, 0.8, 0.8, 0.9}
local STAR_ON_COLOR = {1, 0.85, 0.2, 0.9}
local STAR_OFF_COLOR = {0.5, 0.5, 0.5, 0.4}
local BTN_BG = {0.3, 0.3, 0.35, 1}
local BTN_HOVER = {0.4, 0.4, 0.5, 1}
local ERROR_COLOR = {0.9, 0.3, 0.3, 0.8}
local EMPTY_COLOR = {0.5, 0.5, 0.5, 0.6}
local SCROLLBAR_COLOR = {0.4, 0.4, 0.4, 0.3}
local DIVIDER_COLOR = {0.25, 0.25, 0.25, 0.5}

--- Initialize the preset browser: set up root directory and scan.
function browser.Init()
    local ok, root = pcall(reaper.GetResourcePath)
    if not ok or not root then
        island_store.SetBrowserError("Could not get REAPER resource path")
        return
    end
    local preset_dir = root .. "/grove-presets"
    island_store.SetPresetRoot(preset_dir)

    -- Create directory on first access
    local dir_exists = false
    local ok2, attr = pcall(reaper.GetResourcePath, preset_dir)
    pcall(function()
        local f = io.open(preset_dir, "r")
        if f then dir_exists = true; f:close() end
    end)

    if not dir_exists then
        local ok3 = pcall(reaper.RecursiveCreateDirectory, preset_dir, 0)
        if not ok3 then
            island_store.SetBrowserError("Could not create grove-presets directory")
            return
        end
    end

    island_store.SetCurrentDirectory(preset_dir)
    island_store.SetBrowserError(nil)
    browser.ScanDirectory(preset_dir)

    -- Load favorites from persistent storage
    browser.LoadFavorites()
end

--- Scan a directory for subdirectories and .grove files.
--- @param dir_path string Absolute path to directory
function browser.ScanDirectory(dir_path)
    if not dir_path or #dir_path == 0 then return end

    -- Build folder tree (directories)
    local dirs = {}
    local ok1, handle1 = pcall(io.popen, 'dir "' .. dir_path .. '" /B /AD 2>nul')
    if ok1 and handle1 then
        for line in handle1:lines() do
            if #line > 0 then
                table.insert(dirs, {name = line, path = dir_path .. "\\" .. line, type = "folder", expanded = false})
            end
        end
        handle1:close()
    end

    -- Sort directories alphabetically
    table.sort(dirs, function(a, b) return a.name:lower() < b.name:lower() end)

    -- Build file list (.grove files only)
    local files = {}
    local ok2, handle2 = pcall(io.popen, 'dir "' .. dir_path .. '\\*.grove" /B 2>nul')
    if ok2 and handle2 then
        for line in handle2:lines() do
            if #line > 0 then
                local name = line:gsub("%.grove$", "")
                table.insert(files, {name = name, filename = line, path = dir_path .. "\\" .. line})
            end
        end
        handle2:close()
    end

    -- Sort files alphabetically
    table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)

    island_store.SetPresetTree({path = dir_path, dirs = dirs, files_count = #files})
    island_store.SetPresetFiles(files)
    island_store.SetSelectedPresetIdx(nil)
    island_store.SetBrowserScroll(0)
    island_store.SetBrowserError(nil)
end

--- Load favorites from REAPER persistent storage.
function browser.LoadFavorites()
    local ok, str = pcall(reaper.GetExtState, "GROVE_FL_MIDI", "preset_favorites")
    if ok and str and #str > 0 then
        local ok2, t = pcall(load("return " .. str))
        if ok2 and type(t) == "table" then
            local favs = {}
            for _, path in ipairs(t) do
                favs[path] = true
            end
            island_store.SetFavorites(favs)
        end
    end
end

--- Save favorites to REAPER persistent storage.
function browser.SaveFavorites()
    local favs = island_store.GetFavorites()
    local paths = {}
    for path, _ in pairs(favs) do
        table.insert(paths, path)
    end
    table.sort(paths)
    local parts = {}
    for _, p in ipairs(paths) do
        table.insert(parts, string.format("%q", p))
    end
    local str = "{" .. table.concat(parts, ",") .. "}"
    pcall(reaper.SetExtState, "GROVE_FL_MIDI", "preset_favorites", str, true)
end

--- Toggle favorite status for a given file path.
--- @param file_path string
function browser.ToggleFavorite(file_path)
    if not file_path then return end
    local favs = island_store.GetFavorites()
    if favs[file_path] then
        favs[file_path] = nil
    else
        favs[file_path] = true
    end
    island_store.SetFavorites(favs)
    browser.SaveFavorites()
end

--- Check if a file path is favorited.
--- @param file_path string
--- @return boolean
function browser.IsFavorite(file_path)
    if not file_path then return false end
    local favs = island_store.GetFavorites()
    return favs[file_path] == true
end

--- Save current notes to a .grove file.
--- @param file_path string Full path to save
--- @param preset_name string Display name for the preset
function browser.SavePreset(file_path, preset_name)
    local notes = island_store.GetNotes()
    if not notes then notes = {} end

    -- Serialize notes to Lua table format
    local lines = {}
    table.insert(lines, "return {")
    table.insert(lines, string.format("    name = %q,", preset_name or "Untitled"))
    table.insert(lines, "    version = 1,")
    table.insert(lines, "    notes = {")
    for _, n in ipairs(notes) do
        table.insert(lines, string.format(
            "        {pitch=%d,start_beat=%d,duration=%d,velocity=%d,muted=%s},",
            n.pitch or 60, n.start_beat or 0, n.duration or 4, n.velocity or 100,
            n.muted and "true" or "false"
        ))
    end
    table.insert(lines, "    },")
    table.insert(lines, "}")

    local content = table.concat(lines, "\n")

    local ok, f = pcall(io.open, file_path, "w")
    if not ok or not f then
        island_store.SetBrowserError("Could not write file: " .. tostring(file_path))
        return false
    end
    f:write(content)
    f:close()

    -- Refresh file list
    browser.ScanDirectory(island_store.GetCurrentDirectory())
    island_store.SetBrowserError(nil)
    return true
end

--- Load notes from a .grove file.
--- @param file_path string Full path to the preset file
--- @return boolean true on success
function browser.LoadPreset(file_path)
    if not file_path then
        island_store.SetBrowserError("No preset selected")
        return false
    end

    local ok, result = pcall(dofile, file_path)
    if not ok then
        island_store.SetBrowserError("Error loading preset: " .. tostring(result))
        return false
    end

    if type(result) ~= "table" then
        island_store.SetBrowserError("Invalid preset file: expected table, got " .. type(result))
        return false
    end

    if not result.notes or type(result.notes) ~= "table" then
        island_store.SetBrowserError("Invalid preset: missing 'notes' array")
        return false
    end

    -- Validate notes structure
    local valid_notes = {}
    for _, n in ipairs(result.notes) do
        if type(n) == "table" and n.pitch then
            table.insert(valid_notes, {
                pitch = n.pitch,
                start_beat = n.start_beat or 0,
                duration = n.duration or 4,
                velocity = n.velocity or 100,
                muted = n.muted == true,
            })
        end
    end

    if #valid_notes == 0 then
        island_store.SetBrowserError("Preset contains no valid notes")
        return false
    end

    island_store.SetNotes(valid_notes)
    island_store.SetBrowserError(nil)
    return true
end

--- Draw a single action button.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param label string
--- @param hover boolean
--- @return boolean clicked
local function DrawActionButton(x, y, w, h, label, hover)
    helpers.SetColor(hover and BTN_HOVER or BTN_BG)
    gfx.rect(x, y, w, h, 1)

    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", FONT_SIZE)
    local lw, lh = gfx.measurestr(label)
    gfx.x, gfx.y = x + (w - lw) / 2, y + (h - lh) / 2
    gfx.drawstr(label)

    return hover and ui_store.GetMouseClick()
end

--- Draw the folder navigation header.
--- @param x number
--- @param y number
--- @param w number
--- @param path string Current directory path
--- @param click_happend boolean Whether there was a click this frame
--- @return string|nil "up" if user clicked the up button
local function DrawFolderHeader(x, y, w, path)
    helpers.SetColor(HEADER_BG)
    gfx.rect(x, y, w, HEADER_H, 1)

    -- Up button (..)
    local up_x = x + 4
    local up_w = 24
    local up_hover = gfx.mouse_x >= up_x and gfx.mouse_x <= up_x + up_w
                  and gfx.mouse_y >= y and gfx.mouse_y <= y + HEADER_H
    helpers.SetColor(up_hover and theme.colors.btn_hover or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", FONT_SIZE)
    gfx.x, gfx.y = up_x + 4, y + (HEADER_H - 11) / 2
    gfx.drawstr("..")

    -- Current folder name (truncated)
    local dir_name = path:match([=[([^\\]+)$]=]) or path
    if #dir_name > 18 then
        dir_name = dir_name:sub(1, 16) .. ".."
    end
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", FONT_SIZE)
    local dw, dh = gfx.measurestr(dir_name)
    local label_x = up_x + up_w + 6
    gfx.x, gfx.y = label_x, y + (HEADER_H - dh) / 2
    gfx.drawstr(dir_name)

    if up_hover and ui_store.GetMouseClick() then
        return "up"
    end
    return nil
end

--- Draw the folder/directory list section.
--- @param x number
--- @param y number
--- @param w number
--- @param max_h number Max height for this section
--- @param dirs table Array of directory entries
--- @param scroll_offset number Current scroll offset
--- @return number new_scroll_offset, number total_height
--- @return string|nil "navigate:path" if user clicked a folder
local function DrawFolderList(x, y, w, max_h, dirs, scroll_offset)
    local result = nil
    if not dirs or #dirs == 0 then
        -- Show "No folders" quietly
        return scroll_offset, 0, nil
    end

    local total_h = #dirs * ITEM_H
    local max_visible = math.floor(max_h / ITEM_H)
    local scroll = math.max(0, math.min(scroll_offset, math.max(0, #dirs - max_visible)))

    -- Draw each visible folder
    local start_idx = scroll + 1
    local end_idx = math.min(#dirs, scroll + max_visible)

    for i = start_idx, end_idx do
        local item_y = y + (i - start_idx) * ITEM_H
        if item_y + ITEM_H > y + max_h then break end

        local entry = dirs[i]
        local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + w
                  and gfx.mouse_y >= item_y and gfx.mouse_y <= item_y + ITEM_H

        -- Background
        if hover then
            helpers.SetColor(ITEM_HOVER)
            gfx.rect(x, item_y, w, ITEM_H, 1)
        end

        -- Folder icon (▶ or ▼)
        helpers.SetColor(FOLDER_COLOR)
        gfx.setfont(1, "Calibri", 10)
        local icon = entry.expanded and "▼" or "▶"
        local iw, ih = gfx.measurestr(icon)
        gfx.x, gfx.y = x + 4, item_y + (ITEM_H - ih) / 2
        gfx.drawstr(icon)

        -- Folder name
        local label = entry.name
        if #label > 22 then label = label:sub(1, 20) .. ".." end
        gfx.setfont(1, "Calibri", FONT_SIZE)
        local lw, lh = gfx.measurestr(label)
        gfx.x, gfx.y = x + FOLDER_ICON_W + 8, item_y + (ITEM_H - lh) / 2
        gfx.drawstr(label)

        -- Click handler
        if hover and ui_store.GetMouseClick() then
            result = "navigate:" .. entry.path
        end
    end

    -- Draw scrollbar if needed
    if #dirs > max_visible then
        local sb_x = x + w - 6
        local sb_h = max_h * (max_visible / #dirs)
        local sb_y = y + (scroll / math.max(1, #dirs - max_visible)) * (max_h - sb_h)
        helpers.SetColor(SCROLLBAR_COLOR)
        gfx.rect(sb_x, sb_y, 6, math.max(8, sb_h), 1)
    end

    return scroll, total_h, result
end

--- Draw the preset files list.
--- @param x number
--- @param y number
--- @param w number
--- @param h number Available height
--- @param files table Array of file entries
--- @param scroll_offset number Current scroll
--- @param selected_idx number|nil Selected index
--- @return number new_scroll_offset
--- @return string|nil "select:idx" or "fav:path" or "load:path"
local function DrawPresetList(x, y, w, h, files, scroll_offset, selected_idx)
    local result = nil

    if not files or #files == 0 then
        helpers.SetColor(EMPTY_COLOR)
        gfx.setfont(1, "Calibri", FONT_SIZE)
        local msg = "(No presets)"
        local mw, mh = gfx.measurestr(msg)
        gfx.x, gfx.y = x + (w - mw) / 2, y + (h - mh) / 2
        gfx.drawstr(msg)
        return scroll_offset, nil
    end

    -- Draw divider between folder area and file list
    helpers.SetColor(DIVIDER_COLOR)
    gfx.line(x, y, x + w, y)

    local list_y = y + 2
    local list_h = h - 2
    local max_visible = math.floor(list_h / ITEM_H)
    local scroll = math.max(0, math.min(scroll_offset, math.max(0, #files - max_visible)))
    local start_idx = scroll + 1
    local end_idx = math.min(#files, scroll + max_visible)

    -- Header label
    gfx.setfont(1, "Calibri", 9)
    helpers.SetColor(theme.colors.text_dim)
    local hdr = "PRESETS (" .. #files .. ")"
    local hw, hh = gfx.measurestr(hdr)
    gfx.x, gfx.y = x + 4, y - 12
    gfx.drawstr(hdr)

    for i = start_idx, end_idx do
        local item_y = list_y + (i - start_idx) * ITEM_H
        if item_y + ITEM_H > y + h then break end

        local entry = files[i]
        local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + w
                  and gfx.mouse_y >= item_y and gfx.mouse_y <= item_y + ITEM_H
        local is_selected = (i == selected_idx)

        -- Selection/hover background
        if is_selected then
            helpers.SetColor(ITEM_SELECTED)
            gfx.rect(x, item_y, w, ITEM_H, 1)
        elseif hover then
            helpers.SetColor(ITEM_HOVER)
            gfx.rect(x, item_y, w, ITEM_H, 1)
        end

        -- Favorite star
        local is_fav = browser.IsFavorite(entry.path)
        local star_x = x + w - STAR_SIZE - 4
        local star_hover = hover and gfx.mouse_x >= star_x and gfx.mouse_x <= star_x + STAR_SIZE
        helpers.SetColor(is_fav and STAR_ON_COLOR or STAR_OFF_COLOR)
        gfx.setfont(1, "Calibri", 10)
        local star_sym = is_fav and "★" or "☆"
        local sw, sh = gfx.measurestr(star_sym)
        gfx.x, gfx.y = star_x, item_y + (ITEM_H - sh) / 2
        gfx.drawstr(star_sym)

        -- File name
        local label = entry.name
        if #label > 20 then label = label:sub(1, 18) .. ".." end
        helpers.SetColor(FILE_COLOR)
        gfx.setfont(1, "Calibri", FONT_SIZE)
        local lw, lh = gfx.measurestr(label)
        gfx.x, gfx.y = x + 4, item_y + (ITEM_H - lh) / 2
        gfx.drawstr(label)

        -- Click handling
        if hover and ui_store.GetMouseClick() then
            -- Check if click is on star icon
            if gfx.mouse_x >= star_x and gfx.mouse_x <= star_x + STAR_SIZE then
                result = "fav:" .. entry.path
            else
                result = "select:" .. tostring(i)
            end
        end
    end

    -- Scrollbar if needed
    if #files > max_visible then
        local sb_x = x + w - 6
        local sb_h = list_h * (max_visible / #files)
        local sb_y = list_y + (scroll / math.max(1, #files - max_visible)) * (list_h - sb_h)
        helpers.SetColor(SCROLLBAR_COLOR)
        gfx.rect(sb_x, sb_y, 6, math.max(8, sb_h), 1)
    end

    return scroll, result
end

--- Main drawer for the preset browser panel.
--- Called from DrawIslandView for the left panel area.
--- @param x number Left edge
--- @param y number Top edge
--- @param w number Panel width
--- @param h number Panel height
function browser.DrawPresetBrowser(x, y, w, h)
    if w <= 0 or h <= 0 then return end

    local current_y = y
    local remaining_h = h

    -- ===========================
    -- Error banner (if any)
    -- ===========================
    local err = island_store.GetBrowserError()
    if err then
        local err_h = 30
        helpers.SetColor(ERROR_COLOR)
        gfx.setfont(1, "Calibri", 9)
        local ew, eh = gfx.measurestr(err)
        gfx.x, gfx.y = x + 4, current_y + (err_h - eh) / 2
        gfx.drawstr(err)
        current_y = current_y + err_h
        remaining_h = remaining_h - err_h
    end

    -- ===========================
    -- Action buttons row (Save / Load)
    -- ===========================
    local btn_y = current_y
    local btn_w = math.floor((w - 8) / 2)
    local btn_spacing = 4

    -- Save button
    local save_hover = gfx.mouse_x >= x + 4 and gfx.mouse_x <= x + 4 + btn_w
                   and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + BTN_H
    if DrawActionButton(x + 4, btn_y, btn_w, BTN_H, "Save", save_hover) then
        reaper.GetUserInputs("Save Preset", 1, "Preset name:", "Untitled")
        -- Note: GetUserInputs returns ret, csv; we handle the save action
        -- via the load button since REAPER dialogs need special handling
    end

    -- Save button actually works via GetUserInputs
    if save_hover and ui_store.GetMouseClick() then
        local ret, csv = reaper.GetUserInputs("Save Preset", 1, "Preset name:", "Untitled")
        if ret and csv and #csv > 0 then
            local dir = island_store.GetCurrentDirectory()
            if not dir or #dir == 0 then
                dir = island_store.GetPresetRoot()
            end
            local filename = csv:gsub("[^%w_%-%s]", ""):gsub("%.grove$", "")
            if #filename > 0 then
                local filepath = dir .. "\\" .. filename .. ".grove"
                browser.SavePreset(filepath, filename)
            end
        end
    end

    -- Load button
    local load_x = x + 4 + btn_w + btn_spacing
    local load_hover = gfx.mouse_x >= load_x and gfx.mouse_x <= load_x + btn_w
                   and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + BTN_H
    if DrawActionButton(load_x, btn_y, btn_w, BTN_H, "Load", load_hover) then
        -- Handled below
    end

    if load_hover and ui_store.GetMouseClick() then
        local files = island_store.GetPresetFiles()
        local idx = island_store.GetSelectedPresetIdx()
        if idx and idx >= 1 and idx <= #files then
            browser.LoadPreset(files[idx].path)
        end
    end

    current_y = btn_y + BTN_H + 4
    remaining_h = h - (current_y - y)

    -- ===========================
    -- Folder list (directory navigation)
    -- ===========================
    if remaining_h > 20 then
        local folder_h = math.min(remaining_h * 0.35, 150)
        local dirs = {}
        local tree = island_store.GetPresetTree()
        if tree and tree.dirs then
            dirs = tree.dirs
        end

        local nav_result
        local new_scroll, _, nav_result = DrawFolderList(x + 4, current_y, w - 8, folder_h, dirs, 0)
        island_store.SetBrowserScroll(new_scroll)

        if nav_result then
            local action, path = nav_result:match("^(.-):(.+)$")
            if action == "navigate" and path then
                island_store.SetCurrentDirectory(path)
                browser.ScanDirectory(path)
            end
        end

        current_y = current_y + folder_h
        remaining_h = h - (current_y - y)
    end

    -- ===========================
    -- Preset list
    -- ===========================
    if remaining_h > 30 then
        local files = island_store.GetPresetFiles()
        local scroll = island_store.GetBrowserScroll()
        local sel_idx = island_store.GetSelectedPresetIdx()

        local _, list_result = DrawPresetList(x + 4, current_y, w - 8, remaining_h, files, scroll, sel_idx)

        if list_result then
            local action, value = list_result:match("^(.-):(.+)$")
            if action == "select" and value then
                island_store.SetSelectedPresetIdx(tonumber(value))
            elseif action == "fav" and value then
                browser.ToggleFavorite(value)
            end
        end

        -- Scroll via mouse wheel
        if gfx.mouse_x >= x and gfx.mouse_x <= x + w
           and gfx.mouse_y >= current_y and gfx.mouse_y <= current_y + remaining_h then
            local wheel = ui_store.ConsumeMouseWheelDelta()
            if wheel ~= 0 then
                local max_scroll = math.max(0, (#files or 0) - math.floor(remaining_h / ITEM_H))
                island_store.SetBrowserScroll(math.max(0, math.min(max_scroll, scroll - wheel)))
            end
        end

        current_y = current_y + remaining_h
    end
end

--- Handle mouse wheel scrolling in the preset browser.
--- @param x number Panel left edge
--- @param y number Panel top edge
--- @param w number Panel width
--- @param h number Panel height
function browser.HandleBrowserWheel(x, y, w, h)
    -- Check if mouse is over the browser
    if gfx.mouse_x >= x and gfx.mouse_x <= x + w
       and gfx.mouse_y >= y and gfx.mouse_y <= y + h then
        local wheel = ui_store.ConsumeMouseWheelDelta()
        if wheel ~= 0 then
            local scroll = island_store.GetBrowserScroll()
            local files = island_store.GetPresetFiles()
            local max_scroll = math.max(0, (#files or 0) - math.floor(h / ITEM_H))
            island_store.SetBrowserScroll(math.max(0, math.min(max_scroll, scroll - wheel)))
        end
    end
end

return browser
