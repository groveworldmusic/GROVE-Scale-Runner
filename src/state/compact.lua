-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Compact State Store
-- Encapsulates compact view state with getters/setters.
-- Extracted from config.state.compact to isolate concerns.
local compact_state = {
    transport_hwnd = nil,
    lice_bitmap = nil,
    lice_font = nil,
    gdi_font = nil,
    overlay_active = false,
    last_gfx_state = nil,
}

local m = {}

function m.Init(defaults)
    if defaults.compact then
        for k, v in pairs(defaults.compact) do compact_state[k] = v end
    end
    -- standalone keys
    if defaults.compact_overlay_active ~= nil then compact_state.overlay_active = defaults.compact_overlay_active end
    if defaults.last_gfx_state then compact_state.last_gfx_state = defaults.last_gfx_state end
end

-- Getters
function m.GetTransportHwnd() return compact_state.transport_hwnd end
function m.GetLiceBitmap() return compact_state.lice_bitmap end
function m.GetLiceFont() return compact_state.lice_font end
function m.GetGdiFont() return compact_state.gdi_font end
function m.GetOverlayActive() return compact_state.overlay_active end
function m.GetLastGfxState() return compact_state.last_gfx_state end

-- Setters
function m.SetTransportHwnd(v) compact_state.transport_hwnd = v end
function m.SetLiceBitmap(v) compact_state.lice_bitmap = v end
function m.SetLiceFont(v) compact_state.lice_font = v end
function m.SetGdiFont(v) compact_state.gdi_font = v end
function m.SetOverlayActive(v) compact_state.overlay_active = v end
function m.SetLastGfxState(v) compact_state.last_gfx_state = v end

return m
