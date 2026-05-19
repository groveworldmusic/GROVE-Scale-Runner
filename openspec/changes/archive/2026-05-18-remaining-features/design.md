# Design: Remaining Features

## Technical Approach

Five sequential phases (A→B→C→D→E), each as a chained PR. A+B share progression domain; C+D independent (share only store/preference infra); E tests late-bound code and must be last. All changes affect the **main GFX window** (midi-island context). No compact panel changes.

## Architecture Decisions

### A1: Swap Composite Wrap

| Option | Tradeoffs | Decision |
|--------|-----------|----------|
| Wrap in `ProgBeginComposite()`/`EndComposite()` | Need new functions in seq_store; clean but more surface | ❌ Rejected |
| Manual gate + snapshot in Swap() | Uses existing `SetProgUndoGate` directly; 6 LOC | ✅ **Chosen** |

Call `ProgSnapshot()` + `PushProgUndo()` before gate opens, `SetProgUndoGate(true)` during swaps, `false` after. No new functions needed.

### A2: Progression Focus Detection

| Option | Tradeoffs | Decision |
|--------|-----------|----------|
| Pass `progression_focused` bool from midi-island.lua | Computes bounds before Draw; decouples input.lua from layout | ✅ **Chosen** |
| Compute inside HandleKeyboard() | Input module needs layout constants; duplication | ❌ Rejected |

midi-island.lua computes mouse-in-grid check before calling `input.HandleKeyboard()`.

### B1: Load Branching by `type` field

| Option | Tradeoffs | Decision |
|--------|-----------|----------|
| Version-based branching (v3 = progression) | `.grove-prog` implies type=progression already; version is redundancy | ❌ Rejected |
| Type-field branching with `.grove-prog` extension detection | Deterministic at file-discovery time; no version ambiguity | ✅ **Chosen** |

`io.lua` checks `result.type == "progression"` OR filename ends in `.grove-prog` to dispatch Load branch.

### B2: Filter Tab State

| Option | Tradeoffs | Decision |
|--------|-----------|----------|
| Store filter in preset_store | Preserve across reloads; more state surface | ❌ Rejected |
| Module-local variable | Zero surface; reset on script reload (desired) | ✅ **Chosen** |

`main.lua` uses `_type_filter` (local, values: "all", "notes", "progression"). Default "all".

### C1: Vkey-map Store Architecture

| Option | Tradeoffs | Decision |
|--------|-----------|----------|
| Full state store with Init/Get/Set | Heavy; vkey_map is a single map not a store domain | ❌ Rejected |
| Module with local closure + JSON serialization | Simple, follows API pattern, no Init needed | ✅ **Chosen** |

`vkey-map.lua` exports `GetVkeyMap()`, `SetEntry()`, `ResetToDefaults()`. Internal `_map` is deep copy of `config.VKEY_MAP`. `_modified` flag tracks dirtiness.

### C2: Remap Modal Overlay

| Option | Tradeoffs | Decision |
|--------|-----------|----------|
| New sub-module `midi-island/remap.lua` | Clean separation; keeps header.lua focused | ✅ **Chosen** |
| Inline in header.lua | Header already 291 LOC; would bloat further | ❌ Rejected |

New `src/ui/midi-island/remap.lua` — renders 4×7 grid, handles cell click + degree/octave selection dropdown, conflict detection via `reaper.MB`.

### C3+D: Header Overflow Mitigation

| Option | Tradeoffs | Decision |
|--------|-----------|----------|
| Reduce icon_btn_w from 0.6× to 0.5× | Saves 0.1× per icon × 5 icons = 0.5× total | ✅ **Chosen (partial)** |
| Reduce ps_btn_w from 1.0× to 0.8× | Already trimmed from 1.2×; further impact on label | ❌ Rejected |
| Record button at 0.4× (smaller) | It's just a red circle + glow icon | ✅ **Chosen** |

Implement: icon_btn_w stays 0.6× for gear (full interactive button), record is `math.floor(b_w * 0.4)` circle-only. If still tight, the 6px main_gap can be trimmed to 4px.

### D1: MIDI Input Polling Integration

