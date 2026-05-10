local config = require("config")
-- NOTE: do NOT require core.sequencer here — creates circular dependency (sequencer → midi → sequencer)
local midi = {}

function midi.GetMidiNote(root_idx, scale_idx, degree_idx, octave_val)
    local root = root_idx - 1
    local scale = config.SCALES[scale_idx]
    local n_scale = #scale.intervals
    local deg0 = degree_idx - 1
    local oct_off = math.floor(deg0 / n_scale)
    local interval = scale.intervals[(deg0 % n_scale) + 1]
    local result = (octave_val + 1) * 12 + root + (oct_off * 12) + interval
    return math.max(0, math.min(127, result))
end

function midi.SendMidi(note, on, velocity)
    if not note or note < 0 or note > 127 then return end
    local vel = velocity or 100
    if on then local vol = config.state.sequencer.volume or 100; vel = math.floor(vel * vol / 100) end
    local ch = config.state.midi_channel - 1
    reaper.StuffMIDIMessage(ch, on and 0x90 or 0x80, note, on and vel or 0)
    if on then
        local name = config.NOTE_NAMES[(note % 12) + 1] or "?"
        config.state.last_note_played = string.format("%s%d", name, math.floor(note/12)-1)
        config.state.active_note_draw_timer = 20
        config.state.active_notes[note] = (config.state.active_notes[note] or 0) + 1
    else
        if config.state.active_notes[note] then
            config.state.active_notes[note] = config.state.active_notes[note] - 1
            if config.state.active_notes[note] <= 0 then
                config.state.active_notes[note] = nil
            end
        end
    end
end

function midi.TriggerChord(degree, on, ctx, velocity)
    local c = ctx or config.state
    local notes = {}
    local offsets = config.CHORD_MODES[c.chord_mode_index].offsets
    for _, off in ipairs(offsets) do
        local n = midi.GetMidiNote(c.root_index, c.scale_index, degree + off, c.octave)
        midi.SendMidi(n, on, velocity)
        table.insert(notes, n)
    end
    return notes
end

function midi.AllNotesOff()
    -- Send CC 123 (All Notes Off) — some VSTs respond to this
    reaper.StuffMIDIMessage(config.state.midi_channel - 1, 0xB0, 123, 0)
    
    -- Explicit note-offs: not all VSTs respond to CC 123, so send individual Note Off
    -- for every held note before clearing state tables
    for _, s in pairs(config.state.key_states) do
        for _, n in ipairs(s.midi_notes) do
            midi.SendMidi(n, false)
        end
        s.is_pressed = false
        s.midi_notes = {}
    end
    
    for _, n in ipairs(config.state.mouse_pad_state.midi_notes) do
        midi.SendMidi(n, false)
    end
    config.state.mouse_pad_state.active_degree = -1
    config.state.mouse_pad_state.midi_notes = {}
    
    config.state.active_notes = {}
    
    -- NOTE: sequencer.Stop() is called at each AllNotesOff call site in main.lua
    -- to avoid circular dependency (sequencer → midi → sequencer)
end

function midi.ExportToMidi()
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.InsertTrackAtIndex(0, true)
        track = reaper.GetTrack(0, 0)
    end
    local start_qn = reaper.TimeMap_timeToQN(reaper.GetCursorPosition())
    
    -- Find last filled slot in all 16 slots
    local count = 0
    for i=16, 1, -1 do 
        if config.state.progression[i] then 
            count = i 
            break 
        end 
    end
    if count == 0 then return end
    
    local end_qn = start_qn + (count * 4)
    local item = reaper.CreateNewMIDIItemInProj(track, reaper.TimeMap_QNToTime(start_qn), reaper.TimeMap_QNToTime(end_qn), false)
    local take = reaper.GetActiveTake(item)
    for i=1, count do
        local slot = config.state.progression[i]
        if slot then
            local q0 = start_qn + (i-1)*4
            local p0, p1 = reaper.MIDI_GetPPQPosFromProjQN(take, q0), reaper.MIDI_GetPPQPosFromProjQN(take, q0+4)
            local export_vel = 100
            for _, off in ipairs(config.CHORD_MODES[slot.chord_mode_index].offsets) do
                local n = midi.GetMidiNote(slot.root_index, slot.scale_index, slot.degree+off, slot.octave)
                reaper.MIDI_InsertNote(take, false, false, p0, p1, 0, n, export_vel, true)
            end
        end
    end
    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()
end

return midi
