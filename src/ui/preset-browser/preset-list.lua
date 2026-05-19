-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Preset Browser — Preset List Module
-- Handles rendering and interaction for the preset list in the preset browser.

local theme = require("ui.theme")
local helpers = require("ui.helpers")
local ui_store = require("state.ui")
local components = require("ui.components")
local layout = require("ui.layout")
local io_mod = require("ui.preset-browser.io")
local path_utils = require("ui.path-utils")
local preset_store = require("state.preset-store")
local island_store = require("state.island")
local note_store = require("state.note-store")
local preview_mod = require("ui.preset-browser.preview")
local safe_loader = require("ui.safe-loader")

local m = {}

-- Layout constants
local ITEM_H = 22
local STAR_SIZE = 14
local FONT_SIZE = 13
local ITEM_HOVER = {0.35, 0.35, 0.35, 0.4}
local ITEM_SELECTED = {0.25, 0.45, 0.8, 0.3}
local FILE_COLOR = {0.8, 0.8, 0.8, 0.9}
local STAR_ON_COLOR = {1, 0.85, 0.2, 0.9}
local STAR_OFF_COLOR = {0.5, 0.5, 0.5, 0.4}
local EMPTY_COLOR = {0.5, 0.5, 0.5, 0.6}
local SCROLLBAR_COLOR = {0.4, 0.4, 0.4, 0.3}

function m.DrawFavoriteStar(x, y, is_fav)
    helpers.SetColor(is_fav and STAR_ON_COLOR or STAR_OFF_COLOR)
    gfx.setfont(1, "Calibri", 10)
    local star_sym = is_fav and "★" or "☆"
    local sw, sh = gfx.measurestr(star_sym)
    gfx.x, gfx.y = x, y + (ITEM_H - sh) / 2
    gfx.drawstr(star_sym)
end

