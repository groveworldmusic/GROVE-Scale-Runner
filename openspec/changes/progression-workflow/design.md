# Design: Progression Workflow

## Technical Approach

Two independent features sharing the undo infrastructure. **P1** adds snapshot-based undo/redo at the sequencer store level with a guard flag to handle composite ops (Swap). **P2** adds progression-only presets as `.grove-prog` files with a type branch in `LoadPreset`. P1 must ship before P2.

---

## P1: Progression Undo/Redo

### Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|-------------|-----------|
| **Snapshot strategy** | Per-entry shallow copy `{k=v, ...}` for all 16 slots | Deep copy vs reference copy | Entries are small (5-7 keys); 16 × `setmetatable({}, nil)` is cheap. Matches note-store snapshot cost profile |
| **Storage** | New fields in `seq_state` (sequencer store) | Separate `progression-undo.lua` store | Progression state lives here; adding 2 stacks + 5 functions avoids a new file. Fits existing pattern — note-store keeps undo/redo inline |
| **Integration** | Store-level wrapping with `_prog_undo_gate` guard | 10 call-site hooks (brittle, easy to miss) | Gate disabled for composite ops (Swap) and undo/restore paths. Single source of truth |
| **Keyboard dispatch** | `midi_island.Draw()` before early return guard | `keyboard.lua` VKeys path (wrong — Ctrl+Z/Y comes via `gfx.getchar()`) | The `char` variable already flows through `Draw()`. Checking before island-collapsed return ensures progression undo works regardless of island state |

### Guard Flag Pattern

```lua
-- sequencer store internals (state)
local _prog_undo_gate = true  -- default: snapshot on mutation

-- Wrapped setter
function m.SetProgressionEntry(i, v)
    if _prog_undo_gate then m.ProgPushUndo() end
    seq_state.progression[i] = v
    seq_state.progression_revision = seq_state.progression_revision + 1
end

-- Composite ops (Swap, HandleUndo) disable gate
function m.ProgBeginComposite()  _prog_undo_gate = false  end
function m.ProgEndComposite()    _prog_undo_gate = true   end
```

### Snapshot Format

```lua
-- An undo/redo entry: flat array of 16 entries (nil or table)
{ [1] = { degree=3, root_index=1, scale_index=4, octave=4, chord_mode_index=2, velocity=100 },
  [2] = nil, ... [16] = nil }
```

Deep copy per entry: `{ degree=e.degree, root_index=e.root_index, scale_index=e.scale_index, octave=e.octave, chord_mode_index=e.chord_mode_index, velocity=e.velocity, duration=e.duration }`. Explicit keys (no `for k,v in pairs`) for performance and deterministic snapshot.

### Data Flow

```
   progression.Add/Remove/Swap/Clear
         │
         ▼
   seq_store.SetProgressionEntry(i, v)
         │
         ├── _prog_undo_gate == true ? ProgPushUndo() → undo stack, clears redo
         │
         ▼
   seq_state.progression[i] = v
   
   Ctrl+Z (gfx.getchar char=346)
         │
         ▼
   midi_island.Draw() → IsProgressionFocused()
         │
         ├── true  → seq_store.ProgHandleUndo() → pop undo → push redo → SetProgression(snapshot)
         └── false → input.HandleKeyboard() → piano_roll.HandleKeyboardShortcut() → note undo
```

### Keyboard Focus Detection

```lua
function IsProgressionFocused()
    -- Focused when: island collapsed AND mouse Y within performance area
    if island_store.GetMidiIslandExpanded() then return false end
    -- Performance area is the top ~2/3 of the 720×497 window
    -- Slots occupy y ~200..450 (pixel coords, depends on layout)
    -- We check against the last-drawn slot area bounds cached from DrawPerformanceArea
    local my = gfx.mouse_y
    return my >= _perf_area_top and my <= _perf_area_bottom
end
```

`_perf_area_top`/`_perf_area_bottom` are module-level caches updated each frame in `DrawPerformanceArea`. This avoids duplicating layout calculations.

### Stack Semantics

- **Cap**: 50 entries (MAX_UNDO constant, same value as note-store)
- **Eviction**: `table.remove(stack, 1)` on push when `#stack >= 50`
- **Redo clear**: `ProgPushUndo()` sets `redo_stack = {}` (mirrors note-store line 147)
- **No-op on empty**: `ProgHandleUndo()` returns early if `#undo_stack == 0` (no crash)

### Files & LOC

| File | Action | LOC | What |
|------|--------|-----|------|
| `src/state/sequencer.lua` | Modify | +55 | Add prog_undo_stack, prog_redo_stack, MAX_UNDO, ProgPushUndo/HandleUndo/HandleRedo/ClearProgressionUndoStacks, guard in SetProgressionEntry/SetProgression/ClearProgression |
| `src/core/progression.lua` | Modify | +15 | Add ProgPushUndo() call at top of Add/Remove/Swap/Clear. Swap uses ProgBegin/EndComposite |
| `src/ui/midi-island.lua` | Modify | +20 | Ctrl+Z/Y dispatch + IsProgressionFocused cache, before collapsed-guard early return |
| `src/state/note-store.lua` | Modify | +2 | Call seq_store.ProgPushUndo() at top of SyncNotesToProgression |
| `src/state/sequencer.lua` (undo guard) | — | — | Guard gated: `ProgBeginComposite()`/`ProgEndComposite()` for Swap path |