| Option | Tradeoffs | Decision |
|--------|-----------|----------|
| Poll every frame unconditionally | ~60fps MIDI_GetRecentInputEvent is cheap; armed check is local | ❌ Rejected (wasteful) |
| **Poll only when armed** | if `_armed` check is cheap; body runs only when recording | ✅ **Chosen** |

MainLoop calls `midi_input.Poll()` only `if midi_input.IsArmed()`. `_open_notes` is a local table: `{[pitch] = {start_beat, velocity}}`.

## Data Flow

```
Phase A:  midi-island.lua ──► input.HandleKeyboard(char, is_prog_focused)
                               ├── Ctrl+Z → seq_store.HandleProgUndo()
                               └── Ctrl+Y → seq_store.HandleProgRedo()

          progression.Swap(a,b) → snapshot + gate → 2× SetProgressionEntry → gate off
          note_store.SyncNotesToProgression() → PushProgUndo(ProgSnapshot()) → ...mutations

Phase B:  SaveProgressionPreset(name, dir) → serialize only progression[1..16] + ctx → .grove-prog
          LoadPreset(path) ──► type check ──► type="progression" → ClearProgressionUndoStacks + restore
                                              else → existing v2 logic

Phase C:  header gear button ──► toggle remap.lua overlay ──► SetEntry(vk, deg, oct) ──► vkey-map._map
          keyboard.HandleKeyboard() ──► vkey_map.GetVkeyMap() ──► map.deg, map.oct
          persist.Load ──► vkey_map_raw JSON string ──► vkey-map._map

Phase D:  midi_input.Poll() ──► MIDI_GetRecentInputEvent ──► note-on → AddNote(origin="midi-input")
                              ──► note-off → UpdateOpenNoteDuration(pitch, dur)
                              ──► 5s timeout → auto-close in _open_notes

Phase E:  tests/test_*.lua ──► helpers.check() ──► runner coverage
```

## File Changes

| File | Action | Phase | LOC | Description |
|------|--------|-------|-----|-------------|
| `src/core/progression.lua` | Modify | A | +6 | Wrap Swap in undo gate + manual snapshot |
| `src/ui/midi-island.lua` | Modify | A | +8 | Compute `progression_focused` flag, pass to input.HandleKeyboard |
| `src/ui/midi-island/input.lua` | Modify | A | +18 | Ctrl+Z/Y dispatch before piano-roll shortcuts |
| `src/state/note-store.lua` | Modify | A,D | +10 | Add ProgPushUndo in SyncNotesToProgression (A) + UpdateOpenNoteDuration (D) |
| `src/ui/preset-browser/io.lua` | Modify | B | +65 | Dual-ext, SaveProgressionPreset, Load branching |
| `src/ui/preset-browser/main.lua` | Modify | B | +55 | Filter tabs, Save Progression button |
| `src/ui/preset-browser/preset-list.lua` | Modify | B | +12 | type_filter param, type badge |
| `src/ui/preset-browser.lua` | Modify | B | +1 | Re-export SaveProgressionPreset |
| `src/core/vkey-map.lua` | **Create** | C | +80 | GetVkeyMap, SetEntry, ResetToDefaults, serialization |
| `src/core/keyboard.lua` | Modify | C | +6 | Replace config.VKEY_MAP → vkey_map.GetVkeyMap() |
| `src/ui/pads.lua` | Modify | C | +1 | Same VKEY_MAP replacement |
| `src/state/preferences.lua` | Modify | C | +4 | Add vkey_map_raw, vkey_map_modified keys |
| `src/state/persist.lua` | Modify | C | +1 | Add vkey_map_raw to PREF_KEYS |
| `src/config.lua` | Modify | C | +2 | Add vkey_map_raw to config.state |
| `src/ui/midi-island/remap.lua` | **Create** | C | +195 | 4×7 grid overlay, cell click, conflict detection |
| `src/ui/midi-island/header.lua` | Modify | C,D | +40 | Gear button (C), record toggle (D) |
| `src/core/midi-input.lua` | **Create** | D | +110 | Poll, SetArmed, GetArmed, Cleanup, _open_notes |
| `src/main.lua` | Modify | D | +12 | Require + Poll + Cleanup wiring |
| `tests/test_piano_roll_grid.lua` | **Create** | E | +80 | Snap pure functions, grid calc |
| `tests/test_preset_browser_io.lua` | **Create** | E | +70 | I/O with mock filesystem |
| `tests/test_piano_roll_drag.lua` | **Create** | E | +80 | Edge detection, drag threshold |
| `tests/run.lua` | Modify | E | +3 | Register new test files |

