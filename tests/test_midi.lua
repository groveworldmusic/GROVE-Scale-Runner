-- Tests for midi.GetMidiNote (real module) — no REAPER dependency
-- Run via: lua tests/run.lua

local config = require("config")
local midi = require("core.midi")
local helpers = require("tests.helpers")
local check = helpers.check
local assert_eq = helpers.assert_eq

io.write("=== GetMidiNote Tests ===\n")

-- 1. Basic note calculations
io.write("\n-- Basic note calculations\n")

local result = midi.GetMidiNote(1, 1, 1, 4)
check(result == 60, "Root C (1), Major (1), degree 1, octave 4 → 60 (C4), got " .. result)

result = midi.GetMidiNote(1, 1, 7, 4)
check(result == 71, "Root C (1), Major (1), degree 7, octave 4 → 71 (B4), got " .. result)

result = midi.GetMidiNote(10, 7, 1, 2)
check(result == 45, "Root A (10), Minor Natural (7), degree 1, octave 2 → 45 (A2), got " .. result)

-- 2. All 21 scales with root C, degree 1, octave 4 (no crashes, valid MIDI range)
io.write("\n-- All 21 scales: no crashes, valid MIDI range\n")
for i = 1, #config.SCALES do
    local ok = true
    local n = midi.GetMidiNote(1, i, 1, 4)
    if n < 0 or n > 127 then ok = false end
    check(ok, "Scale " .. i .. " (" .. config.SCALES[i].name .. "): note " .. n .. " in 0-127 range")
end

-- 3. Degree wraparound: degree 8 in 7-note scale → octave + 1, degree 1
io.write("\n-- Degree wraparound\n")
result = midi.GetMidiNote(1, 1, 8, 4)
check(result == 72, "Major, degree 8, octave 4 → 72 (C5), got " .. result)

result = midi.GetMidiNote(1, 1, 15, 4)
check(result == 84, "Major, degree 15, octave 4 → 84 (C6), got " .. result)

result = midi.GetMidiNote(1, 3, 6, 4)
check(result == 72, "Major Pentatonic, degree 6, octave 4 → 72 (C5), got " .. result)

-- 4. Octave 0: all degrees should be >= 0
io.write("\n-- Octave 0 boundary\n")
for d = 1, 14 do
    local n = midi.GetMidiNote(1, 1, d, 0)
    check(n >= 0, "Major, degree " .. d .. ", octave 0: " .. n .. " >= 0")
end

-- 5. Octave 8: all degrees should be <= 127
io.write("\n-- Octave 8 boundary\n")
for d = 1, 7 do
    local n = midi.GetMidiNote(1, 1, d, 8)
    check(n <= 127, "Major, degree " .. d .. ", octave 8: " .. n .. " <= 127")
end

-- 6. Chord mode offsets (computed per-offset via midi.GetMidiNote)
io.write("\n-- Chord mode offsets\n")

-- Tri (offsets {0, 2, 4}) on C Major, degree 1, octave 4
local n0 = midi.GetMidiNote(1, 1, 1 + 0, 4)
local n2 = midi.GetMidiNote(1, 1, 1 + 2, 4)
local n4 = midi.GetMidiNote(1, 1, 1 + 4, 4)
check(n0 == 60 and n2 == 64 and n4 == 67,
    "Tri C: 60, 64, 67 — got " .. n0 .. ", " .. n2 .. ", " .. n4)

-- 7ma (offsets {0, 2, 4, 6}) on C Major, degree 1, octave 4
local m0 = midi.GetMidiNote(1, 1, 1 + 0, 4)
local m2 = midi.GetMidiNote(1, 1, 1 + 2, 4)
local m4 = midi.GetMidiNote(1, 1, 1 + 4, 4)
local m6 = midi.GetMidiNote(1, 1, 1 + 6, 4)
check(m0 == 60 and m2 == 64 and m4 == 67 and m6 == 71,
    "7ma C: 60, 64, 67, 71 — got " .. m0 .. ", " .. m2 .. ", " .. m4 .. ", " .. m6)

-- 9na (offsets {0, 2, 4, 6, 8}) on C Major, degree 1, octave 4
local d0 = midi.GetMidiNote(1, 1, 1 + 0, 4)
local d2 = midi.GetMidiNote(1, 1, 1 + 2, 4)
local d4 = midi.GetMidiNote(1, 1, 1 + 4, 4)
local d6 = midi.GetMidiNote(1, 1, 1 + 6, 4)
local d8 = midi.GetMidiNote(1, 1, 1 + 8, 4)
check(d0 == 60 and d2 == 64 and d4 == 67 and d6 == 71 and d8 == 74,
    "9na C: 60, 64, 67, 71, 74 — got " .. d0 .. ", " .. d2 .. ", " .. d4 .. ", " .. d6 .. ", " .. d8)

-- 7. Edge cases
io.write("\n-- Edge cases\n")

-- Negative degree (should clamp or handle gracefully)
result = midi.GetMidiNote(1, 1, -1, 4)
check(result >= 0 and result <= 127, "Negative degree -1: " .. result .. " in 0-127 range")

-- Degree 0 (boundary)
result = midi.GetMidiNote(1, 1, 0, 4)
check(result >= 0 and result <= 127, "Degree 0: " .. result .. " in 0-127 range")

-- Maximum scale index
result = midi.GetMidiNote(1, #config.SCALES, 1, 4)
local last_name = config.SCALES[#config.SCALES].name
check(result >= 0 and result <= 127,
    "Last scale index " .. #config.SCALES .. " (" .. last_name .. "): " .. result .. " in 0-127 range")

-- Minimum scale index
result = midi.GetMidiNote(1, 1, 1, 4)
check(result >= 0 and result <= 127, "First scale index 1 (Major): " .. result .. " in 0-127 range")

-- Root index 0 (out of range)
result = midi.GetMidiNote(0, 1, 1, 4)
check(result >= 0 and result <= 127, "Root index 0: " .. result .. " in 0-127 range")

-- Root index 13 (out of range)
result = midi.GetMidiNote(13, 1, 1, 4)
check(result >= 0 and result <= 127, "Root index 13: " .. result .. " in 0-127 range")

-- All returned values are within 0-127
io.write("\n-- Exhaustive range check\n")
local all_in_range = true
for s = 1, #config.SCALES do
    for d = 1, 21 do
        for o = 0, 8 do
            local n = midi.GetMidiNote(1, s, d, o)
            if n < 0 or n > 127 then
                all_in_range = false
                io.write("  OUT OF RANGE: scale " .. s .. ", degree " .. d .. ", octave " .. o .. " → " .. n .. "\n")
            end
        end
    end
end
check(all_in_range, "All combinations (21 scales × 21 degrees × 9 octaves = 3969) within 0-127")
