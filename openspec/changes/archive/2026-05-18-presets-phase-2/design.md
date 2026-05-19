# Design: Presets Phase 2 — Multi-Select + Batch Operations

## Technical Approach

Replace single `selected_preset_idx` with the exact set-based multi-select pattern proven in `island.lua` (`selected_indices = {[idx]=true}` + anchor). Expand context menu with batch actions. Three new I/O functions add delete/merge/export batch ops. Modifier keys (Ctrl/Shift) detected on-the-fly via `JS_VKeys_GetState` at click time — no new state module needed.

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|----------|--------|----------|-----------|
| Selection model | `selected_indices = {[idx]=true}` | bitfield / array of indices | Mirror `island.lua` exactly — proved pattern, 2k LOC shipping |
| Modifier source | On-the-fly `JS_VKeys_GetState(0)` at click time | Track in ui_store | Zero new state, zero MainLoop changes. VKeys API already available and used by keyboard.lua |
| Post-delete strategy | Clear selection + RefreshPresets | In-place index fixup | After `os.remove`, preset_files is stale until RefreshPresets rebuilds from disk. Indices are meaningless after refresh |
| Merge load approach | Separate `LoadPresetMerge(paths)` function | Modify `LoadPreset` with param | Clearer API contract. `LoadPreset` stays as single-preset-replace. Merge is a fundamentally different operation |
| Export MIDI | One MIDI item per preset on selected track | Single combined item | Simpler, independent undo-per-item. User can drag/move each preset's output separately |
| Phase 1 barrel status | **Not yet done** — tracked blocker | — | Sub-modules exist at `preset-browser/*.lua` but `preset-browser.lua` is still 881-LOC monolith. Must complete barrel first |

## Data Flow

```
Mouse click in preset-list ──→ preset-list.lua click handler
    ├── reads modifier state via JS_VKeys_GetState(0)
    ├── dispatches: plain-click / Ctrl+click / Shift+click
    └── calls preset-store set/clear/toggle

Context menu (right-click) ──→ preset-list.lua HandleContextMenu
    ├── selection > 1 ? batch menu : single menu
    └── dispatches to io.lua (BatchDelete / LoadPresetMerge / ExportPresetsToMIDI)

BatchDelete ──→ loop os.remove() → RefreshPresets() → ClearSelection()
LoadPresetMerge ──→ loop safe_loader.LoadSandboxed() → concat notes → PushUndo() → SetNotes()
ExportPresetsToMIDI ──→ for each preset: CreateNewMIDIItemInProj → MIDI_InsertNote → MIDI_Sort
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/state/preset-store.lua` | Modify | Replace `selected_preset_idx` with `selected_indices`, add set-based API + backward compat shim |
| `src/ui/preset-browser/preset-list.lua` | Modify | Multi-select rendering (highlight all selected), Shift/Ctrl click dispatch, batch context menu |
| `src/ui/preset-browser/main.lua` | Modify | Route multi-select results, handle batch action dispatch from main click handler |
| `src/ui/preset-browser/io.lua` | Modify | Add `BatchDelete`, `LoadPresetMerge`, `ExportPresetsToMIDI` |
| `src/ui/preset-browser.lua` | Modify | Re-export new functions through barrel. **Also: complete Phase 1 barrel refactor** |
| `src/ui/midi-island.lua` | None | No changes needed — already imports barrel, barrel forwards new functions |
| `src/ui/midi-island/header.lua` | None | No changes needed |

## Interfaces / Contracts

### preset-store.lua — Selection API (mirrors island.lua exactly)

```lua
-- State replacement:
--   state.selected_preset_idx = nil  →  REMOVED
--   state.selected_indices = {}       -- {[idx] = true}
--   state._last_selected_idx = nil    -- anchor for shift-range

function m.GetSelectedIndices()      return state.selected_indices end        -- TABLE REF (mutable)
function m.SetSelectedIndices(t)      state.selected_indices = t or {} end    -- full replace
function m.ClearSelection()           state.selected_indices = {}; state._last_selected_idx = nil end
function m.IsPresetSelected(idx)      return state.selected_indices[idx] == true end
function m.TogglePresetSelected(idx)  ...  -- toggle + update _last_selected_idx
function m.GetPrimarySelectedIndex()  return state._last_selected_idx end
function m.GetSelectionCount()        local c=0; for _ in pairs(state.selected_indices) do c=c+1 end; return c end

-- Backward compat shims (same pattern as island.lua Get/SetSelectedNoteIndex)
function m.GetSelectedPresetIdx()     return m.GetPrimarySelectedIndex() end
function m.SetSelectedPresetIdx(v)    m.ClearSelection(); if v then state.selected_indices[v]=true; state._last_selected_idx=v end end
```

### preset-list.lua — Modifier detection + click dispatch

```lua
-- Inside DrawPresetList / HandlePresetClick, at click time:
local vk_state = reaper.JS_VKeys_GetState(0)
local ctrl_held  = vk_state and vk_state:byte(0x11) ~= 0   -- VK_CONTROL
local shift_held = vk_state and vk_state:byte(0x10) ~= 0   -- VK_SHIFT

-- Dispatch:
if ctrl_held then
    preset_store.TogglePresetSelected(i)                    -- toggle in set
elseif shift_held then
    local anchor = preset_store.GetPrimarySelectedIndex() or i
    local lo, hi = math.min(anchor, i), math.max(anchor, i)
    m.ClearSelection()
    for j = lo, hi do m.SetSelectionAt(j) end               -- set range
    m.SetSelectionAnchor(anchor)                             -- keep anchor end
else
    m.ClearSelection()
    m.SetSelectionAt(i)
    m.SetSelectionAnchor(i)
end
```

