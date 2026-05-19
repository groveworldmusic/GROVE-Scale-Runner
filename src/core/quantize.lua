-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Quantize Module
-- Quantize note positions to the nearest grid boundary.
-- Pure function module (zero store dependencies) — follows snap.lua pattern.

local m = {}

--- Quantize a beat value to the nearest grid boundary.
--- @param beat number The beat to quantize
--- @param resolution number Grid resolution (1, 2, 4, 8, 16, 32)
--- @param strength number 0-100 percentage (100 = exact snap, 50 = half-way)
--- @param triplet boolean|nil Use triplet grid
--- @return number Quantized beat
function m.QuantizeBeat(beat, resolution, strength, triplet)
    strength = strength or 100
    -- Match snap.lua's grid calculation: step = 4 / eff_res, triplet = resolution * 1.5
    local effective_res = resolution
    if triplet then
        effective_res = resolution * 1.5
    end
    local grid_size = 4 / effective_res
    if grid_size <= 0 then return beat end
    local nearest = math.floor(beat / grid_size + 0.5) * grid_size
    if strength >= 100 then
        return nearest
    end
        -- Partial quantize: move fractionally toward grid
        return beat + (nearest - beat) * (strength / 100)
    end
    return nearest
end

--- Quantize a beat value to the nearest grid boundary WITH swing.
--- Swing delays every other off-beat subdivision by a fraction of half-step.
--- @param beat number The beat to quantize
--- @param resolution number Grid resolution (1, 2, 4, 8, 16, 32)
--- @param strength number 0-100 percentage
--- @param triplet boolean|nil Use triplet grid
--- @param swing number 0-50 (0=no swing, 50=max shuffle)
--- @return number Quantized beat (with swing offset if applicable)
function m.QuantizeBeatWithSwing(beat, resolution, strength, triplet, swing)
    strength = strength or 100
    swing = swing or 0
    -- Match snap.lua's grid calculation: step = 4 / eff_res, triplet = resolution * 1.5
    local effective_res = resolution
    if triplet then
        effective_res = resolution * 1.5
    end
    local grid_size = 4 / effective_res
    if grid_size <= 0 then return beat end
    local nearest = math.floor(beat / grid_size + 0.5) * grid_size
    local snapped = beat
    if strength >= 100 then
        snapped = nearest
    else
        -- Partial quantize: move fractionally toward grid
        snapped = beat + (nearest - beat) * (strength / 100)
    end
    -- Swing: delay odd off-beat subdivisions
    if swing > 0 then
        local subdivision_index = math.floor(beat / grid_size)
        if (subdivision_index % 2) == 1 then
            local offset = (swing / 100) * (grid_size / 2)
            snapped = snapped + offset
        end
    end
    return snapped
end

--- Quantize start_beat and duration of a single note to the nearest grid boundary.
--- @param note table {start_beat, duration, ...}
--- @param resolution number Grid resolution
--- @param strength number 0-100
--- @param triplet boolean|nil
--- @return number, number Quantized start_beat and duration
function m.QuantizeNote(note, resolution, strength, triplet)
    local q_start = m.QuantizeBeat(note.start_beat, resolution, strength, triplet)
    local q_end = m.QuantizeBeat(note.start_beat + note.duration, resolution, strength, triplet)
    local q_dur = math.max(0.125, q_end - q_start)
    return q_start, q_dur
end

return m
