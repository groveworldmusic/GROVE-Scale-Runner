-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Button UI Components (extracted from components.lua)
local config = require("config")
local drag_store = require("state.drag")
local ui_store = require("state.ui")
local helpers = require("ui.helpers")
local theme = require("ui.theme")

-- NOTE: `components` (for DrawRoundedRect) is resolved lazily inside each function
-- to avoid circular require at load time (components.lua also requires buttons.lua)

local m = {}

function m.DrawToolIcon(type, x, y, size, active)
    local components = require("ui.components")
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + size and gfx.mouse_y >= y and gfx.mouse_y <= y + size
    
    -- Glyph mapping for 5 supported icon types
    local glyphs = {
        help = "?",
        settings = "\226\154\153",  -- U+2699 ⚙
        view = "\226\138\158",       -- U+229E ⊞
        clear = "\226\156\149",      -- U+2715 ✕
        export = "\226\134\151",     -- U+2197 ↗
    }
    local glyph = glyphs[type]
    if not glyph then
        return ui_store.GetMouseClick() and hover
    end
    
    -- Background color: active → btn_active, hover(not active) → btn_hover, default → island_bg
    local bg_color = active and theme.colors.btn_active or (hover and theme.colors.btn_hover or theme.colors.island_bg)
    helpers.SetColor(bg_color)
    components.DrawRoundedRect(x, y, size, size, math.floor(size / 4), true)
    
    -- Glyph color: active → text, else → text_dim (matching MIDI island header pattern)
    local glyph_color = active and theme.colors.text or theme.colors.text_dim
    helpers.SetColor(glyph_color)
    
    -- Font state isolation: set font before every measurestr/drawstr
    gfx.setfont(1, "Calibri", math.floor(size * 0.75))
    local gw, gh = gfx.measurestr(glyph)
    gfx.x, gfx.y = x + (size - gw) / 2, y + (size - gh) / 2
    gfx.drawstr(glyph)
    
    return ui_store.GetMouseClick() and hover
end

function m.DrawNoteDisplay(x, y, w, h, note)
    local components = require("ui.components")
    helpers.SetColor(theme.colors.bg)
    components.DrawRoundedRect(x, y, w, h, 6, true)
    
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", math.floor(h * 0.7))
    local note_str = note == "None" and "-" or note
    local nw, nh = gfx.measurestr(note_str)
    gfx.x, gfx.y = x + (w - nw) / 2, y + (h - nh) / 2
    gfx.drawstr(note_str)
end

function m.DrawButton(x, y, w, h, label, active, font_size)
    local components = require("ui.components")
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    local is_mouse_down = (gfx.mouse_cap & 1) == 1
    local pressed = hover and is_mouse_down

    -- 1. Base background: btn_bg or btn_active
    helpers.SetColor(active and theme.colors.btn_active or theme.colors.btn_bg)
    components.DrawRoundedRect(x, y, w, h, 6, true)

    -- 2. Stroke on inactive buttons (rounded outline)
    if not active then
        helpers.SetColor(theme.colors.text_dim, 0.25)
        gfx.roundrect(x, y, w, h, 6, 0)
    end

    -- 3. Hover overlay (white semi-transparent instead of swapping bg)
    if hover and not active then
        helpers.SetColor({1, 1, 1, 0.08})
        components.DrawRoundedRect(x, y, w, h, 6, true)
    end

    -- 4. Press effect: darker top half shadow + text offset
    if pressed then
        helpers.SetColor({0, 0, 0, 0.15})
        gfx.rect(x, y, w, math.floor(h/2), 1)
    end

    -- 5. Active toggle: subtle white inner border (rounded)
    if active then
        helpers.SetColor({1, 1, 1, 0.2})
        components.DrawRoundedRect(x+1, y+1, w-2, h-2, 5, true)
        helpers.SetColor(theme.colors.btn_active)
        components.DrawRoundedRect(x+2, y+2, w-4, h-4, 4, true)
    end

    -- Label (pressed offset: +1px down)
    helpers.SetColor(active and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", font_size or 12)
    local sw, sh = gfx.measurestr(label)
    local off = pressed and 1 or 0
    gfx.x, gfx.y = x+(w-sw)/2, y+(h-sh)/2 + off
    gfx.drawstr(label)

    return not drag_store.GetIsDragging() and ui_store.GetMouseClick() and hover
end

function m.DrawTransportButton(label, x, y, w, h)
    local components = require("ui.components")
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + w and gfx.mouse_y >= y and gfx.mouse_y <= y + h
    local is_mouse_down = (gfx.mouse_cap & 1) == 1
    local pressed = hover and is_mouse_down

    helpers.SetColor(pressed and theme.colors.btn_active or (hover and theme.colors.btn_hover or theme.colors.btn_bg))
    components.DrawRoundedRect(x, y, w, h, 6, true)

    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 11)
    local lw, lh = gfx.measurestr(label)
    local off = pressed and 1 or 0
    gfx.x, gfx.y = x + (w - lw) / 2, y + (h - lh) / 2 + off
    gfx.drawstr(label)

    return ui_store.GetMouseClick() and hover
end

return m
