-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordov�
-- GROVE Scale Runner: Global Configuration and State
local config = {}

config.APP_NAME = "GROVE Scale Runner"
config.EXTSTATE_NS = "GROVE_Scale_Runner"
config.script_title = "Scale Runner"

config.NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

config.SCALES = {
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

config.CHORD_MODES = {
    {name="Off", offsets={0}},
    {name="Tri", offsets={0, 2, 4}},
    {name="7ma", offsets={0, 2, 4, 6}},
    {name="9na", offsets={0, 2, 4, 6, 8}},
    {name="sus2", offsets={0, 2, 7}},
    {name="sus4", offsets={0, 5, 7}},
    {name="dim", offsets={0, 3, 6}},
    {name="aug", offsets={0, 4, 8}},
    {name="11th", offsets={0, 4, 7, 10, 14, 17}},
    {name="13th", offsets={0, 4, 7, 10, 14, 17, 21}}
}

config.INVERSION_MODES = {"Base", "1st", "2nd", "3rd"}

config.SUBDIVISION_MODES = {1, 2, 3, 4, 8, 16}
config.SUBDIVISION_LABELS = {"1/1", "1/2", "1/3", "1/4", "1/8", "1/16"}

config.VIEW_MODES = { FULL = 1, COMPACT = 2 }

-- Docked Transport Bar dimensions
config.DOCK_MIN_W, config.DOCK_MIN_H = 400, 50

-- Preference keys persisted via reaper.SetExtState/GetExtState.
-- These must match the key registry in state/persist.lua.
config.PREF_KEYS = {
    "root_index",
    "scale_index",
    "octave",
    "chord_mode_index",
    "inversion_index",
    "inversion_direction",
    "subdivision_index",
    "volume",
    "color_mode",
}

-- Expanded state for Pagination (16 slots, 4 pages)
config.state = {
    view_mode = config.VIEW_MODES.FULL,
    root_index = 1, scale_index = 1, octave = 4, chord_mode_index = 1, inversion_index = 1, inversion_direction = 0, subdivision_index = 1,
    use_velocity = true,
    use_scroll = true,
    show_tooltips = false,
    last_note_played = "None", active_note_draw_timer = 0,
    key_states = {},
    mouse_pad_state = { active_degree = -1, midi_notes = {} },
    pad_flash = { degree = -1, timer = 0, prev_active = {} },
    drag = { is_dragging = false, source_degree = -1, source_slot_idx = -1, start_x = 0, start_y = 0, x = 0, y = 0, pending_degree = nil, pending_slot_idx = nil },
    slider_dragging = false,
    progression = {}, -- Now holds up to 16 slots
    current_page = 1, -- Page 1 to 4
    page_override_timer = 0,
    slot_flash = { idx = -1, timer = 0 },
    sequencer = { is_playing = false, current_step = 0, last_measure = -1, midi_notes = {}, progress = 0, internal_beats = 0, last_time = nil, volume = 100 },
    active_notes = {},  -- ref-counted: [midi_note] = count
    color_mode = "grade", -- "grade" = grade_colors per degree, "flat" = all blue
    last_mouse_cap = 0, mouse_click = false, mouse_wheel_delta = 0,
    view_offset_x = 1000,
    view_offset_y = 0,
    -- Auto-start configuration
    auto_start_compact = false,  -- Start compact bar overlay alongside full view
    auto_start_reaper = false,   -- Auto-launch this script when REAPER starts
    auto_track_setup = true,     -- Auto-arm + monitor + MIDI input on track selection
    compact_overlay_active = false,  -- Compact bar visible alongside full view
    -- Docked transport bar state
    docked_mode = false,
    dock_id = 0,
    -- (MIDI Island state moved to core/midi.lua)
    -- Compact composite state (for JS_Composite transport bar view)
    last_gfx_state = {dock=0, x=100, y=100, w=720, h=500},
    -- Compact composite resources (managed by ui/compact.lua)
    compact = {
        transport_hwnd = nil,
        lice_bitmap = nil,
        lice_font = nil,
        gdi_font = nil
    }
}

-- Initialize 16 slots (table already empty)

-- Maps from original prototype
-- Row-based mapping (Degree 1-7, Octave Offset)
config.VKEY_MAP = {
    -- Row 1: Numbers (Octave + 1)
    [0x31]={deg=1, oct=1}, [0x32]={deg=2, oct=1}, [0x33]={deg=3, oct=1}, [0x34]={deg=4, oct=1}, [0x35]={deg=5, oct=1}, [0x36]={deg=6, oct=1}, [0x37]={deg=7, oct=1},
    -- Row 2: QWERTYU (Octave + 0 - Base)
    [0x51]={deg=1, oct=0}, [0x57]={deg=2, oct=0}, [0x45]={deg=3, oct=0}, [0x52]={deg=4, oct=0}, [0x54]={deg=5, oct=0}, [0x59]={deg=6, oct=0}, [0x55]={deg=7, oct=0},
    -- Row 3: ASDFGHJ (Octave - 1)
    [0x41]={deg=1, oct=-1}, [0x53]={deg=2, oct=-1}, [0x44]={deg=3, oct=-1}, [0x46]={deg=4, oct=-1}, [0x47]={deg=5, oct=-1}, [0x48]={deg=6, oct=-1}, [0x4A]={deg=7, oct=-1},
    -- Row 4: ZXCVBNM (Octave - 2)
    [0x5A]={deg=1, oct=-2}, [0x58]={deg=2, oct=-2}, [0x43]={deg=3, oct=-2}, [0x56]={deg=4, oct=-2}, [0x42]={deg=5, oct=-2}, [0x4E]={deg=6, oct=-2}, [0x4D]={deg=7, oct=-2},
}

for k_code, _ in pairs(config.VKEY_MAP) do 
    config.state.key_states[k_code] = {is_pressed = false, midi_notes = {}, code = k_code} 
end

return config
