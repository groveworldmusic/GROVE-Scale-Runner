-- Tests: Piano Roll Drag — Edge Detection & Drag Threshold
-- Tests IsNoteRightEdge, IsNoteLeftEdge, ArmNoteDrag, CheckAndStartDrag, DisarmNoteDrag
-- in piano-roll/interaction/drag.lua
--
-- These functions use pure math + module-local state — no store/reaper dependency
-- for the tested paths.
--
-- Usage: lua tests/run.lua (from project root)

local check = require("tests.helpers").check
local drag = require("ui.piano-roll.interaction.drag")
local grid = require("ui.piano-roll.grid")

io.write("=== Piano Roll Drag Tests ===\n")

-- ============================================================
-- Constants (mirror grid defaults for test calculations)
-- ============================================================
local PITCH_ROW_H = 16
local MIN_PITCH = 12
local MAX_PITCH = 119
local GRID_X = 100
local GRID_Y = 200
local ZOOM_X = 40
local RESIZE_HOTZONE_PX = 4

-- Build a test note at pitch 64 (E4), beat 2.0, duration 1.0
-- For scroll_y=55: top_pitch = max(12, 119-55) = 64
-- For pitch 64: pitch_row = 0 → my = GRID_Y + 0*16 = 200
-- Right edge screen: GRID_X + (2.0 + 1.0 - 0) * 40 = 220
-- Left edge screen: GRID_X + (2.0 - 0) * 40 = 180
local SCROLL_Y = 55
local SCROLL_X = 0
local function make_note(pitch, start_beat, duration)
    return { pitch = pitch or 64, start_beat = start_beat or 2.0, duration = duration or 1.0 }
end

-- ============================================================
-- 1. IsNoteRightEdge — True Cases (within 4px hotzone)
-- ============================================================
io.write("\n-- IsNoteRightEdge: true cases\n")

local notes = { make_note() }
local hit_idx = 1

