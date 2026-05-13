-- GROVE FL MIDI: Paginator UI Component (extracted from components.lua)
local config = require("config")
local seq_store = require("state.sequencer")
local ui_store = require("state.ui")
local helpers = require("ui.helpers")
local theme = require("ui.theme")

-- NOTE: `components` (for DrawRoundedRect) is resolved lazily inside each function
-- to avoid circular require at load time (components.lua also requires paginator.lua)

local m = {}

function m.DrawPaginator(x, y, total_pages)
    local components = require("ui.components")
    local radius = 6
    local spacing = 24
    local start_x = x - ((total_pages - 1) * spacing) / 2
    for i = 1, total_pages do
        local cx = start_x + (i - 1) * spacing
        helpers.SetColor(seq_store.GetCurrentPage() == i and theme.colors.page_active or theme.colors.page_inactive)
        gfx.circle(cx, y, radius, 1, 1)
        if ui_store.GetShowTooltips() then
            local dot_hover = (gfx.mouse_x - cx)^2 + (gfx.mouse_y - y)^2 <= (radius + 5)^2
            if dot_hover then
                gfx.setfont(1, "Calibri", 11)
                local label = "Page " .. i
                local lw, lh = gfx.measurestr(label)
                local tx = cx - lw/2 - 2
                local ty = y - lh - 8
                helpers.SetColor({0, 0, 0, 0.75})
                components.DrawRoundedRect(tx - 2, ty - 2, lw + 4, lh + 4, 3, true)
                helpers.SetColor(theme.colors.text)
                gfx.x, gfx.y = tx, ty
                gfx.drawstr(label)
            end
        end
        if ui_store.GetMouseClick() and (gfx.mouse_x - cx)^2 + (gfx.mouse_y - y)^2 <= radius^2 then
            seq_store.SetCurrentPage(i)
        end
    end
end

return m