**P1 LOC**: ~92

---

## P2: Progression-Only Presets

### Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Extension** | `.grove-prog` (new) | Self-documenting file type. No content parsing needed for scan filtering. User sees immediately which files are progression-only |
| **Scan** | Both `.grove` and `.grove-prog` with `type` field | Unified file list. UI layer decides how to display (filter tabs vs badges) |
| **Load branch** | On `result.type` field (not extension) | Future-proof: if we merge formats later, `result.type` is the canonical discriminator. Extension-based fallback for old files |

### io.lua Changes

```lua
-- 1. IsValidPresetFile: accept both extensions
function m.IsValidPresetFile(filename)
    return filename:lower():match("%.grove$") or filename:lower():match("%.grove%-prog$")
end

-- 2. ScanDirectory: collect both types with type field
for entry in _lfs.dir(dir_path) do
    local typ
    if entry:match("%.grove$") then typ = "notes"
    elseif entry:match("%.grove%-prog$") then typ = "progression" end
    if typ then
        local name = entry:gsub("%.grove%-prog$", ""):gsub("%.grove$", "")
        table.insert(files, {name=name, filename=entry, path=..., type=typ})
    end
end

-- 3. New: SaveProgressionPreset(file_path, name)
-- Serializes progression[1..16] + root_index, scale_index, octave, chord_mode_index
-- Sets version=1, type="progression", no notes key

-- 4. LoadPreset: branch on result.type
function m.LoadPreset(file_path)
    local ok, result = safe_loader.LoadSandboxed(file_path)
    -- ... validation ...
    if result.type == "progression" then
        -- Restore only: progression + 4 context keys
        -- Skip notes validation entirely
        -- Call ClearProgressionUndoStacks() after success
    else
        -- Existing behavior (notes + optional v2 progression)
    end
end
```

### Serialization Format

```lua
return {
    type = "progression",
    name = "my-prog",
    version = 1,
    root_index = 1,
    scale_index = 4,
    octave = 4,
    chord_mode_index = 2,
    progression = {
        { degree=3, root_index=1, scale_index=4, octave=4, chord_mode_index=2, velocity=100 },
        nil, nil, nil, { degree=5, root_index=1, scale_index=4, octave=4, chord_mode_index=1 },
        -- ... 16 entries total
    },
}
```

### UI Integration

**Button** → "Save Progression" placed directly right of the existing SAVE button in the preset browser toolbar. Same `gfx.showmenu` name-input pattern.

**File list discrimination** → Two approaches, pick one:
- **Filter tabs**: "Notes" / "Progression" toggle tabs at top of file list. Active tab filters `preset_files` by `type`. Simpler rendering, clearer UX.
- **Badges**: Small "N"/"P" label on each file row. Unified list, more noise.

**Recommendation**: Filter tabs first (lower cognitive load). Badges as future enhancement.

### Undo Interaction

```lua
-- In LoadPreset, after successful load:
if result.type == "progression" then
    seq_store.ClearProgressionUndoStacks()  -- P1 dependency
end
-- Note: ClearUndoStacks() (piano-roll) is ALREADY called in the existing path
```

### Files & LOC

| File | Action | LOC | What |
|------|--------|-----|------|
| `src/ui/preset-browser/io.lua` | Modify | +75 | SaveProgressionPreset (30), ScanDirectory dual-ext (15), IsValidPresetFile (3), LoadPreset branching (20), ClearProgressionUndoStacks call (2), GetPresetFilePath variant (5) |
| `src/ui/preset-browser.lua` | Modify | +90 | "Save Progression" button (25), filter tabs rendering + dispatch (40), type-aware file list sorting/filter (25) |
| `src/ui/preset-browser.lua` (barrel) | Modify | +2 | Re-export SaveProgressionPreset |

**P2 LOC**: ~167

---

## Sequencing

**P1 MUST ship before P2** because P2 depends on `ClearProgressionUndoStacks()` which P1 implements. Without P1, the undo-stack-clearing behavior on progression preset load cannot be implemented. P1 also establishes the `prog_undo_stack`/`prog_redo_stack` fields in the store that P2 reads (indirectly, via the clear call).

---

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Focus false-positive**: User edits slots while mouse is over piano-roll region | Low | Spec says island collapsed = progression focus. When collapsed, there is no piano-roll visible |
| **Focus false-negative**: User edits slot with mouse in slot area but island is expanded | Medium | By spec, island expanded → piano-roll focus. User must collapse island or mouse strictly in slots area for progression undo |
| **Double-snapshot on Swap**: Guard gate not propagated correctly | Low | `ProgBeginComposite()` before the 2 SetProgressionEntry calls. Test verifies exactly 1 undo entry per swap |
| **P2 ↔ Batch A conflict**: Both modify io.lua | Medium | Chain branches; P2 applies on top of Batch A's barrel. Resolve in feature branch merge |
| **Safe-loader behavior on .grove-prog**: `load()` returns unexpected type | Low | Existing `type(result) ~= "table"` guard catches this. Add `result.type == "progression"` check in validation |