-- At the right edge boundary: mx = right_edge = 220
check(drag.IsNoteRightEdge(220, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Redge: mx=right_edge returns true")

-- Inside hotzone: mx = right_edge - 2 (within 4px hotzone)
check(drag.IsNoteRightEdge(218, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Redge: mx=218 (2px inside) returns true")

-- Edge of hotzone: mx = right_edge - 4
check(drag.IsNoteRightEdge(216, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Redge: mx=216 (hotzone boundary) returns true")

-- Bottom of note Y range: my = 215 (last pixel of pitch row 64)
check(drag.IsNoteRightEdge(218, 215, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Redge: my=215 (bottom of pitch row) returns true")

-- Top of note Y range: my = note_top = GRID_Y = 200
check(drag.IsNoteRightEdge(218, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Redge: my=note_top (200) returns true")

-- ============================================================
-- 2. IsNoteRightEdge — False Cases
-- ============================================================
io.write("\n-- IsNoteRightEdge: false cases\n")

-- Outside hotzone (left): mx = 215 (1px too far left)
check(drag.IsNoteRightEdge(215, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Redge: mx=215 (1px outside hotzone) returns false")

-- Outside hotzone (right): mx = 221 (1px past right edge)
check(drag.IsNoteRightEdge(221, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Redge: mx=221 (past right edge) returns false")

-- Wrong Y (below note): my = 217 (1px below note_bot=216)
check(drag.IsNoteRightEdge(218, 217, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Redge: my=217 (below note) returns false")

-- Wrong Y (above note): my = 199 (1px above note_top=200)
check(drag.IsNoteRightEdge(218, 199, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Redge: my=199 (above note) returns false")

-- Wrong pitch: my=216 gives pitch_row=1, click_pitch=63 != 64
check(drag.IsNoteRightEdge(218, 216, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Redge: my=216 (pitch 63 != 64) returns false")

-- No notes table
check(drag.IsNoteRightEdge(218, 200, nil, 1, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Redge: nil notes returns false")

-- Invalid index
check(drag.IsNoteRightEdge(218, 200, notes, 99, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Redge: invalid hit_idx returns false")

-- ============================================================
-- 3. IsNoteLeftEdge — True Cases (within 4px hotzone)
-- ============================================================
io.write("\n-- IsNoteLeftEdge: true cases\n")

-- At the left edge boundary: mx = left_edge = 180
check(drag.IsNoteLeftEdge(180, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Ledge: mx=left_edge returns true")

-- Inside hotzone: mx = left_edge + 2
check(drag.IsNoteLeftEdge(182, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Ledge: mx=182 (2px inside) returns true")

-- Edge of hotzone: mx = left_edge + 4
check(drag.IsNoteLeftEdge(184, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Ledge: mx=184 (hotzone boundary) returns true")

-- Bottom of note Y range: my = 215 (last pixel of pitch row 64)
check(drag.IsNoteLeftEdge(182, 215, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Ledge: my=215 (bottom of pitch row) returns true")

-- Top of note Y range
check(drag.IsNoteLeftEdge(182, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Ledge: my=note_top still inside returns true")

-- ============================================================
-- 4. IsNoteLeftEdge — False Cases
-- ============================================================
io.write("\n-- IsNoteLeftEdge: false cases\n")

-- Outside hotzone (left): mx = 179 (1px too far left)
check(drag.IsNoteLeftEdge(179, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Ledge: mx=179 (1px past left edge) returns false")

-- Outside hotzone (right): mx = 185 (1px past hotzone)
check(drag.IsNoteLeftEdge(185, 200, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Ledge: mx=185 (1px past hotzone) returns false")

-- Wrong Y (below note): my = 217
check(drag.IsNoteLeftEdge(182, 217, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Ledge: my=217 (below note) returns false")

-- Wrong Y (above note): my = 199
check(drag.IsNoteLeftEdge(182, 199, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Ledge: my=199 (above note) returns false")

-- Wrong pitch: my=216 gives pitch_row=1, click_pitch=63 != 64
check(drag.IsNoteLeftEdge(182, 216, notes, hit_idx, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Ledge: my=216 (pitch 63 != 64) returns false")

-- No notes table
check(drag.IsNoteLeftEdge(182, 200, nil, 1, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Ledge: nil notes returns false")

-- Invalid index
check(drag.IsNoteLeftEdge(182, 200, notes, 99, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Ledge: invalid hit_idx returns false")

-- ============================================================
-- 5. Drag Arming + Threshold (ArmNoteDrag / CheckAndStartDrag)
-- ============================================================
io.write("\n-- Drag arming and threshold\n")

-- Arm a drag at (100, 100)
drag.ArmNoteDrag(1, 100, 100)

-- Check under threshold: moved to (105, 105) → dx=5, dy=5, dist²=50 < 64
local started = drag.CheckAndStartDrag(105, 105, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X)
check(started == false, "thresh: 5px movement does NOT start drag")

-- Still armed — under threshold (5,5) again
drag.ArmNoteDrag(1, 100, 100)
started = drag.CheckAndStartDrag(107, 103, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X)
-- dx=7, dy=3 → 49+9=58, 58 < 64 → false
check(started == false, "thresh: (7,3) movement (58 < 64) does NOT start drag")

-- At threshold exactly: (8,0) → dx=8, dy=0 → 64 >= 64 → true
drag.ArmNoteDrag(1, 100, 100)
started = drag.CheckAndStartDrag(108, 100, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X)
check(started == true, "thresh: 8px exactly triggers drag")

-- Over threshold: (6,6) → dx=6, dy=6 → 72 >= 64 → true
drag.ArmNoteDrag(1, 100, 100)
started = drag.CheckAndStartDrag(106, 106, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X)
check(started == true, "thresh: (6,6) movement (72 >= 64) triggers drag")

-- Over threshold diagonal: (10,0) → 100 >= 64 → true
drag.ArmNoteDrag(1, 100, 100)
started = drag.CheckAndStartDrag(110, 100, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X)
check(started == true, "thresh: 10px right triggers drag")

-- ============================================================
-- 6. DisarmNoteDrag
-- ============================================================
io.write("\n-- DisarmNoteDrag\n")

-- Arm then disarm
drag.ArmNoteDrag(5, 200, 300)
drag.DisarmNoteDrag()

-- After disarm, CheckAndStartDrag should return false
local after_disarm = drag.CheckAndStartDrag(210, 310, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X)
check(after_disarm == false, "disarm: after DisarmNoteDrag, CheckAndStartDrag returns false")

-- Multiple disarms are safe
drag.DisarmNoteDrag()
drag.DisarmNoteDrag()
check(true, "disarm: multiple disarms do not crash")

-- Arm + disarm + re-arm + threshold check
drag.ArmNoteDrag(3, 50, 60)
drag.DisarmNoteDrag()
drag.ArmNoteDrag(3, 50, 60)
local rearmed = drag.CheckAndStartDrag(60, 60, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X)
-- dx=10, dy=0 → 100 >= 64 → true
check(rearmed == true, "disarm: re-arm works after disarm")

-- CheckAndStartDrag with no arm
-- First, make sure we're not armed
drag.DisarmNoteDrag()
started = drag.CheckAndStartDrag(200, 200, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X)
check(started == false, "disarm: no arm -> no drag start")

-- ============================================================
-- 7. Additional Edge Cases — Different Note Positions
-- ============================================================
io.write("\n-- Edge cases: different note positions\n")

-- Note at pitch 72 (C5), beat 8.0, duration 2.0
-- For scroll_y=47: top_pitch = max(12, 119-47) = 72
-- scroll_px_off = (47-47)*16 = 0 (integer scroll)
--
-- pitch_row for pitch 72: (72-72) = 0 → my = 200
-- right_edge = 100 + (8.0+2.0-0)*40 = 100+400 = 500
-- left_edge = 100 + (8.0-0)*40 = 100+320 = 420
local notes2 = { make_note(72, 8.0, 2.0) }

-- Right edge: mx=498 should hit (in [496, 500])
check(drag.IsNoteRightEdge(498, 200, notes2, 1, GRID_X, GRID_Y, 47, 0, ZOOM_X) == true,
    "Redge2: mx=498 hotzone hit at beat 8+2")
-- Right edge: mx=495 should miss (< 496)
check(drag.IsNoteRightEdge(495, 200, notes2, 1, GRID_X, GRID_Y, 47, 0, ZOOM_X) == false,
    "Redge2: mx=495 outside hotzone")

-- Left edge: mx=422 should hit (in [420, 424])
check(drag.IsNoteLeftEdge(422, 200, notes2, 1, GRID_X, GRID_Y, 47, 0, ZOOM_X) == true,
    "Ledge2: mx=422 hotzone hit at beat 8")
-- Left edge: mx=425 should miss (> 424)
check(drag.IsNoteLeftEdge(425, 200, notes2, 1, GRID_X, GRID_Y, 47, 0, ZOOM_X) == false,
    "Ledge2: mx=425 outside hotzone")

-- Note with zero duration (edge case: should treat as duration=1)
local notes3 = { make_note(64, 2.0, 0) }
-- right_edge = 100 + (2.0+0-0)*40 = 180 -- wait, function uses `or 1`
-- Actually the function checks `n.duration or 1`, so duration=0 is truthy (0 is falsy in Lua)
-- n.duration or 1 → 0 or 1 → 0 (since 0 is truthy? NO, 0 is truthy in Lua!)
-- In Lua, only false and nil are falsy. 0 is truthy!
-- So n.duration=0 → n.duration or 1 → 0
-- right_edge = 100 + (2.0+0-0)*40 = 180
-- Hotzone: [176, 180]
check(drag.IsNoteRightEdge(178, 200, notes3, 1, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Redge3: zero-duration note right edge hit at mx=178")
-- But wait, the pitch_row matching for this note:
-- We're using SCROLL_Y=55, top_pitch=64, note pitch=64 → pitch_row=0
check(drag.IsNoteRightEdge(181, 200, notes3, 1, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == false,
    "Redge3: mx=181 past zero-duration right edge")

-- Note with explicit nil duration (uses `or 1` fallback → duration = 1)
local notes4 = { make_note(64, 2.0, nil) }
-- right_edge = 100 + (2.0+1-0)*40 = 220
check(drag.IsNoteRightEdge(218, 200, notes4, 1, GRID_X, GRID_Y, SCROLL_Y, SCROLL_X, ZOOM_X) == true,
    "Redge4: nil-duration note (default 1) right edge hit")

io.write("\n=== Piano Roll Drag Tests Complete ===\n")
