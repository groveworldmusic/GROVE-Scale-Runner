-- GROVE FL MIDI: Theme extracted from SVGs
local theme = {}

-- Helper to convert hex to 0-1 scale needed by Reaper GFX
local function hex2rgb(hex)
    hex = hex:gsub("#","")
    if #hex == 3 then
        return {tonumber("0x"..hex:sub(1,1):rep(2))/255, tonumber("0x"..hex:sub(2,2):rep(2))/255, tonumber("0x"..hex:sub(3,3):rep(2))/255, 1}
    else
        return {tonumber("0x"..hex:sub(1,2))/255, tonumber("0x"..hex:sub(3,4))/255, tonumber("0x"..hex:sub(5,6))/255, 1}
    end
end

theme.colors = {
    bg = hex2rgb("#0d0d0d"),        -- Main Background
    text = hex2rgb("#e6e6e6"),      -- Active Text
    text_dim = hex2rgb("#858585"),  -- Inactive Text / labels
    text_dark = hex2rgb("#1a1a1a"), -- Dark text (e.g., piano keys)
    btn_bg = hex2rgb("#333333"),    -- Default button
    btn_hover = hex2rgb("#444444"), -- Hover
    btn_active = hex2rgb("#3f81da"),-- Active mode
    pad_active = hex2rgb("#3f81da"),-- Pad highlight (used in compact.lua note flash)
    island_bg = hex2rgb("#333333"), -- Background for control islands
    slot_filled = hex2rgb("#3f81da"),-- Filled slot (blue)
    slot_playing = hex2rgb("#6ba659"),-- Playing slot / Play button
    piano_white = hex2rgb("#d9d9d9"),
    piano_black = hex2rgb("#0d0d0d"), -- Black keys are same as main bg in SVG
    page_inactive = hex2rgb("#1a1a1a"),
    page_active = hex2rgb("#808080"),
    grade_colors = {
        hex2rgb("#3f81da"),  -- I:  blue
        hex2rgb("#4a9e6b"),  -- II: green
        hex2rgb("#d4a04a"),  -- III: amber
        hex2rgb("#c96060"),  -- IV: red
        hex2rgb("#9b6bbf"),  -- V: purple
        hex2rgb("#5ba8c4"),  -- VI: teal
        hex2rgb("#d47a5a"),  -- VII: orange
    },
}

return theme
