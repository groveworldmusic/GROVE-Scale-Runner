-- Tests: Preset Browser I/O — IsValidPresetFile, GetPresetFilePath, HasLFS, IsFavorite
-- Tests pure/simple functions in preset-browser/io.lua
-- No reaper dependency for these functions — store deps are lightweight.
--
-- Setup: requires io module + preset_store (stores work without reaper)
--
-- Usage: lua tests/run.lua (from project root)

local check = require("tests.helpers").check
local io_module = require("ui.preset-browser.io")
local preset_store = require("state.preset-store")

io.write("=== Preset Browser I/O Tests ===\n")

-- Init preset_store with minimal state (GetFavorites needs it init'd)
preset_store.Init({})

-- ============================================================
-- 1. IsValidPresetFile — Extension Validation
-- ============================================================
io.write("\n-- IsValidPresetFile\n")

-- Valid: .grove extension
check(io_module.IsValidPresetFile("test.grove") == true,
    "IsValid: .grove returns true")
check(io_module.IsValidPresetFile("my_preset.grove") == true,
    "IsValid: my_preset.grove returns true")
check(io_module.IsValidPresetFile("mixed.Case.GROVE") == true,
    "IsValid: .GROVE (uppercase) returns true via lower()")

-- Valid: .grove-prog extension
check(io_module.IsValidPresetFile("prog.grove-prog") == true,
    "IsValid: .grove-prog returns true")
check(io_module.IsValidPresetFile("chords.grove-prog") == true,
    "IsValid: chords.grove-prog returns true")

-- Invalid: wrong extensions
check(io_module.IsValidPresetFile("test.txt") == false,
    "IsValid: .txt returns false")
check(io_module.IsValidPresetFile("test.lua") == false,
    "IsValid: .lua returns false")
check(io_module.IsValidPresetFile("test") == false,
    "IsValid: no extension returns false")
check(io_module.IsValidPresetFile(".grove-hidden") == false,
    "IsValid: dotfile with .grove prefix but no match returns false")

-- Invalid: nil and empty
check(io_module.IsValidPresetFile(nil) == false,
    "IsValid: nil returns false")
check(io_module.IsValidPresetFile("") == false,
    "IsValid: empty string returns false")

-- Valid: path with directory prefix
check(io_module.IsValidPresetFile("/path/to/preset.grove") == true,
    "IsValid: full path .grove returns true")
check(io_module.IsValidPresetFile("C:\\presets\\song.grove-prog") == true,
    "IsValid: Windows path .grove-prog returns true")

-- ============================================================
-- 2. GetPresetFilePath — Path Concatenation
-- ============================================================
io.write("\n-- GetPresetFilePath\n")

-- Basic concat
local result = io_module.GetPresetFilePath("/presets", "mypreset")
check(result == "/presets/mypreset.grove",
    "GetPath: /presets + mypreset = /presets/mypreset.grove, got " .. result)

-- With trailing slash
result = io_module.GetPresetFilePath("/presets/", "song")
check(result == "/presets//song.grove",
    "GetPath: /presets/ + song keeps extra slash (concat preserves segments), got " .. result)

-- Windows backslash converted to forward slash
result = io_module.GetPresetFilePath("C:\\presets", "jam")
check(result == "C:/presets/jam.grove",
    "GetPath: C:\\presets + jam = C:/presets/jam.grove, got " .. result)

-- Empty directory
result = io_module.GetPresetFilePath("", "test")
check(result == "/test.grove",
    "GetPath: empty dir + test = /test.grove, got " .. result)

-- Special characters in name
result = io_module.GetPresetFilePath("/presets", "my-cool_jam v2")
check(result == "/presets/my-cool_jam v2.grove",
    "GetPath: name with special chars preserved, got " .. result)

-- ============================================================
-- 3. HasLFS — LuaFileSystem Detection
-- ============================================================
io.write("\n-- HasLFS\n")

-- In test environment (no lfs installed), should return false
check(io_module.HasLFS() == false,
    "HasLFS: returns false in mock/test environment")

-- Multiple calls return consistent result
check(io_module.HasLFS() == false,
    "HasLFS: second call consistent")

-- ============================================================
-- 4. IsFavorite — Favorites Lookup
-- ============================================================
io.write("\n-- IsFavorite\n")

-- Empty favorites (default after Init)
check(io_module.IsFavorite("/presets/test.grove") == false,
    "Fav: empty favorites returns false")

-- Set a favorite
preset_store.SetFavorites({["/presets/song.grove"] = true})
check(io_module.IsFavorite("/presets/song.grove") == true,
    "Fav: favorited path returns true")
check(io_module.IsFavorite("/presets/other.grove") == false,
    "Fav: non-favorited path returns false")

-- Multiple favorites
preset_store.SetFavorites({
    ["/presets/a.grove"] = true,
    ["/presets/b.grove"] = true,
})
check(io_module.IsFavorite("/presets/a.grove") == true,
    "Fav: first of multiple returns true")
check(io_module.IsFavorite("/presets/b.grove") == true,
    "Fav: second of multiple returns true")
check(io_module.IsFavorite("/presets/c.grove") == false,
    "Fav: third not in favorites returns false")

-- Clear favorites (empty table)
preset_store.SetFavorites({})
check(io_module.IsFavorite("/presets/song.grove") == false,
    "Fav: after clear returns false")

-- ============================================================
-- 5. GetProgressionPresetFilePath — .grove-prog Extension
-- ============================================================
io.write("\n-- GetProgressionPresetFilePath\n")

local result = io_module.GetProgressionPresetFilePath("/presets", "prog1")
check(result == "/presets/prog1.grove-prog",
    "ProgPath: /presets + prog1 = /presets/prog1.grove-prog, got " .. result)

result = io_module.GetProgressionPresetFilePath("C:\\presets\\folder", "my-chords")
check(result == "C:/presets/folder/my-chords.grove-prog",
    "ProgPath: backslashes converted, got " .. result)

-- ============================================================
-- 6. Edge Cases — nil/empty path
-- ============================================================
io.write("\n-- Edge cases\n")

-- IsFavorite with nil path (table lookup of nil key = nil, should return false)
check(io_module.IsFavorite(nil) == false,
    "Fav: nil path returns false")

-- GetPresetFilePath with empty name
local empty_result = io_module.GetPresetFilePath("/presets", "")
check(empty_result:match("%.grove$") ~= nil, "GetPath: empty name still appends .grove extension")
check(empty_result == "/presets/.grove", "GetPath: empty name = '/presets/.grove', got " .. empty_result)

-- GetPresetFilePath with special directory
result = io_module.GetPresetFilePath("/presets/sub dir/with spaces", "test")
check(result == "/presets/sub dir/with spaces/test.grove",
    "GetPath: dir with spaces preserves spaces, got " .. result)

-- GetProgressionPresetFilePath with empty dir
result = io_module.GetProgressionPresetFilePath("", "prog")
check(result == "/prog.grove-prog",
    "ProgPath: empty dir, got " .. result)

-- IsValidPresetFile with double extension
check(io_module.IsValidPresetFile("backup.grove.bak") == false,
    "IsValid: .grove.bak (double ext) returns false")
check(io_module.IsValidPresetFile("name.grove-prog.backup") == false,
    "IsValid: .grove-prog.backup returns false")

io.write("\n=== Preset Browser I/O Tests Complete ===\n")
