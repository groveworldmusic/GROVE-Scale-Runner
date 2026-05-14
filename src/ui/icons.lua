-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- Centralized icon rendering for GROVE Scale Runner
-- Dispatches to procedural GFX or Unicode gfx.drawstr by icon type.

local ui_store = require("state.ui")
local helpers = require("ui.helpers")
local theme = require("ui.theme")

local m = {}

function m.DrawIcon(type, x, y, size, active, color)
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + size and gfx.mouse_y >= y and gfx.mouse_y <= y + size
    local col = color or (active and theme.colors.btn_active or (hover and theme.colors.text or theme.colors.text_dim))
    helpers.SetColor(col)

    local r = size / 2

    if type == "settings" then
        -- Gear: outer circle + 8 teeth
        gfx.circle(x + r, y + r, r * 0.5, 0, 1)
        for i = 0, 7 do
            local ang = i * (math.pi / 4)
            gfx.line(
                x + r + math.cos(ang) * r * 0.5, y + r + math.sin(ang) * r * 0.5,
                x + r + math.cos(ang) * r * 0.9, y + r + math.sin(ang) * r * 0.9
            )
        end

    elseif type == "view" then
        -- View toggle: two side-by-side rects (split panel)
        local padding = size * 0.2
        gfx.rect(x + padding, y + padding, size - padding * 2, size - padding * 2, 0)
        gfx.line(x + padding, y + size / 2, x + size - padding, y + size / 2)

    elseif type == "help" then
        -- Help: circle with "?" inside
        gfx.circle(x + r, y + r, r * 0.65, 0, 1)
        gfx.setfont(1, "Calibri", math.floor(size * 0.75))
        local qw, qh = gfx.measurestr("?")
        gfx.x, gfx.y = x + (size - qw) / 2, y + (size - qh) / 2 - 1
        gfx.drawstr("?")

    elseif type == "scroll" then
        -- Scroll: up/down arrows
        local cx, cy = x + r, y + r
        local a = size * 0.3
        gfx.line(cx, cy - a * 0.7, cx - a * 0.5, cy - a * 0.2)
        gfx.line(cx, cy - a * 0.7, cx + a * 0.5, cy - a * 0.2)
        gfx.line(cx, cy + a * 0.7, cx - a * 0.5, cy + a * 0.2)
        gfx.line(cx, cy + a * 0.7, cx + a * 0.5, cy + a * 0.2)

    elseif type == "clear" then
        -- Trash can
        local padding = size * 0.2
        local body_w = size - padding * 2
        local body_h = size * 0.48
        local body_x = x + padding
        local body_y = y + size * 0.30
        local lid_y = body_y - size * 0.04
        gfx.line(body_x - size * 0.06, lid_y, body_x + body_w + size * 0.06, lid_y)
        local hw = size * 0.12
        gfx.line(body_x + body_w * 0.28, lid_y, body_x + body_w * 0.28, y + size * 0.16)
        gfx.line(body_x + body_w * 0.72, lid_y, body_x + body_w * 0.72, y + size * 0.16)
        gfx.line(body_x + body_w * 0.28, y + size * 0.16, body_x + body_w * 0.72, y + size * 0.16)
        gfx.rect(body_x, body_y, body_w, body_h, 0)
        gfx.line(body_x + body_w * 0.3, body_y + size * 0.06, body_x + body_w * 0.3, body_y + body_h - size * 0.06)
        gfx.line(body_x + body_w * 0.5, body_y + size * 0.06, body_x + body_w * 0.5, body_y + body_h - size * 0.06)
        gfx.line(body_x + body_w * 0.7, body_y + size * 0.06, body_x + body_w * 0.7, body_y + body_h - size * 0.06)

    elseif type == "export" then
        -- Arrow up from tray
        local cx = x + size / 2
        local bottom = y + size - size * 0.22
        gfx.line(x + size * 0.1, bottom, x + size * 0.9, bottom)
        gfx.line(x + size * 0.1, bottom, x + size * 0.1, bottom - size * 0.04)
        gfx.line(x + size * 0.9, bottom, x + size * 0.9, bottom - size * 0.04)
        gfx.line(cx, bottom - size * 0.04, cx, y + size * 0.19)
        gfx.line(cx, y + size * 0.19, cx - size * 0.22, y + size * 0.36)
        gfx.line(cx, y + size * 0.19, cx + size * 0.22, y + size * 0.36)

    elseif type == "prev" then
        -- Previous page: ◀ (U+25C0)
        gfx.setfont(1, "Calibri", size)
        local pw, ph = gfx.measurestr("◀")
        gfx.x, gfx.y = x + (size - pw) / 2, y + (size - ph) / 2
        gfx.drawstr("◀")

    elseif type == "next" then
        -- Next page: ▶ (U+25B6)
        gfx.setfont(1, "Calibri", size)
        local nw, nh = gfx.measurestr("▶")
        gfx.x, gfx.y = x + (size - nw) / 2, y + (size - nh) / 2
        gfx.drawstr("▶")

    elseif type == "up" then
        -- Up/back navigation: ⬆ (U+2B06)
        gfx.setfont(1, "Calibri", size)
        local uw, uh = gfx.measurestr("⬆")
        gfx.x, gfx.y = x + (size - uw) / 2, y + (size - uh) / 2
        gfx.drawstr("⬆")
    end

    local clicked = ui_store.GetMouseClick() and hover
    if clicked then ui_store.ConsumeMouseClick() end
    return clicked
end

return m
