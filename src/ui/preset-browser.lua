-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Preset Browser — Barrel Module
-- Re-exports public API from sub-modules (io, folder, preset-list, main).
-- Transparent barrel: external consumers require("ui.preset-browser") work
-- without changes — all previously public functions are still accessible.

local io_mod = require("ui.preset-browser.io")
local folder_mod = require("ui.preset-browser.folder")
local list_mod = require("ui.preset-browser.preset-list")
local main_mod = require("ui.preset-browser.main")

local browser = {}

-- I/O operations (from io.lua)
browser.Init = io_mod.Init
browser.ScanDirectory = io_mod.ScanDirectory
browser.RefreshPresets = io_mod.RefreshPresets
browser.SavePreset = io_mod.SavePreset
browser.LoadPreset = io_mod.LoadPreset
browser.RenamePreset = io_mod.RenamePreset
browser.DeletePreset = io_mod.DeletePreset
browser.IsFavorite = io_mod.IsFavorite
browser.LoadFavorites = io_mod.LoadFavorites
browser.SaveFavorites = io_mod.SaveFavorites
browser.GetPresetFilePath = io_mod.GetPresetFilePath
browser.HasLFS = io_mod.HasLFS
browser.BatchDeletePresets = io_mod.BatchDeletePresets
browser.BatchMergeLoadPresets = io_mod.BatchMergeLoadPresets
browser.ExportPresetsToMIDI = io_mod.ExportPresetsToMIDI

-- Main composition (from main.lua)
browser.DrawPresetBrowser = main_mod.DrawPresetBrowser

-- Folder and preset-list are internal to main.lua — not re-exported.
-- DrawFolderHeader, DrawFolderList, DrawPresetList, HandleContextMenu
-- etc. are consumed directly by main_mod via local requires.

return browser
