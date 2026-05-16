-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Layout System — Uniform Scale Factor & Canvas Constants
-- Provides coordinate scaling functions and canvas dimensions for gfx rendering.
local m = {}

-- Canvas dimensions (virtual coordinate space)
m.CANVAS_W = 39914
m.CANVAS_H = 29162

-- Uniform Scale Factor & Offsets
-- Set ONLY via SetScale() at the start of each frame.
-- Do NOT assign _S/_OX/_OY directly — use SetScale().
-- Underscore prefix = internal, do not touch from outside this module.
local _S, _OX, _OY = 0, 0, 0

function m.UX(v) return math.floor(v * _S + _OX) end
function m.UY(v) return math.floor(v * _S + _OY) end
function m.US(v) return math.floor(v * _S) end

-- Set the scale context for the current frame.
-- Must be called before any UX/UY/US call. Only DrawFullView calls this.
function m.SetScale(s, ox, oy) _S, _OX, _OY = s, ox, oy end

return m
