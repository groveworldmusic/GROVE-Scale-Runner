-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Preset Browser — Preview Module
-- Ghost-note preview: plays preset notes briefly without mutating state.
-- Uses direct StuffMIDIMessage for note-on/off to bypass ref-counting.

local safe_loader = require("ui.safe-loader")

local m = {}

local _current_preview = nil  -- {channel, notes={}}, cleared after timeout

local PREVIEW_DURATION = 0.5  -- seconds

local _preview_timer = 0

--- Play a brief preview of a preset's notes.
--- Sends note-on for all notes, schedules note-off after PREVIEW_DURATION.
--- @param path string Full path to .grove file
--- @param channel number MIDI channel (0-15)
function m.PlayPreview(path, channel)
    if not path then return end
    channel = channel or 0

    local ok, result = safe_loader.LoadSandboxed(path)
    if not ok or not result or not result.notes then return end

    -- Stop any current preview first
    m.StopPreview(channel)

    -- Send note-on for unique pitches (avoid duplicates)
    local sent = {}
    for _, n in ipairs(result.notes) do
        local pitch = n.pitch or 60
        if not sent[pitch] then
            reaper.StuffMIDIMessage(0, 0x90 + channel, pitch, 100)
            sent[pitch] = true
        end
    end

    -- Store for later note-off
    _current_preview = {
        channel = channel,
        notes = sent,
        start_time = reaper.time_precise(),
    }
    _preview_timer = reaper.time_precise()
end

--- Stop all currently previewing notes.
function m.StopPreview(channel)
    if not _current_preview then return end
    if channel ~= nil and _current_preview.channel ~= channel then return end

    for pitch in pairs(_current_preview.notes) do
        reaper.StuffMIDIMessage(0, 0x80 + _current_preview.channel, pitch, 0)
    end
    _current_preview = nil
end

--- Tick function: check if preview duration expired and stop.
--- Call this from DrawPresetBrowser or MainLoop.
function m.TickPreview()
    if _current_preview and reaper.time_precise() - _preview_timer >= PREVIEW_DURATION then
        m.StopPreview()
    end
end

--- Check if a preview is currently active.
function m.IsPreviewActive()
    return _current_preview ~= nil
end

return m
