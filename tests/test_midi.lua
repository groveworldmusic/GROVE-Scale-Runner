-- Standalone tests for midi.GetMidiNote
-- Run with: lua tests/test_midi.lua
-- No REAPER dependency — uses local mock of config tables

local assert = assert
local math = math
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local type = type

-- Track test results
local passed = 0
local failed = 0
local function check(condition, msg)
    if condition then
        passed = passed + 1
        io.write("  PASS: " .. msg .. "\n")
    else
        failed = failed + 1
        io.write("  FAIL: " .. msg .. "\n")
    end
end

-- Mock config tables (mirroring src/config.lua)
local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

local SCALES = {
    {name = "Major", intervals = {0, 2, 4, 5, 7, 9, 11}},
    {name = "Major Bebop", intervals = {0, 2, 4, 5, 7, 8, 9, 11}},
    {name = "Major Pentatonic", intervals = {0, 2, 4, 7, 9}},
    {name = "Minor Harmonic", intervals = {0, 2, 3, 5, 7, 8, 11}},
    {name = "Minor Hungarian", intervals = {0, 2, 3, 6, 7, 8, 11}},
    {name = "Minor Melodic", intervals = {0, 2, 3, 5, 7, 9, 11}},
    {name = "Minor Natural (Aeolian)", intervals = {0, 2, 3, 5, 7, 8, 10}},
    {name = "Minor Neopolitan", intervals = {0, 1, 3, 5, 7, 8, 11}},
    {name = "Minor Pentatonic", intervals = {0, 3, 5, 7, 10}},
    {name = "Arabic", intervals = {0, 1, 4, 5, 7, 8, 10}},
    {name = "Blues", intervals = {0, 3, 5, 6, 7, 10}},
    {name = "Diminished", intervals = {0, 2, 3, 5, 6, 8, 9, 11}},
    {name = "Dominant Bebop", intervals = {0, 2, 4, 5, 7, 9, 10, 11}},
    {name = "Dorian", intervals = {0, 2, 3, 5, 7, 9, 10}},
    {name = "Enigmatic", intervals = {0, 1, 4, 6, 8, 10, 11}},
    {name = "Japanese Insen", intervals = {0, 1, 5, 7, 10}},
    {name = "Locrian", intervals = {0, 1, 3, 5, 6, 8, 10}},
    {name = "Lydian", intervals = {0, 2, 4, 6, 7, 9, 11}},
    {name = "Mixolydian", intervals = {0, 2, 4, 5, 7, 9, 10}},
    {name = "Neopolitan", intervals = {0, 1, 3, 5, 7, 9, 10}},
    {name = "Phrygian", intervals = {0, 1, 3, 5, 7, 8, 10}},
}

local CHORD_MODES = {
    {name="Off", offsets={0}},
    {name="Tri", offsets={0, 2, 4}},
    {name="7ma", offsets={0, 2, 4, 6}},
    {name="9na", offsets={0, 2, 4, 6, 8}}
}

-- Local copy of GetMidiNote logic (mirrors src/core/midi.lua)
local function GetMidiNote(root_idx, scale_idx, degree_idx, octave_val)
    local root = root_idx - 1
    local scale = SCALES[scale_idx]
    local n_scale = #scale.intervals
    local deg0 = degree_idx - 1
    local oct_off = math.floor(deg0 / n_scale)
    local interval = scale.intervals[(deg0 % n_scale) + 1]
    local result = (octave_val + 1) * 12 + root + (oct_off * 12) + interval
    return math.max(0, math.min(127, result))
end

-- Helper to get note name from MIDI note number
local function NoteName(midi_note)
    return NOTE_NAMES[(midi_note % 12) + 1]
end

-- Helper for chord offset note calculation
local function GetChordNotes(root_idx, scale_idx, degree, octave_val, chord_mode_idx)
    local notes = {}
    local offsets = CHORD_MODES[chord_mode_idx].offsets
    for _, off in ipairs(offsets) do
        local n = GetMidiNote(root_idx, scale_idx, degree + off, octave_val)
        table.insert(notes, n)
    end
    return notes
end

io.write("=== GetMidiNote Tests ===\n\n")

-- 1. Basic note calculations
io.write("-- Basic note calculations\n")

local result = GetMidiNote(1, 1, 1, 4)
local name = NoteName(result)
check(result == 60, "Root C (1), Major (1), degree 1, octave 4 → 60 (C4), got " .. result .. " (" .. name .. ")")

result = GetMidiNote(1, 1, 7, 4)
name = NoteName(result)
check(result == 71, "Root C (1), Major (1), degree 7, octave 4 → 71 (B4), got " .. result .. " (" .. name .. ")")

-- Root A (10), Minor Natural (index 7), degree 1, octave 2 → 45 (A2)
result = GetMidiNote(10, 7, 1, 2)
name = NoteName(result)
check(result == 45, "Root A (10), Minor Natural (7), degree 1, octave 2 → 45 (A2), got " .. result .. " (" .. name .. ")")

-- 2. All 21 scales with root C, degree 1, octave 4 (no crashes, valid MIDI range)
io.write("\n-- All 21 scales: no crashes, valid MIDI range\n")
for i = 1, #SCALES do
    local ok = true
    local n = GetMidiNote(1, i, 1, 4)
    if n < 0 or n > 127 then ok = false end
    check(ok, "Scale " .. i .. " (" .. SCALES[i].name .. "): note " .. n .. " in 0-127 range")
end

