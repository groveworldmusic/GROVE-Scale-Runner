# Design: Presets Full Features

## Technical Approach

Four phases extending the preset browser from file picker to full preset management system. Each phase builds on the prior: foundation (stats + v3 format), media (preview + thumbnails), UX (badges + auto-save + versioning), sharing (export/import packs). Zero new dependencies — all features use existing `reaper.*` API, ExtState persistence, and `io.open` file I/O.

## Architecture Decisions

### Decision: Stats Persistence

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Separate `.json` file | +Simple | **REJECTED** — filesystem I/O per load |
| In-memory + ExtState flush | +Matches existing pattern, atomic | **CHOSEN** — follows `persist.lua` pattern, `TickSaveDebounce` flush once per frame |
| MIDI note-store mutation | -Pollutes note state | **REJECTED** |

Stats stored in new `src/state/preset-stats.lua` module. Backed by `reaper.SetExtState("GROVE_Scale_Runner", "preset_stats", json_string, true)`. Flush debounced 3 frames after last increment.

### Decision: .grove v3 backward compat

| Option | Tradeoff | Decision |
|--------|----------|----------|
| New extension `.grove3` | -Breaks existing file associations | **REJECTED** |
| Same `.grove`, version field 3, additive fields | +v2 files load identically, +no migration needed | **CHOSEN** |
| Separate metadata file | -Complexity, sync issues | **REJECTED** |

Loader checks `version >= 2` already (line 244). Change to `if result.key ~= nil` style for v3 fields — version check is sufficient.

### Decision: Preview MIDI — no ref-count pollution

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `midi.SendMidi` | +Reuses existing code, -Pollutes `active_notes` | **REJECTED** |
| `reaper.StuffMIDIMessage` direct + scheduled note-off | +Zero state side effects, +Matches REAPER's single-threaded defer | **CHOSEN** |
| `midi.TriggerChord` with force | -Needs cleanup logic | **REJECTED** |

Preview uses a setup-ref-notes-approach: load the preset notes from disk each preview call (no caching, ~100 lines of Lua = <2ms), loop through notes sending `reaper.StuffMIDIMessage(0, 0x90 + ch, pitch, velocity)` for each, schedule a single `reaper.defer` callback 800ms later that sends note-offs. No interaction with `midi_store`, `active_notes`, or ref-counting.

### Decision: Auto-save hook placement

| Location | Tradeoff | Decision |
|----------|----------|----------|
| `progression.Add()` | +Direct, -Circular dep risk (progression → io → note-store) | **REJECTED** |
| `main.lua` MainLoop | +No circular deps, -Needs manual debounce | **CHOSEN** |
| `ui/slots.lua` after interaction | +Close to UX, -Duplicates across drag/click paths | **REJECTED** |

Hook in MainLoop: after `sequencer.Run()`, check a debounce timer. When timer expires, compare `seq_store.GetProgressionRevision()` against last-saved revision. If changed and not currently playing, save each slot's progression notes to `_autosave/slot_{page}_{idx}.grove`.

### Decision: Theme sync (formerly "Dark/Light Sync")

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Detect OS/REAPER theme | -Complex, fragile | **REJECTED** |
| Use existing `theme.colors` | +Already works, +3 themes supported | **CHOSEN** |
| New `preset_theme` field in metadata | -Over-engineered | **REJECTED** |

The existing theme system (themes.lua → theme.lua → `theme.colors`) already provides 3 palettes (Current, Dark, HighContrast) that the preset browser headers/folders can consume via `helpers.SetColor(theme.colors.*)`. No changes needed — just ensure preset browser code uses `theme.colors` consistently (it already does via `helpers`).

## Data Flow

