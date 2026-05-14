-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Snap Grid — Pure Function Module
-- SnapBeat snaps a raw beat value to the nearest grid boundary.
-- ZERO side effects — takes values, returns values.
--
-- Design:
--   resolution = subdivisions per whole note (1, 2, 4, 8, 16, 32)
--   step = 4 / resolution  (beats per grid cell)
--   triplet: effective step = 4 / (resolution * 1.5)
--   resolution 0 or nil → identity (no snap)

local function SnapBeat(beat, resolution, triplet)
    if not resolution or resolution <= 0 then
        return beat
    end

    local effective_res = resolution
    if triplet then
        effective_res = resolution * 1.5
    end

    local step = 4 / effective_res
    if step <= 0 then return beat end

    return math.floor(beat / step + 0.5) * step
end

local m = {}
m.SnapBeat = SnapBeat
return m
