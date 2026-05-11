-- GROVE FL MIDI: Island State Store
-- Encapsulates island piano-roll state with getters/setters.
-- Schema: island_active, preset_panel_visible, notes (flat note list),
--         playback_pos, scroll_offset_y/x, zoom_x, selected_note_index, note_count.
local config = require("config")

local island_state = {
    island_active = false,
    preset_panel_visible = true,
    notes = {},
    playback_pos = 0,
    scroll_offset_y = 48,
    scroll_offset_x = 0,
    zoom_x = 40,
    selected_note_index = nil,
    note_count = 0,

    -- Preset browser state
    current_directory = "",
    preset_root = "",
    preset_tree = {},
    preset_files = {},
    selected_preset_idx = nil,
    browser_scroll = 0,
    browser_error = nil,
    favorites = {},
    bookmarks = {},
}

local m = {}

function m.Init(defaults)
    if defaults.island_active ~= nil then island_state.island_active = defaults.island_active end
    if defaults.preset_panel_visible ~= nil then island_state.preset_panel_visible = defaults.preset_panel_visible end
    if defaults.notes then
        -- notes are shared by reference
        island_state.notes = defaults.notes
        island_state.note_count = #defaults.notes
    end
    if defaults.playback_pos ~= nil then island_state.playback_pos = defaults.playback_pos end
    if defaults.scroll_offset_y ~= nil then island_state.scroll_offset_y = defaults.scroll_offset_y end
    if defaults.scroll_offset_x ~= nil then island_state.scroll_offset_x = defaults.scroll_offset_x end
    if defaults.zoom_x ~= nil then island_state.zoom_x = defaults.zoom_x end
    if defaults.selected_note_index ~= nil then island_state.selected_note_index = defaults.selected_note_index end
    if defaults.current_directory ~= nil then island_state.current_directory = defaults.current_directory end
    if defaults.preset_root ~= nil then island_state.preset_root = defaults.preset_root end
end

-- Island active state
function m.GetIslandActive() return island_state.island_active end
function m.SetIslandActive(v) island_state.island_active = v end

-- Preset panel visibility (collapsible left panel)
function m.GetPresetPanelVisible() return island_state.preset_panel_visible end
function m.SetPresetPanelVisible(v) island_state.preset_panel_visible = v end

-- Notes table — returned by reference for in-place mutation
-- Each entry: {pitch, start_beat, duration, velocity, muted}
function m.GetNotes() return island_state.notes end
function m.SetNotes(t)
    island_state.notes = t or {}
    island_state.note_count = #island_state.notes
end

-- Note count — updated automatically by SetNotes, can also be set directly
function m.GetNoteCount() return island_state.note_count end
function m.SetNoteCount(v) island_state.note_count = v end

-- Playback position (beats)
function m.GetPlaybackPos() return island_state.playback_pos end
function m.SetPlaybackPos(v) island_state.playback_pos = v end

-- Vertical scroll offset (pitch rows) — clamped to 0..56
-- 73 pitch rows (C2=36 to C8=108), min 17 visible → max offset = 56
function m.GetScrollOffsetY() return island_state.scroll_offset_y end
function m.SetScrollOffsetY(v)
    island_state.scroll_offset_y = math.max(0, math.min(56, v))
end

-- Horizontal scroll offset (beats) — clamped to non-negative
function m.GetScrollOffsetX() return island_state.scroll_offset_x end
function m.SetScrollOffsetX(v)
    island_state.scroll_offset_x = math.max(0, v)
end

-- Zoom level (pixels per beat) — clamped to 10..200
function m.GetZoomX() return island_state.zoom_x end
function m.SetZoomX(v)
    island_state.zoom_x = math.max(10, math.min(200, v))
end

-- Selected note index (number or nil)
function m.GetSelectedNoteIndex() return island_state.selected_note_index end
function m.SetSelectedNoteIndex(v) island_state.selected_note_index = v end

-- Preset browser state
function m.GetCurrentDirectory() return island_state.current_directory end
function m.SetCurrentDirectory(v) island_state.current_directory = v or "" end
function m.GetPresetRoot() return island_state.preset_root end
function m.SetPresetRoot(v) island_state.preset_root = v or "" end
function m.GetPresetTree() return island_state.preset_tree end
function m.SetPresetTree(t) island_state.preset_tree = t or {} end
function m.GetPresetFiles() return island_state.preset_files end
function m.SetPresetFiles(t) island_state.preset_files = t or {} end
function m.GetSelectedPresetIdx() return island_state.selected_preset_idx end
function m.SetSelectedPresetIdx(v) island_state.selected_preset_idx = v end
function m.GetBrowserScroll() return island_state.browser_scroll end
function m.SetBrowserScroll(v) island_state.browser_scroll = math.max(0, v or 0) end
function m.GetBrowserError() return island_state.browser_error end
function m.SetBrowserError(v) island_state.browser_error = v end
function m.GetFavorites() return island_state.favorites end
function m.SetFavorites(t) island_state.favorites = t or {} end
function m.GetBookmarks() return island_state.bookmarks end
function m.SetBookmarks(t) island_state.bookmarks = t or {} end

