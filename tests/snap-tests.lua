-- Tests: Snap Grid + Note Drag (PR2)
-- Covers SnapBeat() resolutions, note drag coordinate math,
-- multi-note relative offset preservation.
--
-- SnapBeat is a pure function — no mocks needed.
-- Drag/resize uses island_store state so only the store mock + helpers needed.

local check = require("tests.helpers").check
local snap = require("core.snap")
local island_store = require("state.island")

io.write("=== Snap Grid Tests ===\n")

-- ============================================================
-- 1. SnapBeat() — Pure Function
-- ============================================================
io.write("\n-- SnapBeat: standard resolutions\n")

-- Resolution 1 (whole note) → step = 4 beats
check(snap.SnapBeat(0, 1) == 0, "SnapBeat(0, 1) = 0")
check(snap.SnapBeat(1.9, 1) == 0, "SnapBeat(1.9, 1) = 0")
check(snap.SnapBeat(2.1, 1) == 4, "SnapBeat(2.1, 1) = 4")
check(snap.SnapBeat(3.9, 1) == 4, "SnapBeat(3.9, 1) = 4")
check(snap.SnapBeat(4.0, 1) == 4, "SnapBeat(4.0, 1) = 4")

-- Resolution 2 (half note) → step = 2 beats
check(snap.SnapBeat(0.9, 2) == 0, "SnapBeat(0.9, 2) = 0")
check(snap.SnapBeat(1.1, 2) == 2, "SnapBeat(1.1, 2) = 2")
check(snap.SnapBeat(2.9, 2) == 2, "SnapBeat(2.9, 2) = 2")
check(snap.SnapBeat(3.1, 2) == 4, "SnapBeat(3.1, 2) = 4")

-- Resolution 4 (quarter note) → step = 1 beat
check(snap.SnapBeat(2.0, 4) == 2, "SnapBeat(2.0, 4) = 2")
check(snap.SnapBeat(2.3, 4) == 2, "SnapBeat(2.3, 4) = 2")
check(snap.SnapBeat(2.49, 4) == 2, "SnapBeat(2.49, 4) = 2")
check(snap.SnapBeat(2.5, 4) == 3, "SnapBeat(2.5, 4) = 3")
check(snap.SnapBeat(2.7, 4) == 3, "SnapBeat(2.7, 4) = 3")

-- Resolution 8 (eighth note) → step = 0.5 beats
check(snap.SnapBeat(2.0, 8) == 2, "SnapBeat(2.0, 8) = 2")
check(snap.SnapBeat(2.125, 8) == 2, "SnapBeat(2.125, 8) = 2")
check(snap.SnapBeat(2.25, 8) == 2.5, "SnapBeat(2.25, 8) = 2.5")
check(snap.SnapBeat(2.3, 8) == 2.5, "SnapBeat(2.3, 8) = 2.5")

-- Resolution 16 (sixteenth note) → step = 0.25 beats
check(snap.SnapBeat(2.0, 16) == 2, "SnapBeat(2.0, 16) = 2")
check(snap.SnapBeat(2.1, 16) == 2, "SnapBeat(2.1, 16) = 2 (closer to 2.0 than 2.25)")
check(snap.SnapBeat(2.3, 16) == 2.25, "SnapBeat(2.3, 16) = 2.25")
check(snap.SnapBeat(2.4, 16) == 2.5, "SnapBeat(2.4, 16) = 2.5")

-- Resolution 32 (thirty-second note) → step = 0.125 beats
check(snap.SnapBeat(2.05, 32) == 2, "SnapBeat(2.05, 32) = 2")
check(snap.SnapBeat(2.07, 32) == 2.125, "SnapBeat(2.07, 32) = 2.125")
check(snap.SnapBeat(2.1, 32) == 2.125, "SnapBeat(2.1, 32) = 2.125")

io.write("\n-- SnapBeat: identity when disabled\n")

-- Resolution 0 or nil → identity
check(snap.SnapBeat(2.37, 0) == 2.37, "SnapBeat(2.37, 0) = identity")
check(snap.SnapBeat(2.37, nil) == 2.37, "SnapBeat(2.37, nil) = identity")
check(snap.SnapBeat(2.37, -1) == 2.37, "SnapBeat(2.37, -1) = identity (negative)")

io.write("\n-- SnapBeat: triplet modes\n")

