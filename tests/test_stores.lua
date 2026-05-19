-- Tests for all 5 state stores: Init defaults, getter/setter round-trips,
-- consumable lifecycle (ui_store), edge cases (nil values, overwrites)

local check = require("tests.helpers").check
local compact_store = require("state.compact")
local drag_store = require("state.drag")
local sequencer_store = require("state.sequencer")
local midi_store = require("state.midi")
local ui_store = require("state.ui")

io.write("=== Store Tests ===\n")

-- ============================================================
-- 1. compact_store (6 pairs + overlay_active + last_gfx_state)
-- ============================================================
io.write("\n-- compact_store\n")

local compact_state = {
    compact = {},
    compact_overlay_active = false,
    last_gfx_state = { dock = 0, x = 100, y = 100, w = 720, h = 500 },
}
compact_store.Init(compact_state)

-- Defaults
check(compact_store.GetTransportHwnd() == nil, "compact: TransportHwnd default nil")
check(compact_store.GetOverlayActive() == false, "compact: OverlayActive default false")

-- Round-trips
compact_store.SetTransportHwnd(12345)
check(compact_store.GetTransportHwnd() == 12345, "compact: TransportHwnd round-trip")

compact_store.SetOverlayActive(true)
check(compact_store.GetOverlayActive() == true, "compact: OverlayActive round-trip")

compact_store.SetLastGfxState({ dock = 1, x = 200 })
check(compact_store.GetLastGfxState().dock == 1, "compact: LastGfxState round-trip")

-- Nil overwrite
compact_store.SetTransportHwnd(nil)
check(compact_store.GetTransportHwnd() == nil, "compact: TransportHwnd accept nil")

-- ============================================================
-- 2. drag_store (9 pairs + Reset)
-- ============================================================
io.write("\n-- drag_store\n")

local drag_state = {
    drag = {
        is_dragging = false, source_degree = -1, source_slot_idx = -1,
        pending_degree = nil, pending_slot_idx = nil,
        start_x = 0, start_y = 0, x = 0, y = 0,
    },
}
drag_store.Init(drag_state)

-- Defaults
check(drag_store.GetIsDragging() == false, "drag: IsDragging default false")
check(drag_store.GetSourceDegree() == -1, "drag: SourceDegree default -1")
check(drag_store.GetPendingDegree() == nil, "drag: PendingDegree default nil")

-- Round-trips
drag_store.SetIsDragging(true)
check(drag_store.GetIsDragging() == true, "drag: IsDragging round-trip")

drag_store.SetSourceDegree(3)
check(drag_store.GetSourceDegree() == 3, "drag: SourceDegree round-trip")

drag_store.SetSourceSlotIdx(7)
check(drag_store.GetSourceSlotIdx() == 7, "drag: SourceSlotIdx round-trip")

drag_store.SetPendingDegree(5)
check(drag_store.GetPendingDegree() == 5, "drag: PendingDegree round-trip")

drag_store.SetPendingSlotIdx(2)
check(drag_store.GetPendingSlotIdx() == 2, "drag: PendingSlotIdx round-trip")

drag_store.SetStartX(100)
check(drag_store.GetStartX() == 100, "drag: StartX round-trip")

drag_store.SetStartY(200)
check(drag_store.GetStartY() == 200, "drag: StartY round-trip")

drag_store.SetX(150)
check(drag_store.GetX() == 150, "drag: X round-trip")

drag_store.SetY(250)
check(drag_store.GetY() == 250, "drag: Y round-trip")

-- Reset clears all to defaults
drag_store.Reset()
check(drag_store.GetIsDragging() == false, "drag: Reset clears IsDragging")
check(drag_store.GetSourceDegree() == -1, "drag: Reset clears SourceDegree")
check(drag_store.GetPendingDegree() == nil, "drag: Reset clears PendingDegree")
check(drag_store.GetPendingSlotIdx() == nil, "drag: Reset clears PendingSlotIdx")
-- Non-reset fields preserved
check(drag_store.GetStartX() == 100, "drag: StartX preserved after Reset")
check(drag_store.GetY() == 250, "drag: Y preserved after Reset")

-- ============================================================
-- 3. sequencer_store (14 fields + progression helpers + Clear)
-- ============================================================
io.write("\n-- sequencer_store\n")

local seq_state = {
    progression = {},
    sequencer = {
        is_playing = false, current_step = 0, last_measure = -1,
        midi_notes = {}, progress = 0, internal_beats = 0,
        last_time = nil, volume = 100,
    },
    current_page = 1, page_override_timer = 0,
    slot_flash = { idx = -1, timer = 0 },
}
sequencer_store.Init(seq_state)

-- Progression helpers
check(sequencer_store.GetProgressionLen() == 0, "seq: ProgressionLen default 0")
check(sequencer_store.GetProgressionEntry(1) == nil, "seq: ProgressionEntry 1 default nil")

sequencer_store.SetProgressionEntry(5, { degree = 3 })
check(sequencer_store.GetProgressionEntry(5).degree == 3, "seq: ProgressionEntry set/get")

