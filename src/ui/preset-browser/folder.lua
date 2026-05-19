-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Preset Browser — Folder Module
-- Handles rendering and interaction for the folder tree in the preset browser.

local theme = require("ui.theme")
local helpers = require("ui.helpers")
local ui_store = require("state.ui")
local components = require("ui.components")

local m = {}

-- Constants (matching preset-browser.lua)
local ITEM_H = 22
local FOLDER_ICON_W = 16
local HEADER_H = 28
local FONT_SIZE = 13
local HEADER_BG = {0.22, 0.22, 0.22, 1}
local ITEM_HOVER = {0.35, 0.35, 0.35, 0.4}
local FOLDER_COLOR = {0.6, 0.6, 0.7, 0.9}
local SCROLLBAR_COLOR = {0.4, 0.4, 0.4, 0.3}

--- Draw the folder navigation header.
--- @param x number
--- @param y number
--- @param w number
--- @param path string Current directory path
--- @return string|nil "up" if user clicked the up button
function m.DrawFolderHeader(x, y, w, path)
    -- Rounded top bar to match panel corners
    helpers.SetColor(HEADER_BG)
    components.DrawRoundedRectEx(x, y, w, HEADER_H, 10, {tl=true, tr=true})

    -- Up button (..)
    local up_x = x + 4
    local up_w = 24
    local up_hover = gfx.mouse_x >= up_x and gfx.mouse_x <= up_x + up_w
                  and gfx.mouse_y >= y and gfx.mouse_y <= y + HEADER_H
    helpers.SetColor(up_hover and theme.colors.text_dim or theme.colors.text)
    gfx.setfont(1, "Calibri", FONT_SIZE)
    local iw, ih = gfx.measurestr("..")
    gfx.x, gfx.y = up_x + 4, y + (HEADER_H - ih) / 2
    gfx.drawstr("..")

    -- Current folder name (truncated)
    local dir_name = path:match([=[([^\\]+)$]=]) or path
    if #dir_name > 18 then
        dir_name = dir_name:sub(1, 16) .. ".."
    end
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", FONT_SIZE)
    local lw, lh = gfx.measurestr(dir_name)
    local label_x = up_x + up_w + 8
    gfx.x, gfx.y = label_x, y + (HEADER_H - lh) / 2
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
--- @return number new_scroll_offset
--- @return number total_height
function m.DrawFolderList(x, y, w, max_h, dirs, scroll_offset)
    if not dirs or #dirs == 0 then
        return scroll_offset, 0
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
        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", FONT_SIZE)
        local lw, lh = gfx.measurestr(label)
        gfx.x, gfx.y = x + FOLDER_ICON_W + 8, item_y + (ITEM_H - lh) / 2
        gfx.drawstr(label)
    end

    -- Draw scrollbar if needed
    if #dirs > max_visible then
        local sb_x = x + w - 6
        local sb_h = max_h * (max_visible / #dirs)
        local sb_y = y + (scroll / math.max(1, #dirs - max_visible)) * (max_h - sb_h)
        helpers.SetColor(SCROLLBAR_COLOR)
        gfx.rect(sb_x, sb_y, 6, math.max(8, sb_h), 1)
    end

    return scroll, total_h
end

--- Handle folder navigation click.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param dirs table
--- @param scroll_offset number
--- @return string|nil "navigate:path" if folder was clicked
function m.HandleFolderClick(x, y, w, h, dirs, scroll_offset)
    if not dirs or #dirs == 0 then return nil end

    local max_visible = math.floor(h / ITEM_H)
    local scroll = math.max(0, math.min(scroll_offset, math.max(0, #dirs - max_visible)))
    local start_idx = scroll + 1
    local end_idx = math.min(#dirs, scroll + max_visible)

    for i = start_idx, end_idx do
        local item_y = y + (i - start_idx) * ITEM_H
        if item_y + ITEM_H > y + h then break end
        local entry = dirs[i]
        local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + w
                   and gfx.mouse_y >= item_y and gfx.mouse_y <= item_y + ITEM_H

        if hover and ui_store.GetMouseClick() then
            return "navigate:" .. entry.path
        end
    end
    return nil
end

--- Handle folder list scroll wheel.
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param dirs table
--- @param scroll_offset number
--- @return number new_scroll_offset
function m.HandleFolderWheel(x, y, w, h, dirs, scroll_offset)
    if not dirs or #dirs == 0 then return scroll_offset end

    if gfx.mouse_x >= x and gfx.mouse_x <= x + w
       and gfx.mouse_y >= y and gfx.mouse_y <= y + h then
        local wheel = ui_store.ConsumeMouseWheelDelta()
        if wheel ~= 0 then
            local max_scroll = math.max(0, #dirs - math.floor(h / ITEM_H))
            return math.max(0, math.min(max_scroll, scroll_offset - wheel))
        end
    end
    return scroll_offset
end

return m
