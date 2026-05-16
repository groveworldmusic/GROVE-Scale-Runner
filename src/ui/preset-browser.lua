-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Preset Browser
-- Filesystem-based preset browser for saving/loading island note configurations.
-- Uses io.* for file I/O and reaper.GetResourcePath() for base directory.
-- Supports folder tree, preset list, favorites, and save/load.

local config = require("config")
local island_store = require("state.island")
local note_store = require("state.note-store")
local preset_store = require("state.preset-store")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local ui_store = require("state.ui")
local seq_store = require("state.sequencer")
local prefs = require("state.preferences")
-- persist removed; prefs.SetKey marks dirty_key, TickSaveDebounce() flushes
local layout = require("ui.layout")

local browser = {}

-- Directory scan cache: avoids io.* filesystem calls during draw frames.
-- Keys are absolute directory paths, values are { dirs = table, files = table }.
-- Populated on Init() and on explicit RefreshPresets(); read-only during draw.
local _scan_cache = {}

-- lfs availability (Lua File System) — pcall-guarded with io.popen fallback
local _has_lfs, _lfs = pcall(require, "lfs")

-- Configuration
local ITEM_H = 22                 -- Height per list item in pixels
local FOLDER_ICON_W = 16         -- Width of folder/file icons
local STAR_SIZE = 14             -- Size of favorite star icon
local HEADER_H = 28              -- Height of the browser header row
local BTN_H = 24                 -- Height of action buttons
local FONT_SIZE = 13             -- Base font size for preset list items

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
        preset_store.SetBrowserError("Could not get REAPER resource path")
        return
    end
    local preset_dir = root .. "/grove-presets"
    preset_store.SetPresetRoot(preset_dir)

    -- Create directory on first access
    local dir_exists = false
    pcall(function()
        local f = io.open(preset_dir, "r")
        if f then dir_exists = true; f:close() end
    end)

    if not dir_exists then
        local ok3 = pcall(reaper.RecursiveCreateDirectory, preset_dir, 0)
        if not ok3 then
            preset_store.SetBrowserError("Could not create grove-presets directory")
            return
        end
    end

    preset_store.SetCurrentDirectory(preset_dir)
    preset_store.SetBrowserError(nil)
    browser.ScanDirectory(preset_dir)

    -- Load favorites from persistent storage
    browser.LoadFavorites()
end

