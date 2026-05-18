# Design: Bidirectional Progression Sync

## Technical Approach

Invert `ProgressionEntryToPitch` → detect degree by nearest-interval matching within CURRENT root/scale. Sync flows piano-roll notes → 16 progression slots via grouping by 4-beat column, per-note degree detection, and chord-mode inference from degree offset patterns.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Degree detection uses CURRENT root/scale | Not auto-detected from notes | Auto-detection is ambiguous (multiple roots/scales fit same notes). User expects sync to use active key, same as `ProgressionToNotes` does. |
| `SyncNotesToProgression` lives in note-store | Takes stores as params | Keeps note-store dependency-light. Inverse of existing `ProgressionToNotes`. Parallel pattern. |
| `notes_dirty` → tri-state enum | Full migration, no shims | 14 call sites is manageable in a single change. Shims would mask bugs. |
| Scrollbar drag → island_store | Getters/setters + `ResetScrollbarDragState()` | Follows existing `ResetNoteDrag()` pattern. All island UI state in one store. |
| pcall fix at preset-browser:65 | Remove wrapper, simple if-guard | `pcall(reaper.GetResourcePath, preset_dir)` is a no-op (wrong arg order). Direct call is safe. |

## Data Flow

```
notes[] ──SyncNotesToProgression()──►
  │  1. Group by slot: floor(start_beat / 4) + 1
  │  2. For each group:
  │     a. Per note: nearest interval → degree
  │     b. Min degree = slot root degree
  │     c. Degree offsets pattern → chord_mode
  │     d. Lowest pitch octave → slot octave
  │  3. Write slot ← seq_store.SetProgressionEntry(i, slot)
  ▼
progression[1..16] ──► sequencer
```

## State Machine

```
NOTES_STATE = { LOADED=0, EDITED=1, SYNCED=2 }
Transitions:
  LOADED ──note mutation──► EDITED
  EDITED ──sync button────► SYNCED
  SYNCED ──note mutation──► EDITED
  LOADED ──reload button──► LOADED  (no-op, already loaded)
  EDITED ──reload button──► LOADED
  SYNCED ──reload button──► LOADED
  ANY ────island close────► LOADED  (reset on close/reopen)
```

Guard in midi-island.lua: auto-reload from progression only when `state == LOADED`.

## File Changes

| File | Action | Key changes |
|------|--------|-------------|
| `src/state/island.lua` | Modify | `notes_dirty` → `notes_state` tri-state + getters/setters + scrollbar drag state (6 fields + `ResetScrollbarDragState()`) |
| `src/state/note-store.lua` | Modify | Add `SyncNotesToProgression(seq_store, prefs_store, beats_per_slot?)` + internal helpers `GroupNotesByBeat`, `NearestScaleDegree`, `DetectChordModeFromDegrees` |
| `src/ui/midi-island.lua` | Modify | Replace `_sb_dragging` locals with `island_store.GetSb* / SetSb*`; `notes_dirty` → `notes_state` guard |
| `src/ui/midi-island/header.lua` | Modify | Add SYNC button after RELOAD. Return `sync_requested` alongside `reload_requested`. |
| `src/ui/preset-browser.lua` | Modify | Line 65: remove `pcall(reaper.GetResourcePath, preset_dir)`, keep `pcall(reaper.GetResourcePath)` |
| `src/ui/piano-roll/note.lua` | Modify | `SetNotesDirty(true)` → `SetNotesState(NOTES_STATE_EDITED)` |
| `src/ui/piano-roll/interaction/drag.lua` | Modify | 7× `SetNotesDirty(true)` → `SetNotesState(NOTES_STATE_EDITED)` |
| `src/ui/piano-roll/interaction/handlers.lua` | Modify | 2× `SetNotesDirty(true)` → `SetNotesState(NOTES_STATE_EDITED)` |
| `src/ui/piano-roll/knife.lua` | Modify | 1× `SetNotesDirty(true)` → `SetNotesState(NOTES_STATE_EDITED)` |

Total: 9 files modified, 0 created, 0 deleted.

## Interfaces / Contracts

```lua
-- === island_store additions ===
NOTES_STATE_LOADED = 0
NOTES_STATE_EDITED = 1
NOTES_STATE_SYNCED = 2

m.GetNotesState() → number (0-2)
m.SetNotesState(v) → void
-- Removed: GetNotesDirty(), SetNotesDirty(v)

-- Scrollbar drag state (6 pairs + reset)
m.GetSbDragging() → boolean;  m.SetSbDragging(v) → void
m.GetSbDragStartX() → number; m.SetSbDragStartX(v) → void
m.GetSbScrollAtDragStart() → number; m.SetSbScrollAtDragStart(v) → void
m.GetVsbDragging() → boolean;  m.SetVsbDragging(v) → void
m.GetVsbDragStartY() → number; m.SetVsbDragStartY(v) → void
m.GetVsbScrollAtDragStart() → number; m.SetVsbScrollAtDragStart(v) → void
m.ResetScrollbarDragState() → void  -- clears all 6 to defaults

-- === note-store additions ===
--- Sync piano-roll notes back to progression slots.
--- @param seq_store table  sequencer store (for GetProgressionEntry/SetProgressionEntry)
--- @param prefs_store table  preferences store (for GetRootIndex/GetScaleIndex/GetOctave)
--- @param beats_per_slot number  default 4
--- @return number  count of slots written
m.SyncNotesToProgression(seq_store, prefs_store, beats_per_slot) → count

-- === header.lua ===
--- Returns (cur_x, reload_requested, sync_requested)
function m.DrawHeader(content_w) → number, boolean, boolean
```

### SyncNotesToProgression Algorithm