## Interfaces / Contracts

```lua
-- src/core/vkey-map.lua
-- Returns reference to internal vkey map (deep copy of config.VKEY_MAP at load)
vkey_map.GetVkeyMap() → table  -- {[vk_code] = {deg=1..7, oct=-2..1}}
-- Set a single key mapping. Returns true on success, false if overwriting a key
-- with the same deg+oct as another key (caller controls conflict handling).
vkey_map.SetEntry(vk_code, deg, oct) → boolean (conflict_detected)
-- Restore all 28 keys to config.VKEY_MAP defaults. Also resets _modified flag.
vkey_map.ResetToDefaults() → void
-- Serialization: returns JSON string of current _map for ExtState persistence.
vkey_map.Serialize() → string
-- Deserialize: overwrites _map from a JSON string. Used after persist.Load.
vkey_map.Deserialize(json_str) → void
-- Returns true if user has deviated from defaults (for UI hinting).
vkey_map.IsModified() → boolean

-- src/core/midi-input.lua
midi_input.SetArmed(state) → void  -- true = record arm, false = disarm (flushes open notes)
midi_input.IsArmed() → boolean
midi_input.Poll() → void  -- called from MainLoop, no-op if not armed
midi_input.Cleanup() → void  -- finalizes all open notes, called from CleanupAll

-- src/state/note-store.lua additions
note_store.UpdateOpenNoteDuration(pitch, duration) → void
  -- Finds most recent origin="midi-input" note at pitch, updates duration.

-- src/ui/preset-browser/io.lua additions
io.SaveProgressionPreset(dir, name) → boolean
  -- Serializes progression[1..16] + context to .grove-prog (type="progression", version=3)
```

## Testing Strategy

| Layer | Phase | What to Test | Approach |
|-------|-------|-------------|----------|
| Unit | A | Swap composite: undo stack depth +1, correct restore | seq_store mock, check stack |
| Unit | A | Ctrl+Z dispatch calls HandleProgUndo when focused | Mock seq_store, check call |
| Unit | A | Ctrl+Z falls through when NOT focused | Mock both stores, check no prog call |
| Unit | B | SaveProgressionPreset serializes correct format | Capture file content via mock io |
| Unit | B | LoadPreset branching: type="progression" skips SetNotes | Mock note_store, check no SetNotes call |
| Unit | B | LoadPreset branching: type="notes" unchanged (v2) | Existing behavior asserted |
| Unit | C | GetVkeyMap returns deep copy, not same ref as config | Check not `rawequal` to config.VKEY_MAP |
| Unit | C | SetEntry updates map, SetEntry conflict detection returns true | Call SetEntry twice same deg+oct |
| Unit | C | ResetToDefaults restores all 28 keys | Mutate, reset, verify against config |
| Unit | C | Serialize/Deserialize round-trip | Serialize, mutate, Deserialize, verify |
| Unit | D | UpdateOpenNoteDuration sets correct duration | Add note with origin, call, check value |
| Unit | D | 5s timeout auto-closes open note | Advance time_precise, check note finalized |
| Unit | E | SnapBeat grid pure functions | Test all resolutions, triplets, edges |
| Unit | E | Preset I/O with mock filesystem | Mock io.open, test read/write paths |
| Unit | E | Drag edge detection (8px threshold) | Compute distances, test under/over threshold |

## Migration / Rollout

No data migration needed. `.grove-prog` files are new format — no existing files to upgrade. Vkey-map config is created on first script load from `config.VKEY_MAP` default, so no migration. Phases revert independently via per-PR revert.

## Open Questions

- None — all technical questions resolved by exploration and spec documents.