-- ClearProgression
sequencer_store.SetProgressionEntry(1, { degree = 1 })
sequencer_store.SetProgressionEntry(2, { degree = 2 })
sequencer_store.ClearProgression()
check(sequencer_store.GetProgressionEntry(1) == nil, "seq: ClearProgression removes entry 1")
check(sequencer_store.GetProgressionEntry(2) == nil, "seq: ClearProgression removes entry 2")

-- Sequencer playback fields round-trips
sequencer_store.SetIsPlaying(true)
check(sequencer_store.GetIsPlaying() == true, "seq: IsPlaying round-trip")

sequencer_store.SetCurrentStep(3)
check(sequencer_store.GetCurrentStep() == 3, "seq: CurrentStep round-trip")

sequencer_store.SetLastMeasure(2)
check(sequencer_store.GetLastMeasure() == 2, "seq: LastMeasure round-trip")

sequencer_store.SetVolume(75)
check(sequencer_store.GetVolume() == 75, "seq: Volume round-trip")

sequencer_store.SetProgress(0.5)
check(sequencer_store.GetProgress() == 0.5, "seq: Progress round-trip")

sequencer_store.SetLastTime(123.456)
check(sequencer_store.GetLastTime() == 123.456, "seq: LastTime round-trip")

-- Page state
sequencer_store.SetCurrentPage(3)
check(sequencer_store.GetCurrentPage() == 3, "seq: CurrentPage round-trip")

sequencer_store.SetPageOverrideTimer(15)
check(sequencer_store.GetPageOverrideTimer() == 15, "seq: PageOverrideTimer round-trip")

-- Slot flash
sequencer_store.SetSlotFlashIdx(4)
check(sequencer_store.GetSlotFlashIdx() == 4, "seq: SlotFlashIdx round-trip")

sequencer_store.SetSlotFlashTimer(8)
check(sequencer_store.GetSlotFlashTimer() == 8, "seq: SlotFlashTimer round-trip")

-- ============================================================
-- 4. midi_store (3 simple fields + key_states + active_notes + mouse_pad_state)
-- ============================================================
io.write("\n-- midi_store\n")

local midi_state = {
    use_velocity = false,
    last_note_played = "None",
    active_note_draw_timer = 0,
    key_states = {},
    active_notes = {},
    mouse_pad_state = { active_degree = -1, midi_notes = {} },
}
midi_store.Init(midi_state)

-- Simple fields
check(midi_store.GetUseVelocity() == false, "midi: UseVelocity default false")
midi_store.SetUseVelocity(true)
check(midi_store.GetUseVelocity() == true, "midi: UseVelocity round-trip")

check(midi_store.GetLastNotePlayed() == "None", "midi: LastNotePlayed default 'None'")
midi_store.SetLastNotePlayed("C4")
check(midi_store.GetLastNotePlayed() == "C4", "midi: LastNotePlayed round-trip")

check(midi_store.GetActiveNoteDrawTimer() == 0, "midi: ActiveNoteDrawTimer default 0")
midi_store.SetActiveNoteDrawTimer(25)
check(midi_store.GetActiveNoteDrawTimer() == 25, "midi: ActiveNoteDrawTimer round-trip")

-- Key states (indexed)
check(midi_store.GetKeyState(65) == nil, "midi: KeyState 65 default nil")
midi_store.SetKeyState(65, { is_pressed = true, midi_notes = {}, code = 65 })
check(midi_store.GetKeyState(65).is_pressed == true, "midi: KeyState 65 set/get")
-- Key states (full table ref)
local ks = midi_store.GetKeyStates()
check(ks[65] ~= nil, "midi: GetKeyStates ref includes key 65")

-- Active notes (ref-counted, indexed)
check(midi_store.GetActiveNote(60) == nil, "midi: ActiveNote 60 default nil")
midi_store.SetActiveNote(60, 1)
check(midi_store.GetActiveNote(60) == 1, "midi: ActiveNote 60 set/get")
midi_store.SetActiveNote(60, 2)
check(midi_store.GetActiveNote(60) == 2, "midi: ActiveNote 60 increment")
-- Set nil clears
midi_store.SetActiveNote(60, nil)
check(midi_store.GetActiveNote(60) == nil, "midi: ActiveNote 60 clear via nil")
-- ClearActiveNotes
midi_store.SetActiveNote(61, 1)
midi_store.SetActiveNote(62, 3)
midi_store.ClearActiveNotes()
check(midi_store.GetActiveNote(61) == nil, "midi: ClearActiveNotes removes 61")
check(midi_store.GetActiveNote(62) == nil, "midi: ClearActiveNotes removes 62")

-- Mouse pad state (table ref)
local mps = midi_store.GetMousePadState()
check(mps.active_degree == -1, "midi: MousePadState active_degree default -1")
mps.active_degree = 4
check(midi_store.GetMousePadState().active_degree == 4, "midi: MousePadState mutable ref")

-- ============================================================
-- 5. ui_store (14 simple fields + Consume lifecycle + pad_flash)
-- ============================================================
io.write("\n-- ui_store\n")