```
┌─ Phase 1 ────────────────────────────────────────────────┐
│                                                          │
│  presets-full-features/proposal.md is the source truth   │
│  for requirements. Specs are embedded below.             │
│                                                          │
│   SavePreset (.grove v3)                                 │
│     Editor notes → note_store.GetNotes()                 │
│         → io.lua serializes version=3 + metadata         │
│         → io.open(file_path, "w") → .grove file          │
│                                                          │
│   LoadPreset (stats hook)                                │
│     io.lua:LoadPreset(path) → normal load                │
│         → preset-stats.IncrementLoadCount(path)          │
│         → TickSaveDebounce flushes to ExtState           │
│                                                          │
│   EditMetadata                                           │
│     reaper.GetUserInputs → writes tags/notes/bpm/genre   │
│         → io.lua:SavePreset with updated fields          │
│                                                          │
├─ Phase 2 ────────────────────────────────────────────────┤
│                                                          │
│   Preview Auditivo                                       │
│     Hover/Ctrl+Space → io.lua:LoadSandboxed(path)        │
│         → parse notes → StuffMIDIMessage(0x90)           │
│         → reaper.defer(fn, 0.8s) → StuffMIDIMessage(0x80)│
│                                                          │
│   Thumbnails                                             │
│     ScanDirectory → for each file, compute 8×8 grid      │
│         → store grid[] in file entry                     │
│     DrawPresetList → render 40×40 dot grid per item      │
│                                                          │
├─ Phase 3 ────────────────────────────────────────────────┤
│                                                          │
│   Badges                                                 │
│     DrawPresetList → read stats[path].load_count         │
│         → derive badge → render colored label            │
│                                                          │
│   Auto-save                                              │
│     MainLoop → timer check → seq_store.GetProgressionRev │
│         → io.SaveSlotSnapshot(page, idx, notes)          │
│         → _autosave/slot_{page}_{idx}.grove              │
│                                                          │
│   Versioning                                             │
│     SavePreset → os.rename(old, old_v1) → write new      │
│         → scan for _vN, pick next                        │
│                                                          │
├─ Phase 4 ────────────────────────────────────────────────┤
│                                                          │
│   Export/Import Packs                                    │
│     Export: read each .grove → io.open → table           │
│         → manifest{name, path, tags} + content[]         │
│         → write .grove-pack as Lua return{}              │
│     Import: io.open .grove-pack → load sandboxed         │
│         → write each content[] to grove-presets/         │
│         → RefreshPresets                                 │
└──────────────────────────────────────────────────────────┘
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/state/preset-stats.lua` | **Create** | Usage stats store: load count, last loaded, favorite count, ExtState persist |
| `src/ui/preset-browser/io.lua` | Modify | .grove v3 format, metadata dialog, stats hook, pack I/O, versioning |
| `src/ui/preset-browser/main.lua` | Modify | Badge rendering, auto-save tick in DrawPresetBrowser |
| `src/ui/preset-browser/preset-list.lua` | Modify | Thumbnail rendering, badge UI, preview hover zone |
| `src/ui/preset-browser/preset-list.lua` | Modify | "i" and "📝" icon buttons, right-click metadata edit |
| `src/state/preset-store.lua` | Modify | Add `preset_stats`, `pack_data`, `show_thumbnails` fields |
| `src/core/midi.lua` | Minor | No changes — preview uses StuffMIDIMessage directly |
| `src/core/progression.lua` | Minor | Add revision hash function for auto-save dirty detect |
| `src/ui/preset-browser/folder.lua` | Modify | Color-mode aware folder icons (minor) |
| `tests/test_midi.lua` | Minor | Add `.grove v3` parse tests if runnable |

## Interfaces / Contracts

### preset-stats.lua — new store

```lua
-- Stats entry per preset path:
-- { load_count: number, last_loaded: number (reaper.time_precise), favorite_count: number }
-- Persisted to ExtState as JSON: GROVE_Scale_Runner / preset_stats

function m.Init() → void
  -- Load stats from ExtState, init internal table

function m.GetStats(path) → table|nil
  -- Returns entry for path or nil

function m.GetAllStats() → table
  -- Returns full stats table (keyed by path)

function m.IncrementLoadCount(path) → void
  -- Increment load_count, set last_loaded = reaper.time_precise()

function m.IncrementFavoriteCount(path) → void
  -- Increment favorite_count on favorite toggle (from io.lua)

function m.TickSaveDebounce() → void
  -- If dirty, flush to ExtState (called from MainLoop, 3 frame debounce)

function m.GetBadge(load_count) → string
  -- Returns "veteran" (>50), "regular" (11-50), "new" (2-10), "fresh" (1), nil (0)
```

### .grove v3 format — extended schema

```lua
-- Fields added to the return{table}:
--   version = 3,                     -- bumped from 2
--   key = "C",                        -- musical key (string: C, Dm, etc.)
--   bpm = 120,                        -- beats per minute (number)
--   genre = "",                       -- genre tag (string)
--   difficulty = 1,                   -- 1-5 (number)
--   tags = {"chord", "jazz", "fast"}, -- freeform tags (table of strings)
--   save_count = 0,                   -- how many times this preset was saved
--   created_at = 0,                   -- unix timestamp from reaper.time_precise() on first save
--   modified_at = 0,                  -- unix timestamp on last save
-- All fields optional — nil defaults handled at load time.
```

### preview.lua — new ghost preview module

Following the keyboard.lua `temp_ctx` pattern:

```lua
-- m.IsPreviewing() → boolean
--   Returns true if a preview is currently playing.

-- m.StartPreview(notes_array, channel) → void
--   Takes array of {pitch, start_beat, duration, velocity}.
--   Sends note-on via StuffMIDIMessage for ALL notes immediately.
--   Schedules note-off via reaper.defer after 800ms.

-- m.StopPreview() → void
--   Cancels pending note-off defer, sends note-offs for all preview notes.
--   Clears internal note list.
```

Notable design: preview notes are stored in a module-local table, NOT in any store. The note-off defer callback is also module-local. This ensures zero interaction with the ref-counted `active_notes` or `midi_store`.

### Versioning in SavePreset

```lua
-- function m.SavePresetWithVersioning(file_path, preset_name) → boolean
--   1. If file exists at file_path:
--      a. Scan directory for name_vN.grove, pick next N
--      b. Rename old file: name.grove → name_v1.grove
--      c. Write new file at name.grove
--   2. If file doesn't exist: normal save
--   3. Returns success/fail
```

### Pack format (.grove-pack)

