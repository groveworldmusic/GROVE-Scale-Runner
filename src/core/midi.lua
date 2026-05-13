-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
local config = require("config")
local compact_store = require("state.compact")
local sequencer_store = require("state.sequencer")
local midi_store = require("state.midi")
local ui_store = require("state.ui")
local island_store = require("state.island")
local api_guard = require("core.api-guard")
-- NOTE: do NOT require core.sequencer here — creates circular dependency (sequencer → midi → sequencer)
local COLLAPSED_H = 497
local EXPANDED_H = 793
local midi = {}

-- MIDI state fields (moved from config.state)
midi.midi_island_expanded = false
midi.midi_channel = 1
midi.midi_island_toggled = false

function midi.GetMidiNote(root_idx, scale_idx, degree_idx, octave_val)
    local root = (api_guard.ClampIndex(root_idx, 1, 12) or root_idx) - 1
    local si = api_guard.ClampIndex(scale_idx, 1, #config.SCALES)
    local scale = config.SCALES[si]
    if not scale then return 60 end  -- fallback to middle C
    local n_scale = #scale.intervals
    local deg0 = degree_idx - 1
    local oct_off = math.floor(deg0 / n_scale)
    local interval = scale.intervals[(deg0 % n_scale) + 1]
    local result = (octave_val + 1) * 12 + root + (oct_off * 12) + interval
    return math.max(0, math.min(127, result))
end

function midi.SendMidi(note, on, velocity, force)
    if not note or note < 0 or note > 127 then return end
    local vel = velocity or 100
    local ch = midi.midi_channel - 1
    if on then
        -- Note-on: apply volume, always send
        local vol = sequencer_store.GetVolume() or 100
        vel = math.floor(vel * vol / 100)
        reaper.StuffMIDIMessage(ch, 0x90, note, vel)
        local name = config.NOTE_NAMES[(note % 12) + 1] or "?"
        midi_store.SetLastNotePlayed(string.format("%s%d", name, math.floor(note/12)-1))
        midi_store.SetActiveNoteDrawTimer(20)
        midi_store.SetActiveNote(note, (midi_store.GetActiveNote(note) or 0) + 1)
    else
        -- Note-off: only send 0x80 when ref-count reaches 0 (or force=true bypasses gate)
        local cur = midi_store.GetActiveNote(note)
        if cur then
            cur = cur - 1
            if cur <= 0 then
                midi_store.SetActiveNote(note, nil)
            else
                midi_store.SetActiveNote(note, cur)
            end
            if cur <= 0 or force then
                reaper.StuffMIDIMessage(ch, 0x80, note, 0)
            end
        end
    end
end

function midi.InvertChord(notes, inv_idx, direction)
    -- Pure function: reorder chord notes by moving N notes up/down an octave
    -- inv_idx is 1-based: 1=Base, 2=1st, 3=2nd, 4=3rd
    -- direction: 0=UP (bottom notes move up 12, standard), 1=DN (bottom notes move down 12)
    if not notes or #notes == 0 then return notes end
    local n = #notes
    local move = math.min(inv_idx or 1, n) - 1  -- how many notes to shift
    if move <= 0 then return notes end
    local result = {}
    if direction and direction == 1 then
        -- DN: same bottom notes go DOWN an octave instead of up
        for i = move + 1, n do result[#result + 1] = notes[i] end
        for i = 1, move do result[#result + 1] = notes[i] - 12 end
        table.sort(result)
    else
        -- UP (default, standard): bottom notes go UP an octave
        for i = move + 1, n do result[#result + 1] = notes[i] end
        for i = 1, move do result[#result + 1] = notes[i] + 12 end
    end
    return result
end

function midi.TriggerChord(degree, on, ctx, velocity, inversion_index)
    local c = ctx or config.state
    local cmi = api_guard.ClampIndex(c.chord_mode_index, 1, #config.CHORD_MODES)
    local ri = api_guard.ClampIndex(c.root_index, 1, 12)
    local si = api_guard.ClampIndex(c.scale_index, 1, #config.SCALES)
    local notes = {}
    local offsets = config.CHORD_MODES[cmi].offsets
    for _, off in ipairs(offsets) do
        local n = midi.GetMidiNote(ri, si, degree + off, c.octave)
        table.insert(notes, n)
    end
    -- Apply inversion (parameter takes precedence, fallback to config.state)
    local inv = inversion_index or config.state.inversion_index
    if inv and inv > 1 then
        notes = midi.InvertChord(notes, inv, config.state.inversion_direction)
    end
    -- Send MIDI (after inversion)
    for _, n in ipairs(notes) do
        midi.SendMidi(n, on, velocity)
    end
    return notes
end

function midi.AllNotesOff(force)
    -- Send CC 123 (All Notes Off) — some VSTs respond to this
    reaper.StuffMIDIMessage(midi.midi_channel - 1, 0xB0, 123, 0)
    
    -- Explicit note-offs: not all VSTs respond to CC 123, so send individual Note Off
    -- for every held note before clearing state tables
    for _, s in pairs(midi_store.GetKeyStates()) do
        for _, n in ipairs(s.midi_notes) do
            midi.SendMidi(n, false, nil, force)
        end
        s.is_pressed = false
        s.midi_notes = {}
    end
    
    local mps = midi_store.GetMousePadState()
    for _, n in ipairs(mps.midi_notes) do
        midi.SendMidi(n, false, nil, force)
    end
    mps.active_degree = -1
    mps.midi_notes = {}
    
    midi_store.ClearActiveNotes()
    
    -- NOTE: sequencer.Stop() is called at each AllNotesOff call site in main.lua
    -- to avoid circular dependency (sequencer → midi → sequencer)
end

function midi.ExportToMidi()
    reaper.Undo_BeginBlock()

    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.Undo_EndBlock("Export MIDI", -1)
        reaper.MB("No track selected for MIDI export.\nPlease select a track first.", "Export MIDI", 0)
        return
    end
    -- Validate track pointer is still valid
    if not reaper.ValidatePtr(track, "MediaTrack*") then
        reaper.Undo_EndBlock("Export MIDI", -1)
        reaper.MB("Selected track is no longer valid.", "Export MIDI", 0)
        return
    end
    local start_qn = reaper.TimeMap_timeToQN(reaper.GetCursorPosition())
    
    -- Find last filled slot in all 16 slots
    local count = 0
    for i=16, 1, -1 do 
        if sequencer_store.GetProgressionEntry(i) then 
            count = i 
            break 
        end 
    end
    if count == 0 then
        reaper.Undo_EndBlock("Export MIDI", -1)
        return
    end
    
    local end_qn = start_qn + (count * 4)
    local item = reaper.CreateNewMIDIItemInProj(track, reaper.TimeMap_QNToTime(start_qn), reaper.TimeMap_QNToTime(end_qn), false)
    if not item then  -- guard: CreateNewMIDIItemInProj may return nil
        reaper.Undo_EndBlock("Export MIDI", -1)
        return
    end
    if not reaper.ValidatePtr(item, "MediaItem*") then
        reaper.Undo_EndBlock("Export MIDI", -1)
        return
    end
    local take = reaper.GetActiveTake(item)
    if not take or not reaper.ValidatePtr(take, "MediaTake*") then
        reaper.Undo_EndBlock("Export MIDI", -1)
        return
    end
    for i=1, count do
        local slot = sequencer_store.GetProgressionEntry(i)
        if slot then
            local q0 = start_qn + (i-1)*4
            local p0, p1 = reaper.MIDI_GetPPQPosFromProjQN(take, q0), reaper.MIDI_GetPPQPosFromProjQN(take, q0+4)
            local export_vel = 100
            local cmi = api_guard.ClampIndex(slot.chord_mode_index, 1, #config.CHORD_MODES)
            for _, off in ipairs(config.CHORD_MODES[cmi].offsets) do
                local n = midi.GetMidiNote(slot.root_index, slot.scale_index, slot.degree+off, slot.octave)
                reaper.MIDI_InsertNote(take, false, false, p0, p1, 0, n, export_vel, true)
            end
        end
    end
    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Export MIDI", -1)
end

-- Toggle the MIDI island expanded/collapsed state (moved from ui/views.lua)
-- Resizes window via gfx.quit()+gfx.init(). Docked mode is not supported.
-- Saves pre-toggle state to island_store for resilience (PR1b).
function midi.ToggleIsland()
    if ui_store.GetDockedMode() then return end
    midi.midi_island_expanded = not midi.midi_island_expanded
    midi.midi_island_toggled = true
    local dock = gfx.dock(-1)
    local gs = compact_store.GetLastGfxState()
    local hwnd = gfx.hwnd
    if hwnd then
        local l, t, r, b = reaper.JS_Window_GetRect(hwnd)
        gs.x, gs.y = l, t
        -- Save to island_store for resilience across toggle
        island_store.SetPreToggleDock(dock)
        island_store.SetPreToggleRect({x = l, y = t})
    end
    island_store.SetIslandTransitioning(true)
    local new_h = midi.midi_island_expanded and EXPANDED_H or COLLAPSED_H
    gfx.quit()
    gfx.init(config.script_title, 720, new_h, dock, gs.x, gs.y)
    gfx.setfont(1, "Calibri", 16)
    island_store.SetIslandTransitioning(false)
end

return midi