local ui_state = {
    view_mode = 1,
    mouse_click = false, mouse_wheel_delta = 0,
    show_tooltips = false, color_mode = "grade",
    last_mouse_cap = 0, slider_dragging = false,
    pad_flash = { degree = -1, timer = 0, prev_active = {} },
    docked_mode = false, dock_id = 0,
    auto_start_compact = false, auto_start_reaper = false,
    did_cleanup = false, use_scroll = true,
}
ui_store.Init(ui_state)

-- View
check(ui_store.GetViewMode() == 1, "ui: ViewMode default 1")
ui_store.SetViewMode(2)
check(ui_store.GetViewMode() == 2, "ui: ViewMode round-trip")

-- Preferences
check(ui_store.GetShowTooltips() == false, "ui: ShowTooltips default false")
ui_store.SetShowTooltips(true)
check(ui_store.GetShowTooltips() == true, "ui: ShowTooltips round-trip")

check(ui_store.GetColorMode() == "grade", "ui: ColorMode default grade")
ui_store.SetColorMode("flat")
check(ui_store.GetColorMode() == "flat", "ui: ColorMode round-trip")

check(ui_store.GetUseScroll() == true, "ui: UseScroll default true")
ui_store.SetUseScroll(false)
check(ui_store.GetUseScroll() == false, "ui: UseScroll round-trip")

-- State flags
check(ui_store.GetLastMouseCap() == 0, "ui: LastMouseCap default 0")
ui_store.SetLastMouseCap(5)
check(ui_store.GetLastMouseCap() == 5, "ui: LastMouseCap round-trip")

check(ui_store.GetSliderDragging() == false, "ui: SliderDragging default false")
ui_store.SetSliderDragging(true)
check(ui_store.GetSliderDragging() == true, "ui: SliderDragging round-trip")

-- Dock
check(ui_store.GetDockedMode() == false, "ui: DockedMode default false")
check(ui_store.GetDockId() == 0, "ui: DockId default 0")
ui_store.SetDockedMode(true)
ui_store.SetDockId(123)
check(ui_store.GetDockedMode() == true, "ui: DockedMode round-trip")
check(ui_store.GetDockId() == 123, "ui: DockId round-trip")

-- Auto-start
check(ui_store.GetAutoStartCompact() == false, "ui: AutoStartCompact default false")
check(ui_store.GetAutoStartReaper() == false, "ui: AutoStartReaper default false")
ui_store.SetAutoStartCompact(true)
check(ui_store.GetAutoStartCompact() == true, "ui: AutoStartCompact round-trip")

-- Guard
check(ui_store.GetDidCleanup() == false, "ui: DidCleanup default false")
ui_store.SetDidCleanup(true)
check(ui_store.GetDidCleanup() == true, "ui: DidCleanup round-trip")

-- Pad flash
check(ui_store.GetPadFlashDegree() == -1, "ui: PadFlashDegree default -1")
ui_store.SetPadFlashDegree(7)
check(ui_store.GetPadFlashDegree() == 7, "ui: PadFlashDegree round-trip")
check(ui_store.GetPadFlashTimer() == 0, "ui: PadFlashTimer default 0")
ui_store.SetPadFlashTimer(12)
check(ui_store.GetPadFlashTimer() == 12, "ui: PadFlashTimer round-trip")
ui_store.ClearPadFlash()
check(ui_store.GetPadFlashDegree() == -1, "ui: ClearPadFlash resets degree")
check(ui_store.GetPadFlashTimer() == 0, "ui: ClearPadFlash resets timer")

-- ============================================================
-- Consume lifecycle (ui_store: mouse_click, mouse_wheel_delta)
-- ============================================================
io.write("\n-- Consume lifecycle\n")

-- ConsumeMouseClick: set true, consume returns true, second consume returns false
ui_store.SetMouseClick(true)
check(ui_store.ConsumeMouseClick() == true, "consume: first ConsumeMouseClick returns true")
check(ui_store.ConsumeMouseClick() == false, "consume: second ConsumeMouseClick returns false")
check(ui_store.GetMouseClick() == false, "consume: GetMouseClick false after consume")

-- Set false → consume returns false
ui_store.SetMouseClick(false)
check(ui_store.ConsumeMouseClick() == false, "consume: ConsumeMouseClick false when never set")

-- ConsumeMouseWheelDelta: set delta, consume returns it, second returns 0
ui_store.SetMouseWheelDelta(120)
check(ui_store.ConsumeMouseWheelDelta() == 120, "consume: first ConsumeMouseWheelDelta returns 120")
check(ui_store.ConsumeMouseWheelDelta() == 0, "consume: second ConsumeMouseWheelDelta returns 0")
check(ui_store.GetMouseWheelDelta() == 0, "consume: GetMouseWheelDelta 0 after consume")

-- Zero delta → consume returns 0
check(ui_store.ConsumeMouseWheelDelta() == 0, "consume: ConsumeMouseWheelDelta 0 when never set")