```lua
-- return {
--   version = 1,
--   name = "My Pack",
--   description = "Jazz chord presets",
--   created_at = 1234567.89,
--   presets = {
--     {
--       name = "Preset 1",
--       filename = "Preset 1.grove",
--       content = "return {\n  version = 3,\n  ...\n}",  -- raw string content
--     },
--     -- ...
--   },
-- }
```

This avoids base64 and uses the same Lua-serialization pattern as .grove files. `content` is the full file content as a string, written back via `io.open(path, "w")`.

### Auto-save file path

```
{preset_root}/_autosave/slot_{page}_{slot}.grove
```

Example: `grove-presets/_autosave/slot_1_5.grove` for page 1, slot 5.

## Feature-by-Feature Code Sketches

### F1 — Stats de Uso

**Files**: Create `src/state/preset-stats.lua`, Modify `src/ui/preset-browser/io.lua` (LoadPreset hook)

```lua
-- src/state/preset-stats.lua
local STATS_KEY = "preset_stats"
local CANONICAL_NS = "GROVE_Scale_Runner"
local state = {}  -- { [path] = { load_count, last_loaded, favorite_count } }
local _dirty = false
local _save_counter = 0
local m = {}

-- Lua JSON subset: simple k/v pairs, no nested objects beyond the entry
local function encode(stats)
    local parts = {}
    for path, s in pairs(stats) do
        table.insert(parts, string.format("[%q]={lc=%d,ll=%f,fc=%d}",
            path, s.load_count or 0, s.last_loaded or 0, s.favorite_count or 0))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function decode(str)
    local t = {}
    -- Use safe_loader.LoadString to evaluate the Lua table expression
    local ok, result = safe_loader.LoadString("return " .. str)
    if ok and type(result) == "table" then
        for path, entry in pairs(result) do
            t[path] = {
                load_count = entry.lc or 0,
                last_loaded = entry.ll or 0,
                favorite_count = entry.fc or 0,
            }
        end
    end
    return t
end

function m.Init()
    _dirty = false
    _save_counter = 0
    local ok, str = pcall(reaper.GetExtState, CANONICAL_NS, STATS_KEY)
    if ok and str and #str > 0 then
        state = decode(str)
    end
end

function m.IncrementLoadCount(path)
    local entry = state[path]
    if not entry then
        entry = { load_count = 0, last_loaded = 0, favorite_count = 0 }
        state[path] = entry
    end
    entry.load_count = (entry.load_count or 0) + 1
    entry.last_loaded = reaper.time_precise()
    _dirty = true
    _save_counter = 3
end

function m.IncrementFavoriteCount(path)
    local entry = state[path]
    if not entry then
        entry = { load_count = 0, last_loaded = 0, favorite_count = 0 }
        state[path] = entry
    end
    entry.favorite_count = (entry.favorite_count or 0) + 1
    _dirty = true
    _save_counter = 3
end

function m.GetStats(path) return state[path] end
function m.GetAllStats() return state end

function m.TickSaveDebounce()
    if _save_counter > 0 then
        _save_counter = _save_counter - 1
        if _save_counter == 0 and _dirty then
            pcall(reaper.SetExtState, CANONICAL_NS, STATS_KEY, encode(state), true)
            _dirty = false
        end
    end
end

-- Badge derivation (F6)
local BADGE_LABELS = {
    veteran = { label = "VETERAN", color = {0.9, 0.6, 0.1, 1}, threshold = 50 },
    regular = { label = "REGULAR", color = {0.4, 0.7, 0.4, 1}, threshold = 11 },
    new     = { label = "NEW",     color = {0.4, 0.6, 0.9, 1}, threshold = 2 },
}

function m.GetBadge(load_count)
    if not load_count or load_count == 0 then return nil end
    for _, b in ipairs({{"fresh",1},{"new",2},{"regular",11},{"veteran",50}}) do
        local name, threshold = b[1], b[2]
        if load_count >= threshold then
            return BADGE_LABELS[name]
        end
    end
    return { label = "FRESH", color = {0.6, 0.6, 0.6, 1}, threshold = 1 }
end

-- Display-value mapping: 1→"Fresh", 2-10→"New", 11-50→"Regular", >50→"Veteran"

return m
```

**Hook in io.lua:LoadPreset** (end of function, before `return true`):
```lua
local preset_stats = require("state.preset-stats")
preset_stats.IncrementLoadCount(file_path)
```

**Init** in main.lua (after stores, before core requires):
```lua
require("state.preset-stats").Init()
```

**Tick** in MainLoop (after `preferences_store.TickSaveDebounce()`):
```lua
require("state.preset-stats").TickSaveDebounce()
```

### F2 — Tags + Metadatos (.grove v3)

**Files**: Modify `src/ui/preset-browser/io.lua`

**SavePreset v3 serialization** (modify lines ~140-177):

```lua
-- In SavePreset, change version line:
table.insert(lines, "    version = 3,")

-- Add metadata fields (after scale/octave lines):
table.insert(lines, string.format("    key = %q,", metadata.key or ""))
table.insert(lines, string.format("    bpm = %d,", metadata.bpm or 120))
table.insert(lines, string.format("    genre = %q,", metadata.genre or ""))
table.insert(lines, string.format("    difficulty = %d,", metadata.difficulty or 1))

-- Tags as table:
table.insert(lines, "    tags = {")
for _, t in ipairs(metadata.tags or {}) do
    table.insert(lines, string.format("        %q,", t))
end
table.insert(lines, "    },")

-- Notes field:
table.insert(lines, string.format("    notes = %q,", metadata.notes or ""))
```