function m.DrawPresetList(x, y, w, h, files, scroll_offset, selected_idx, last_cap, search_query, type_filter)
    local result = nil
    local right_click_pressed = (gfx.mouse_cap & 2) == 2 and (last_cap & 2) == 0

    -- Filter files by search query (T3)
    local filtered_files = files
    if search_query and #search_query > 0 then
        filtered_files = {}
        local q_lower = search_query:lower()
        for _, f in ipairs(files) do
            if f.name:lower():find(q_lower, 1, true) then
                table.insert(filtered_files, f)
            end
        end
    end

    if not filtered_files or #filtered_files == 0 then
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
    local scroll = math.max(0, math.min(scroll_offset, math.max(0, #filtered_files - max_visible)))
    local start_idx = scroll + 1
    local end_idx = math.min(#filtered_files, scroll + max_visible)

    for i = start_idx, end_idx do
        local item_y = list_y + (i - start_idx) * ITEM_H
        if item_y + ITEM_H > y + h then break end

        local entry = filtered_files[i]
        local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + w
                   and gfx.mouse_y >= item_y and gfx.mouse_y <= item_y + ITEM_H
        local is_selected = preset_store.IsPresetSelected(i)

        if is_selected then
            helpers.SetColor(ITEM_SELECTED)
            gfx.rect(x, item_y, w, ITEM_H, 1)
        elseif hover then
            helpers.SetColor(ITEM_HOVER)
            gfx.rect(x, item_y, w, ITEM_H, 1)
        end

        local is_fav = io_mod.IsFavorite(entry.path)
        local star_x = x + w - STAR_SIZE - 4
        local meta_x = star_x - 18  -- shared by thumbnail and meta icon positioning
        helpers.SetColor(is_fav and STAR_ON_COLOR or STAR_OFF_COLOR)
        gfx.setfont(1, "Calibri", 10)
        local star_sym = is_fav and "★" or "☆"
        local sw, sh = gfx.measurestr(star_sym)
        gfx.x, gfx.y = star_x, item_y + (ITEM_H - sh) / 2
        gfx.drawstr(star_sym)

        -- Thumbnail rendering (8x8 mini-grid, between star and label)
        local thumb_size = 36
        local thumb_x = meta_x - thumb_size - 3
        helpers.SetColor({0.15, 0.15, 0.15, 0.3})
        gfx.rect(thumb_x, item_y + 2, thumb_size, thumb_size, 1)
        local thumb = preset_store.GetThumbnail(entry.path)
        if thumb and #thumb > 0 then
            local cell_w = thumb_size / 8
            local cell_h = thumb_size / 8
            for row = 1, 8 do
                for col = 1, 8 do
                    if thumb[row] and thumb[row][col] then
                        helpers.SetColor({0.4, 0.7, 1, 0.6})
                        gfx.rect(thumb_x + (col-1) * cell_w, item_y + 2 + (row-1) * cell_h, cell_w, cell_h, 1)
                    end
                end
            end
        end

        -- Metadata info "i" icon (v3)
        local meta_hover = hover and gfx.mouse_x >= meta_x and gfx.mouse_x <= meta_x + 14
        if meta_hover then
            helpers.SetColor({0.3, 0.6, 1, 0.8})  -- blue tint on hover
        else
            helpers.SetColor({0.5, 0.5, 0.5, 0.4})
        end
        gfx.setfont(1, "Calibri", 10)
        local mw, _ = gfx.measurestr("i")
        gfx.x, gfx.y = meta_x, item_y + (ITEM_H - sh) / 2
        gfx.drawstr("i")

        local label = entry.name
        if #label > 20 then label = label:sub(1, 18) .. ".." end
        helpers.SetColor(FILE_COLOR)
        gfx.setfont(1, "Calibri", FONT_SIZE)
        local lw, lh = gfx.measurestr(label)
        gfx.x, gfx.y = x + 4, item_y + (ITEM_H - lh) / 2
        gfx.drawstr(label)

        -- Badge rendering based on stats (T1: UX Features)
        local badge_text = nil
        local bw, bh = 0, 0
        local stats = preset_store.GetPresetStat(entry.path)
        if stats then
            local now = os.time()
            local today_start = now - (now % 86400)
            if stats.last_modified and stats.last_modified >= today_start then
                badge_text = "NEW"
                helpers.SetColor({0.2, 0.8, 0.2, 0.7})
            elseif stats.load_count > 50 then
                badge_text = "VETERAN"
                helpers.SetColor({0.9, 0.7, 0.2, 0.7})
            elseif stats.load_count > 10 then
                badge_text = "REGULAR"
                helpers.SetColor({0.3, 0.6, 0.9, 0.7})
            elseif stats.load_count > 1 then
                badge_text = "USED"
                helpers.SetColor({0.6, 0.6, 0.6, 0.5})
            end
        end

        if badge_text then
            gfx.setfont(1, "Calibri", 8)
            bw, bh = gfx.measurestr(badge_text)
            local bx = x + 4 + lw + 4
            if bx + bw + 4 < star_x then
                gfx.rect(bx - 1, item_y + (ITEM_H - bh) / 2 - 1, bw + 2, bh + 2, 1)
                helpers.SetColor({1, 1, 1, 0.8})
                gfx.x, gfx.y = bx, item_y + (ITEM_H - bh) / 2
                gfx.drawstr(badge_text)
            end
        end

        -- Version indicator (T4: UX Features)
        local v_match = entry.name:match("_(v%d+)$")
        if v_match then
            helpers.SetColor({0.5, 0.5, 0.5, 0.4})
            gfx.setfont(1, "Calibri", 8)
            local vt = v_match
            local vw, vh = gfx.measurestr(vt)
            local vx = x + 4 + lw + 4 + (badge_text and (bw + 4) or 0)
            if vx + vw + 4 < star_x then
                gfx.x, gfx.y = vx, item_y + (ITEM_H - vh) / 2
                gfx.drawstr(vt)
            end
        end

        -- Type badge (Phase B: Progression-Only Presets)
        local entry_type = entry.type or "notes"
        local type_badge = entry_type == "progression" and "Prog." or "Notes"
        local type_color = entry_type == "progression"
            and {0.3, 0.7, 0.3, 0.6}   -- green for progression
            or {0.3, 0.5, 0.8, 0.6}    -- blue for notes
        gfx.setfont(1, "Calibri", 8)
        local tbw, tbh = gfx.measurestr(type_badge)
        local tbx = x + 4 + lw + 4 + (badge_text and (bw + 4) or 0) + (v_match and (vw + 4) or 0)
        if tbx + tbw + 4 < star_x then
            helpers.SetColor(type_color)
            gfx.rect(tbx - 1, item_y + (ITEM_H - tbh) / 2 - 1, tbw + 2, tbh + 2, 1)
            helpers.SetColor({1, 1, 1, 0.8})
            gfx.x, gfx.y = tbx, item_y + (ITEM_H - tbh) / 2
            gfx.drawstr(type_badge)
        end

        -- Preview on hover + Ctrl+Click
        if hover and (gfx.mouse_cap & 4) == 4 and ui_store.GetMouseClick() then
            preview_mod.PlayPreview(entry.path)
        end

        -- Lazy thumbnail computation: compute on first hover if not cached
        if hover and not preset_store.GetThumbnail(entry.path) then
            local ok, result = safe_loader.LoadSandboxed(entry.path)
            if ok and result and result.notes then
                local grid = io_mod.ComputeThumbnail(result.notes)
                if grid and #grid > 0 then
                    preset_store.SetThumbnail(entry.path, grid)
                end
            end
        end

        if hover and ui_store.GetMouseClick() then
            if gfx.mouse_x >= meta_x and gfx.mouse_x <= meta_x + 14 then
                -- Open metadata editor for this preset
                io_mod.EditMetadataDialog()
            elseif gfx.mouse_x >= star_x and gfx.mouse_x <= star_x + STAR_SIZE then
                result = "fav:" .. entry.path
            else
                -- Multi-select modifier detection
                if (gfx.mouse_cap & 4) ~= 0 then
                    -- Ctrl+click: toggle individual selection
                    preset_store.TogglePresetSelected(i)
                    result = "multi_select:" .. tostring(i)
                elseif (gfx.mouse_cap & 8) ~= 0 then
                    -- Shift+click: range select from primary to this index
                    local primary = preset_store.GetPrimarySelectedIndex()
                    if primary then
                        local s, e = math.min(primary, i), math.max(primary, i)
                        local new_set = {}
                        for j = s, e do new_set[j] = true end
                        preset_store.SetSelectedIndices(new_set)
                    else
                        preset_store.SetSelectedIndices({[i] = true})
                    end
                    result = "multi_select:" .. tostring(i)
                else
                    -- Regular click: single selection
                    preset_store.SetSelectedIndices({[i] = true})
                    result = "select:" .. tostring(i)
                end
            end
        end

        if hover and right_click_pressed and not (gfx.mouse_x >= star_x and gfx.mouse_x <= star_x + STAR_SIZE) then
            result = "context:" .. tostring(i)
        end
    end

    if #filtered_files > max_visible then
        local sb_x = x + w - 6
        local sb_h = list_h * (max_visible / #filtered_files)
        local sb_y = list_y + (scroll / math.max(1, #filtered_files - max_visible)) * (list_h - sb_h)
        helpers.SetColor(SCROLLBAR_COLOR)
        gfx.rect(sb_x, sb_y, 6, math.max(8, sb_h), 1)
    end

    return scroll, result
end

function m.HandlePresetClick(x, y, w, h, files, scroll_offset, selected_idx, last_cap)
    if not files or #files == 0 then return nil end
    local right_click_pressed = (gfx.mouse_cap & 2) == 2 and (last_cap & 2) == 0
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
        if hover and ui_store.GetMouseClick() then
            local star_x = x + w - STAR_SIZE - 4
            if gfx.mouse_x >= star_x and gfx.mouse_x <= star_x + STAR_SIZE then
                return "fav:" .. entry.path
            end
            if right_click_pressed then
                return "context:" .. tostring(i)
            end
            -- Detect Ctrl modifier for multi-select passthrough
            if (gfx.mouse_cap & 4) ~= 0 then
                return "ctrl_select:" .. tostring(i)
            end
            return "select:" .. tostring(i)
        end
    end
    return nil
end

--- Handle multi-select click logic: Ctrl+click toggles, Shift+click ranges,
--- regular click selects single. Mutates preset_store selection state directly.
--- Returns the clicked index or nil.
--- Intended for use from main.lua before dispatching DrawPresetList results.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param files table Array of file entries
--- @param scroll_offset number Current scroll
--- @return number|nil clicked index
function m.HandleMultiSelectClick(x, y, w, h, files, scroll_offset)
    if not files or #files == 0 then return nil end
    local list_y = y + 1
    local list_h = h - 1
    local max_visible = math.floor(list_h / ITEM_H)
    local scroll = math.max(0, math.min(scroll_offset, math.max(0, #files - max_visible)))
    local start_idx = scroll + 1
    local end_idx = math.min(#files, scroll + max_visible)

    for i = start_idx, end_idx do
        local item_y = list_y + (i - start_idx) * ITEM_H
        if item_y + ITEM_H > y + h then break end
        local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + w
                   and gfx.mouse_y >= item_y and gfx.mouse_y <= item_y + ITEM_H
        if hover and ui_store.GetMouseClick() then
            if (gfx.mouse_cap & 4) ~= 0 then
                -- Ctrl+click: toggle
                preset_store.TogglePresetSelected(i)
            elseif (gfx.mouse_cap & 8) ~= 0 then
                -- Shift+click: range select
                local primary = preset_store.GetPrimarySelectedIndex()
                if primary then
                    local s, e = math.min(primary, i), math.max(primary, i)
                    local new_set = {}
                    for j = s, e do new_set[j] = true end
                    preset_store.SetSelectedIndices(new_set)
                else
                    preset_store.SetSelectedIndices({[i] = true})
                end
            else
                -- Regular click: single select
                preset_store.SetSelectedIndices({[i] = true})
            end
            return i
        end
    end
    return nil
end

function m.HandlePresetListWheel(x, y, w, h, files, scroll_offset)
    if not files or #files == 0 then return scroll_offset end
    if gfx.mouse_x >= x and gfx.mouse_x <= x + w
       and gfx.mouse_y >= y and gfx.mouse_y <= y + h then
        local wheel = ui_store.ConsumeMouseWheelDelta()
        if wheel ~= 0 then
            local max_scroll = math.max(0, #files - math.floor(h / ITEM_H))
            return math.max(0, math.min(max_scroll, scroll_offset - wheel))
        end
    end
    return scroll_offset
end

function m.HandleContextMenu(idx, files, dir)
    local entry = files[idx]
    if not entry then return end

    -- Check if multiple presets are selected → show batch menu
    local sel_count = preset_store.GetSelectionCount()
    if sel_count > 1 then
        local choice = gfx.showmenu("Load Primary|Merge Load All|Export to MIDI|Export "
            .. sel_count .. " as pack...|Delete All")
        if not choice or choice <= 0 then return end

        local sel_indices = preset_store.GetSelectedIndices()
        if choice == 1 then
            -- Load the primary (right-clicked) preset
            if io_mod.LoadPreset(entry.path) then
                island_store.SetNotesState(island_store.NOTES_STATE_LOADED)
                note_store.ClearSelection()
            end
        elseif choice == 2 then
            io_mod.BatchMergeLoadPresets(sel_indices, files)
        elseif choice == 3 then
            io_mod.ExportPresetsToMIDI(sel_indices, files)
        elseif choice == 4 then
            io_mod.ExportPackFromContext(sel_indices, files)
        elseif choice == 5 then
            local count = sel_count
            local ret = reaper.MB("Delete " .. count .. " selected presets?", "Delete Presets", 4)
            if ret == 6 then
                local deleted = io_mod.BatchDeletePresets(sel_indices, files)
                if deleted > 0 then
                    preset_store.ClearSelection()
                    io_mod.RefreshPresets()
                end
            end
        end
        return
    end

    -- Single selection context menu (existing behavior + import pack option)
    local choice = gfx.showmenu("Import pack...|Load|Rename|Duplicate|Delete|Show in Explorer")
    if not choice or choice <= 0 then return end

    if choice == 1 then
        local ret, path = reaper.GetUserInputs("Import Pack", 1, "Pack file path:", "")
        if ret and path and #path > 0 then
            local count = io_mod.ImportPresetsFromPack(path)
            if count > 0 then
                reaper.ShowConsoleMsg("Imported " .. count .. " presets from pack.\n")
            end
        end
    elseif choice == 2 then
        if io_mod.LoadPreset(entry.path) then
            island_store.SetNotesState(island_store.NOTES_STATE_LOADED)
            note_store.ClearSelection()
        end
    elseif choice == 3 then
        io_mod.RenamePreset()
    elseif choice == 4 then
        local dup_path = path_utils.PathJoin(dir, entry.name .. "_copy.grove")
        local f_in = io.open(entry.path, "rb")
        if f_in then
            local content = f_in:read("*all")
            f_in:close()
            local f_out = io.open(dup_path, "wb")
            if f_out then
                f_out:write(content)
                f_out:close()
                io_mod.RefreshPresets()
            end
        end
    elseif choice == 5 then
        if reaper.MB("Delete preset \"" .. entry.name .. "\"?", "Delete Preset", 4) == 6 then
            if io_mod.DeletePreset(entry.path) then
                preset_store.SetSelectedPresetIdx(nil)
                io_mod.RefreshPresets()
            end
        end
    elseif choice == 6 then
        reaper.ExecProcess("explorer.exe /select,\" " .. entry.path .. "\"")
    end
end

function m.LoadFavorites() io_mod.LoadFavorites() end
function m.SaveFavorites() io_mod.SaveFavorites() end

return m
