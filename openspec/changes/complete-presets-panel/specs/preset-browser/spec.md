# Delta for Preset Browser

## ADDED Requirements

### Requirement: Folder Scroll Wheel

The preset browser SHALL respond to mouse wheel events over the folder list area. `main.lua` MUST call `folder_mod.HandleFolderWheel()` with the same `dirs` and `scroll_offset` as `DrawFolderList`, and SHALL persist the returned scroll offset via `preset_store.SetFolderScroll()`.

#### Scenario: Scroll on folder area

- GIVEN the folder list has 15 directories and the viewport shows 6
- WHEN the user scrolls the mouse wheel over the folder list
- THEN `HandleFolderWheel` returns a new scroll offset
- AND `preset_store.SetFolderScroll()` is updated with the new offset

#### Scenario: Scroll outside folder area ignored

- GIVEN a scrollable folder list
- WHEN the user scrolls outside the folder area bounds
- THEN `HandleFolderWheel` returns the existing `scroll_offset` unchanged

#### Scenario: Scroll clamps at bounds

- GIVEN 10 items with 5 visible (max scroll = 5)
- WHEN the user scrolls past the last item
- THEN the scroll offset does not exceed `#dirs - max_visible`

### Requirement: Error Banner

The preset browser SHALL render `preset_store.GetBrowserError()` as a visible banner when the value is non-nil. The banner MUST appear inside the browser panel below the header and above the folder/preset content, with a distinguishing background color and the error text in a readable font.

#### Scenario: Error appears on write failure

- GIVEN `preset_store.GetBrowserError()` returns `"Could not write file"`
- WHEN the preset browser renders the next frame
- THEN a colored error banner is drawn below the header with the text `"Could not write file"`

#### Scenario: Error banner clears

- GIVEN an error banner is visible
- WHEN `preset_store.SetBrowserError(nil)` is called
- THEN no error banner renders on the next frame

### Requirement: Init Sequence

`midi-island.lua` MUST call `preset_browser.Init()` instead of calling `preset_browser.ScanDirectory(root)` at module load time. `io_mod.Init()` SHALL call `reaper.GetResourcePath()`, set `preset_root` to `<resource>/grove-presets/`, create the directory if absent, set `current_directory` to root, and call `ScanDirectory`.

#### Scenario: Normal init flow

- GIVEN REAPER resource path is available at module load
- WHEN `preset_browser.Init()` is called
- THEN `preset_store.GetPresetRoot()` returns the `<resource>/grove-presets/` path
- AND `preset_store.GetCurrentDirectory()` equals the root
- AND `preset_store.GetPresetFiles()` is populated with `.grove` files in that directory

#### Scenario: Missing resource path

- GIVEN `reaper.GetResourcePath()` returns nil
- WHEN `preset_browser.Init()` is called
- THEN `preset_store.SetBrowserError("Could not get REAPER resource path")` is called
- AND `preset_store.GetPresetRoot()` returns `""`

### Requirement: Cross-Platform Paths

All path construction in `io.lua` MUST use forward slashes (`/`) or delegate to a platform-aware helper. Hardcoded backslashes (`\`) in path concatenation SHALL NOT appear in `GetPresetFilePath`, `ScanDirectory`, or `RenamePreset`. The `io.popen` fallback SHALL remain behind a platform check — only executed on Windows.

#### Scenario: lfs path uses forward slashes

- GIVEN LuaFileSystem is available on any OS
- WHEN `ScanDirectory` constructs a full path
- THEN the separator is `/` between directory and entry name

#### Scenario: Shell fallback only on Windows

- GIVEN LuaFileSystem is unavailable
- WHEN `ScanDirectory` runs on a non-Windows OS
- THEN the `io.popen('dir ...')` fallback SHALL NOT execute
- AND the function SHALL NOT crash (returns empty dirs/files lists)

## MODIFIED Requirements

### Requirement: Directory Navigation

The preset browser SHALL display a folder tree panel rooted at `reaper.GetResourcePath() .. "/grove-presets/"`. This directory MUST be created on first access if it does not exist. The folder list SHALL be rendered in a left column (`DrawFolderList`) with `dirs` from `preset_store.GetPresetTree().dirs` and `scroll_offset` from `preset_store.GetFolderScroll()`. Clicking a folder entry SHALL call `io_mod.ScanDirectory(path)` and reset folder scroll. Parent navigation (`..`) SHALL be supported via a clickable `..` button in the folder header (`DrawFolderHeader`).
(Previously: Abstractly mentioned keyboard/mouse navigation without specifying rendering arguments or click dispatch wiring.)

#### Scenario: First access creates directory

- GIVEN no `grove-presets/` directory exists in the REAPER resource path
- WHEN the preset browser initializes
- THEN the directory SHALL be created via `reaper.RecursiveCreateDirectory()`
- AND the folder tree shows an empty directory

#### Scenario: Navigate into subdirectory by click

- GIVEN the folder list shows a subdirectory `my-scales` with path `/preset/root/my-scales`
- WHEN the user clicks on `my-scales` in the folder list
- THEN `HandleFolderClick` returns `"navigate:/preset/root/my-scales"`
- AND `io_mod.ScanDirectory("/preset/root/my-scales")` is called
- AND `preset_store.GetCurrentDirectory()` returns `/preset/root/my-scales`
- AND `preset_store.SetFolderScroll(0)` resets the folder scroll
- AND the preset list panel updates with `.grove` files in `my-scales`

#### Scenario: Parent navigation via header up button

- GIVEN the current directory is `/preset/root/my-scales`
- WHEN the user clicks the `..` label in the folder header
- THEN `DrawFolderHeader` returns `"up"`
- AND `io_mod.ScanDirectory("/preset/root")` is called
- AND `preset_store.SetFolderScroll(0)` resets the folder scroll

#### Scenario: At root level, up does nothing

- GIVEN the current directory equals `preset_store.GetPresetRoot()`
- WHEN the user clicks the `..` label in the folder header
- THEN no directory change occurs
- AND the current directory remains unchanged

#### Scenario: Folder list renders with dirs and scroll state

- GIVEN the current directory has subdirectories and folder scroll is 3
- WHEN `DrawPresetBrowser` renders the next frame
- THEN `folder_mod.DrawFolderList` receives the `dirs` array from the preset tree
- AND it receives `scroll_offset = 3` from `preset_store.GetFolderScroll()`
- AND the returned scroll is saved via `preset_store.SetFolderScroll()`

#### Scenario: Empty directory shows no folders

- GIVEN the current directory has no subdirectories
- WHEN `DrawPresetBrowser` renders
- THEN `folder_mod.DrawFolderList` returns early with `(scroll_offset, 0)`
- AND no folder items are drawn in the left column
