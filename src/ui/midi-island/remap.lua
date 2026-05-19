-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Remap Modal Overlay
-- 4×7 grid showing current VK→degree mapping, per-cell dropdown,
-- conflict detection, and Reset to Defaults button.
local vkey_map = require("core.vkey-map")
local keyboard = require("core.keyboard")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local ui_store = require("state.ui")
local config = require("config")

local m = {}

-- Visibility state
local _visible = false

function m.SetVisible(v)
    _visible = v
end

function m.GetVisible()
    return _visible
end

-- Physical key labels for the chart (shown in tooltip/row header)
local ROW_NAMES = { "Row 1 (Numbers)", "Row 2 (QWERTYU)", "Row 3 (ASDFGHJ)", "Row 4 (ZXCVBNM)" }

-- Layout constants for the grid
local CELL_W = 72
local CELL_H = 44
local CELL_GAP = 4
local DEG_OCT_OPTIONS = {}

-- Build dropdown options: "deg N, oct N" for all 28 combos
local function BuildDegOctOptions()
    if #DEG_OCT_OPTIONS > 0 then return DEG_OCT_OPTIONS end
    for deg = 1, 7 do
        for o = -2, 1 do
            local label = "deg " .. tostring(deg) .. ", oct " .. tostring(o)
            table.insert(DEG_OCT_OPTIONS, { deg = deg, oct = o, label = label })
        end
    end
    return DEG_OCT_OPTIONS
end

-- Convert a VK code to the key character label
local function VkToChar(vk)
    if vk >= 0x30 and vk <= 0x39 then
        return string.char(vk)
    elseif vk >= 0x41 and vk <= 0x5A then
        return string.char(vk)
    end
    return "?"
end

-- Find which option index matches a given deg+oct
local function FindOptionIndex(deg, oct)
    local opts = BuildDegOctOptions()
    for i, opt in ipairs(opts) do
        if opt.deg == deg and opt.oct == oct then return i end
    end
    return 1
end

-- Show conflict dialog and return true if user confirms override
local function ConfirmConflict(conflict_vk, new_deg, new_oct)
    local conflict_char = VkToChar(conflict_vk)
    local msg = string.format(
        "Key '%s' already maps to deg %d, oct %d.\n\nDo you want to override? The old assignment will be lost.",
        conflict_char, new_deg, new_oct
    )
    local ret = reaper.MB(msg, "Key Mapping Conflict", 4)  -- 4 = Yes/No
    return ret == 6  -- 6 = Yes
end