**Metadata storage**: Add new store fields in `preset-store.lua`:
```lua
-- In state table add:
    preset_metadata = {},  -- { [path] = { key, bpm, genre, difficulty, tags, notes } }
```

**EditMetadataDialog** — new function in `io.lua`:

```lua
function m.EditMetadataDialog(file_path)
    local ok, result = safe_loader.LoadSandboxed(file_path)
    if not ok then return end
    local meta = result or {}

    local ret, key = reaper.GetUserInputs("Edit Metadata", 4,
        "Key (e.g. C, Dm):,BPM:,Genre:,Difficulty (1-5):",
        (meta.key or "") .. "," .. (meta.bpm or "120") .. "," ..
        (meta.genre or "") .. "," .. (meta.difficulty or "1"))
    if not ret then return end

    -- Parse comma-separated tags
    local ret2, tags_str = reaper.GetUserInputs("Tags", 1,
        "Tags (comma-separated, e.g. jazz,chord,fast):",
        table.concat(meta.tags or {}, ","))
    if not ret2 then return end

    local ret3, notes = reaper.GetUserInputs("User Notes", 1,
        "Notes:,",
        meta.notes or "")
    if not ret3 then return end

    local key_part, bpm_part, genre_part, diff_part = key:match("^(.-),(.-),(.-),(.-)$")
    if not key_part then return end

    -- Validate
    local bpm_num = tonumber(bpm_part) or 120
    local diff_num = tonumber(diff_part) or 1
    diff_num = math.max(1, math.min(5, diff_num))

    -- Parse tags
    local tags = {}
    for t in tags_str:gmatch("[^,]+") do
        local trimmed = t:match("^%s*(.-)%s*$")
        if trimmed and #trimmed > 0 then
            table.insert(tags, trimmed)
        end
    end

    -- Update metadata and re-save
    local preset_store = require("state.preset-store")
    local meta_storage = preset_store.GetPresetMetadata()
    meta_storage[file_path] = {
        key = key_part, bpm = bpm_num, genre = genre_part,
        difficulty = diff_num, tags = tags, notes = notes or "",
    }
    preset_store.SetPresetMetadata(meta_storage)

    -- Re-save with updated metadata
    -- (SavePreset already reads from note_store, we just need to pass metadata)
    -- We need to add an optional metadata param to SavePreset
end
```

**LoadPreset v3 compat** (modify v2 block at line 244):
```lua
if result.version and result.version >= 2 then
    -- existing v2 fields ...
end
if result.version and result.version >= 3 then
    -- Read optional v3 fields into metadata store
    local meta_storage = preset_store.GetPresetMetadata()
    meta_storage[file_path] = {
        key = result.key or "",
        bpm = result.bpm or 120,
        genre = result.genre or "",
        difficulty = result.difficulty or 1,
        tags = result.tags or {},
        notes = result.notes or "",
    }
    preset_store.SetPresetMetadata(meta_storage)
end
```

**UI — "i" icon** in `preset-list.lua`, next to preset name:
```lua
local info_x = star_x - 18
helpers.SetColor({0.6, 0.6, 0.8, 0.6})
gfx.setfont(1, "Calibri", 9)
gfx.x, gfx.y = info_x, item_y + (ITEM_H - sh) / 2
gfx.drawstr("i")
if hover and ui_store.GetMouseClick() and gfx.mouse_x >= info_x and gfx.mouse_x <= info_x + 14 then
    io_mod.EditMetadataDialog(entry.path)
end
```

### F3 — Notas por Preset

Implemented as part of F2 metadata editor — the "notes" field is already in the v3 schema and the `EditMetadataDialog` above already includes a notes input. The "📝" icon can be added similarly next to the "i" icon, or the notes editor can be part of the same dialog (as designed above — 3 sequential `GetUserInputs` calls: key/bpm/genre/diff → tags → notes).

### F4 — Preview Auditivo

**Files**: Modify `src/ui/preset-browser/preset-list.lua` (hover detection), Create `src/ui/preset-browser/preview.lua`

```lua
-- src/ui/preset-browser/preview.lua
local m = {}
local _preview_notes = {}  -- { pitch, velocity }
local _defer_scheduled = false
local _preview_channel = 0

function m.StartPreview(notes_array, channel)
    m.StopPreview()  -- cancel any existing preview first

    _preview_channel = channel or 0
    _preview_notes = {}

    for _, n in ipairs(notes_array or {}) do
        if n.pitch then
            local pitch = n.pitch
            local vel = n.velocity or 100
            reaper.StuffMIDIMessage(_preview_channel, 0x90, pitch, vel)
            table.insert(_preview_notes, pitch)
        end
    end

    if #_preview_notes > 0 and not _defer_scheduled then
        _defer_scheduled = true
        reaper.defer(function()
            m.StopPreview()
            _defer_scheduled = false
        end)
    end
end

function m.StopPreview()
    for _, pitch in ipairs(_preview_notes) do
        reaper.StuffMIDIMessage(_preview_channel, 0x80, pitch, 0)
    end
    _preview_notes = {}
end

function m.IsPreviewing() return #_preview_notes > 0 end

return m
```

