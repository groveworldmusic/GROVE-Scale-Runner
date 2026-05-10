-- GROVE FL MIDI: Button UI Components (extracted from components.lua)
local config = require("config")
local helpers = require("ui.helpers")
local theme = require("ui.theme")

-- NOTE: `components` (for DrawRoundedRect) is resolved lazily inside each function
-- to avoid circular require at load time (components.lua also requires buttons.lua)

local m = {}

function m.DrawToolIcon(type, x, y, size, active)
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + size and gfx.mouse_y >= y and gfx.mouse_y <= y + size
    helpers.SetColor(active and theme.colors.btn_active or (hover and theme.colors.text or theme.colors.text_dim))
    
    local r = size / 2
    if type == "settings" then
        -- Gear Icon
        gfx.circle(x+r, y+r, r*0.5, 0, 1)
        for i=0, 7 do
            local ang = i * (math.pi/4)
            gfx.line(x+r + math.cos(ang)*r*0.5, y+r + math.sin(ang)*r*0.5, 
                     x+r + math.cos(ang)*r*0.9, y+r + math.sin(ang)*r*0.9)
        end
    elseif type == "view" then
        -- View Mode Icon (Minimal/Full toggle)
        local padding = size * 0.2
        gfx.rect(x + padding, y + padding, size - padding*2, size - padding*2, 0)
        gfx.line(x + padding, y + size/2, x + size - padding, y + size/2)
    elseif type == "help" then
        -- Help Icon (?) — círculo con signo, mismo estilo que settings/view
        gfx.circle(x+r, y+r, r*0.65, 0, 1)
        gfx.setfont(1, "Calibri", math.floor(size * 0.75))
        local qw, qh = gfx.measurestr("?")
        gfx.x, gfx.y = x + (size - qw)/2, y + (size - qh)/2 - 1
        gfx.drawstr("?")
    elseif type == "scroll" then
        -- Scroll Icon (up/down arrows)
        local cx, cy = x + r, y + r
        local a = size * 0.3
        -- Up arrow
        gfx.line(cx, cy - a*0.7, cx - a*0.5, cy - a*0.2)
        gfx.line(cx, cy - a*0.7, cx + a*0.5, cy - a*0.2)
        -- Down arrow
        gfx.line(cx, cy + a*0.7, cx - a*0.5, cy + a*0.2)
        gfx.line(cx, cy + a*0.7, cx + a*0.5, cy + a*0.2)
    elseif type == "clear" then
        -- Trash can outline (centrado verticalmente)
        local padding = size * 0.2
        local body_w = size - padding * 2
        local body_h = size * 0.48
        local body_x = x + padding
        local body_y = y + size * 0.30

        -- Lid line
        local lid_y = body_y - size * 0.04
        gfx.line(body_x - size * 0.06, lid_y, body_x + body_w + size * 0.06, lid_y)

        -- Handles on lid
        local hw = size * 0.12
        gfx.line(body_x + body_w * 0.28, lid_y, body_x + body_w * 0.28, y + size * 0.16)
        gfx.line(body_x + body_w * 0.72, lid_y, body_x + body_w * 0.72, y + size * 0.16)
        gfx.line(body_x + body_w * 0.28, y + size * 0.16, body_x + body_w * 0.72, y + size * 0.16)

        -- Body (rect open top)
        gfx.rect(body_x, body_y, body_w, body_h, 0)

        -- Inner vertical lines
        gfx.line(body_x + body_w * 0.3, body_y + size * 0.06, body_x + body_w * 0.3, body_y + body_h - size * 0.06)
        gfx.line(body_x + body_w * 0.5, body_y + size * 0.06, body_x + body_w * 0.5, body_y + body_h - size * 0.06)
        gfx.line(body_x + body_w * 0.7, body_y + size * 0.06, body_x + body_w * 0.7, body_y + body_h - size * 0.06)
    elseif type == "export" then
        -- Arrow up from tray (centrado verticalmente)
        local cx = x + size / 2
        local bottom = y + size - size * 0.22  -- tray un poco más arriba

        -- Tray (horizontal line with small vertical edges)
        gfx.line(x + size * 0.1, bottom, x + size * 0.9, bottom)
        gfx.line(x + size * 0.1, bottom, x + size * 0.1, bottom - size * 0.04)
        gfx.line(x + size * 0.9, bottom, x + size * 0.9, bottom - size * 0.04)

        -- Arrow shaft
        gfx.line(cx, bottom - size * 0.04, cx, y + size * 0.19)

        -- Arrow head
        gfx.line(cx, y + size * 0.19, cx - size * 0.22, y + size * 0.36)
        gfx.line(cx, y + size * 0.19, cx + size * 0.22, y + size * 0.36)
    end
    
    return config.state.mouse_click and hover
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
    local pressed = hover and config.state.mouse_click

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

    return not config.state.drag.is_dragging and config.state.mouse_click and hover
end

function m.DrawTransportButton(label, x, y, w, h)
    local components = require("ui.components")
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + w and gfx.mouse_y >= y and gfx.mouse_y <= y + h

    helpers.SetColor(hover and theme.colors.btn_hover or theme.colors.btn_bg)
    components.DrawRoundedRect(x, y, w, h, 6, true)

    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 11)
    local lw, lh = gfx.measurestr(label)
    gfx.x, gfx.y = x + (w - lw) / 2, y + (h - lh) / 2
    gfx.drawstr(label)

    return config.state.mouse_click and hover
end

return m