-- 3. Degree wraparound: degree 8 in 7-note scale → octave + 1, degree 1
io.write("\n-- Degree wraparound\n")
-- Major scale (7 notes): degree 8 should wrap to octave 5, degree 1 (C5 = 72)
result = GetMidiNote(1, 1, 8, 4)
check(result == 72, "Major, degree 8, octave 4 → 72 (C5), got " .. result)

-- degree 15 in Major should wrap 2 octaves: result = (4+1+2)*12 + 0 + 0 = 84 (C6)
result = GetMidiNote(1, 1, 15, 4)
check(result == 84, "Major, degree 15, octave 4 → 84 (C6), got " .. result)

-- Major Pentatonic (5 notes): degree 6 → octave 5, degree 1
result = GetMidiNote(1, 3, 6, 4)
-- oct_off = floor(5/5) = 1, interval = intervals[0+1] = 0, result = (4+1)*12 + 0 + 1*12 = 72
check(result == 72, "Major Pentatonic, degree 6, octave 4 → 72 (C5), got " .. result)

-- 4. Octave 0: all degrees should be >= 0
io.write("\n-- Octave 0 boundary\n")
for d = 1, 14 do
    local n = GetMidiNote(1, 1, d, 0)
    check(n >= 0, "Major, degree " .. d .. ", octave 0: " .. n .. " >= 0")
end

-- 5. Octave 8: all degrees should be <= 127
io.write("\n-- Octave 8 boundary\n")
for d = 1, 7 do
    local n = GetMidiNote(1, 1, d, 8)
    check(n <= 127, "Major, degree " .. d .. ", octave 8: " .. n .. " <= 127")
end

-- 6. Chord mode offsets
io.write("\n-- Chord mode offsets\n")
local notes, expected

-- Tri (offsets {0, 2, 4}) on C Major, degree 1, octave 4
notes = GetChordNotes(1, 1, 1, 4, 2)
check(#notes == 3, "Tri: 3 notes, got " .. #notes)
check(notes[1] == 60 and notes[2] == 64 and notes[3] == 67,
    "Tri C: 60, 64, 67 — got " .. notes[1] .. ", " .. notes[2] .. ", " .. notes[3])

-- 7ma (offsets {0, 2, 4, 6}) on C Major, degree 1, octave 4
notes = GetChordNotes(1, 1, 1, 4, 3)
check(#notes == 4, "7ma: 4 notes, got " .. #notes)
check(notes[1] == 60 and notes[2] == 64 and notes[3] == 67 and notes[4] == 71,
    "7ma C: 60, 64, 67, 71 — got " .. notes[1] .. ", " .. notes[2] .. ", " .. notes[3] .. ", " .. notes[4])

-- 9na (offsets {0, 2, 4, 6, 8}) on C Major, degree 1, octave 4
notes = GetChordNotes(1, 1, 1, 4, 4)
check(#notes == 5, "9na: 5 notes, got " .. #notes)
check(notes[1] == 60 and notes[2] == 64 and notes[3] == 67 and notes[4] == 71 and notes[5] == 74,
    "9na C: 60, 64, 67, 71, 74 — got " .. notes[1] .. ", " .. notes[2] .. ", " .. notes[3] .. ", " .. notes[4] .. ", " .. notes[5])

-- 7. Edge cases
io.write("\n-- Edge cases\n")

-- Negative degree (should clamp or handle gracefully)
result = GetMidiNote(1, 1, -1, 4)
check(result >= 0 and result <= 127, "Negative degree -1: " .. result .. " in 0-127 range")

-- Degree 0 (boundary)
result = GetMidiNote(1, 1, 0, 4)
check(result >= 0 and result <= 127, "Degree 0: " .. result .. " in 0-127 range")

-- Maximum scale index
result = GetMidiNote(1, #SCALES, 1, 4)
local last_name = SCALES[#SCALES].name
check(result >= 0 and result <= 127,
    "Last scale index " .. #SCALES .. " (" .. last_name .. "): " .. result .. " in 0-127 range")

-- Minimum scale index
result = GetMidiNote(1, 1, 1, 4)
check(result >= 0 and result <= 127, "First scale index 1 (Major): " .. result .. " in 0-127 range")

-- Root index 0 (out of range) — should handle gracefully
result = GetMidiNote(0, 1, 1, 4)
-- root = -1, (4+1)*12 + (-1) + 0 + 0 = 60 - 1 = 59, clamped to 0..127 = 59
check(result >= 0 and result <= 127, "Root index 0: " .. result .. " in 0-127 range")

-- Root index 13 (out of range)
result = GetMidiNote(13, 1, 1, 4)
-- root = 12, (4+1)*12 + 12 = 72, clamped to 0..127 = 72
check(result >= 0 and result <= 127, "Root index 13: " .. result .. " in 0-127 range")

-- All returned values are within 0-127
io.write("\n-- Exhaustive range check\n")
local all_in_range = true
for s = 1, #SCALES do
    for d = 1, 21 do
        for o = 0, 8 do
            local n = GetMidiNote(1, s, d, o)
            if n < 0 or n > 127 then
                all_in_range = false
                io.write("  OUT OF RANGE: scale " .. s .. ", degree " .. d .. ", octave " .. o .. " → " .. n .. "\n")
            end
        end
    end
end
check(all_in_range, "All combinations (21 scales × 21 degrees × 9 octaves = 3969) within 0-127")

-- Summary
io.write("\n=== Results ===\n")
io.write("Passed: " .. passed .. "\n")
io.write("Failed: " .. failed .. "\n")

if failed > 0 then
    io.write("SOME TESTS FAILED\n")
    os.exit(1)
else
    io.write("ALL TESTS PASSED\n")
    os.exit(0)
end
