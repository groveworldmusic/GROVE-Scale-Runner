-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Preset Browser — I/O Module
-- Filesystem operations for preset management: directory scanning,
-- file read/write, rename, delete, and path utilities.

local preset_store = require("state.preset-store")
local island_store = require("state.island")
local note_store = require("state.note-store")
local seq_store = require("state.sequencer")
local prefs = require("state.preferences")
local safe_loader = require("ui.safe-loader")
local path_utils = require("ui.path-utils")

local m = {}

-- Directory scan cache
local _scan_cache = {}
local _has_lfs, _lfs = pcall(require, "lfs")
local PRESET_EXT = ".grove"

function m.Init()
    local ok, root = pcall(reaper.GetResourcePath)
    if not ok or not root then
        preset_store.SetBrowserError("Could not get REAPER resource path")
        return
    end
    local preset_dir = root .. "/grove-presets"
    preset_store.SetPresetRoot(preset_dir)

    local dir_exists = false
    pcall(function()
        local f = io.open(preset_dir, "r")
        if f then dir_exists = true; f:close() end
    end)

    if not dir_exists then
        pcall(reaper.RecursiveCreateDirectory, preset_dir, 0)
    end

    preset_store.SetCurrentDirectory(preset_dir)
    preset_store.SetBrowserError(nil)
    m.ScanDirectory(preset_dir)
    m.LoadFavorites()
end

function m.IsValidPresetFile(filename)
    if not filename or #filename == 0 then return false end
    return filename:lower():match("%.grove$") ~= nil
end

function m.GetPresetFilePath(directory, name)
    return path_utils.PathJoin(directory, name .. PRESET_EXT)
end

