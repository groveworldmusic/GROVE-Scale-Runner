-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Dropdown UI Component (extracted from components.lua)
local config = require("config")
local ui_store = require("state.ui")
local helpers = require("ui.helpers")
local theme = require("ui.theme")

-- NOTE: `components` (for DrawRoundedRect) is resolved lazily inside each function
-- to avoid circular require at load time (components.lua also requires dropdown.lua)

-- GetFitText cache: keyed by (str, max_w, font_size). The displayed dropdown
-- value rarely changes between frames, so a single-entry cache saves ~36
-- gfx.measurestr calls per frame when the value is stable.
local _fit_cache_key = ""
local _fit_cache_result = nil

local m = {}

function m.DrawDropdown(x, y, w, h, label, value, options, current_index, font_size)
    local components = require("ui.components")
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    helpers.SetColor(theme.colors.bg)
    components.DrawRoundedRect(x, y, w, h, 6, true)
    
    -- Adaptive Text Logic: progressive font reduction, then dynamic truncation
    -- Single-entry cache: (str, max_w, font_size) rarely changes between frames.
    local function GetFitText(str, max_w, f_size)
        local ck = str .. "|" .. tostring(max_w) .. "|" .. tostring(f_size)
        if _fit_cache_key == ck then return _fit_cache_result[1], _fit_cache_result[2] end
        
        local s = str:gsub("%s*%b()", "")
        local r1, r2
        -- Try full size first
        gfx.setfont(1, "Calibri", f_size)
        if gfx.measurestr(s) <= max_w then r1, r2 = s, f_size end
        if not r1 then
            -- Step down font size until it fits
            for size = f_size - 1, 8, -1 do
                gfx.setfont(1, "Calibri", size)
                if gfx.measurestr(s) <= max_w then r1, r2 = s, size; break end
            end
        end
        if not r1 then
            -- Truncate at smallest font
            gfx.setfont(1, "Calibri", 8)
            for len = #s - 1, 1, -1 do
                local t = s:sub(1, len) .. ".."
                if gfx.measurestr(t) <= max_w then r1, r2 = t, 8; break end
            end
        end
        if not r1 then r1, r2 = "..", 8 end
        _fit_cache_key, _fit_cache_result = ck, {r1, r2}
        return r1, r2
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
    
    -- Scroll wheel selection (clamped to bounds, no wrap)
    if hover and ui_store.GetUseScroll() then
        local raw = ui_store.ConsumeMouseWheelDelta()
        if raw ~= 0 then
            local dir = raw > 0 and -1 or 1
            local new_idx = math.max(1, math.min(#options, current_index + dir))
            if new_idx ~= current_index then
                return new_idx
            end
        end
    end
    
    if hover and ui_store.GetMouseClick() then
        local menu_str = ""
        for i, opt in ipairs(options) do
            local safe_opt = opt:gsub("|", "·")
            menu_str = menu_str .. (i == current_index and "!" or "") .. safe_opt .. "|"
        end
        local choice = gfx.showmenu(menu_str:sub(1, -2))
        if choice > 0 then return choice end
    end
    return nil
end

return m