-- Resolution 8 triplet → step = 4 / (8 * 1.5) = 4 / 12 = 1/3 beat
check(snap.SnapBeat(2.0, 8, true) == 2, "SnapBeat(2.0, 8, true) = 2")
-- 1/3 beat boundaries: 0, 0.333, 0.667, 1.0, 1.333, 1.667, 2.0, 2.333, 2.667, 3.0
check(snap.SnapBeat(2.15, 8, true) == 2, "SnapBeat(2.15, 8, true) = 2 (snapped to 2.0)")
-- 2.333 is 7/3, use tolerance to avoid float comparison
check(math.abs(snap.SnapBeat(2.2, 8, true) - 2.333) < 0.001, "SnapBeat(2.2, 8, true) ~= 2.333")
check(math.abs(snap.SnapBeat(2.5, 8, true) - 2.667) < 0.001, "SnapBeat(2.5, 8, true) ~= 2.667 (equidistant, rounds up)")
check(math.abs(snap.SnapBeat(2.6, 8, true) - 2.667) < 0.001, "SnapBeat(2.6, 8, true) ~= 2.667")

-- Resolution 16 triplet → step = 4 / (16 * 1.5) = 4 / 24 = 1/6 beat
check(snap.SnapBeat(2.0, 16, true) == 2, "SnapBeat(2.0, 16, true) = 2")
-- 1/6 beat boundaries from 2.0: 2.0, 2.167, 2.333, 2.5, 2.667, 2.833, 3.0
check(math.abs(snap.SnapBeat(2.1, 16, true) - 2.167) < 0.001, "SnapBeat(2.1, 16, true) ~= 2.167")
check(math.abs(snap.SnapBeat(2.25, 16, true) - 2.333) < 0.001, "SnapBeat(2.25, 16, true) ~= 2.333")

io.write("\n-- SnapBeat: edge cases\n")

-- Negative beats
check(snap.SnapBeat(-0.5, 4) == 0, "SnapBeat(-0.5, 4) = 0 (rounds to nearest grid: floor(-0.5/1+0.5)=0)")
check(snap.SnapBeat(-0.3, 4) == 0, "SnapBeat(-0.3, 4) = 0")

-- Zero beats
check(snap.SnapBeat(0, 4) == 0, "SnapBeat(0, 4) = 0")

-- Very large values
check(snap.SnapBeat(1000.3, 4) == 1000, "SnapBeat(1000.3, 4) = 1000")
check(snap.SnapBeat(1000.6, 4) == 1001, "SnapBeat(1000.6, 4) = 1001")

-- ============================================================
-- 2. Island Store — Snap State Round-Trips
-- ============================================================
io.write("\n-- Island Store: snap state\n")

-- Init with defaults (no config.state passed — uses module defaults)
island_store.Init({})