**Preview trigger** in `preset-list.lua` hover:

```lua
-- In DrawPresetList, inside the item loop, add:
local do_preview = false
if hover and not (gfx.mouse_cap & 1 == 1) then  -- not clicking
    local preview = require("ui.preset-browser.preview")
    if not preview.IsPreviewing() then
        -- Sandbox-load preset for notes
        local ok, result = safe_loader.LoadSandboxed(entry.path)
        if ok and result and result.notes then
            preview.StartPreview(result.notes)
        end
    end
    do_preview = true
end
```

NOTE: Don't load the preset file every frame. Cache entry path and use a debounce — only start preview after 300ms of sustained hover. Use a module-level `_hover_timer` and `_hover_path` in main.lua or a new preview module.

**Ctrl+Space trigger** — keyboard intercept in `keyboard.lua`:
```lua
-- In HandleKeyboard, add case for VK_SPACE with Ctrl:
if vk == 0x20 and (ctrl_down) then
    -- Get selected preset path and preview
    local files = preset_store.GetPresetFiles()
    local idx = preset_store.GetSelectedPresetIdx()
    if idx and files[idx] then
        local ok, result = safe_loader.LoadSandboxed(files[idx].path)
        if ok and result and result.notes then
            preview.StartPreview(result.notes)
        end
    end
end
```

### F5 — Miniaturas de Patrón

**Files**: Modify `src/ui/preset-browser/io.lua` (scan-time computation), `preset-list.lua` (rendering), `preset-store.lua` (storage)

**Analysis function** in `io.lua`:

```lua
--- Compute 8×8 note density grid from notes array.
--- @param notes table Array of {pitch, start_beat, duration}
--- @return table 8×8 boolean grid { {bool,...}, ... }
function m.ComputeThumbnailGrid(notes)
    if not notes or #notes == 0 then return {} end

    -- Find time/pitch ranges
    local min_beat, max_beat = math.huge, -math.huge
    local min_pitch, max_pitch = math.huge, -math.huge
    for _, n in ipairs(notes) do
        local s, e = n.start_beat or 0, (n.start_beat or 0) + (n.duration or 4)
        if s < min_beat then min_beat = s end
        if e > max_beat then max_beat = e end
        if n.pitch < min_pitch then min_pitch = n.pitch end
        if n.pitch > max_pitch then max_pitch = n.pitch end
    end

    if min_beat == math.huge then return {} end

    local beat_range = max_beat - min_beat
    local pitch_range = max_pitch - min_pitch
    if beat_range <= 0 then beat_range = 4 end
    if pitch_range <= 0 then pitch_range = 12 end

    local grid = {}
    for y = 1, 8 do
        grid[y] = {}
        for x = 1, 8 do
            grid[y][x] = false
        end
    end

    for _, n in ipairs(notes) do
        local start_col = math.floor(((n.start_beat or 0) - min_beat) / beat_range * 8) + 1
        local end_col = math.floor(((n.start_beat or 0) + (n.duration or 4) - min_beat) / beat_range * 8) + 1
        local row = math.floor((max_pitch - n.pitch) / math.max(1, pitch_range) * 8) + 1
        start_col = math.max(1, math.min(8, start_col))
        end_col = math.max(start_col, math.min(8, end_col))
        row = math.max(1, math.min(8, row))
        for x = start_col, end_col do
            grid[row][x] = true
        end
    end

    return grid
end
```

**Scan-time caching** in `ScanDirectory` (after file name extraction):

```lua
-- Inside ScanDirectory, after adding a file to files[]:
local ok, result = safe_loader.LoadSandboxed(entry.path)
if ok and result and result.notes then
    files[#files].thumbnail = m.ComputeThumbnailGrid(result.notes)
end
```

This adds ~1-2ms per file. For 50 files, ~100ms total on first scan. Acceptable for Init-time. Cache in `_scan_cache` prevents re-computation on re-render.

**Rendering** in `preset-list.lua`:

```lua
-- Inside DrawPresetList item loop, after drawing name:
local thumb = entry.thumbnail
if thumb and #thumb > 0 then
    local tx = x + 4
    local ty = item_y + (ITEM_H - 16) / 2
    local cell_w = 2
    local cell_h = 2
    helpers.SetColor({0.15, 0.15, 0.15, 0.5})
    gfx.rect(tx, ty, 16, 16, 1)  -- background
    for row = 1, 8 do
        for col = 1, 8 do
            if thumb[row] and thumb[row][col] then
                helpers.SetColor({0.3, 0.6, 0.9, 0.7})
            else
                helpers.SetColor({0.12, 0.12, 0.12, 0.3})
            end
            gfx.rect(tx + (col-1) * cell_w, ty + (row-1) * cell_h, cell_w, cell_h, 1)
        end
    end
    -- Shift name right to avoid overlap
    local name_x = tx + 18
    -- (update name drawing x to use name_x instead of x+4)
end
```

