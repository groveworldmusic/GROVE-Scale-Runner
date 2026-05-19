-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local buttons = require("ui.buttons")
local paginator = require("ui.paginator")
local dropdown = require("ui.dropdown")
local piano = require("ui.piano")
local pads = require("ui.pads")
local slots = require("ui.slots")
local drag = require("ui.drag")

local components = {}

-- Persistent state for Alpha-Safe rendering (Smart Buffer Management)
local _temp_buf = 1023
local _temp_buf_w, _temp_buf_h = -1, -1

--- Ensures the drawing destination is restored even if an error occurs.
local function SafeDraw(func, ...)
    local old_dest = gfx.dest
    local ok, err = pcall(func, ...)
    gfx.dest = old_dest
    if not ok then reaper.ShowConsoleMsg("Render Error: " .. tostring(err) .. "\n") end
    return ok
end

function components.DrawIsland(x, y, w, h, title, font_size)
    helpers.SetColor(theme.colors.island_bg)
    components.DrawRoundedRect(x, y, w, h, 10, true)
    
    if title then
        helpers.SetColor(theme.colors.text_dim)
        gfx.setfont(1, "Calibri", font_size or 12)
        local tw, th = gfx.measurestr(title)
        gfx.x, gfx.y = x + (w - tw)/2, y + math.floor((font_size or 12) * 0.5)
        gfx.drawstr(title)
    end
end

function components.DrawRoundedRect(x, y, w, h, r, fill)
    if r <= 0 then gfx.rect(x,y,w,h,1) return end
    r = math.min(r, w/2, h/2)
    
    if fill then
        local gr, gg, gb = gfx.r, gfx.g, gfx.b
        local a = gfx.a
        if a >= 0.99 then
            -- Opaque fast path: +1 overshoot on rects prevents 1px seams at
            -- rect-circle boundaries. REAPER gfx.circle anti-aliasing leaves
            -- gaps when two shapes meet at an exact edge — the overshoots
            -- make rects overlap circles by 1px, filling those gaps.
            gfx.circle(x + r, y + r, r, 1, 1)
            gfx.circle(x + w - r, y + r, r, 1, 1)
            gfx.circle(x + r, y + h - r, r, 1, 1)
            gfx.circle(x + w - r, y + h - r, r, 1, 1)
            gfx.rect(x, y + r, w + 1, math.max(0, h - r * 2) + 1, 1)
            gfx.rect(x + r, y, math.max(0, w - r * 2) + 1, r + 1, 1)
            gfx.rect(x + r, y + h - r, math.max(0, w - r * 2) + 1, r + 1, 1)
        else
            -- Alpha-safe path: 2x SUPERSAMPLING with Smart Buffer Management
            local rw, rh = w * 2 + 8, h * 2 + 8
            
            gfx.dest = _temp_buf
            if rw ~= _temp_buf_w or rh ~= _temp_buf_h then
                gfx.setimgdim(_temp_buf, -1, -1) -- Hard reset to clear junk
                gfx.setimgdim(_temp_buf, rw, rh)
                _temp_buf_w, _temp_buf_h = rw, rh
            end
            
            -- 1. CLEAR BUFFER (Aggressive clear)
            gfx.set(0, 0, 0, 0)
            gfx.mode = 0
            gfx.rect(0, 0, rw, rh, 1)
            
            -- 2. DRAW SHAPE (at 2x scale)
            -- Same +1 overshoot as opaque path (harmless here: the blit below
            -- reads only bw/bh pixels, so extras are discarded).
            gfx.set(gr, gg, gb, 1.0)
            local br = r * 2
            local bw, bh = w * 2, h * 2
            gfx.circle(br, br, br, 1, 1)
            gfx.circle(bw - br, br, br, 1, 1)
            gfx.circle(br, bh - br, br, 1, 1)
            gfx.circle(bw - br, bh - br, br, 1, 1)
            gfx.rect(0, br, bw + 1, math.max(0, bh - br * 2) + 1, 1)
            gfx.rect(br, 0, math.max(0, bw - br * 2) + 1, br + 1, 1)
            gfx.rect(br, bh - br, math.max(0, bw - br * 2) + 1, br + 1, 1)
            
            -- 3. BLIT BACK TO SCREEN (Downscale 2x -> 1x for exact 2:1 AA)
            gfx.dest = -1
            gfx.set(gr, gg, gb, a)
            gfx.mode = 0
            gfx.blit(_temp_buf, 1, 0, 0, 0, bw, bh, x, y, w, h)
        end
    else
        gfx.roundrect(x, y, w, h, r, 1)
    end
end

