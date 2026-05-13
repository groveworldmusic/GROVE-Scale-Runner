local theme = require("ui.theme")
local helpers = require("ui.helpers")
local buttons = require("ui.buttons")
local paginator = require("ui.paginator")
local dropdown = require("ui.dropdown")
local piano = require("ui.piano")
local pads = require("ui.pads")
local slots = require("core.slots")
local drag = require("ui.drag")

local components = {}

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
        gfx.circle(x + r, y + r, r, 1, 1)
        gfx.circle(x + w - r, y + r, r, 1, 1)
        gfx.circle(x + r, y + h - r, r, 1, 1)
        gfx.circle(x + w - r, y + h - r, r, 1, 1)
        gfx.rect(x + r, y, math.max(0, w - r * 2) + 1, h + 1, 1)
        gfx.rect(x, y + r, w + 1, math.max(0, h - r * 2) + 1, 1)
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
    
    local tl = corners and corners.tl
    local tr = corners and corners.tr
    local bl = corners and corners.bl
    local br = corners and corners.br

    -- If all or none, use standard method
    if (tl and tr and bl and br) or not (tl or tr or bl or br) then
        components.DrawRoundedRect(x, y, w, h, r, true)
        return
    end

    -- Draw rounded rect for the corners we want
    if tl then gfx.circle(x + r, y + r, r, 1, 1) end
    if tr then gfx.circle(x + w - r, y + r, r, 1, 1) end
    if bl then gfx.circle(x + r, y + h - r, r, 1, 1) end
    if br then gfx.circle(x + w - r, y + h - r, r, 1, 1) end

    -- Fill body (accounts for existing circles)
    gfx.rect(x, y + r, w, math.max(0, h - r * 2) + 1, 1)
    gfx.rect(x + r, y, math.max(0, w - r * 2) + 1, r + 1, 1)  -- above body
    gfx.rect(x + r, y + h - r, math.max(0, w - r * 2) + 1, r + 1, 1)  -- below body

    -- Overdraw corners that should be square
    if not tl then gfx.rect(x, y, r, r, 1) end
    if not tr then gfx.rect(x + w - r, y, r, r, 1) end
    if not bl then gfx.rect(x, y + h - r, r, r, 1) end
    if not br then gfx.rect(x + w - r, y + h - r, r, r, 1) end
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