### F6 — Badges por Uso

**Files**: Modify `src/ui/preset-browser/preset-list.lua`

Badge rendering is purely derived from stats — no new state needed.

```lua
-- In DrawPresetList item loop, after drawing star:
local stats = preset_store.GetAllStats()  -- or imported from preset-stats
local entry_stats = stats[entry.path]
if entry_stats then
    local badge = preset_stats.GetBadge(entry_stats.load_count)
    if badge then
        local bx = star_x - 40
        local bw = 36
        helpers.SetColor(badge.color)
        gfx.rect(bx, item_y + 2, bw, ITEM_H - 4, 1)  -- badge bg
        helpers.SetColor({0, 0, 0, 0.7})
        gfx.setfont(1, "Calibri", 7)
        local bw_str = gfx.measurestr(badge.label)
        gfx.x, gfx.y = bx + (bw - bw_str) / 2, item_y + (ITEM_H - 8) / 2
        gfx.drawstr(badge.label)
    end
end
```

### F7 — Auto-save por Slot

**Files**: Modify `src/ui/preset-browser/io.lua` (save helper), `src/state/preset-store.lua` (tracking), `src/ui/preset-browser/main.lua` (tick from DrawPresetBrowser), `src/core/progression.lua` (revision access — already available via `GetProgressionRevision`)

```lua
-- In io.lua:
local AUTOSAVE_DIR = "_autosave"

function m.SaveSlotSnapshot(page, slot_idx, notes, progression_entry)
    local dir = (preset_store.GetPresetRoot() or "") .. "/" .. AUTOSAVE_DIR
    -- Ensure dir exists
    pcall(reaper.RecursiveCreateDirectory, dir, 0)

    local file_path = dir .. "/slot_" .. tostring(page) .. "_" .. tostring(slot_idx) .. ".grove"
    local lines = {
        "return {",
        "    name = \"autosave\",",
        "    version = 2,",
        "    notes = {",
    }
    for _, n in ipairs(notes or {}) do
        table.insert(lines, string.format(
            "        {pitch=%s,start_beat=%s,duration=%s,velocity=%s,muted=%s},",
            tostring(n.pitch), tostring(n.start_beat), tostring(n.duration),
            tostring(n.velocity), n.muted and "true" or "false"))
    end
    table.insert(lines, "    },")
    -- Also save the progression slot entry for context:
    if progression_entry then
        table.insert(lines, "    progression_entry = {",
            "degree=" .. (progression_entry.degree or 1),
            ",root_index=" .. (progression_entry.root_index or 1),
            ",scale_index=" .. (progression_entry.scale_index or 1),
            ",octave=" .. (progression_entry.octave or 4),
            ",chord_mode_index=" .. (progression_entry.chord_mode_index or 1),
            "},")
    end
    table.insert(lines, "}")
    local ok, f = pcall(io.open, file_path, "w")
    if f then f:write(table.concat(lines, "\n")); f:close() end
end

-- In main.lua or main.lua-equivalent, in MainLoop:
-- (or in DrawPresetBrowser which runs every frame)
function m.TickAutoSave()
    local seq_store = require("state.sequencer")
    if seq_store.GetIsPlaying() then return end  -- don't save during playback

    local rev = seq_store.GetProgressionRevision()
    local last_rev = seq_store.GetAutoSaveLastRevision() or 0
    if rev <= last_rev then return end

    -- Debounce: only save if no changes for 60 frames (~1s)
    local no_change_frames = seq_store.GetAutoSaveNoChangeFrames() or 0
    if rev ~= last_rev then
        seq_store.SetAutoSaveNoChangeFrames(0)
        seq_store.SetAutoSaveLastRevision(rev)
    else
        seq_store.SetAutoSaveNoChangeFrames(no_change_frames + 1)
        if no_change_frames >= 60 then
            -- Actually save
            local progression = seq_store.GetProgression()
            local page = seq_store.GetCurrentPage()
            for i = 1, 16 do
                local entry = progression[i]
                if entry then
                    io_mod.SaveSlotSnapshot(page, i, note_store.GetNotes(), entry)
                end
            end
            seq_store.SetAutoSaveNoChangeFrames(-1)  -- saved, don't re-save
        end
    end
end
```

**Init in Init()** or in `preset-store.lua`: add `autosave_last_revision = 0`, `autosave_no_change_frames = 0` fields and getters/setters.

### F8 — Versionado Automático

**Files**: Modify `src/ui/preset-browser/io.lua`