function m.ClearBrowserState()
    island_state.current_directory = ""
    island_state.preset_tree = {}
    island_state.preset_files = {}
    island_state.selected_preset_idx = nil
    island_state.browser_scroll = 0
    island_state.browser_error = nil
end

-- =========================================================
-- Progression→Notes Conversion
-- =========================================================

--- Pure function: converts a progression entry to a MIDI pitch.
--- Matches the formula from midi.GetMidiNote (core/midi.lua line 14-23)
--- without requiring the midi module directly.
--- @param root_idx number 1-12 (index into NOTE_NAMES)
--- @param scale_idx number 1-21 (index into SCALES)
--- @param degree_idx number 1-N (scale degree, wraps by scale length)
--- @param octave_val number 0-8 (MIDI octave)
--- @return number 0-127 (MIDI pitch)
local function ProgressionEntryToPitch(root_idx, scale_idx, degree_idx, octave_val)
    local root = root_idx - 1
    local scale = config.SCALES[scale_idx]
    local n_scale = #scale.intervals
    local deg0 = degree_idx - 1
    local oct_off = math.floor(deg0 / n_scale)
    local interval = scale.intervals[(deg0 % n_scale) + 1]
    local result = (octave_val + 1) * 12 + root + (oct_off * 12) + interval
    return math.max(0, math.min(127, result))
end

--- Convert a progression entry table to a list of note pitches.
--- Each entry has {degree, root_index, scale_index, octave, chord_mode_index}.
--- Each chord offset produces one pitch.
--- @param entry table Progression slot entry
--- @return table Array of MIDI pitch numbers
local function EntryToPitches(entry)
    local chord_mode = config.CHORD_MODES[entry.chord_mode_index or 1]
    local pitches = {}
    for _, off in ipairs(chord_mode.offsets) do
        local pitch = ProgressionEntryToPitch(
            entry.root_index or 1,
            entry.scale_index or 1,
            entry.degree + off,
            entry.octave or 4
        )
        table.insert(pitches, pitch)
    end
    return pitches
end

--- Convert a progression table to a flat list of note entries.
--- Each slot i produces notes starting at (i-1) * beats_per_slot beats.
--- Each chord offset becomes a separate note entry.
---
--- @param progression table Array of progression entries (1..16, may have nils)
--- @param beats_per_slot number Beats per slot (default 4)
--- @param velocity number Default velocity (default 100)
--- @return table Array of {pitch, start_beat, duration, velocity, muted}
function m.ProgressionToNotes(progression, beats_per_slot, velocity)
    beats_per_slot = beats_per_slot or 4
    velocity = velocity or 100
    local notes = {}

    if not progression then return notes end

    for i = 1, 16 do
        local entry = progression[i]
        if entry and entry.degree then
            local start_beat = (i - 1) * beats_per_slot
            local pitches = EntryToPitches(entry)
            for _, pitch in ipairs(pitches) do
                table.insert(notes, {
                    pitch = pitch,
                    start_beat = start_beat,
                    duration = beats_per_slot,
                    velocity = velocity,
                    muted = false,
                })
            end
        end
    end

    return notes
end

--- Convenience: reads progression from sequencer_store and populates island notes.
--- Call this when entering island mode to materialise the progression as note blocks.
function m.LoadNotesFromProgression(seq_store)
    local progression = seq_store.GetProgression()
    local notes = m.ProgressionToNotes(progression, 4, 100)
    m.SetNotes(notes)
end

--- Filter notes by visible pitch and time range (for virtual scrolling).
--- @param notes table Full notes array
--- @param pitch_start number Minimum pitch (inclusive)
--- @param pitch_end number Maximum pitch (inclusive)
--- @param beat_start number Minimum beat (inclusive)
--- @param beat_end number Maximum beat (inclusive)
--- @return table Filtered notes (sub-set suitable for rendering)
function m.GetVisibleNotes(notes, pitch_start, pitch_end, beat_start, beat_end)
    local result = {}
    if not notes then return result end
    for _, note in ipairs(notes) do
        if note.pitch >= pitch_start and note.pitch <= pitch_end then
            local ns = note.start_beat
            local nd = note.duration or 1
            if ns + nd >= beat_start and ns <= beat_end then
                table.insert(result, note)
            end
        end
    end
    return result
end

return m