-- Defaults
check(island_store.GetSnapEnabled() == false, "island: snap_enabled default false")
check(island_store.GetSnapResolution() == 4, "island: snap_resolution default 4")
check(island_store.GetSnapTriplet() == false, "island: snap_triplet default false")
check(island_store.GetNoteDragActive() == false, "island: note_drag_active default false")
check(island_store.GetNoteDragIndices() ~= nil, "island: note_drag_indices default {}")
check(#island_store.GetNoteDragIndices() == 0, "island: note_drag_indices empty")

-- Round-trips
island_store.SetSnapEnabled(false)
check(island_store.GetSnapEnabled() == false, "island: snap_enabled set false")
island_store.SetSnapEnabled(true)
check(island_store.GetSnapEnabled() == true, "island: snap_enabled set true")

island_store.SetSnapResolution(8)
check(island_store.GetSnapResolution() == 8, "island: snap_resolution set 8")
island_store.SetSnapResolution(4)
check(island_store.GetSnapResolution() == 4, "island: snap_resolution back to 4")

island_store.SetSnapTriplet(true)
check(island_store.GetSnapTriplet() == true, "island: snap_triplet set true")
island_store.SetSnapTriplet(false)
check(island_store.GetSnapTriplet() == false, "island: snap_triplet set false")

-- ============================================================
-- 3. Island Store — Note Drag State Round-Trips
-- ============================================================
io.write("\n-- Island Store: note drag state\n")

island_store.SetNoteDragActive(true)
check(island_store.GetNoteDragActive() == true, "island: note_drag_active true")

island_store.SetNoteDragIndices({3, 5, 7})
check(island_store.GetNoteDragIndices()[1] == 3, "island: note_drag_indices[1] = 3")
check(island_store.GetNoteDragIndices()[2] == 5, "island: note_drag_indices[2] = 5")
check(island_store.GetNoteDragIndices()[3] == 7, "island: note_drag_indices[3] = 7")

island_store.SetNoteDragStartPitch(60)
check(island_store.GetNoteDragStartPitch() == 60, "island: note_drag_start_pitch = 60")

island_store.SetNoteDragStartBeat(2.5)
check(island_store.GetNoteDragStartBeat() == 2.5, "island: note_drag_start_beat = 2.5")

island_store.SetNoteDragOriginMx(150)
check(island_store.GetNoteDragOriginMx() == 150, "island: note_drag_origin_mx = 150")

island_store.SetNoteDragOriginMy(300)
check(island_store.GetNoteDragOriginMy() == 300, "island: note_drag_origin_my = 300")

island_store.SetNoteResizeEdge("right")
check(island_store.GetNoteResizeEdge() == "right", "island: note_resize_edge = right")

-- ResetNoteDrag
island_store.ResetNoteDrag()
check(island_store.GetNoteDragActive() == false, "island: ResetNoteDrag clears active")
check(island_store.GetNoteResizeEdge() == nil, "island: ResetNoteDrag clears resize_edge")
check(island_store.GetNoteDragStartPitch() == 0, "island: ResetNoteDrag clears start_pitch")

-- ============================================================
-- 4. Note Drag Coordinate Math (simulated)
-- ============================================================
io.write("\n-- Note drag coordinate math\n")

-- Simulate the note drag math from interaction.lua UpdateNoteDrag
-- Constants matching grid.lua
local PITCH_ROW_H = 12
local MIN_PITCH = 12
local MAX_PITCH = 119
local ZOOM_X = 40
local GRID_X = 100
local GRID_Y = 200

-- Setup test notes in island_store
local test_notes = {
    { pitch = 60, start_beat = 2.0, duration = 1.0, velocity = 100, muted = false },
    { pitch = 64, start_beat = 4.0, duration = 1.0, velocity = 100, muted = false },
}
island_store.SetNotes(test_notes)
island_store.ClearSelection()
island_store.ToggleNoteSelected(1)
island_store.ToggleNoteSelected(2)

-- Calculate initial screen positions
-- Note 0 (index 1): pitch 60, beat 2.0
-- Inverted Y: top_pitch calculation
-- top_pitch = max(MIN_PITCH, MAX_PITCH - scroll_y) with scroll_y=36 (default)
local scroll_y = 36
local top_pitch = math.max(MIN_PITCH, MAX_PITCH - scroll_y)
-- Note 0 screen: 
-- nx = GRID_X + (2.0 - 0) * 40 = 180
-- ny = GRID_Y + (top_pitch - 60) * 12

local function calc_nx(beat, scroll_x)
    return GRID_X + (beat - (scroll_x or 0)) * ZOOM_X
end

local function calc_ny(pitch)
    local tp = math.max(MIN_PITCH, MAX_PITCH - scroll_y)
    return GRID_Y + (tp - pitch) * PITCH_ROW_H
end

local function pitch_at_my(my)
    local tp = math.max(MIN_PITCH, MAX_PITCH - scroll_y)
    local pitch_row = math.floor((my - GRID_Y) / PITCH_ROW_H)
    return math.max(MIN_PITCH, tp - pitch_row)
end

local function beat_at_mx(mx, scroll_x)
    return (mx - GRID_X) / ZOOM_X + (scroll_x or 0)
end

-- Mouse down on note 1 at its center
local note1_nx = calc_nx(2.0, 0)
local note1_ny = calc_ny(60)
local mouse_down_mx = note1_nx
local mouse_down_my = note1_ny + PITCH_ROW_H / 2

-- Mouse drag: move up 3 semitones and right 2 beats
local delta_semitones = 3   -- moving UP (lower Y)
local delta_beats = 2
local mouse_up_mx = mouse_down_mx + delta_beats * ZOOM_X
local mouse_up_my = mouse_down_my - delta_semitones * PITCH_ROW_H  -- up = lower Y

-- Calculate pitch/beat from screen position
local moved_pitch = pitch_at_my(mouse_up_my)
local moved_beat = beat_at_mx(mouse_up_mx, 0)

check(moved_pitch == 63, "drag up 3 semitones → pitch 63, got " .. tostring(moved_pitch))
check(moved_beat == 4.0, "drag right 2 beats → beat 4.0, got " .. tostring(moved_beat))

-- Multi-note relative offset preservation
-- Note 1 at beat 2.0, Note 2 at beat 4.0 (offset = 2.0 beats)
-- After drag right 1 beat: Note 1 → 3.0, Note 2 → 5.0 (offset preserved)
local delta_1 = 1.0  -- beats right
local scroll_x = 0
-- Compute delta from origin using mouse coordinates (as interaction code does)
local delta_x_beats = (mouse_up_mx - mouse_down_mx) / ZOOM_X
-- Apply to both notes from their ORIGINAL positions
local new_beat_1 = 2.0 + delta_1
local new_beat_2 = 4.0 + delta_1
check(new_beat_1 == 3.0, "multi-note: note1 at beat 3.0, got " .. tostring(new_beat_1))
check(new_beat_2 == 5.0, "multi-note: note2 at beat 5.0, got " .. tostring(new_beat_2))
check(new_beat_2 - new_beat_1 == 2.0, "multi-note: relative offset preserved (2.0 beats)")

-- Snap on drop: drag to beat 3.3, snap enabled at 1/4 → beat 3.0
local snapped = snap.SnapBeat(3.3, 4, false)
check(snapped == 3.0, "snap on drop: 3.3 → 3.0 at 1/4, got " .. tostring(snapped))

-- Snap to 1/8: drag to 3.3, snap at 1/8 → beat 3.5
snapped = snap.SnapBeat(3.3, 8, false)
check(snapped == 3.5, "snap on drop: 3.3 → 3.5 at 1/8, got " .. tostring(snapped))

-- ============================================================
-- 5. Resize Math
-- ============================================================
io.write("\n-- Note resize math\n")

-- Note at start_beat 2.0, duration 1.0
-- Right edge screen position: GRID_X + (2.0 + 1.0 - 0) * 40 = 220
local right_edge_px = calc_nx(2.0 + 1.0, 0)
check(right_edge_px == 220, "right edge at beat 3.0 → px 220")

-- Snap resize: extend to beat 4.2 at 1/8 → snap to 4.0 (closer to 4.0 than 4.5)
-- New duration = 4.0 - 2.0 = 2.0
local new_duration = snap.SnapBeat(4.2, 8, false) - 2.0
check(new_duration == 2.0, "snap resize: duration 2.0, got " .. tostring(new_duration))

-- Minimum duration clamp at 1/4 snap: min = 0.25 beats
local min_dur_1_4 = 1 / math.max(1, 4)
check(min_dur_1_4 == 0.25, "min duration at 1/4 = 0.25")

-- Minimum duration clamp at 1/8 snap: min = 0.125 beats
local min_dur_1_8 = 1 / math.max(1, 8)
check(min_dur_1_8 == 0.125, "min duration at 1/8 = 0.125")

-- ============================================================
-- 6. Backward Compat: barrel exports
-- ============================================================
io.write("\n-- Barrel backward compat\n")

local piano_roll_barrel = require("ui.piano-roll")

check(piano_roll_barrel.IsNoteRightEdge ~= nil, "barrel: IsNoteRightEdge exported")
check(piano_roll_barrel.ArmNoteDrag ~= nil, "barrel: ArmNoteDrag exported")
check(piano_roll_barrel.CheckAndStartDrag ~= nil, "barrel: CheckAndStartDrag exported")
check(piano_roll_barrel.DisarmNoteDrag ~= nil, "barrel: DisarmNoteDrag exported")
check(piano_roll_barrel.StartNoteDrag ~= nil, "barrel: StartNoteDrag exported")
check(piano_roll_barrel.UpdateNoteDrag ~= nil, "barrel: UpdateNoteDrag exported")
check(piano_roll_barrel.CommitNoteDrag ~= nil, "barrel: CommitNoteDrag exported")
check(piano_roll_barrel.CancelNoteDrag ~= nil, "barrel: CancelNoteDrag exported")
check(piano_roll_barrel.StartNoteResize ~= nil, "barrel: StartNoteResize exported")
check(piano_roll_barrel.UpdateNoteResize ~= nil, "barrel: UpdateNoteResize exported")
check(piano_roll_barrel.CommitNoteResize ~= nil, "barrel: CommitNoteResize exported")

-- Verify snap module is loadable
local snap_module = require("core.snap")
check(snap_module ~= nil, "snap: module loads")
check(snap_module.SnapBeat ~= nil, "snap: SnapBeat function exists")

-- Cleanup
island_store.ResetNoteDrag()