```lua
--- Save preset with automatic versioning on name collision.
--- @param file_path string Target path (name.grove)
--- @param preset_name string User-visible name
--- @return boolean success
function m.SavePresetWithVersioning(file_path, preset_name)
    -- Check if target exists
    local f = io.open(file_path, "r")
    if not f then
        -- No collision: normal save
        return m.SavePreset(file_path, preset_name)
    end
    f:close()

    -- File exists: find next version
    local dir = file_path:match("^(.+)[\\/][^\\/]+$") or "."
    local name_no_ext = preset_name:gsub("%.grove$", "")
    local next_v = 1
    local old_versions = {}

    -- Scan for existing _vN files
    local ok, handle = pcall(io.popen, 'dir "' .. dir .. '\\' .. name_no_ext .. '_v*.grove" /B 2>nul')
    if ok and handle then
        for line in handle:lines() do
            local vnum = line:match("_v(%d+)%.grove$")
            if vnum then
                table.insert(old_versions, tonumber(vnum))
            end
        end
        handle:close()
    end

    -- Pick next version number
    table.sort(old_versions)
    next_v = (#old_versions > 0) and (old_versions[#old_versions] + 1) or 1

    -- Rename existing to _v1 (or next), then save new as base name
    local backup_path = dir .. "\\" .. name_no_ext .. "_v" .. next_v .. ".grove"
    os.rename(file_path, backup_path)

    -- Save as the base name (latest version always has no suffix)
    return m.SavePreset(file_path, preset_name)
end
```

**UI version indicator** in `preset-list.lua`:
```lua
-- After drawing name, show version count
local rev = io_mod.GetVersionCount(entry.path)
if rev and rev > 0 then
    helpers.SetColor({0.5, 0.5, 0.5, 0.5})
    gfx.setfont(1, "Calibri", 8)
    gfx.x, gfx.y = name_x + lw + 4, item_y + (ITEM_H - 8) / 2
    gfx.drawstr("v:" .. rev)
end
```

**GetVersionCount helper** in `io.lua`:
```lua
function m.GetVersionCount(file_path)
    local dir = file_path:match("^(.+)[\\/][^\\/]+$")
    local name_no_ext = file_path:match("([^\\/]+)%.grove$"):gsub("%.grove$", "")
    local count = 0
    local ok, handle = pcall(io.popen, 'dir "' .. dir .. '\\' .. name_no_ext .. '_v*.grove" /B 2>nul')
    if ok and handle then
        for _ in handle:lines() do count = count + 1 end
        handle:close()
    end
    return count
end
```

**Context menu "Load previous version"** in `preset-list.lua:HandleContextMenu`:
```lua
-- In single-selection context menu, add option:
local choice = gfx.showmenu("Load|Rename|Duplicate|Delete|Show in Explorer|Load Previous Version|-" ..
    "Edit Metadata|Preview")
-- Add handler:
elseif choice == 6 then
    -- Show version list and load
    local versions = io_mod.GetVersionPaths(entry.path)
    if #versions == 0 then
        reaper.MB("No previous versions found.", "Version History", 0)
    else
        -- Build menu string
        local menu_items = {}
        for i, v in ipairs(versions) do
            table.insert(menu_items, "Version " .. i)
        end
        local vchoice = gfx.showmenu(table.concat(menu_items, "|"))
        if vchoice and vchoice > 0 and versions[vchoice] then
            io_mod.LoadPreset(versions[vchoice])
        end
    end
```

### F9 — Dark/Light Sync

**Files**: Inspect `src/ui/preset-browser/main.lua`, `preset-list.lua`, `folder.lua` — ensure all use `theme.colors` via `helpers.SetColor`.

**No code changes needed**. Verify existing usage:
- `main.lua` lines 21-26: uses `SEARCH_BG`, `SEARCH_TEXT` hardcoded — these should use `theme.colors`:
  ```lua
  -- Replace hardcoded SEARCH_BG with theme:
  local search_bg = theme.colors.bar_bg  -- already matches ~0.14 alpha
  local search_text = theme.colors.text
  ```

- `preset-list.lua` lines 19-29: `ITEM_HOVER`, `ITEM_SELECTED`, `FILE_COLOR` hardcoded — migrate to `theme.colors`:
  ```lua
  -- Use theme.tinted values:
  local ITEM_HOVER = nil  -- computed per frame via theme
  ```

**Recommendation**: Minimal change — the existing theme system already works. Only adjust preset-browser constants that are hardcoded to use `theme.colors` for proper theme switching.

### F10 — Export/Import Packs

**Files**: Modify `src/ui/preset-browser/io.lua`

