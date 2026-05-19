-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: MIDI Input Recording
-- Polls REAPER's global MIDI input buffer via MIDI_GetRecentInputEvent(),
-- converts note-on/off to internal note-store entries with beat-accurate
-- timing. Tracked via _open_notes table (dedup + 5s safety timeout).

local note_store = require("state.note-store")

local m = {}

--- Module-level state
local _armed = false
local _open_notes = {}   -- {[pitch] = {start_beat, start_time, velocity}}

--- 5-second safety timeout for unpaired note-ons (lost note-off guard).
local NOTE_TIMEOUT = 5.0

function m.SetArmed(state)
    state = state or false
    if _armed == state then return end
    _armed = state
    if not _armed then
        m.FinalizeAllOpenNotes()
    end
end

function m.IsArmed()
    return _armed
end

--- Get the current beat position via REAPER's time map (tempo-aware).
--- @return number Absolute beat position (fractional)
local function GetCurrentBeat()
    local ok, beats = reaper.TimeMap2_timeToBeats(0, reaper.time_precise())
    if ok then return beats end
    return 0
end

--- Finalize ALL open notes by computing duration from current beat.
--- Called on disarm and Cleanup.
function m.FinalizeAllOpenNotes()
    local end_beat = GetCurrentBeat()
    for pitch, info in pairs(_open_notes) do
        local duration = end_beat - info.start_beat
        if duration < 0 then duration = 0 end
        note_store.UpdateOpenNoteDuration(pitch, duration)
    end
    _open_notes = {}
end

--- Check for timed-out open notes (5s max) and auto-close them.
local function CheckOpenNoteTimeouts()
    local end_beat = GetCurrentBeat()
    local now = reaper.time_precise()
    for pitch, info in pairs(_open_notes) do
        if now - info.start_time >= NOTE_TIMEOUT then
            local duration = end_beat - info.start_beat
            if duration < 0 then duration = 0 end
            note_store.UpdateOpenNoteDuration(pitch, duration)
            _open_notes[pitch] = nil
        end
    end
end

--- Poll REAPER's MIDI input buffer. No-op if not armed.
--- Processes note-on → AddNote(origin="midi-input"), note-off →
--- UpdateOpenNoteDuration. Uses _open_notes as natural deduplicator.
--- 5s timeout auto-closes unpaired notes.
function m.Poll()
    if not _armed then return end

    -- Safety: auto-close timed-out open notes
    CheckOpenNoteTimeouts()

    -- Iterate the entire MIDI input buffer (ring buffer, newest at idx 0)
    local idx = 0
    while true do
        local retval, note_val, chan_val, msg = reaper.MIDI_GetRecentInputEvent(idx, 0, 0)
        if not retval then break end
        idx = idx + 1
        if idx > 64 then break end   -- safety: never exceed ring buffer size

        local msgtype = msg & 0xF0

        if msgtype == 0x90 then
            -- Note On: note_val = pitch, chan_val = velocity
            local pitch = note_val
            local velocity = chan_val

            -- Note-on with velocity 0 is a note-off (standard MIDI)
            if velocity == 0 then
                if _open_notes[pitch] then
                    local end_beat = GetCurrentBeat()
                    local duration = end_beat - _open_notes[pitch].start_beat
                    if duration < 0 then duration = 0 end
                    note_store.UpdateOpenNoteDuration(pitch, duration)
                    _open_notes[pitch] = nil
                end

            else
                -- Real note-on: only process if no open note (dedup guard)
                if not _open_notes[pitch] and pitch >= 0 and pitch <= 127 then
                    local start_beat = GetCurrentBeat()
                    note_store.AddNote({
                        pitch = pitch,
                        start_beat = start_beat,
                        duration = 0,
                        velocity = velocity,
                        muted = false,
                        origin = "midi-input",
                    })
                    _open_notes[pitch] = {
                        start_beat = start_beat,
                        start_time = reaper.time_precise(),
                        velocity = velocity,
                    }
                end
            end

        elseif msgtype == 0x80 then
            -- Note Off: note_val = pitch, chan_val = release velocity (usually 0)
            local pitch = note_val
            if _open_notes[pitch] then
                local end_beat = GetCurrentBeat()
                local duration = end_beat - _open_notes[pitch].start_beat
                if duration < 0 then duration = 0 end
                note_store.UpdateOpenNoteDuration(pitch, duration)
                _open_notes[pitch] = nil
            end
        end
        -- All other MIDI messages (CC, aftertouch, pitch bend, sysEx)
        -- are silently ignored per spec.
    end
end

--- Cleanup: finalize all open notes. Called from CleanupAll on script stop.
function m.Cleanup()
    m.FinalizeAllOpenNotes()
end

return m
