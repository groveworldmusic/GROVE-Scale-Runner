# Design — Piano Roll Professional — Fase 2 (Musicality & Groove)

**Change**: `piano-roll-pro-fase2`
**Project**: `grove-scale-runner`
**Status**: Design
**Date**: 2026-05-18

---

## 1. Technical Approach

### Feature-by-Feature Mapping

#### 1.1 Swing

The `quantize_swing` field already lives in `island_store` (line 62 of `src/state/island.lua`). The gap is that `quantize.lua`'s `QuantizeBeat()` never reads it.

**Approach**: Add a new exported function `QuantizeBeatWithSwing(beat, resolution, strength, triplet, swing)` that wraps `QuantizeBeat()` and applies the swing offset for off-beat subdivisions. The shortcut handler (`shortcuts.lua:HandleQuantize()`) will call this new function instead of `quantize.QuantizeNote()`, passing `island_store.GetQuantizeSwing()` as the extra argument.

Swing formula per spec:
```
offset = (swing / 100) * (grid_size / 2)
```
The off-beat detection is: a beat is an "off-beat" when `(beat / grid_size) % 2 >= 1` (i.e., the beat falls on the second half of a full beat pair — indices 1, 3, 5... within the grid). Implementation: `local is_offbeat = (math.floor(beat / grid_size) % 2) == 1`.

The UI control is a dropdown/slider in the piano roll header (`src/ui/midi-island/header.lua`), inserted after the QNTZ button (currently the rightmost control). The Swing UI reads/writes `island_store.quantize_swing` directly (0-50 range).

#### 1.2 Humanize

Implemented as a pure function `HumanizeNotes(notes, selected_indices, timing_range_pct, velocity_range)` in a new file `src/core/humanize.lua` (~30 LOC max).

The function iterates selected notes and applies per-note jitter:
```
timing_offset = (math.random() - 0.5) * (timing_range_pct / 100) * current_grid_size
new_beat = beat + timing_offset
new_vel = clamp(vel + (math.random() - 0.5) * velocity_range, 1, 127)
```

The `current_grid_size` is derived from the snap resolution (same formula as `QuantizeBeat`: `4 / effective_res`). This keeps the jitter amplitude proportional to the currently displayed grid, which is musically meaningful.

The `humanize.lua` module is **pure** — it takes a notes array and indices, mutates the notes, and returns nothing. No store reads. This decision keeps it testable without mocks.