```lua
--- Export selected presets as a .grove-pack bundle.
--- @param indices table Sparse set {[idx]=true}
--- @param files table File entries array
--- @param pack_name string User-chosen pack name
function m.ExportPresetsAsPack(indices, files, pack_name)
    if not indices or not files then return end

    local pack = {
        version = 1,
        name = pack_name or "Untitled Pack",
        description = "",
        created_at = reaper.time_precise(),
        presets = {},
    }

    for idx in pairs(indices) do
        local entry = files[idx]
        if entry then
            local ok, handle = pcall(io.open, entry.path, "r")
            if ok and handle then
                local content = handle:read("*all")
                handle:close()
                table.insert(pack.presets, {
                    name = entry.name,
                    filename = entry.filename,
                    content = content,
                })
            end
        end
    end

    if #pack.presets == 0 then
        preset_store.SetBrowserError("No presets to export")
        return
    end

    -- Serialize as Lua return table (same pattern as .grove files)
    local lines = {
        "return {",
        string.format("    version = %d,", pack.version),
        string.format("    name = %q,", pack.name),
        string.format("    created_at = %f,", pack.created_at),
        "    presets = {",
    }
    for _, p in ipairs(pack.presets) do
        table.insert(lines, "        {")
        table.insert(lines, string.format("            name = %q,", p.name))
        table.insert(lines, string.format("            filename = %q,", p.filename))
        table.insert(lines, "            content = [====[")
        table.insert(lines, p.content)
        table.insert(lines, "            ]====],")
        table.insert(lines, "        },")
    end
    table.insert(lines, "    },")
    table.insert(lines, "}")

    -- Write .grove-pack file
    local dir = preset_store.GetCurrentDirectory()
    local safe_name = path_utils.SanitizePresetName(pack_name)
    local pack_path = dir .. "/" .. safe_name .. ".grove-pack"
    local ok, f = pcall(io.open, pack_path, "w")
    if f then
        f:write(table.concat(lines, "\n"))
        f:close()
        preset_store.SetBrowserError(nil)
    else
        preset_store.SetBrowserError("Could not write pack file")
    end
end

--- Import a .grove-pack bundle, extracting all presets into the current directory.
--- @param pack_path string Path to .grove-pack file
function m.ImportPack(pack_path)
    local ok, pack = safe_loader.LoadSandboxed(pack_path)
    if not ok then
        preset_store.SetBrowserError("Invalid pack file")
        return
    end
    if pack.version ~= 1 then
        preset_store.SetBrowserError("Unsupported pack version: " .. tostring(pack.version))
        return
    end

    local dir = preset_store.GetCurrentDirectory()
    local count = 0
    for _, p in ipairs(pack.presets or {}) do
        if p.content and p.filename then
            local file_path = dir .. "/" .. p.filename
            local f = io.open(file_path, "w")
            if f then
                f:write(p.content)
                f:close()
                count = count + 1
            end
        end
    end

    m.RefreshPresets()
    preset_store.SetBrowserError(nil)
    reaper.MB("Imported " .. count .. " presets from pack.", "Import Complete", 0)
end
```

**Context menu integration** in `preset-list.lua:HandleContextMenu` (multi-select):
```lua
-- In multi-select menu, add export option:
local choice = gfx.showmenu("Load Primary|Merge Load All|Export to MIDI|Export as Pack|Delete All")
if choice == 4 then
    local ret, name = reaper.GetUserInputs("Export Pack", 1, "Pack name:,", "My Presets")
    if ret and name and #name > 0 then
        io_mod.ExportPresetsAsPack(sel_indices, files, name)
    end
end
```

**Import button** in `main.lua` or `folder.lua`:
```lua
-- Add "Import Pack" button in DrawFolderHeader or as a toolbar icon
if ui_store.GetMouseClick() then
    -- button hit-test
    local ret, path = reaper.GetUserInputs("Import Pack", 1, "Path to .grove-pack:,", "")
    if ret and path and #path > 0 then
        io_mod.ImportPack(path)
    end
end
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `ComputeThumbnailGrid` — edge cases (empty, single note, dense) | Pure function, can test with mock notes table |
| Unit | `GetBadge` — thresholds at boundaries (0, 1, 2, 10, 11, 50, 51) | Pure function, simple asserts |
| Unit | v3 SavePreset round-trip — notes/metadata preserve fidelity | Sandbox load + field comparison |
| Unit | `SavePresetWithVersioning` — version increment logic | Mock `io.open` results, verify file path |
| Integration | Preview MIDI — notes fire and clear within 800ms | Manual REAPER test |
| Integration | Pack export/import — file content round-trip | Manual REAPER test |
| Integration | Auto-save — progression changes trigger file creation | Manual REAPER test |

## Migration / Rollout

- **Phase 1**: No migration. New .grove v3 files coexist with v2. Old v2 files load identically. Stats table initializes empty.
- **Phase 2**: Preview module added silently. Ctrl+Space requires user discovery.
- **Phase 3**: Auto-save creates `_autosave/` directory on first trigger. Badges only show after preset loads (no retroactive data).
- **Phase 4**: Pack files are independent — no migration needed. Old .grove files remain untouched.

**Feature flags**: None. All features are additive and safe. If a phase needs rollback, git revert the phase's commit range.

## Open Questions

- [ ] Preview MIDI channel should use `midi.midi_channel` or a dedicated channel (e.g., channel 16)?
- [ ] Should auto-save respect the `_autosave/` dir in the preset root or in a separate location?
- [ ] Pack format: should we use base64 encoding for safety or raw Lua string content (which may fail on multi-line or special chars)?

## Implementation Order

Recommended implementation order within each phase:

**Phase 1**: preset-stats store → .grove v3 SavePreset → .grove v3 LoadPreset → EditMetadataDialog → stats hook in LoadPreset → Notes UI
**Phase 2**: preview.lua → hover detection in preset-list → ComputeThumbnailGrid → scan-time caching → thumbnail rendering → Ctrl+Space trigger
**Phase 3**: badge derivation → badge rendering → auto-save debounce timer → SaveSlotSnapshot → versioning in SavePreset → version UI → context menu version load → theme color migration
**Phase 4**: ExportPresetsAsPack → ImportPack → context menu integration → import button