function m.ScanDirectory(dir_path, force_refresh)
    if not dir_path or #dir_path == 0 then return end
    if not force_refresh and _scan_cache[dir_path] then
        local cached = _scan_cache[dir_path]
        preset_store.SetPresetTree({path = dir_path, dirs = cached.dirs, files_count = #cached.files})
        preset_store.SetPresetFiles(cached.files)
        preset_store.SetSelectedPresetIdx(nil)
        preset_store.SetBrowserScroll(0)
        preset_store.SetBrowserError(nil)
        return
    end

    local dirs = {}
    if _has_lfs then
        for entry in _lfs.dir(dir_path) do
            if entry ~= "." and entry ~= ".." then
                local full_path = path_utils.PathJoin(dir_path, entry)
                local attr = _lfs.attributes(full_path)
                if attr and attr.mode == "directory" then
                    table.insert(dirs, {name = entry, path = full_path, type = "folder", expanded = false})
                end
            end
        end
    else
        local ok1, handle1 = pcall(io.popen, 'dir "' .. dir_path .. '" /B /AD 2>nul')
        if ok1 and handle1 then
            for line in handle1:lines() do
                if #line > 0 then
                    table.insert(dirs, {name = line, path = path_utils.PathJoin(dir_path, line), type = "folder", expanded = false})
                end
            end
            handle1:close()
        end
    end

    table.sort(dirs, function(a, b) return a.name:lower() < b.name:lower() end)

    local files = {}
    if _has_lfs then
        for entry in _lfs.dir(dir_path) do
            if entry:match("%.grove$") then
                local name = entry:gsub("%.grove$", "")
                table.insert(files, {name = name, filename = entry, path = path_utils.PathJoin(dir_path, entry)})
            end
        end
    else
        local ok2, handle2 = pcall(io.popen, 'dir "' .. dir_path .. '\\*.grove" /B 2>nul')
        if ok2 and handle2 then
            for line in handle2:lines() do
                if #line > 0 then
                    local name = line:gsub("%.grove$", "")
                    table.insert(files, {name = name, filename = line, path = path_utils.PathJoin(dir_path, line)})
                end
            end
            handle2:close()
        end
    end

    table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
    _scan_cache[dir_path] = { dirs = dirs, files = files }
    preset_store.SetPresetTree({path = dir_path, dirs = dirs, files_count = #files})
    preset_store.SetPresetFiles(files)
    preset_store.SetSelectedPresetIdx(nil)
    preset_store.SetBrowserScroll(0)
    preset_store.SetBrowserError(nil)
end

function m.RefreshPresets()
    local dir = preset_store.GetCurrentDirectory() or preset_store.GetPresetRoot()
    if dir and #dir > 0 then
        _scan_cache[dir] = nil
        m.ScanDirectory(dir, true)
    end
end

function m.SavePreset(file_path, preset_name)
    local notes = note_store.GetNotes()
    if not notes then notes = {} end
    -- Sanitize the preset name to prevent path traversal or illegal characters
    local safe_name = path_utils.SanitizePresetName(preset_name)
    if safe_name == "" then
        preset_store.SetBrowserError("Invalid preset name")
        return false
    end
    local lines = {}
    table.insert(lines, "return {")
    table.insert(lines, string.format("    name = %q,", safe_name))
    table.insert(lines, "    version = 2,")
    table.insert(lines, "    notes = {")
    for _, n in ipairs(notes) do
        table.insert(lines, string.format(
            "        {pitch=%s,start_beat=%s,duration=%s,velocity=%s,muted=%s},",
            tostring(n.pitch or 60), tostring(n.start_beat or 0), tostring(n.duration or 4), tostring(n.velocity or 100),
            n.muted and "true" or "false"
        ))
    end
    table.insert(lines, "    },")
    table.insert(lines, string.format("    root_index = %d,", prefs.GetRootIndex() or 1))
    table.insert(lines, string.format("    scale_index = %d,", prefs.GetScaleIndex() or 1))
    table.insert(lines, string.format("    octave = %d,", prefs.GetOctave() or 4))
    table.insert(lines, string.format("    chord_mode_index = %d,", prefs.GetChordModeIndex() or 1))
    local progression = seq_store.GetProgression()
    table.insert(lines, "    progression = {")
    for i = 1, 16 do
        local entry = progression[i]
        if entry then
            local parts = {
                "degree=" .. (entry.degree or 1),
                "root_index=" .. (entry.root_index or 1),
                "scale_index=" .. (entry.scale_index or 1),
                "octave=" .. (entry.octave or 4),
                "chord_mode_index=" .. (entry.chord_mode_index or 1),
            }
            if entry.velocity then table.insert(parts, "velocity=" .. entry.velocity) end
            if entry.duration then table.insert(parts, "duration=" .. entry.duration) end
            table.insert(lines, "        {" .. table.concat(parts, ",") .. "},")
        else
            table.insert(lines, "        nil,")
        end
    end
    table.insert(lines, "    },")
    table.insert(lines, "}")
    local content = table.concat(lines, "\n")
    local ok, f = pcall(io.open, file_path, "w")
    if not ok or not f then
        preset_store.SetBrowserError("Could not write file: " .. tostring(file_path))
        return false
    end
    f:write(content)
    f:close()
    m.RefreshPresets()
    preset_store.SetBrowserError(nil)
    return true
end

function m.LoadPreset(file_path)
    if not file_path then
        preset_store.SetBrowserError("No preset selected")
        return false
    end
    -- Load preset in a sandboxed environment to prevent code execution
    local ok, result = safe_loader.LoadSandboxed(file_path)
    if not ok then
        preset_store.SetBrowserError("Error loading preset: " .. tostring(result))
        return false
    end
    if type(result) ~= "table" then
        preset_store.SetBrowserError("Invalid preset file: expected table, got " .. type(result))
        return false
    end
    if not result.notes or type(result.notes) ~= "table" then
        preset_store.SetBrowserError("Invalid preset: missing 'notes' array")
        return false
    end
    local valid_notes = {}
    for _, n in ipairs(result.notes) do
        if type(n) == "table" and n.pitch then
            table.insert(valid_notes, {
                pitch = n.pitch,
                start_beat = n.start_beat or 0,
                duration = n.duration or 4,
                velocity = n.velocity or 100,
                muted = n.muted == true,
                uuid = note_store.AllocNoteUUID(),
            })
        end
    end
    if #valid_notes == 0 then
        preset_store.SetBrowserError("Preset contains no valid notes")
        return false
    end
    -- Snapshot current notes for undo (T4: Undo on Load)
    local current_notes = note_store.GetNotes()
    local snapshot = {}
    if current_notes then
        for _, n in ipairs(current_notes) do
            table.insert(snapshot, {
                pitch = n.pitch,
                start_beat = n.start_beat,
                duration = n.duration,
                velocity = n.velocity,
                muted = n.muted,
                uuid = n.uuid,
            })
        end
    end
    note_store.PushUndo({type = "preset_load", snapshot = snapshot})
    note_store.SetNotes(valid_notes)
    if result.version and result.version >= 2 then
        if result.root_index then prefs.SetRootIndex(result.root_index) end
        if result.scale_index then prefs.SetScaleIndex(result.scale_index) end
        if result.octave then prefs.SetOctave(result.octave) end
        if result.chord_mode_index then prefs.SetChordModeIndex(result.chord_mode_index) end
        if result.progression and type(result.progression) == "table" then
            seq_store.SetProgression(result.progression)
        end
    end
    preset_store.SetBrowserError(nil)
    return true
end

function m.RenamePreset()
    local files = preset_store.GetPresetFiles()
    local idx = preset_store.GetSelectedPresetIdx()
    if not idx or idx < 1 or idx > #files then
        preset_store.SetBrowserError("No preset selected to rename")
        return false
    end
    local entry = files[idx]
    local ret, new_name = reaper.GetUserInputs("Rename Preset", 1, "New name:", entry.name)
    if not ret or not new_name or #new_name == 0 then
        return false
    end
    new_name = path_utils.SanitizePresetName(new_name)
    -- Remove trailing .grove if present
    new_name = new_name:gsub("%.grove$", "")
    if new_name == "" then
        preset_store.SetBrowserError("Invalid preset name")
        return false
    end
    local dir = preset_store.GetCurrentDirectory()
    local old_path = entry.path
    local new_path = path_utils.PathJoin(dir, new_name .. ".grove")
    local f = io.open(new_path, "r")
    if f then
        f:close()
        preset_store.SetBrowserError("A preset with that name already exists")
        return false
    end
    local ok, err = os.rename(old_path, new_path)
    if not ok then
        preset_store.SetBrowserError("Could not rename preset: " .. tostring(err or "unknown error"))
        return false
    end
    m.RefreshPresets()
    preset_store.SetBrowserError(nil)
    return true
end

function m.DeletePreset(path)
    if not path or #path == 0 then
        return false, "No path specified"
    end
    local ok, err = os.remove(path)
    if not ok then
        return false, tostring(err or "unknown error")
    end
    return true, nil
end

function m.IsFavorite(path)
    local favs = preset_store.GetFavorites()
    return favs[path] == true
end

function m.LoadFavorites()
    local ok, str = pcall(reaper.GetExtState, "GROVE_Scale_Runner", "preset_favorites")
    if not ok or not str or #str == 0 then
        preset_store.SetFavorites({})
        return
    end

    local success, result = pcall(function()
        -- Validate braces
        if str:sub(1,1) ~= "{" or str:sub(-1) ~= "}" then return {} end
        local inner = str:sub(2, -2)
        if #inner == 0 then return {} end

        local favs = {}
        local start_pos = 1
        local in_quotes = false
        for i = 1, #inner do
            local c = inner:sub(i,i)
            if c == '"' then
                in_quotes = not in_quotes
            elseif c == ',' and not in_quotes then
                local segment = inner:sub(start_pos, i-1):gsub('^%s*"', ''):gsub('"%s*$', '')
                if #segment > 0 then
                    favs[segment] = true
                end
                start_pos = i + 1
            end
        end
        -- Last segment
        local segment = inner:sub(start_pos):gsub('^%s*"', ''):gsub('"%s*$', '')
        if #segment > 0 then
            favs[segment] = true
        end
        return favs
    end)

    if success and type(result) == "table" then
        preset_store.SetFavorites(result)
    else
        preset_store.SetFavorites({})
    end
end

function m.SaveFavorites()
    local favs = preset_store.GetFavorites()
    local paths = {}
    for path, _ in pairs(favs) do
        table.insert(paths, path)
    end
    table.sort(paths)
    local parts = {}
    for _, p in ipairs(paths) do
        table.insert(parts, string.format("%q", p))
    end
    local str = "{" .. table.concat(parts, ",") .. "}"
    pcall(reaper.SetExtState, "GROVE_Scale_Runner", "preset_favorites", str, true)
end

function m.GetPresetFilePath(directory, name)
    return path_utils.PathJoin(directory, name .. PRESET_EXT)
end

--- Check if LuaFileSystem is available.
function m.HasLFS()
    return _has_lfs
end

-- =========================================================
-- Batch operations (presets-phase-2: multi-select)
-- =========================================================

--- Delete multiple presets at once.
--- @param indices table Sparse set of indices to delete {[idx] = true}
--- @param files table Array of file entries from preset store
--- @return number count of successfully deleted presets
function m.BatchDeletePresets(indices, files)
    if not indices or not files then return 0 end
    local count = 0
    for idx in pairs(indices) do
        local entry = files[idx]
        if entry then
            local ok, _ = m.DeletePreset(entry.path)
            if ok then count = count + 1 end
        end
    end
    m.RefreshPresets()
    preset_store.ClearSelection()
    return count
end

--- Merge-load multiple presets: combine all notes from selected presets into current notes.
--- @param indices table Sparse set of indices {[idx] = true}
--- @param files table Array of file entries
function m.BatchMergeLoadPresets(indices, files)
    if not indices or not files then return end
    local all_notes = {}
    for idx in pairs(indices) do
        local entry = files[idx]
        if entry then
            local ok, result = safe_loader.LoadSandboxed(entry.path)
            if ok and result and result.notes then
                for _, n in ipairs(result.notes) do
                    table.insert(all_notes, {
                        pitch = n.pitch,
                        start_beat = n.start_beat or 0,
                        duration = n.duration or 4,
                        velocity = n.velocity or 100,
                        muted = n.muted == true,
                        uuid = note_store.AllocNoteUUID(),
                    })
                end
            end
        end
    end
    if #all_notes > 0 then
        -- Snapshot current notes for undo (mirrors LoadPreset pattern)
        local current_notes = note_store.GetNotes()
        local snapshot = {}
        if current_notes then
            for _, n in ipairs(current_notes) do
                table.insert(snapshot, {
                    pitch = n.pitch, start_beat = n.start_beat,
                    duration = n.duration, velocity = n.velocity,
                    muted = n.muted, uuid = n.uuid,
                })
            end
        end
        note_store.PushUndo({type = "preset_merge", snapshot = snapshot})
        note_store.SetNotes(all_notes)
    end
end

--- Export selected presets as individual MIDI items on the selected track.
--- Each preset becomes a separate MIDI item at the edit cursor.
--- @param indices table Sparse set of indices {[idx] = true}
--- @param files table Array of file entries
function m.ExportPresetsToMIDI(indices, files)
    if not indices or not files then return end
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.MB("Please select a track first.", "Export to MIDI", 0)
        return
    end
    local cursor = reaper.GetCursorPosition()
    for idx in pairs(indices) do
        local entry = files[idx]
        if entry then
            local ok, result = safe_loader.LoadSandboxed(entry.path)
            if ok and result and result.notes then
                -- Calculate duration from the max end beat among notes
                local max_beat = 0
                for _, n in ipairs(result.notes) do
                    local end_beat = (n.start_beat or 0) + (n.duration or 4)
                    if end_beat > max_beat then max_beat = end_beat end
                end
                local duration_sec = reaper.TimeMap_QNToTime(max_beat or 4)
                if duration_sec <= 0 then duration_sec = 4 end
                local item = reaper.CreateNewMIDIItemInProj(track, cursor, duration_sec, true)
                if item then
                    reaper.MIDIItem_SetName(item, entry.name or "Exported Preset")
                    local take = reaper.GetMediaItemTake(item, 0)
                    if take then
                        for _, n in ipairs(result.notes) do
                            local ppq_start = reaper.MIDI_BeatToPPQ(take, n.start_beat or 0)
                            local ppq_end = reaper.MIDI_BeatToPPQ(take, (n.start_beat or 0) + (n.duration or 4))
                            reaper.MIDI_InsertNote(take, false, n.muted == true, ppq_start, ppq_end, 0, n.pitch or 60, 100, true)
                        end
                        reaper.MIDI_Sort(take)
                    end
                end
                cursor = cursor + duration_sec + 1 -- gap between items
            end
        end
    end
    reaper.UpdateArrange()
end

return m
