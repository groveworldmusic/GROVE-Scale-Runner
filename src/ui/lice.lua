-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
-- GROVE Scale Runner: LICE wrappers for GFX compositing
-- Dependencies: helpers, theme, state.compact (uses compact_store getters/setters)
-- All functions take bitmap/font as explicit parameters (no require("config"))
local helpers = require("ui.helpers")
local theme = require("ui.theme")
local compact_store = require("state.compact")

local m = {}

-- Module-local cache: LICE bitmap reference
local _lice_bitmap = nil

-- =========================================================
-- RESOURCE SETUP
-- =========================================================

-- Ensure LICE bitmap and font resources exist via compact_store
function m.EnsureLICE()
    if not compact_store.GetLiceBitmap() then
        compact_store.SetLiceBitmap(reaper.JS_LICE_CreateBitmap(true, 1, 1))
    end
    if not compact_store.GetLiceFont() then
        compact_store.SetLiceFont(reaper.JS_LICE_CreateFont())
        if not compact_store.GetGdiFont() then
            compact_store.SetGdiFont(reaper.JS_GDI_CreateFont(13, 400, 0, 0, 0, 0, "Calibri"))
        end
        reaper.JS_LICE_SetFontFromGDI(compact_store.GetLiceFont(), compact_store.GetGdiFont(), "")
    end
    _lice_bitmap = compact_store.GetLiceBitmap()
end

-- =========================================================
-- DRAWING FUNCTIONS
-- =========================================================

-- Draw a filled or outline rounded rectangle on a LICE bitmap.
-- bm: LICE bitmap handle
-- x, y, w, h: rectangle dimensions
-- color: {r,g,b,a} table
-- fill: true = filled, false/nil = outline
-- r: corner radius (default 0)
function m.DrawRoundedRectFill(bm, x, y, w, h, color, fill, r)
    local a = 1
    local ci = reaper.ColorToNative(math.floor(color[1]*255), math.floor(color[2]*255), math.floor(color[3]*255)) | 0xFF000000
    r = r or 0
    if not fill then
        reaper.JS_LICE_RoundRect(bm, x, y, w - 1, h - 1, r, ci, a, 0, true)
        return
    end
    if r == 0 then
        reaper.JS_LICE_FillRect(bm, x, y, w, h, ci, a, 0)
        return
    end
    if h <= 2 * r then r = math.floor(h / 2 - 1) end
    if w <= 2 * r then r = math.floor(w / 2 - 1) end
    local F = reaper.JS_LICE_FillCircle
    F(bm, x + r, y + r, r, ci, a, 0, 1)
    F(bm, x + w - r - 1, y + r, r, ci, a, 0, 1)
    F(bm, x + w - r - 1, y + h - r - 1, r, ci, a, 0, 1)
    F(bm, x + r, y + h - r - 1, r, ci, a, 0, 1)
    reaper.JS_LICE_FillRect(bm, x, y + r, r, h - r * 2, ci, a, 0)
    reaper.JS_LICE_FillRect(bm, x + w - r, y + r, r, h - r * 2, ci, a, 0)
    reaper.JS_LICE_FillRect(bm, x + r, y, w - r * 2, h, ci, a, 0)
end

-- Draw a directional arrow icon on a LICE bitmap.
-- bm: LICE bitmap handle
-- x, y, w, h: bounding box
-- direction: "left", "right", "up", or "down"
-- color: {r,g,b,a} table
function m.DrawArrowIcon(bm, x, y, w, h, direction, color)
    local ci = reaper.ColorToNative(math.floor(color[1]*255), math.floor(color[2]*255), math.floor(color[3]*255)) | 0xFF000000

    if direction == "left" or direction == "right" then
        local arrow_w = math.floor(w * 0.55)
        local half = h / 2
        for row = 0, h - 1 do
            local row_dist = math.abs(row - half) / half
            local row_w = math.max(1, math.floor(arrow_w * (1 - row_dist)))
            if direction == "left" then
                reaper.JS_LICE_FillRect(bm, x + (arrow_w - row_w), y + row, row_w, 1, ci, 1, 0)
            else
                reaper.JS_LICE_FillRect(bm, x, y + row, row_w, 1, ci, 1, 0)
            end
        end
    elseif direction == "up" or direction == "down" then
        local arrow_h = math.floor(h * 0.55)
        local half = w / 2
        for col = 0, w - 1 do
            local col_dist = math.abs(col - half) / half
            local col_h = math.max(1, math.floor(arrow_h * (1 - col_dist)))
            if direction == "up" then
                reaper.JS_LICE_FillRect(bm, x + col, y + (arrow_h - col_h), 1, col_h, ci, 1, 0)
            else
                reaper.JS_LICE_FillRect(bm, x + col, y, 1, col_h, ci, 1, 0)
            end
        end
    end
end

-- Draw a progress bar on a LICE bitmap.
-- bm: LICE bitmap handle
-- x, y, w, h: bar dimensions
-- progress: 0.0 to 1.0
-- color_bg: background color {r,g,b,a}
-- color_fg: fill color {r,g,b,a}
function m.DrawProgressBar(bm, x, y, w, h, progress, color_bg, color_fg)
    local ci_bg = reaper.ColorToNative(math.floor(color_bg[1]*255), math.floor(color_bg[2]*255), math.floor(color_bg[3]*255)) | 0xFF000000
    local ci_fg = reaper.ColorToNative(math.floor(color_fg[1]*255), math.floor(color_fg[2]*255), math.floor(color_fg[3]*255)) | 0xFF000000

    -- Background track
    reaper.JS_LICE_FillRect(bm, x, y, w, h, ci_bg, 1, 0)

    -- Filled portion
    local fill_w = math.max(0, math.min(w, math.floor(w * progress + 0.5)))
    if fill_w > 0 then
        reaper.JS_LICE_FillRect(bm, x, y, fill_w, h, ci_fg, 1, 0)
    end
end

-- Draw a mode hint text on a LICE bitmap using LICE font.
-- bm: LICE bitmap handle
-- font: LICE font handle
-- x, y: text position
-- text: string to draw
-- color: {r,g,b,a} table
function m.DrawModeHint(bm, font, x, y, text, color)
    local ci = reaper.ColorToNative(math.floor(color[1]*255), math.floor(color[2]*255), math.floor(color[3]*255)) | 0xFF000000
    reaper.JS_LICE_SetFontColor(font, ci)
    reaper.JS_LICE_DrawText(bm, font, text, #text, x, y, 1000, 100)
end

return m
