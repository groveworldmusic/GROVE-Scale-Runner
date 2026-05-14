# Design: Comportamiento de la isla MIDI + Sistema de Presets

## Technical Approach

Extend the progression entry schema with optional `velocity`/`duration` captured at drag-to-slot time; update `ProgressionToNotes()` to read per-slot values with fallback; extend `.grove` format to v2 with full progression context; add rename action in preset browser.

## Architecture Decisions

### Decision: When to capture velocity/duration

| Option | Tradeoff | Decision |
|--------|----------|----------|
| At drop time (slots.lua lines 152-158) | Deterministic per-entry, trivial | **CHOSEN** — add `velocity=100, duration=4` to pad-drag entry table |
| At materialization time | Unpredictable, stateful | Rejected |

### Decision: Entry schema

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Optional fields on slot table | Zero migration — extra keys ignored | **CHOSEN** — `{..., velocity=100?, duration=4?}`, nil = default |
| Separate metadata table | Over-engineered for 2 fields | Rejected |

### Decision: Preset format versioning

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `version` field + conditional serialization | Forward-compatible, explicit | **CHOSEN** — v1 = nil/1, v2 = 2 |
| Add fields unconditionally | No v1 loader crash but ambiguous | Rejected |

### Decision: Rename

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `reaper.GetUserInputs()` + `os.rename()` | Matches existing "Save" flow | **CHOSEN** |
| Custom GFX dialog | Over-engineered | Rejected |

## Data Flow

```
Pad drag ──→ slots.lua {..., velocity=100, duration=4}
                  │
                  ▼
      progression.Add() ──→ seq_store.SetProgressionEntry()
                  │
                  ▼
      island_store.ProgressionToNotes()
         ├── entry.velocity or velocity param or 100
         └── entry.duration or beats_per_slot or 4
                  │
                  ▼
      island_store.SetNotes() ──→ piano-roll renders

Save Preset ──→ notes[] + progression[] + context → .grove v2
Load Preset ──→ detect version → v1: notes only; v2: notes + seq_store.SetProgression() + config.state.*
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/core/slots.lua` | Modify | Add `velocity=100, duration=4` to the entry table in lines 152-158 |
| `src/core/progression.lua` | Observe | No change needed — `Add()` accepts any table shape |
| `src/state/island.lua` | Modify | `ProgressionToNotes()` reads `entry.velocity` (fallback `velocity` param, fallback 100) and `entry.duration` (fallback `beats_per_slot`, fallback 4). `LoadNotesFromProgression()` unchanged — it delegates to `ProgressionToNotes()` |
| `src/ui/preset-browser.lua` | Modify | `SavePreset()`: add `version=2`, serialize `progression` + context fields if progression exists. `LoadPreset()`: detect version, restore progression + context on v2. New `RenamePreset()` function |
| `src/state/sequencer.lua` | Observe | No change — entries are tables, extra keys pass through |
| `src/ui/views.lua` | Observe | Info bar already reads `n.velocity` (line 761) — no change needed |
| `src/ui/piano-roll.lua` | Observe | Already renders provided velocity — no change needed |

## Interfaces / Contracts

```lua
-- Progression entry schema (extended)
-- {degree, root_index, scale_index, octave, chord_mode_index}
-- + optional: velocity (1-127, default 100), duration (beats, default 4)

-- ProgressionToNotes(progression, beats_per_slot?, velocity?) → table
--   Per-slot velocity overrides the `velocity` param, which overrides 100.
--   Per-slot duration overrides `beats_per_slot`, which defaults to 4.

-- .grove v2 format:
--   version: 2 (required)
--   notes: {pitch, start_beat, duration, velocity, muted}[] (required)
--   progression: slot-entry[16] (optional, nil for empty slots)
--   root_index: 1-12, scale_index: 1-21, octave: 0-8, chord_mode_index: 1-4

-- RenamePreset(file_path, current_name) → boolean
--   Shows reaper.GetUserInputs("Rename Preset", 1, "New name:", current_name)
--   Sanitizes: gsub("[^%w_%-%s]", "")
--   os.rename(old_file, new_dir.."\\"..new_name..".grove")
--   On success: ScanDirectory() + return true
--   On failure: SetBrowserError() + return false
```

## Migration / Rollout

**Backward compatibility table**:

| Scenario | Behavior |
|----------|----------|
| Old progression entry (no velocity/duration) | `entry.velocity` → nil → fallback to `velocity` param (100). `entry.duration` → nil → fallback to `beats_per_slot` (4). Works without changes. |
| v1 preset loaded | Loader sees no `version` field or `version=1` → reads notes only. Works unchanged. |
| v2 preset loaded by old code | Old `dofile` returns entire table — extra keys are silently ignored. Works. |
| Filesystem rename fails (locked file) | `os.rename` returns nil + err → `SetBrowserError("Could not rename preset")` → existing file untouched. |

## Open Questions

None.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `ProgressionToNotes` with mixed entries (some with velocity/duration, some without) | Pure function, no side effects. Assert note.velocity and note.duration match per-entry or fallback |
| Unit | v2 preset file read/write | Construct a v2 table, serialize+load, assert notes + progression + context round-trip |
| Unit | v1 backward compat | Load existing .grove file (no version field), assert notes loaded, no crash |
| Integration | Rename flow | Call RenamePreset, assert file renamed on disk, assert ScanDirectory sees new name |
