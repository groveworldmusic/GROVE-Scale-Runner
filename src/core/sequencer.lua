-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
local config = require("config")
local seq_store = require("state.sequencer")
local midi = require("core.midi")
local progression = require("core.progression")
local prefs = require("state.preferences")

local sequencer = {}

function sequencer.Stop()
    seq_store.SetIsPlaying(false)
    -- Validate MidiNotes table before iterating (defensive: should never be nil, but guard anyway)
    local midi_notes = seq_store.GetMidiNotes() or {}
    for _, n in ipairs(midi_notes) do 
        midi.SendMidi(n, false, nil, false)  -- No force: respect ref-count gate so shared notes (QWERTY/pad) aren't force-killed
    end
    seq_store.SetMidiNotes({})
    seq_store.SetLastMeasure(-1)
    seq_store.SetCurrentStep(0)
    seq_store.SetProgress(0)
    seq_store.SetInternalBeats(0)
    seq_store.SetLastTime(nil)
end

--- Resolve which chord to trigger for a given sub-step within a slot.
--- For subdivided slots (slot.subs present), picks the sub-chord at sub_step index.
--- For legacy slots (no subs), uses the slot's primary degree (backward compat).
--- @param slot table Progression slot entry
--- @param sub_step number 0-based sub-step index
--- @return number[] MIDI note numbers sent
local function TriggerSubChord(slot, sub_step)
    if slot.subs and #slot.subs > 0 then
        local sub = slot.subs[sub_step + 1]
        if sub and sub.degree then
            return midi.TriggerChord(sub.degree, true, slot, sub.velocity, prefs.GetInversionIndex())
        end
        return {}
    else
        -- Legacy entry: same chord plays on each sub-step
        return midi.TriggerChord(slot.degree, true, slot, nil, prefs.GetInversionIndex())
    end
end

function sequencer.Run()
    if not seq_store.GetIsPlaying() then 
        seq_store.SetProgress(0)
        return 
    end
    
    local measures = 0
    local play_state = reaper.GetPlayState() or 0
    
    if (play_state & 1) ~= 0 then
        -- SYNC TO REAPER
        local ok, m = reaper.TimeMap2_timeToBeats(0, reaper.GetPlayPosition2())
        if not ok then m = 0 end
        measures = m or 0
        seq_store.SetLastTime(nil) -- Reset internal clock
    else
        -- INTERNAL CLOCK MODE
        local now = reaper.time_precise()
        if not seq_store.GetLastTime() then
            seq_store.SetLastTime(now)
            seq_store.SetInternalBeats(0)
        end
        
        local delta = now - seq_store.GetLastTime()
        seq_store.SetLastTime(now)
        
        local bpm = reaper.Master_GetTempo()
        local beats_per_sec = bpm / 60
        seq_store.SetInternalBeats((seq_store.GetInternalBeats() or 0) + (delta * beats_per_sec))
        
        -- Assume 4/4 for the internal visualizer (1 measure = 4 beats)
        measures = seq_store.GetInternalBeats() / 4
    end
    
    local cur_m = math.floor(measures)
    local progress = measures % 1
    seq_store.SetProgress(progress)
    
    -- Cache progression.GetLastFilled() once (Issue 19)
    local loop = progression.GetLastFilled()
    if loop == 0 then 
        sequencer.Stop()
        return 
    end
    
    -- Resolve current subdivision count
    local sub_idx = prefs.GetSubdivisionIndex() or 1
    local subdivision = config.SUBDIVISION_MODES[sub_idx] or 1
    
    -- MEASURE BOUNDARY CROSSED
    if cur_m ~= seq_store.GetLastMeasure() then
        -- Stop previous notes
        for _, n in ipairs(seq_store.GetMidiNotes()) do midi.SendMidi(n, false) end
        seq_store.SetMidiNotes({})
        
        -- Catch up skipped steps if frame was delayed — state-only advance.
        -- The skipped slot's chord never actually played, so no TriggerChord or SendMidi needed.
        while seq_store.GetLastMeasure() >= 0 and cur_m > seq_store.GetLastMeasure() + 1 do
            seq_store.SetLastMeasure(seq_store.GetLastMeasure() + 1)
        end
        
        seq_store.SetCurrentStep((cur_m % loop) + 1)
        seq_store.SetLastMeasure(cur_m)
        seq_store.SetCurrentSubStep(0)
        
        -- Auto-paginate
        seq_store.SetCurrentPage(math.floor((seq_store.GetCurrentStep() - 1) / 4) + 1)
        
        local slot = seq_store.GetProgressionEntry(seq_store.GetCurrentStep())
        if slot and type(slot) == "table" then
            seq_store.SetMidiNotes(TriggerSubChord(slot, 0))
        end
    
    -- SAME MEASURE: check for sub-step boundary
    else
        local current_sub = math.floor(progress * subdivision)
        local prev_sub = seq_store.GetCurrentSubStep()
        
        if current_sub ~= prev_sub and current_sub < subdivision then
            -- Sub-step boundary crossed: stop previous, trigger new
            for _, n in ipairs(seq_store.GetMidiNotes()) do midi.SendMidi(n, false) end
            
            seq_store.SetCurrentSubStep(current_sub)
            local slot = seq_store.GetProgressionEntry(seq_store.GetCurrentStep())
            if slot and type(slot) == "table" then
                seq_store.SetMidiNotes(TriggerSubChord(slot, current_sub))
            end
        end
    end
end

return sequencer