The `humanize_strength` field (renamed from the spec's `timing_range`) is stored in `island_store`.

**Trigger**: Ctrl+H (char 336) added to `shortcuts.lua:HandleKeyboardShortcut()`.

#### 1.3 Velocity Improvements — Absolute Set + Context Menu

**Absolute set mode** is controlled by the Shift modifier key held during drag. Detected in `velocity.lua` via `(gfx.mouse_cap & 4) == 4` (REAPER's Shift flag).

When Shift is held during a velocity drag on a multi-selection, the drag target position computes an absolute value (not a delta), and all selected notes jump to that same value simultaneously.

**Context menu**: right-click on a velocity bar pops a simple REAPER native menu via `gfx.showmenu()` (not a custom dropdown widget). The menu items are: "Reset to 100" and "Normalize".

"Reset to 100" is a direct-set operation on all selected notes.
"Normalize" rescales selected note velocities so that min→1 and max→127 using linear interpolation:
```
scaled = 1 + (vel - min_vel) / (max_vel - min_vel) * 126
```

Both menu operations push a single velocity-type undo entry per the existing pattern.

#### 1.4 Arpeggiator

`GenerateArpeggio(notes, selected_indices, direction, speed_beats, pattern) → new_notes[]` — a pure function in a new file `src/ui/piano-roll/arpeggiator.lua`.

Algorithm:
1. Collect selected notes, sort by pitch ascending.
2. Walk sorted notes per `direction`:
   - `Up`: forward through sorted list, repeat.
   - `Down`: backward through sorted list, repeat.
   - `UpDown`: forward then backward, repeat (no duplicate at pivot).
   - `Random`: random index from sorted list each step.
3. Emit one arpeggiated note per step, with `start_beat = seed_beat + step * speed_beats`, `duration = speed_beats` for staccato or inherited for sustain.
4. Insert each generated note into `island_store` via `AddNote()` (which assigns UUIDs).

The generated notes are inserted within the `GenerateArpeggio` function itself, so the caller gets back UUIDs for undo tracking.

**Trigger**: `'A'` (char 65) in `shortcuts.lua:HandleKeyboardShortcut()`.

**Undo**: Single `"add"` type undo entry capturing all generated note UUIDs in `new_state`. Reversing undo removes them all via UUID-based lookup.

**Arpeggiator settings** (direction, speed, pattern) are NOT stored in `island_store` or persisted; they default per invocation. This is the simplest valid approach per the out-of-scope boundary (no global groove templates). A later phase can add settings storage if needed.

---

## 2. Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|--------------|-----------|
| **Swing math location** | Add `QuantizeBeatWithSwing()` in `core/quantize.lua`, called by shortcut handler | Add optional `swing` param to `QuantizeBeat()` itself | Keeps `QuantizeBeat()` signature clean (back-compat), new function clearly documents swing semantics. Swing breaks "pure function" purity because it reads store state — the wrapper bridges that gap. |
| **Humanize module placement** | New `src/core/humanize.lua` as pure function (~30 LOC) | Fold into `core/quantize.lua` | Separate file makes it independently testable. Quantize is ~45 LOC; humanize would push it to ~75 and mix concerns. |
| **Swing inside QuantizeNote** | Call `QuantizeBeatWithSwing` from `HandleQuantize` context | Refactor `QuantizeNote` to accept swing param | `QuantizeNote` is used in one place (HandleQuantize). The shortcut handler already unrolls the "read state → call quantize → push undo" pattern, so injecting swing there avoids threading the param through an unused generic function. |
| **Velocity absolute-set trigger** | Shift key held during drag (`gfx.mouse_cap & 4`) | Toggle button in velocity header | Shift is already the dominant paradigm in MIDI/DAW tools. A toggle button adds UI clutter for a marginal use case. The `gfx.mouse_cap` read is available to `velocity.lua` since it's called from `input.lua` which already reads it. Requires a parameter injection (add `shift_held` to `HandleVelocityMouse`). |
| **Context menu mechanism** | `gfx.showmenu()` native REAPER menu | Custom `dropdown.DrawDropdown()` widget | REAPER `showmenu` is simpler for a 2-item menu, no position math needed, natively handles DPI and context. |
| **Arpeggiator module** | New `src/ui/piano-roll/arpeggiator.lua` (pure function + `HandleArpeggiator` shortcut wrapper) | Add to `shortcuts.lua` inline | Generates ~30-100 notes per trigger — deserves its own module. Follows the split-migration pattern used for `handlers.lua`, `undo.lua`, `clipboard.lua`. |
| **Arpeggiator state persistence** | `humanize_strength` goes to `island_store`; arpeggiator has no persisted settings | Store arpeggiator settings in `island_store` | Spec's out-of-scope boundary explicitly excludes groove templates. A text label displaying current values is in-scope; storage is deferred. |

---

## 3. Data Flow

### 3.1 Swing

```
User drags Swing control (header.lua)
  │
  ▼
island_store.SetQuantizeSwing(v)          ← writes 0-50 to island_store.quantize_swing
  │
  ▼ (separate interaction, when quantizing)
user presses Ctrl+Q
  │
  ▼
shortcuts.HandleKeyboardShortcut(char=113)
  │
  ▼
HandleQuantize()
  ├── reads island_state.quantize_swing  ← swing value
  ├── reads snap_resolution, strength, triplet from island_store
  │
  ▼
new: quantize.QuantizeBeatWithSwing(beat, res, strength, triplet, swing)
  │     inside function:  calls QuantizeBeat for snapped position
  │     then:  if is_offbeat → adds (swing/100) * (grid_size/2) offset
  │
  ▼
note_data.start_beat updated  (in-place, per existing pattern)
  │
  ▼
note_store.PushUndo({type="quantize", ...})   ← single entry for all selected notes
```

ASCII — Note units:
```
Before:  C   E   G
         |   |   |
Beat:  1.0 2.0 3.0          (purely on-grid, no swing)

Ctrl+Q with swing=25:
Snapshot prev:{start=1.0}, {start=2.0}, {start=3.0}
QuantizeBeat: 1.0 → 1.0, 2.0 → 2.0, 3.0 → 3.0
Swing offset: 2.0 is off-beat → 2.0 + (0.25 * 0.125) = 2.03125

After:  C        E         G
         |        |         |
Beat:  1.0   2.03125    3.0
```

---

### 3.2 Humanize

```
User presses Ctrl+H (char 336)
  │
  ▼
shortcuts.HandleKeyboardShortcut(char)
  │
  ▼
new: shortcuts.HandleHumanize()
  │
  ├── reads island_store.GetNotes() / GetSelectedIndices()
  ├── reads island_store.GetQuantizeSwing() for grid_size (via snap resolution)
  ├── no-op if no selection
  │
  ▼
new: humanize.HumanizeNotes(notes, selected_indices, timing_range_pct, velocity_range)
  │     pure function: mutates notes array in-place
  │     no store reads inside humanize module
  │
  ▼
Snapshot for undo:
  prev_state: {start_beat, velocity} for all affected notes
  new_state: computed values post-humanize
  │
  ▼
note_store.PushUndo({type="humanize", note_uuids, prev_state, new_state})
```

ASCII — Humanize timing_range=10, velocity_range=20:
```
Before (grid_size = 0.0625):   C    E    G
                               |    |    |
Beat indices:              0.0  0.5  1.0

Humanize (random per note):  C    E    G
                         ↖+0.002 ↙+0.001   (per-note random beat offset)
                              vel 98   vel 102    (random ±10 velocity)

Beat indices:              0.001  0.499  1.002
```

---

### 3.3 Velocity Absolute Set + Context Menu

```
Velocity drag in expanded header.lua → input.lua HandleMouse
  │
  ▼
gfx.mouse_cap & 4  →  shift_held = true/false
  │
  ▼
velocity.HandleVelocityMouse(mx, my, ..., shift_held)
  │
  ├── [RELATIVE mode, shift=false]
  │     drag_initial_vel = v0
  │     per-frame: notes[idx].velocity = base + (new_vel - v0)
  │     (existing logic, now parameterized by shift_held)
  │
  ├── [ABSOLUTE mode, shift=true]
  │     per-frame: notes[idx].velocity = new_vel  ← exact pixel→velocity value
  │     all selected notes set to same new_vel
  │
  ▼ (on mouse_up / release drag in velocity.lua)
  PushUndo({type="velocity", uuids, prev_state, new_state})  ← same as existing

RIGHT-CLICK context menu (on velocity bar)
  │
  ▼
gfx.showmenu("Reset to 100|Normalize")
  │
  ├── Reset: notes[sel].velocity = 100  (all selected)
  ├── Normalize: min→1, max→127, linear scale (all selected)
  │
  ▼
PushUndo({type="velocity", uuids, prev_state, new_state})
```

---

### 3.4 Arpeggiator

```
User presses 'A' (char 65)
  │
  ▼
HandleKeyboardShortcut(char=65)
  │
  ▼
shortcuts.HandleArpeggiator()
  │
  ├── reads island_store.GetNotes() / GetSelectedIndices()
  ├── no-op if no selection
  ├── reads default direction=Up, speed=1/16 (0.0625), pattern=Staccato
  │
  ▼
arpeggiator.GenerateArpeggio(notes, selected_indices, direction, speed_beats, pattern)
  │     sorts selected by pitch ascending
  │     walking order = {C4, E4, G4} for Up; {G4, E4, C4} for Down
  │     step = direction WALK * speed_beats from first_selected_note.start_beat
  │     for each step: island_store.AddNote(new_note)  ← assigns UUID
  │
  ▼
Snapshot all generated UUIDs in prev_state (nil for "add" type) + new_state
  │
  ▼
note_store.PushUndo({type="add", note_uuids=generated_uuids,
                     new_state=new_note_tables})
  │
  ▼ (Ctrl+Z)
undo.RestoreUndo(entry.type="add")
  → finds all UUIDs in generated_uuids → removes them via island_store.RemoveNoteAtIndex
```

ASCII — Arp Up 1/16 from C Major (C4,E4,G4 at beat 1.0):
```
Selected notes at beat 1.0:
  C4 E4 G4         ← original chord (left untouched)

→ GenerateArpeggio: sort [C4,E4,G4], step×1/16 on Up

New notes inserted after:
  C4   E4   G4    ← chord
  C4   E4   G4    ← arp step 0 (C4 = seed)
      E4           ← arp step 1 (+0.0625)
           G4      ← arp step 2 (+0.125)

Note positions at beat 1.0625/1.125/1.1875 with DEFAULT_STACCATO_DUR = grid_size = 0.0625
```

---

## 4. File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/core/quantize.lua` | **Modify** | Add exported `QuantizeBeatWithSwing(beat, resolution, strength, triplet, swing)` — wraps `QuantizeBeat` with off-beat swing offset. No change to existing `QuantizeBeat` / `QuantizeNote` signatures. |
| `src/core/humanize.lua` | **New** (~30 LOC) | Pure function module: `HumanizeNotes(notes, selected_indices, timing_range_pct, velocity_range)`. No store dependencies. Mutates notes array in-place. |
| `src/state/island.lua` | **Modify** | Add `humanize_strength` field (default 10, range 1-50), getter `GetHumanizeStrength()`, setter `SetHumanizeStrength(v)`. Field sits next to `quantize_swing` block (line 62 area). |
| `src/ui/midi-island/header.lua` | **Modify** | Add Swing control in the Tools row (after the QNTZ button, in `DrawHeader`). Dropdown showing 0-50%, calling `island_store.SetQuantizeSwing(value)`. ~15 LOC addition. |
| `src/ui/velocity.lua` | **Modify** | 1. Add `shift_held` param to `HandleVelocityMouse` signature. 2. In drag logic: when `shift_held=true`, apply absolute velocity (set, not delta) to all selected notes. 3. After collapse/expand region, add right-click context menu for velocity bars — "Reset to 100" and "Normalize". |
| `src/ui/piano-roll/interaction/shortcuts.lua` | **Modify** | 1. In `HandleQuantize`, pass `island_store.GetQuantizeSwing()` → call `quantize.QuantizeBeatWithSwing`. 2. Add Ctrl+H handler (char 336) → call new `HandleHumanize`. 3. Add char 65 (`'A'`) handler → call new `HandleArpeggiator`. |
| `src/ui/piano-roll/humanize.lua` | **New** (~35 LOC) | Wrapper that reads island_store selection and swing, calls `humanize.HumanizeNotes`, and pushes undo entry type `"humanize"`. Exports `HandleHumanize()`. |
| `src/ui/piano-roll/arpeggiator.lua` | **New** (~50 LOC) | `GenerateArpeggio(notes, selected_indices, direction, speed_beats, pattern) → {generated_uuids, new_notes}`. Exports `HandleArpeggiator()`. Settings default inline (Up, Staccato, 1/16). |
| `src/ui/piano-roll/undo.lua` | **Modify** | Add `"humanize"` type handler in `RestoreUndo` and `RestoreRedo`. Uses `prev_state` to restore start_beat and velocity from the undo entry. |
| `src/ui/piano-roll.lua` | **Modify** | Re-export `HandleHumanize` from `shortcuts.lua` and `HandleArpeggiator` from `arpeggiator.lua`. |
| `src/ui/piano-roll/interaction.lua` | **Modify** | Re-export `HandleHumanize` and `HandleArpeggiator` from the shortcut/arpeggiator modules. |

---

## 5. Interfaces / Contracts

### Core

#### `core/quantize.lua` — New function

```lua
--- Quantize a beat with swing applied to off-beat subdivisions.
--- @param beat number The beat to quantize
--- @param resolution number Grid resolution (1, 2, 4, 8, 16, 32)
--- @param strength number 0-100 percentage
--- @param triplet boolean|nil Use triplet grid
--- @param swing number 0-50 (swing percentage)
--- @return number Quantized beat with swing offset appended
function QuantizeBeatWithSwing(beat, resolution, strength, triplet, swing) → number
```

Swing math:
```
grid_size = 4 / (triplet ? res * 1.5 : res)
nearest = floor(beat / grid_size + 0.5) * grid_size
result = beat + (nearest - beat) * (strength / 100)          ← partial strength
if is_offbeat then
    result = nearest + (swing / 100) * (grid_size / 2)       ← swing force
end
```

`is_offbeat = (math.floor(beat / grid_size) % 2) == 1` — true for the 2nd/4th/6th subdivision within a whole-note grid cell.

#### `core/humanize.lua` — New module

```lua
--- Apply humanization jitter to selected notes in-place.
--- @param notes table Notes array (mutated in-place)
--- @param selected_indices table {[idx]=true} set of note indices to humanize
--- @param timing_range_pct number 1-50 (% of current grid size per note)
--- @param velocity_range number 1-127 (abs velocity delta per note)
function HumanizeNotes(notes, selected_indices, timing_range_pct, velocity_range) → void
```

Returns nothing. Notes array mutated in-place. `current_grid_size` computed from `4 / snap_resolution` (caller passes the snap resolution and triplet flag — see `HandleHumanize` wrapper below).

### UI

#### `src/state/island.lua` — New getter/setter

```lua
function m.GetHumanizeStrength() return island_state.humanize_strength end   -- default 10
function m.SetHumanizeStrength(v) island_state.humanize_strength = v or 10 end  -- clamped 1-50
```

#### `src/ui/piano-roll/humanize.lua` — New module

```lua
--- Read store state, call HumanizeNotes, push undo.
--- Shortcut wrapper — called from shortcuts.HandleKeyboardShortcut (Ctrl+H).
function HandleHumanize() → void
```

Reads:
- `notes = island_store.GetNotes()`
- `selected = island_store.GetSelectedIndices()`
- `timing_range = island_store.GetHumanizeStrength()`  (pct of grid)
- `velocity_range = 20` (hardcoded per spec) or could be store value later
- Snap resolution from `island_store` to derive grid_size

Pushes: `{type="humanize", note_uuids=..., prev_state={start_beat,vel}, new_state={start_beat,vel}}`

#### `src/ui/piano-roll/arpeggiator.lua` — New module

```lua
--- Generate arpeggiated notes from a chord selection and insert them.
--- @param notes table Notes array (island_store.GetNotes())
--- @param selected_indices table {[idx]=true} selected note indices
--- @param direction string "Up"|"Down"|"UpDown"|"Random"  (default "Up")
--- @param speed_beats number Beats per arpeggio step (default 0.0625 = 1/16)
--- @param pattern string "Staccato"|"Sustain"  (default "Staccato")
--- @return generated_uuids, new_notes  (for undo entry)
function GenerateArpeggio(notes, selected_indices, direction, speed_beats, pattern) → table, table
```

Settings are NOT stored in island_store — defaults inline in `HandleArpeggiator`.

#### `src/ui/velocity.lua` — Modified signature

```lua
-- HandleVelocityMouse signature now includes shift_held
function velocity.HandleVelocityMouse(mx, my, grid_x, ed_y, ed_h,
                                      scroll_x, zoom_x, click, mouse_down,
                                      shift_held)   ← new param, appended
```

Caller (`input.lua`) passes `(gfx.mouse_cap & 4) == 4` for the `shift_held` argument.

Internal change — `ApplyVelocity` splits on `shift_held`:
```lua
if shift_held and sel_count > 1 then
    -- ABSOLUTE SET MODE (shift-drag)
    for sel_idx in pairs(selected) do
        if notes[sel_idx] then notes[sel_idx].velocity = new_vel end
    end
else
    -- RELATIVE DRAG (existing behavior, now parameterized)
    -- ... existing delta logic ...
end
```

Context menu on velocity bar right-click:
```
gfx.showmenu("Reset to 100|Normalize")
```
Action `"Reset to 100"`:
```lua
for idx in pairs(selected) do notes[idx].velocity = 100 end
PushUndo({type="velocity", uuids, prev_state={v_i}, new_state={100,...}})
```
Action `"Normalize"`:
```lua
min_v, max_v = scan selected notes
if min_v == max_v then return end  -- no-op when all equal
for idx in pairs(selected) do
    normalized = 1 + (v - min_v) / (max_v - min_v) * 126
    notes[idx].velocity = math.floor(normalized + 0.5)
end
PushUndo({type="velocity", ...})
```

Right-click detection in velocity area: right button down (`gfx.mouse_cap & 2 == 2` and `last_cap & 2 == 0`) in the expanded velocity editor area → show context menu on release.

---

## 6. Testing Strategy

### Strategy summary

This project uses a custom test runner (see `tests/AGENTS.md`). Tests register themselves to the runner and assertions call `check(...)`. The existing runner covers 497 assertions across 14 test files.

| Layer | What to test | How |
|-------|-------------|-----|
| **Unit (core)** | `quantize.QuantizeBeatWithSwing` | Add to `src/tests/test_quantize.lua` or create `test_swing.lua`: test 0% swing (identity), 50% swing max-shift, off-beat vs on-beat distinction, partial strength interaction |
| **Unit (core)** | `humanize.HumanizeNotes` | New test `src/tests/test_humanize.lua`: no-op empty selection, jitter bounds (timing ±timing_range_pct, velocity ±velocity_range), clamped velocities [1,127], UUID uniqueness |
| **Unit (core)** | `arpeggiator.GenerateArpeggio` | New test `src/tests/test_arpeggiator.lua`: Up generates N notes in ascending pitch order, Down reverses, UpDown checks no pivot duplicate, Random verifies all pitches from source, Staccato duration = speed_beats, Sustain duration = original |
| **Integration (ui)** | Full quantization chain | In `test_types.lua` or `test_quantize.lua`: create notes, set `quantize_swing=30`, call `HandleQuantize()`, verify note start_beat has swung off-beats |
| **Integration (ui)** | Ctrl+H no-op empty selection | Integration test: call `HandleHumanize()` with empty `selected_indices`; verify no notes changed, no crash |
| **Manual/verify** | Shift-drag in velocity panel | Run-time: viewer holds Shift on velocity editor multi-select drag; verify bars jump synchronously vs spreading |
| **Manual/verify** | Velocity context menu | Run-time: right-click velocity bar, "Reset to 100" sets all selected to 100, "Normalize" spreads [1..127] |

Because `scenario.lua` tests load `assets/scenarios/` fixtures, humanize/arpeggio scenarios can be added as new fixture files once the test runner supports scenario-level fixtures.

---

## 7. Open Questions

**None.** All four features have unambiguous data paths and clear file-level ownership. The only subtlety noted:

- ~~Whether `quantize_swing` interacts with `snap_triplet` at the grid math level~~: clarifed in Decision table — `QuantizeBeatWithSwing` uses the same `effective_res` as `QuantizeBeat`, so triplet mode routes correctly (`resolution * 1.5`). Swing offset is applied on top of that already-correct grid_size.
- Velocity `shift_held` detection in `velocity.lua` requires the param to be threaded from `input.lua` → `HandleVelocityMouse` → `ApplyVelocity`. Caller ownership is clear: `input.lua` line 28 already captures `gfx.mouse_cap` every frame.
- Whether the Swing header control should be a dropdown (values 0, 5, 10…50) instead of a slider: the proposal says "slider/dropdown". Header space is constrained — a dropdown with 11 items (0-50%) is unambiguous first, slider can be a later refinement.
