-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
-- GROVE Scale Runner: Dropdown UI Component (extracted from components.lua)
local config = require("config")
local ui_store = require("state.ui")
local helpers = require("ui.helpers")
local theme = require("ui.theme")

-- NOTE: `components` (for DrawRoundedRect) is resolved lazily inside each function
-- to avoid circular require at load time (components.lua also requires dropdown.lua)

local m = {}

function m.DrawDropdown(x, y, w, h, label, value, options, current_index, font_size, open_up)
    local components = require("ui.components")
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    helpers.SetColor(theme.colors.bg)
    components.DrawRoundedRect(x, y, w, h, 6, true)
    
    -- Adaptive Text Logic: progressive font reduction, then dynamic truncation
    local function GetFitText(str, max_w, f_size)
        local s = str:gsub("%s*%b()", "")
        -- Try full size first
        gfx.setfont(1, "Calibri", f_size)
        if gfx.measurestr(s) <= max_w then return s, f_size end
        -- Step down font size until it fits
        for size = f_size - 1, 8, -1 do
            gfx.setfont(1, "Calibri", size)
            if gfx.measurestr(s) <= max_w then return s, size end
        end
        -- Truncate at smallest font
        gfx.setfont(1, "Calibri", 8)
        for len = #s - 1, 1, -1 do
            local t = s:sub(1, len) .. ".."
            if gfx.measurestr(t) <= max_w then return t, 8 end
        end
        return "..", 8
    end

    local final_text, final_size = GetFitText(value, w - 25, font_size or 12)
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", final_size)
    local vw, vh = gfx.measurestr(final_text)
    gfx.x, gfx.y = x + 10, y + (h-vh)/2
    gfx.drawstr(final_text)
    
    helpers.SetColor(theme.colors.btn_active)
    local cx, cy = x + w - 15, y + h/2
    for i=0, 1 do
        gfx.line(cx-4, cy-2+i, cx, cy+2+i, 1)
        gfx.line(cx, cy+2+i, cx+4, cy-2+i, 1)
    end
    
    -- Scroll wheel selection
    if hover and ui_store.GetUseScroll() and ui_store.GetMouseWheelDelta() ~= 0 then
        local delta = ui_store.GetMouseWheelDelta() > 0 and -1 or 1
        ui_store.SetMouseWheelDelta(0)
        local new_idx = current_index + delta
        if new_idx < 1 then new_idx = #options end
        if new_idx > #options then new_idx = 1 end
        return new_idx
    end
    
    if hover and ui_store.GetMouseClick() then
        local menu_str = ""
        for i, opt in ipairs(options) do
            local safe_opt = opt:gsub("|", "·")
            menu_str = menu_str .. (i == current_index and "!" or "") .. safe_opt .. "|"
        end
        if open_up then
            gfx.x, gfx.y = x, y
        else
            gfx.x, gfx.y = x, y + h
        end
        local choice = gfx.showmenu(menu_str:sub(1, -2))
        if choice > 0 then return choice end
    end
    return nil
end

return m
