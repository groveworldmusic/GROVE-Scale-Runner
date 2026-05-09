-- GROVE FL MIDI: Shared UI Helpers
local helpers = {}

-- Set GFX color from {r,g,b,a} table with optional alpha multiplier
function helpers.SetColor(c, alpha_mult)
    gfx.set(c[1], c[2], c[3], (c[4] or 1) * (alpha_mult or 1))
end

-- Strip accents and special characters for stable rendering
function helpers.StripAccents(str)
    local s = str
    local subs = {
        ["Á"]="A", ["É"]="E", ["Í"]="I", ["Ó"]="O", ["Ú"]="U",
        ["á"]="a", ["é"]="e", ["í"]="i", ["ó"]="o", ["ú"]="u",
        ["Ñ"]="N", ["ñ"]="n"
    }
    for k, v in pairs(subs) do
        s = s:gsub(k, v)
    end
    return s
end

-- Abbreviations for scale names (2+2 for two-word, first 5 for single-word)
local FULL_ABBREV = {
    ["Major"] = "Major",
    ["Major Bebop"] = "Ma Be",
    ["Major Pentatonic"] = "Ma Pe",
    ["Minor Harmonic"] = "Mi Ha",
    ["Minor Hungarian"] = "Mi Hu",
    ["Minor Melodic"] = "Mi Me",
    ["Minor Natural (Aeolian)"] = "Mi Na",
    ["Minor Neopolitan"] = "Mi Ne",
    ["Minor Pentatonic"] = "Mi Pe",
    ["Arabic"] = "Arabi",
    ["Blues"] = "Blues",
    ["Diminished"] = "Dimin",
    ["Dominant Bebop"] = "Do Be",
    ["Dorian"] = "Doria",
    ["Enigmatic"] = "Enigm",
    ["Japanese Insen"] = "Ja In",
    ["Locrian"] = "Locri",
    ["Lydian"] = "Lydia",
    ["Mixolydian"] = "Mixol",
    ["Neopolitan"] = "Neopo",
    ["Phrygian"] = "Phryg",
}

function helpers.AbbreviateScale(name)
    return FULL_ABBREV[name] or name
end

return helpers