### io.lua — Batch operations

```lua
--- Delete multiple preset files. Confirms with count, then removes each.
function m.BatchDeletePresets(paths, files) → bool
    -- Build confirm string: "Delete 3 presets?\n- Alpha\n- Beta\n- Gamma"
    -- reaper.MB(msg, "Delete Presets", 4) → check Yes (6)
    -- for _, path in ipairs(paths) do os.remove(path) end
    -- m.RefreshPresets()
    -- preset_store.ClearSelection()

--- Merge-load notes from multiple presets. Single undo snapshot.
function m.LoadPresetMerge(file_paths) → bool
    -- for _, path in ipairs(file_paths) do
    --     safe_loader.LoadSandboxed(path) → collect notes with AllocNoteUUID()
    -- PushUndo({type="preset_merge", snapshot=copy(current_notes)})
    -- note_store.SetNotes(all_notes)

--- Export each selected preset as a separate MIDI item on the selected track.
--- Uses reaper.CreateNewMIDIItemInProj + MIDI_InsertNote per note.
--- Beats-to-PPQ conversion via reaper.MIDI_GetPPQPosFromProjQN(take, QN_pos).
function m.ExportPresetsToMIDI(file_paths, preset_store_ref) → void
    -- track = reaper.GetSelectedTrack(0, 0); if nil → MB("Select a track first")
    -- for _, path in ipairs(file_paths) do
    --     LoadSandboxed(path) → for each valid note:
    --         start_qn = reaper.TimeMap_timeToQN(reaper.GetCursorPosition()) + offset
    --         end_qn = start_qn + (n.start_beat + n.duration or 4)
    --         reaper.CreateNewMIDIItemInProj(track, start_qn_time, end_qn_time)
    --         reaper.MIDI_InsertNote(take, ..., ppq_start, ppq_end, pitch, vel, true)
    --         offset += (n.duration or 4)
    --     reaper.MIDI_Sort(take)
    -- reaper.UpdateArrange()
```

## Interaction Semantics

| Gesture | Action | Selection After |
|---------|--------|-----------------|
| Plain click on index `i` | `ClearSelection()` → set `{i}` | `{i}` — single select |
| Ctrl+click on `i` | `TogglePresetSelected(i)` | toggled set |
| Shift+click on `i` | Range from anchor to `i` | contiguous range |
| Right-click on unselected | Select that item first, then context menu | `{i}` |
| Right-click on multi-selection | Batch-context menu (Load Merged N, Delete N, Export N) | unchanged |
| Search query edit | `ClearSelection()` | `{}` — empty |

## Barrel Re-export

Add to `preset-browser.lua` barrel (once refactored from monolith):

```lua
-- In the barrel's io_mod re-exports section:
m.BatchDeletePresets       = io_mod.BatchDeletePresets
m.LoadPresetMerge          = io_mod.LoadPresetMerge
m.ExportPresetsToMIDI      = io_mod.ExportPresetsToMIDI

-- preset-store functions exposed through barrel for consumer convenience:
m.GetSelectedIndices       = preset_store.GetSelectedIndices
m.GetSelectionCount        = preset_store.GetSelectionCount
m.GetPrimarySelectedIndex  = preset_store.GetPrimarySelectedIndex
m.TogglePresetSelected     = preset_store.TogglePresetSelected
```

**Note**: `midi-island.lua` and `midi-island/header.lua` consume `preset_browser.*` and will gain the new functions automatically through the barrel. No consumer changes needed.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `TogglePresetSelected` idempotency, `ClearSelection`, `GetSelectionCount` | Existing test runner (14 files, 497 assertions) — add preset-store test file |
| Unit | Index edge cases: toggle same idx twice, shift-range from anchor=nil, range with anchor > clicked | Pure Lua, no REAPER mocks needed |
| Integration | Batch delete → RefreshPresets → selection cleared | Mock `os.remove`, verify `RefreshPresets` called |
| Integration | Merge load → undo reverts to pre-merge state | Mock `safe_loader`, verify `PushUndo` snapshot |
| Manual | Ctrl+click toggles, Shift+click range, right-click batch menu in REAPER | Checklist in `verify-report.md` |

## Implementation Order

1. **`preset-store.lua`** — data model: replace `selected_preset_idx`, add set API + backward compat shim
2. **`preset-browser.lua`** — complete Phase 1 barrel refactor (extract to sub-module re-exports)
3. **`preset-list.lua`** — multi-select rendering + Shift/Ctrl click dispatch + batch context menu
4. **`main.lua`** (preset-browser) — route multi-select results, clear selection on search edit
5. **`io.lua`** — `BatchDelete`, `LoadPresetMerge`, `ExportPresetsToMIDI`
6. **`preset-browser.lua`** barrel — re-export new functions

**Dependency chain**: 1 → 2 → 3 → 4 → 5 → 6. Task 2 (barrel) is a prerequisite that was not completed in Phase 1.

## Open Questions

- None blocking. Confirm Shift+click behavior when no anchor exists (treat as plain-click is the design).