--- Draw a filled rect with selectively rounded corners.
--- Overdraws unwanted rounded corners with square fill.
--- @param corners table {tl, tr, bl, br} — which corners to round (default all false → square rect)
function components.DrawRoundedRectEx(x, y, w, h, r, corners)
    r = math.min(r or 0, w/2, h/2)
    if r <= 0 then gfx.rect(x, y, w, h, 1); return end
    
    local gr, gg, gb = gfx.r, gfx.g, gfx.b
    local tl = corners and corners.tl
    local tr = corners and corners.tr
    local bl = corners and corners.bl
    local br = corners and corners.br

    -- If all or none, use standard method
    if (tl and tr and bl and br) or not (tl or tr or bl or br) then
        components.DrawRoundedRect(x, y, w, h, r, true)
        return
    end

    local a = gfx.a
    if a >= 0.99 then
        -- Opaque fast path: +1 overshoot prevents 1px GFX seam artifacts
        if tl then gfx.circle(x + r, y + r, r, 1, 1) end
        if tr then gfx.circle(x + w - r, y + r, r, 1, 1) end
        if bl then gfx.circle(x + r, y + h - r, r, 1, 1) end
        if br then gfx.circle(x + w - r, y + h - r, r, 1, 1) end
        gfx.rect(x, y + r, w + 1, math.max(0, h - r * 2) + 1, 1)
        gfx.rect(x + r, y, math.max(0, w - r * 2) + 1, r + 1, 1)
        gfx.rect(x + r, y + h - r, math.max(0, w - r * 2) + 1, r + 1, 1)
        if not tl then gfx.rect(x, y, r, r, 1) end
        if not tr then gfx.rect(x + w - r, y, r, r, 1) end
        if not bl then gfx.rect(x, y + h - r, r, r, 1) end
        if not br then gfx.rect(x + w - r, y + h - r, r, r, 1) end
    else
        -- Alpha-safe path: 2x SUPERSAMPLING with Smart Buffer Management
        local rw, rh = w * 2 + 8, h * 2 + 8
        
        gfx.dest = _temp_buf
        if rw ~= _temp_buf_w or rh ~= _temp_buf_h then
            gfx.setimgdim(_temp_buf, -1, -1) -- Hard reset to clear junk
            gfx.setimgdim(_temp_buf, rw, rh)
            _temp_buf_w, _temp_buf_h = rw, rh
        end
        
        -- 1. CLEAR BUFFER
        gfx.set(0, 0, 0, 0)
        gfx.mode = 0
        gfx.rect(0, 0, rw, rh, 1)
        
        -- 2. DRAW SELECTIVE SHAPE (at 2x scale)
        -- +1 overshoot matches opaque path; harmless here (blit clips to bw/bh)
        gfx.set(gr, gg, gb, 1.0)
        local brr = r * 2
        local bw, bh = w * 2, h * 2
        if tl then gfx.circle(brr, brr, brr, 1, 1) end
        if tr then gfx.circle(bw - brr, brr, brr, 1, 1) end
        if bl then gfx.circle(brr, bh - brr, brr, 1, 1) end
        if br then gfx.circle(bw - brr, bh - brr, brr, 1, 1) end
        gfx.rect(0, brr, bw + 1, math.max(0, bh - brr * 2) + 1, 1)
        gfx.rect(brr, 0, math.max(0, bw - brr * 2) + 1, brr + 1, 1)
        gfx.rect(brr, bh - brr, math.max(0, bw - brr * 2) + 1, brr + 1, 1)
        if not tl then gfx.rect(0, 0, brr, brr, 1) end
        if not tr then gfx.rect(bw - brr, 0, brr, brr, 1) end
        if not bl then gfx.rect(0, bh - brr, brr, brr, 1) end
        if not br then gfx.rect(bw - brr, bh - brr, brr, brr, 1) end
        
        -- 3. BLIT BACK TO SCREEN (Downscale 2x -> 1x for exact 2:1 AA)
        gfx.dest = -1
        gfx.set(gr, gg, gb, a)
        gfx.mode = 0
        gfx.blit(_temp_buf, 1, 0, 0, 0, bw, bh, x, y, w, h)
    end
end

--- Draw the centralized left vertical strip (Spine) for the MIDI island.
--- @param x,y,w,h Position and size
--- @param r number Corner radius
--- @param corners table Which corners to round
function components.DrawIslandSpine(x, y, w, h, r, corners)
    helpers.SetColor({0.1, 0.1, 0.1, 0.2}) -- Consolidated spine tint
    components.DrawRoundedRectEx(x, y, w, h, r, corners)
    
    -- Vertical separator line on the right edge of the spine
    helpers.SetColor({0.15, 0.15, 0.15, 0.6})
    gfx.line(x + w, y, x + w, y + h)
end

-- Barrel re-exports (extracted modules)
components.DrawPianoKeyboard = piano.DrawPianoKeyboard
components.DrawScalePad = pads.DrawScalePad
components.HandleSlotInteraction = slots.HandleSlotInteraction
components.DrawProgressionSlot = slots.DrawProgressionSlot
components.DrawDragPreview = drag.DrawDragPreview
components.DrawButton = buttons.DrawButton
components.DrawToolIcon = buttons.DrawToolIcon
components.DrawTransportButton = buttons.DrawTransportButton
components.DrawNoteDisplay = buttons.DrawNoteDisplay
components.DrawPaginator = paginator.DrawPaginator
components.DrawDropdown = dropdown.DrawDropdown

return components