--- Draw the remap modal overlay.
--- Returns true if the Escape key was consumed (modal will close and main loop
--- should NOT quit), false otherwise.
--- @param x number Left edge of the MIDI island content area
--- @param y number Top edge of the MIDI island content area  
--- @param w number Width available
--- @param h number Height available
--- @param char number The current GFX key character (for Escape detection)
--- @return boolean esc_consumed True if Escape was consumed (don't quit main)
function m.Draw(x, y, w, h, char)
    if not _visible then return false end

    -- Handle Escape to close the modal instead of quitting the script
    if char == 27 then
        _visible = false
        return true  -- Signal to main.lua that Escape was consumed
    end

    -- Dark overlay background
    helpers.SetColor({0.08, 0.08, 0.08, 0.92})
    gfx.rect(x, y, w, h)

    -- Title
    local title = "Key Mapping — Remap Mode"
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", 18)
    local tw, _ = gfx.measurestr(title)
    gfx.x = x + (w - tw) / 2
    gfx.y = y + 12
    gfx.drawstr(title)

    -- Instructions
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 12)
    local instr = "Click any key cell to reassign its degree and octave.  Press ESC to close."
    local iw, _ = gfx.measurestr(instr)
    gfx.x = x + (w - iw) / 2
    gfx.y = y + 36
    gfx.drawstr(instr)

    -- Calculate grid position
    local grid_left = x + 10
    local grid_top = y + 60
    local row_label_w = 16
    local grid_x = grid_left + row_label_w + 6
    local row_data = vkey_map.GetRowData()
    local cur_map = vkey_map.GetVkeyMap()

    -- Draw 4×7 grid
    for row_idx = 1, 4 do
        local row = row_data[row_idx]
        local row_y = grid_top + (row_idx - 1) * (CELL_H + CELL_GAP)

        -- Row label (keyboard row name)
        gfx.setfont(1, "Calibri", 10)
        gfx.x = grid_left
        gfx.y = row_y + math.floor((CELL_H - 12) / 2)
        helpers.SetColor(theme.colors.text_dim)
        gfx.drawstr(ROW_NAMES[row_idx])

        for col_idx = 1, 7 do
            local vk = row.vks[col_idx]
            local key_char = row.key_chars[col_idx]
            local cell_x = grid_x + (col_idx - 1) * (CELL_W + CELL_GAP)

            -- Current mapping for this key
            local entry = cur_map[vk]
            local deg = entry and entry.deg or col_idx
            local oct = entry and entry.oct or 0

            -- Cell background
            local hover = gfx.mouse_x >= cell_x and gfx.mouse_x <= cell_x + CELL_W
                      and gfx.mouse_y >= row_y and gfx.mouse_y <= row_y + CELL_H
            local bg = hover and {0.3, 0.3, 0.3, 0.8} or {0.2, 0.2, 0.2, 0.7}
            helpers.SetColor(bg)
            gfx.rect(cell_x, row_y, CELL_W, CELL_H, 1)

            -- Border
            helpers.SetColor({0.4, 0.4, 0.4, 0.6})
            gfx.rect(cell_x, row_y, CELL_W, 1, 0)  -- top
            gfx.rect(cell_x, row_y + CELL_H - 1, CELL_W, 1, 0)  -- bottom
            gfx.rect(cell_x, row_y, 1, CELL_H, 0)  -- left
            gfx.rect(cell_x + CELL_W - 1, row_y, 1, CELL_H, 0)  -- right

            -- Key character label (top left)
            helpers.SetColor(theme.colors.text)
            gfx.setfont(1, "Calibri", 14)
            gfx.x = cell_x + 4
            gfx.y = row_y + 3
            gfx.drawstr(key_char)

            -- Degree/octave value (centered)
            helpers.SetColor(theme.colors.text)
            gfx.setfont(1, "Calibri", 13)
            local val_str = "deg " .. tostring(deg) .. "\noct " .. tostring(oct)
            gfx.x = cell_x + math.floor((CELL_W - 20) / 2)
            gfx.y = row_y + 16
            gfx.drawstr(val_str)

            -- Click handler: open deg/oct dropdown
            if ui_store.GetMouseClick() and hover then
                local opts = BuildDegOctOptions()
                local menu_strs = {}
                for i, opt in ipairs(opts) do
                    table.insert(menu_strs, opt.label)
                end
                local menu = table.concat(menu_strs, "|")

                local choice = gfx.showmenu(menu)
                if choice and choice > 0 then
                    local selected = opts[choice]
                    if selected then
                        -- Check for conflict BEFORE applying (spec: mapping must not
                        -- be applied until user confirms override)
                        local conflict_key = nil
                        for k, v in pairs(cur_map) do
                            if k ~= vk and v.deg == selected.deg and v.oct == selected.oct then
                                conflict_key = k
                                break
                            end
                        end

                        local should_apply = true
                        if conflict_key then
                            should_apply = ConfirmConflict(conflict_key, selected.deg, selected.oct)
                        end

                        if should_apply then
                            vkey_map.SetEntry(vk, selected.deg, selected.oct)
                            keyboard.RebuildKeyStates()
                        end
                    end
                end
                ui_store.ConsumeMouseClick()
            end
        end
    end

    -- Reset to Defaults button
    local btn_y = grid_top + 4 * (CELL_H + CELL_GAP) + 12
    local btn_w = 160
    local btn_h = 30
    local btn_x = x + (w - btn_w) / 2
    local rst_hover = gfx.mouse_x >= btn_x and gfx.mouse_x <= btn_x + btn_w
                   and gfx.mouse_y >= btn_y and gfx.mouse_y <= btn_y + btn_h

    -- Check if currently modified (for visual hint)
    local is_modified = vkey_map.IsModified()

    -- Reset button
    local rst_bg = rst_hover and {0.5, 0.15, 0.15, 0.9} or (is_modified and {0.4, 0.12, 0.12, 0.8} or {0.25, 0.25, 0.25, 0.7})
    helpers.SetColor(rst_bg)
    gfx.rect(btn_x, btn_y, btn_w, btn_h, 1)
    helpers.SetColor(rst_hover and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 14)
    local rst_label = is_modified and "Reset to Defaults" or "Defaults (no changes)"
    local rw, _ = gfx.measurestr(rst_label)
    gfx.x = btn_x + (btn_w - rw) / 2
    gfx.y = btn_y + (btn_h - 14) / 2
    gfx.drawstr(rst_label)

    if ui_store.GetMouseClick() and rst_hover and is_modified then
        local ret = reaper.MB("Reset all key mappings to defaults?\n\nThis will discard any custom assignments.", "Reset to Defaults", 4)
        if ret == 6 then
            vkey_map.ResetToDefaults()
            keyboard.RebuildKeyStates()
        end
        ui_store.ConsumeMouseClick()
    end

    -- Close hint at the bottom
    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 11)
    local close_hint = "Press ESC to close"
    local chw, _ = gfx.measurestr(close_hint)
    gfx.x = x + (w - chw) / 2
    gfx.y = btn_y + btn_h + 8
    gfx.drawstr(close_hint)

    return false
end

return m
