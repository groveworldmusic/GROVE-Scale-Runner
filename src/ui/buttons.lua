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
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + size and gfx.mouse_y >= y and gfx.mouse_y <= y + size
    local col = active and theme.colors.text or theme.colors.text_dim
    local cx, cy = x + size / 2, y + size / 2
    
    -- Glyph-based icons (Unicode)
    local glyphs = { help = "?", settings = "\226\154\153", view = "\226\138\159" }  -- ? ⚙ ⊟
    local glyph = glyphs[type]
    if glyph then
        helpers.SetColor(col)
        gfx.setfont(1, "Calibri", math.floor(size * 0.75))
        local gw, gh = gfx.measurestr(glyph)
        gfx.x, gfx.y = x + (size - gw) / 2, y + (size - gh) / 2
        gfx.drawstr(glyph)
        return ui_store.GetMouseClick() and hover
    end
    
    -- Procedural icons (no suitable Unicode glyph)
    if type == "clear" then
        -- Trash can: lid + body outline
        helpers.SetColor(col)
        local pad = size * 0.22
        local bw = size - pad * 2
        local bh = size * 0.42
        local bx = x + pad
        local by = y + size * 0.34
        -- Lid line
        gfx.line(bx - size * 0.04, by - size * 0.04, bx + bw + size * 0.04, by - size * 0.04)
        -- Handle
        gfx.line(bx + bw * 0.3, by - size * 0.04, bx + bw * 0.3, y + size * 0.16)
        gfx.line(bx + bw * 0.7, by - size * 0.04, bx + bw * 0.7, y + size * 0.16)
        gfx.line(bx + bw * 0.3, y + size * 0.16, bx + bw * 0.7, y + size * 0.16)
        -- Body outline (open top)
        gfx.line(bx, by, bx, by + bh)
        gfx.line(bx + bw, by, bx + bw, by + bh)
        gfx.line(bx, by + bh, bx + bw, by + bh)
        -- Two inner vertical lines
        gfx.line(bx + bw * 0.3, by + size * 0.05, bx + bw * 0.3, by + bh - size * 0.05)
        gfx.line(bx + bw * 0.7, by + size * 0.05, bx + bw * 0.7, by + bh - size * 0.05)
        return ui_store.GetMouseClick() and hover
    end
    
    if type == "export" then
        -- Piano keyboard: white key body + black keys
        helpers.SetColor(col)
        local kw = size * 0.56
        local kh = size * 0.52
        local kx = cx - kw / 2
        local ky = cy - kh / 2 + size * 0.05
        -- White keys body (3 horizontal lines: top, bottom, bottom outline)
        gfx.line(kx, ky, kx + kw, ky)
        gfx.line(kx, ky + kh, kx + kw, ky + kh)
        gfx.line(kx, ky, kx, ky + kh)
        gfx.line(kx + kw, ky, kx + kw, ky + kh)
        -- White key dividers (vertical lines)
        local wkeys = 6
        for i = 1, wkeys - 1 do
            local xk = kx + (i / wkeys) * kw
            gfx.line(xk, ky, xk, ky + kh)
        end
        -- Black keys (shorter rects at top)
        local bk_w = kw / wkeys * 0.6
        local bk_h = kh * 0.55
        for i = 0, 4 do
            local bxk = kx + ((i + 0.5) / wkeys) * kw - bk_w / 2
            gfx.rect(bxk, ky, bk_w, bk_h, 1)
        end
        return ui_store.GetMouseClick() and hover
    end
    
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