--- Cache-aware directory scan. Returns cached results if available;
--- otherwise performs actual I/O and populates the cache.
--- During draw frames, callers should NOT force a re-scan — use
--- RefreshPresets() for explicit refreshes (e.g., after save/rename).
--- @param dir_path string Absolute path to directory
--- @param force_refresh boolean? If true, bypasses cache and re-scans
function browser.ScanDirectory(dir_path, force_refresh)
    if not dir_path or #dir_path == 0 then return end

    -- Return cached results if available and not forced
    if not force_refresh and _scan_cache[dir_path] then
        local cached = _scan_cache[dir_path]
        preset_store.SetPresetTree({path = dir_path, dirs = cached.dirs, files_count = #cached.files})
        preset_store.SetPresetFiles(cached.files)
        preset_store.SetSelectedPresetIdx(nil)
        preset_store.SetBrowserScroll(0)
        preset_store.SetBrowserError(nil)
        return
    end

    -- Build folder tree (directories)
    local dirs = {}
    if _has_lfs then
        -- lfs path: iterate directory, filter by type
        for entry in _lfs.dir(dir_path) do
            if entry ~= "." and entry ~= ".." then
                local full_path = dir_path .. "\\" .. entry
                local attr = _lfs.attributes(full_path)
                if attr and attr.mode == "directory" then
                    table.insert(dirs, {name = entry, path = full_path, type = "folder", expanded = false})
                end
            end
        end
    else
        -- Fallback: io.popen for environments without lfs
        local ok1, handle1 = pcall(io.popen, 'dir "' .. dir_path .. '" /B /AD 2>nul')
        if ok1 and handle1 then
            for line in handle1:lines() do
                if #line > 0 then
                    table.insert(dirs, {name = line, path = dir_path .. "\\" .. line, type = "folder", expanded = false})
                end
            end
            handle1:close()
        end
    end

    -- Sort directories alphabetically
    table.sort(dirs, function(a, b) return a.name:lower() < b.name:lower() end)

    -- Build file list (.grove files only)
    local files = {}
    if _has_lfs then
        -- lfs path: iterate directory, filter by extension
        for entry in _lfs.dir(dir_path) do
            if entry:match("%.grove$") then
                local name = entry:gsub("%.grove$", "")
                table.insert(files, {name = name, filename = entry, path = dir_path .. "\\" .. entry})
            end
        end
    else
        -- Fallback: io.popen for environments without lfs
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
    end

    -- Sort files alphabetically
    table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)

    -- Populate cache
    _scan_cache[dir_path] = { dirs = dirs, files = files }

    preset_store.SetPresetTree({path = dir_path, dirs = dirs, files_count = #files})
    preset_store.SetPresetFiles(files)
    preset_store.SetSelectedPresetIdx(nil)
    preset_store.SetBrowserScroll(0)
    preset_store.SetBrowserError(nil)
end

--- Force-refresh the cache for the current directory. Call after save, rename,
--- or any filesystem mutation that changes the preset list.
function browser.RefreshPresets()
    local dir = preset_store.GetCurrentDirectory()
    if dir then
        _scan_cache[dir] = nil
        browser.ScanDirectory(dir, true)
    end
end

--- Load favorites from REAPER persistent storage.
function browser.LoadFavorites()
    local ok, str = pcall(reaper.GetExtState, "GROVE_Scale_Runner", "preset_favorites")
    if ok and str and #str > 0 then
        local ok2, t = pcall(load("return " .. str))
        if ok2 and type(t) == "table" then
            local favs = {}
            for _, path in ipairs(t) do
                favs[path] = true
            end
            preset_store.SetFavorites(favs)
        end
    end
end

--- Save favorites to REAPER persistent storage.
function browser.SaveFavorites()
    local favs = preset_store.GetFavorites()
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
    pcall(reaper.SetExtState, "GROVE_Scale_Runner", "preset_favorites", str, true)
end

--- Toggle favorite status for a given file path.
--- @param file_path string
function browser.ToggleFavorite(file_path)
    if not file_path then return end
    local favs = preset_store.GetFavorites()
    if favs[file_path] then
        favs[file_path] = nil
    else
        favs[file_path] = true
    end
    preset_store.SetFavorites(favs)
    browser.SaveFavorites()
end

--- Check if a file path is favorited.
--- @param file_path string
--- @return boolean
function browser.IsFavorite(file_path)
    if not file_path then return false end
    local favs = preset_store.GetFavorites()
    return favs[file_path] == true
end

--- Save current notes to a .grove file (v2 format with progression + context).
--- @param file_path string Full path to save
--- @param preset_name string Display name for the preset
function browser.SavePreset(file_path, preset_name)
    local notes = island_store.GetNotes()
    if not notes then notes = {} end

    -- Serialize notes + progression + context to Lua table format
    local lines = {}
    table.insert(lines, "return {")
    table.insert(lines, string.format("    name = %q,", preset_name or "Untitled"))
    table.insert(lines, "    version = 2,")
    table.insert(lines, "    notes = {")
    for _, n in ipairs(notes) do
        table.insert(lines, string.format(
            "        {pitch=%d,start_beat=%d,duration=%d,velocity=%d,muted=%s},",
            n.pitch or 60, n.start_beat or 0, n.duration or 4, n.velocity or 100,
            n.muted and "true" or "false"
        ))
    end
    table.insert(lines, "    },")

    -- Context fields for full restoration
    table.insert(lines, string.format("    root_index = %d,", prefs.GetRootIndex() or 1))
    table.insert(lines, string.format("    scale_index = %d,", prefs.GetScaleIndex() or 1))
    table.insert(lines, string.format("    octave = %d,", prefs.GetOctave() or 4))
    table.insert(lines, string.format("    chord_mode_index = %d,", prefs.GetChordModeIndex() or 1))

    -- Serialize progression entries (with optional velocity/duration)
    local progression = seq_store.GetProgression()
    table.insert(lines, "    progression = {")
    for i = 1, 16 do
        local entry = progression[i]
        if entry then
            local parts = {
                "degree=" .. (entry.degree or 1),
                "root_index=" .. (entry.root_index or 1),
                "scale_index=" .. (entry.scale_index or 1),
                "octave=" .. (entry.octave or 4),
                "chord_mode_index=" .. (entry.chord_mode_index or 1),
            }
            if entry.velocity then table.insert(parts, "velocity=" .. entry.velocity) end
            if entry.duration then table.insert(parts, "duration=" .. entry.duration) end
            table.insert(lines, "        {" .. table.concat(parts, ",") .. "},")
        else
            table.insert(lines, "        nil,")
        end
    end
    table.insert(lines, "    },")
    table.insert(lines, "}")

    local content = table.concat(lines, "\n")

    local ok, f = pcall(io.open, file_path, "w")
    if not ok or not f then
        preset_store.SetBrowserError("Could not write file: " .. tostring(file_path))
        return false
    end
    f:write(content)
    f:close()

    -- Refresh file list (clear cache so the new file appears immediately)
    browser.RefreshPresets()
    preset_store.SetBrowserError(nil)
    return true
end

--- Load notes from a .grove file.
--- @param file_path string Full path to the preset file
--- @return boolean true on success
function browser.LoadPreset(file_path)
    if not file_path then
        preset_store.SetBrowserError("No preset selected")
        return false
    end

    local ok, result = pcall(dofile, file_path)
    if not ok then
        preset_store.SetBrowserError("Error loading preset: " .. tostring(result))
        return false
    end

    if type(result) ~= "table" then
        preset_store.SetBrowserError("Invalid preset file: expected table, got " .. type(result))
        return false
    end

    if not result.notes or type(result.notes) ~= "table" then
        preset_store.SetBrowserError("Invalid preset: missing 'notes' array")
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
                uuid = note_store.AllocNoteUUID(),
            })
        end
    end

    if #valid_notes == 0 then
        preset_store.SetBrowserError("Preset contains no valid notes")
        return false
    end

    island_store.SetNotes(valid_notes)
    note_store.ClearUndoStacks()

    -- v2 format: restore progression and context for full state reconstruction
    if result.version and result.version >= 2 then
        if result.root_index then prefs.SetRootIndex(result.root_index) end
        if result.scale_index then prefs.SetScaleIndex(result.scale_index) end
        if result.octave then prefs.SetOctave(result.octave) end
        if result.chord_mode_index then prefs.SetChordModeIndex(result.chord_mode_index) end
        if result.progression and type(result.progression) == "table" then
            seq_store.SetProgression(result.progression)
        end
    end

    preset_store.SetBrowserError(nil)
    return true
end

--- Rename the currently selected preset via GetUserInputs() + os.rename().
--- @return boolean true on success
function browser.RenamePreset()
    local files = preset_store.GetPresetFiles()
    local idx = preset_store.GetSelectedPresetIdx()
    if not idx or idx < 1 or idx > #files then
        preset_store.SetBrowserError("No preset selected to rename")
        return false
    end

    local entry = files[idx]
    local ret, new_name = reaper.GetUserInputs("Rename Preset", "New name:", 1, "", entry.name)
    if not ret or not new_name or #new_name == 0 then
        return false
    end

    -- Sanitize: remove invalid chars and strip .grove extension if user typed it
    new_name = new_name:gsub("[^%w_%-%s]", ""):gsub("%.grove$", "")
    if #new_name == 0 then
        preset_store.SetBrowserError("Invalid preset name")
        return false
    end

    local dir = preset_store.GetCurrentDirectory()
    local old_path = entry.path
    local new_path = dir .. "\\" .. new_name .. ".grove"

    -- Check if target already exists
    local f = io.open(new_path, "r")
    if f then
        f:close()
        preset_store.SetBrowserError("A preset with that name already exists")
        return false
    end

    local ok, err = os.rename(old_path, new_path)
    if not ok then
        preset_store.SetBrowserError("Could not rename preset: " .. tostring(err or "unknown error"))
        return false
    end

    -- Refresh the file list and clear selection (clear cache so rename is visible immediately)
    browser.RefreshPresets()
    preset_store.SetBrowserError(nil)
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
    components.DrawRoundedRect(x, y, w, h, 10, true) -- Match header corner radius

    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", layout.US(1300)) -- Match header font size
    local lw, lh = gfx.measurestr(label)
    gfx.x, gfx.y = x + (w - lw) / 2, y + (h - lh) / 2
    gfx.drawstr(label)

    return hover and ui_store.GetMouseClick()
end
function browser.DrawActionButtons(x, y, btn_w, h)
    local btn_spacing = 4
    local total_w = btn_w * 2 + btn_spacing
    local btn_y = y

    -- Save button
    local save_x = x
    local save_hover = gfx.mouse_x >= save_x and gfx.mouse_x <= save_x + btn_w
                   and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + h
    if DrawActionButton(save_x, btn_y, btn_w, h, "SAVE", save_hover) then
        local ret, csv = reaper.GetUserInputs("Save Preset", 1, "Preset name:", "Untitled")
        if ret and csv and #csv > 0 then
            local dir = preset_store.GetCurrentDirectory()
            if not dir or #dir == 0 then
                dir = preset_store.GetPresetRoot()
            end
            local filename = csv:gsub("[^%w_%-%s]", ""):gsub("%.grove$", "")
            if #filename > 0 then
                local filepath = dir .. "\\" .. filename .. ".grove"
                browser.SavePreset(filepath, filename)
            end
        end
    end

    -- Load button
    local load_x = save_x + btn_w + btn_spacing
    local load_hover = gfx.mouse_x >= load_x and gfx.mouse_x <= load_x + btn_w
                   and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + h
    if DrawActionButton(load_x, btn_y, btn_w, h, "LOAD", load_hover) then
        local files = preset_store.GetPresetFiles()
        local idx = preset_store.GetSelectedPresetIdx()
        if idx and idx >= 1 and idx <= #files then
            browser.LoadPreset(files[idx].path)
        end
    end

    return total_w
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
--- @param last_cap number Previous frame mouse_cap (for right-click detection)
--- @return number new_scroll_offset
--- @return string|nil "select:idx" or "fav:path" or "load:path" or "context:idx"
local function DrawPresetList(x, y, w, h, files, scroll_offset, selected_idx, last_cap)
    local result = nil
    local right_click_pressed = (gfx.mouse_cap & 2) == 2 and (last_cap & 2) == 0

    if not files or #files == 0 then
        helpers.SetColor(EMPTY_COLOR)
        gfx.setfont(1, "Calibri", FONT_SIZE)
        local msg = "(No presets)"
        local mw, mh = gfx.measurestr(msg)
        gfx.x, gfx.y = x + (w - mw) / 2, y + (h - mh) / 2
        gfx.drawstr(msg)
        return scroll_offset, nil
    end

    local list_y = y + 1
    local list_h = h - 1
    local max_visible = math.floor(list_h / ITEM_H)
    local scroll = math.max(0, math.min(scroll_offset, math.max(0, #files - max_visible)))
    local start_idx = scroll + 1
    local end_idx = math.min(#files, scroll + max_visible)

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

        -- Left-click handling
        if hover and ui_store.GetMouseClick() then
            if gfx.mouse_x >= star_x and gfx.mouse_x <= star_x + STAR_SIZE then
                result = "fav:" .. entry.path
            else
                result = "select:" .. tostring(i)
            end
        end

        -- Right-click context menu (stationary right-click on preset name area)
        if hover and right_click_pressed and not (gfx.mouse_x >= star_x and gfx.mouse_x <= star_x + STAR_SIZE) then
            -- Select the preset first
            if selected_idx ~= i then
                preset_store.SetSelectedPresetIdx(i)
            end
            -- Show context menu at cursor position
            local dir = preset_store.GetCurrentDirectory()
            local choice = gfx.showmenu("Load|Rename|Duplicate|Delete|Show in Explorer")
            if choice and choice > 0 then
                if choice == 1 then
                    -- Load selected preset
                    local files = preset_store.GetPresetFiles()
                    local idx = preset_store.GetSelectedPresetIdx()
                    if idx and idx >= 1 and idx <= #files then
                        if browser.LoadPreset(files[idx].path) then
                            island_store.SetNotesState(island_store.NOTES_STATE_LOADED)
                            island_store.ClearSelection()
                        end
                    end
                elseif choice == 2 then
                    -- Rename
                    browser.RenamePreset()
                elseif choice == 3 then
                    -- Duplicate: copy file with _copy.grove suffix
                    local path = entry.path
                    if path then
                        local dup_path = dir .. "\\" .. entry.name .. "_copy.grove"
                        local f_in, err_in = io.open(path, "rb")
                        local ok = false
                        if f_in then
                            local content = f_in:read("*all")
                            f_in:close()
                            local f_out, err_out = io.open(dup_path, "wb")
                            if f_out then
                                f_out:write(content)
                                f_out:close()
                                ok = true
                            end
                        end
                        if ok then
                            browser.RefreshPresets()
                        else
                            preset_store.SetBrowserError("Could not duplicate preset")
                        end
                    end
                elseif choice == 4 then
                    -- Delete: prompt then remove
                    local ret = reaper.MB("Delete preset \"" .. entry.name .. "\"?", "Delete Preset", 4) -- 4 = Yes/No
                    if ret == 6 then -- 6 = Yes
                        local ok, err = os.remove(entry.path)
                        if ok then
                            preset_store.SetSelectedPresetIdx(nil)
                            browser.RefreshPresets()
                        else
                            preset_store.SetBrowserError("Could not delete preset: " .. tostring(err or "unknown error"))
                        end
                    end
                elseif choice == 5 then
                    -- Show in Explorer
                    local path = entry.path
                    if path then
                        reaper.ExecProcess("explorer.exe /select,\"" .. path .. "\"")
                    end
                end
            end
            -- Consume this right-click by setting result to prevent double-processing
            result = "context:" .. tostring(i)
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
--- Called from DrawMIDIIsland for the left panel area.
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
    local err = preset_store.GetBrowserError()
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

    current_y = current_y + 4

    -- Preset count label (below Rename, above divider — clearly separated)
    local files = preset_store.GetPresetFiles()
    gfx.setfont(1, "Calibri", 14)
    helpers.SetColor(theme.colors.text_dim)
    local hdr = "PRESETS (" .. tostring(#(files or {})) .. ")"
    local hw, hh = gfx.measurestr(hdr)
    gfx.x, gfx.y = x + 4, current_y
    gfx.drawstr(hdr)
    current_y = current_y + hh + 4

    -- Divider line between action row + count label and folder/preset content
    helpers.SetColor(DIVIDER_COLOR)
    gfx.line(x + 4, current_y, x + w - 4, current_y)
    current_y = current_y + 2
    remaining_h = h - (current_y - y)

    -- ============================================
    -- Split remaining area: folders LEFT, presets RIGHT
    -- Vertical divider in the middle
    -- ============================================
    if remaining_h > 30 then
        local mid_x = x + math.floor(w / 2)
        local left_w = mid_x - x - 4
        local right_x = mid_x + 4
        local right_w = x + w - right_x - 4
        local content_h = remaining_h

        -- Vertical divider line
        helpers.SetColor(DIVIDER_COLOR)
        gfx.line(mid_x, current_y, mid_x, current_y + content_h)

        -- ===========================
        -- Folder list (LEFT side)
        -- ===========================
        if left_w > 40 then
            local dirs = {}
            local tree = preset_store.GetPresetTree()
            if tree and tree.dirs then
                dirs = tree.dirs
            end

            local nav_result
            local folder_scroll
            folder_scroll, _, nav_result = DrawFolderList(x + 2, current_y, left_w - 2, content_h, dirs, preset_store.GetFolderScroll())
            preset_store.SetFolderScroll(folder_scroll)

            if nav_result then
                local action, path = nav_result:match("^(.-):(.+)$")
                if action == "navigate" and path then
                    preset_store.SetCurrentDirectory(path)
                    browser.ScanDirectory(path)
                end
            end
        end

        -- ===========================
        -- Preset list (RIGHT side)
        -- ===========================
        if right_w > 40 then
            local files = preset_store.GetPresetFiles()
            local scroll = preset_store.GetBrowserScroll()
            local sel_idx = preset_store.GetSelectedPresetIdx()

            local last_cap = ui_store.GetLastMouseCap()
            local _, list_result = DrawPresetList(right_x, current_y, right_w, content_h, files, scroll, sel_idx, last_cap)

            if list_result then
                local action, value = list_result:match("^(.-):(.+)$")
                if action == "select" and value then
                    preset_store.SetSelectedPresetIdx(tonumber(value))
                elseif action == "fav" and value then
                    browser.ToggleFavorite(value)
                end
            end

            -- Scroll via mouse wheel over preset list
            if gfx.mouse_x >= right_x and gfx.mouse_x <= right_x + right_w
               and gfx.mouse_y >= current_y and gfx.mouse_y <= current_y + content_h then
                local wheel = ui_store.ConsumeMouseWheelDelta()
                if wheel ~= 0 then
                    local max_scroll = math.max(0, (#files or 0) - math.floor(content_h / ITEM_H))
                    preset_store.SetBrowserScroll(math.max(0, math.min(max_scroll, scroll - wheel)))
                end
            end
        end
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
            local scroll = preset_store.GetBrowserScroll()
            local files = preset_store.GetPresetFiles()
            local max_scroll = math.max(0, (#files or 0) - math.floor(h / ITEM_H))
            preset_store.SetBrowserScroll(math.max(0, math.min(max_scroll, scroll - wheel)))
        end
    end
end

return browser