```lua
function m.SyncNotesToProgression(seq_store, prefs_store, beats_per_slot)
    beats_per_slot = beats_per_slot or 4
    local notes = m.GetNotes()
    if #notes == 0 then return 0 end

    local root_idx = prefs_store.GetRootIndex()
    local scale_idx = prefs_store.GetScaleIndex()
    local octave_val = prefs_store.GetOctave()
    local scale = config.SCALES[api_guard.ClampIndex(scale_idx, 1, #config.SCALES)]
    if not scale then return 0 end

    local slots_written = 0
    for slot_i = 1, 16 do
        local beat_start = (slot_i - 1) * beats_per_slot
        local beat_end = slot_i * beats_per_slot
        local group_notes = {}

        -- Collect notes in this slot's beat range
        for _, n in ipairs(notes) do
            if n.start_beat >= beat_start and n.start_beat < beat_end then
                table.insert(group_notes, n)
            end
        end

        if #group_notes == 0 then
            -- No notes in this slot → skip (keep existing slot or leave nil)
            -- DO NOT clear — user may have slot data from sequencer input
            goto continue
        end

        -- Find nearest degree for each note in group
        local degrees = {}
        local root_pitch_class = (root_idx - 1) % 12
        for _, gn in ipairs(group_notes) do
            local pc = gn.pitch % 12
            local rel_pc = (pc - root_pitch_class + 12) % 12
            local best_dist = 12
            local best_deg = 1
            for di, interval in ipairs(scale.intervals) do
                local dist = math.abs(rel_pc - interval)
                -- Handle wraparound: interval 11 vs rel_pc 0 = dist 1 (wrap at 12)
                dist = math.min(dist, 12 - dist)
                if dist < best_dist then
                    best_dist = dist
                    best_deg = di
                end
            end
            degrees[best_deg] = true  -- dedup
        end

        -- Sort unique degrees
        local sorted = {}
        for d in pairs(degrees) do table.insert(sorted, d) end
        table.sort(sorted)
        if #sorted == 0 then goto continue end

        -- Root degree = min
        local root_degree = sorted[1]

        -- Detect chord_mode from degree pattern
        -- Compare note count first, then verify offset pattern matches
        local chord_mode_idx = 1  -- default Off (single note)
        for ci, cm in ipairs(config.CHORD_MODES) do
            if #cm.offsets == #sorted then
                local match = true
                for oi, off in ipairs(cm.offsets) do
                    if sorted[oi] ~= root_degree + off then
                        match = false; break
                    end
                end
                if match then chord_mode_idx = ci; break end
            end
        end

        -- Determine octave from lowest pitched note in group
        local min_pitch = math.huge
        for _, gn in ipairs(group_notes) do
            if gn.pitch < min_pitch then min_pitch = gn.pitch end
        end
        local slot_octave = math.max(0, math.min(8, math.floor(min_pitch / 12) - 1))

        -- Write the slot
        seq_store.SetProgressionEntry(slot_i, {
            degree = root_degree,
            root_index = root_idx,
            scale_index = scale_idx,
            octave = slot_octave,
            chord_mode_index = chord_mode_idx,
        })
        slots_written = slots_written + 1
        ::continue::
    end

    return slots_written
end
```

## Revision Audit

All call sites already increment `progression_revision`:
- `SetProgressionEntry(i, v)` → line 48: `progression_revision + 1` ✅
- `SetProgression(t)` → line 43: `progression_revision + 1` ✅
- `ClearProgression()` → line 51: `progression_revision + 1` ✅

`SyncNotesToProgression` calls `SetProgressionEntry` which increments revision. No additional tracking needed.

## Migration Path

1. Add `notes_state` enum + new getters/setters to island_store
2. Remove `notes_dirty` field + old getters/setters
3. Replace all 14 `SetNotesDirty(true)` call sites with `SetNotesState(NOTES_STATE_EDITED)`
4. Replace `SetNotesDirty(false)` (2 sites) with `SetNotesState(NOTES_STATE_LOADED)`
5. Update guard at midi-island.lua:98-99: `island_store.GetNotesState() == NOTES_STATE_LOADED`
6. All other changes (scrollbar, pcall, button) are independent

No persisted data migration needed — `notes_dirty` was runtime-only.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `NearestScaleDegree` helper | Given pitch + root + scale, verify correct degree returned. Test edge cases: pitch at interval boundary, pitch outside scale (~wraparound handling) |
| Unit | `DetectChordModeFromDegrees` | Given sorted degrees, verify correct chord_mode_index. Test 1-note, 3-note (Tri), 4-note (7ma), non-matching patterns |
| Unit | `SyncNotesToProgression` with mock stores | Feed known notes → verify slots written match expected. Test empty notes, single note, full 16-slot fill |
| Integration | Guard behavior | After `SyncNotesToProgression`, auto-reload must block. After user edit, auto-reload must block. After reload, auto-reload is allowed. |
| E2E | Full round-trip | Progression → LoadNotes → edit notes → SyncNotes → verify progression matches original (within degree tolerance) |

## Risks & Edge Cases

| Risk | Mitigation |
|------|------------|
| Notes span non-scale pitches (passing tones) | Nearest-interval matching still assigns nearest degree. Won't exactly reproduce original chord voicing, but will be harmonically close. |
| User has different root/scale than when notes were created | Degree detection uses CURRENT root/scale. Notes may map to different degrees. This is INTENTIONAL — user changed key and expects sync to use current key. |
| Empty slots (no notes in beat range) | Slot is NOT cleared. Keeps existing progression data intact. Only non-empty groups write slots. |
| Duplicate notes at same pitch in a column | Dedup by degree (table set). Chord mode inference uses UNIQUE degrees, not raw note count. |
| Notes at same beat but different octaves | Each note assigned to nearest degree independently. Octave of lowest pitch used for slot. |

## Open Questions

None.
