local config = require("config")
local midi = require("core.midi")

local sequencer = {}

function sequencer.GetLastFilledSlot()
    for i=16, 1, -1 do 
        if config.state.progression[i] then return i end 
    end
    return 0
end

function sequencer.Stop()
    config.state.sequencer.is_playing = false
    for _, n in ipairs(config.state.sequencer.midi_notes) do 
        midi.SendMidi(n, false) 
    end
    config.state.sequencer.midi_notes = {}
    config.state.sequencer.last_measure = -1
    config.state.sequencer.current_step = 0
    config.state.sequencer.progress = 0
    config.state.sequencer.internal_beats = 0
    config.state.sequencer.last_time = nil
end

function sequencer.Run()
    if not config.state.sequencer.is_playing then 
        config.state.sequencer.progress = 0
        return 
    end
    
    local measures = 0
    local play_state = reaper.GetPlayState()
    
    if (play_state & 1) ~= 0 then
        -- SYNC TO REAPER
        local _, m = reaper.TimeMap2_timeToBeats(0, reaper.GetPlayPosition2())
        measures = m
        config.state.sequencer.last_time = nil -- Reset internal clock
    else
        -- INTERNAL CLOCK MODE
        local now = reaper.time_precise()
        if not config.state.sequencer.last_time then
            config.state.sequencer.last_time = now
            config.state.sequencer.internal_beats = 0
        end
        
        local delta = now - config.state.sequencer.last_time
        config.state.sequencer.last_time = now
        
        local bpm = reaper.Master_GetTempo()
        local beats_per_sec = bpm / 60
        config.state.sequencer.internal_beats = (config.state.sequencer.internal_beats or 0) + (delta * beats_per_sec)
        
        -- Assume 4/4 for the internal visualizer (1 measure = 4 beats)
        measures = config.state.sequencer.internal_beats / 4
    end
    
    local cur_m = math.floor(measures)
    config.state.sequencer.progress = measures % 1
    
    if cur_m ~= config.state.sequencer.last_measure then
        -- Stop previous
        for _, n in ipairs(config.state.sequencer.midi_notes) do midi.SendMidi(n, false) end
        config.state.sequencer.midi_notes = {}
        
        -- Cache GetLastFilledSlot() once (Issue 19)
        local loop = sequencer.GetLastFilledSlot()
        
        -- Catch up skipped steps if frame was delayed — trigger each skipped slot
        while config.state.sequencer.last_measure >= 0 and cur_m > config.state.sequencer.last_measure + 1 do
            config.state.sequencer.last_measure = config.state.sequencer.last_measure + 1
            if loop > 0 then
                local skipped_step = (config.state.sequencer.last_measure % loop) + 1
                local skipped_slot = config.state.progression[skipped_step]
                if skipped_slot then
                    local catchup_notes = midi.TriggerChord(skipped_slot.degree, true, skipped_slot)
                    for _, n in ipairs(catchup_notes) do
                        midi.SendMidi(n, false)
                    end
                end
            end
        end
        if loop == 0 then 
            sequencer.Stop()
            return 
        end
        
        config.state.sequencer.current_step = (cur_m % loop) + 1
        config.state.sequencer.last_measure = cur_m
        
        -- Auto-paginate
        config.state.current_page = math.floor((config.state.sequencer.current_step - 1) / 4) + 1
        
        local slot = config.state.progression[config.state.sequencer.current_step]
        if slot then 
            config.state.sequencer.midi_notes = midi.TriggerChord(slot.degree, true, slot) 
        end
    end
end

return sequencer
