# Design: Isla de Inversión + Subdivisión de Slots

## Technical Approach

Two sequential phases delivered as chained PRs (A + B). Phase 1 adds a global inversion voicing via `midi.InvertChord()` + 4-button island. Phase 2 rewrites `sequencer.Run()` for sub-beat stepping, stores multi-chord per slot, and adds subdivision grid lines. Backward compat via nil check on new fields.

## Architecture Decisions

### Decision: Global Inversion

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Per-slot | Flexible, but complex data model + UI, OOS | ❌ Deferred |
| Global | Matches `chord_mode_index` pattern, trivial TriggerChord integration | ✅ Chosen |

Stored in `sequencer_store` (like volume, is_playing), read by `midi.TriggerChord()` directly — NOT via ctx/slot.

### Decision: InvertChord Algorithm

| Option | Behavior | Decision |
|--------|----------|----------|
| Move bottom N up octave | Musically correct 1st/2nd/3rd inversion, notes stay sorted | ✅ Chosen |
| Reorder pitch array | Changes note order but not voicing — wrong | ❌ |

```lua
function midi.InvertChord(notes, inv_level)
  if inv_level <= 0 or inv_level >= #notes then return notes end
  local r = {}
  for i = inv_level + 1, #notes do r[#r+1] = notes[i] end
  for i = 1, inv_level do r[#r+1] = notes[i] + 12 end
  return r
end
```

Cap: `min(inv_level, #offsets - 1)` en TriggerChord.

### Decision: Subdivision Data Model

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `subs[]` array per slot | Clean backward compat (nil=1/1), self-contained | ✅ Chosen |
| Spawn N separate entries | Fragment progression indices, complex pagination | ❌ |

Slot entry gains optional `subs = {{degree=N, velocity=O}, ...}`. Backward compat: nil triggers legacy single-chord path.

### Decision: Sequencer Loop Rewrite

| Approach | How | Decision |
|----------|-----|----------|
| Sub-step tracking | `current_sub_step` + `progress * sub_count` → detect boundary crosses same-frame | ✅ Chosen |
| Separate RunSubTick | More code, harder to maintain | ❌ |

`Run()` now checks sub-step boundaries within same measure via `floor(progress * sub_count)`. At 1/1, sub_count=1 → never fires.

### Decision: Progress Circles

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Reuse paginator dots | Shared visual language, easy impl | ✅ Chosen |
| Custom progress bar | More code, doesn't show count | ❌ |

Dots at slot bottom: N circles (N=subdivision count), filled = active sub-step, outline = inactive.

### Decision: Grid Subdivisions

| Layer | Existing | Added |
|-------|----------|-------|
| Beat strong | Every 4 beats | Unchanged |
| Beat weak | Every beat | Unchanged |
| Sub-beat | — | Even thinner lines at sub-division boundaries (only when subdivision > 1/1) |

Timeline: sub-beat ticks at 2px height (vs 8px for beat, 16px for measure).

### Decision: Island Placement for Inversion

| Option | Tradeoff | Decision |
|--------|----------|----------|
| New island between Chord & Cmd | No horizontal room (450 UX gap ≈ 5.6px) | ❌ |
| Inside Chord island (row below) | Musically logical, compact 4-small-btn row | ✅ Chosen |

4 small buttons (Base / 1st / 2nd / 3rd) below CHORD buttons in Island 3. Uses existing island height. Buttons at ~60% height of chord buttons.

## Data Flow

```
TriggerChord(degree, on, ctx, vel)
  │
  ├─► Generate pitches from CHORD_MODES[chord_mode_index].offsets
  │
  ├─► sequencer_store.GetInversionIndex() → inv_idx
  │     if inv_idx > 1 → midi.InvertChord(notes, inv_level)
  │
  └─► SendMidi() for each pitch

Sequencer.Run() per tick (Phase 2):
  │
  ├─► measures = sync/clock
  ├─► cur_m = floor(measures), progress = measures % 1
  │
  ├─► if cur_m != last_measure:
  │     ├─ note-off prev
  │     ├─ current_sub_step = 0
  │     ├─ TriggerChord(slot.subs[0] or slot.degree)
  │     └─ last_measure = cur_m
  │
  └─► else:
        ├─ sub_count = SUBDIVISION_COUNT[subdivision_index]
        ├─ target = floor(progress * sub_count)
        └─ if target != current_sub_step:
              ├─ note-off prev
              ├─ current_sub_step = target
              └─ TriggerChord(slot.subs[target])
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/config.lua` | Modify | Add `INVERSION_MODES` + `SUBDIVISION_MODES` constants |
| `src/state/sequencer.lua` | Modify | Add `inversion_index`, `subdivision_index`, `current_sub_step` fields + getters/setters |
| `src/core/midi.lua` | Modify | Add `InvertChord()`, modify `TriggerChord()` for inversion |
| `src/core/keyboard.lua` | Modify | Pass inversion to temp_ctx (or TriggerChord reads global) |
| `src/core/sequencer.lua` | Modify | Add sub-step tracking in `Run()`, backward compat |
| `src/core/slots.lua` | Modify | Drag-to-slot fills `subs[]` when subdivision > 1. Progress circles in DrawSlotBackground |
| `src/core/progression.lua` | Modify | Add `/` helper for subdivided slots |
| `src/ui/views.lua` | Modify | Inversion island (4 buttons in Island 3), subdivision dropdown in Command Stack |
| `src/ui/piano-roll.lua` | Modify | Subdivision grid lines |
| `src/ui/timeline.lua` | Modify | Subdivision beat ticks |
| `src/state/island.lua` | Modify | `ProgressionToNotes()` subdivision-aware |
| `src/main.lua` | Modify | Init handles new store fields (no config.state changes needed) |

## Interfaces / Contracts

```lua
-- New constants
config.INVERSION_MODES = {{name="Base"},{name="1st"},{name="2nd"},{name="3rd"}}
config.SUBDIVISION_MODES = {{name="1/1",c=1},{name="1/2",c=2},{name="1/3",c=3},
                            {name="1/4",c=4},{name="1/8",c=8},{name="1/16",c=16}}

-- Store additions
sequencer_store.GetInversionIndex() → 1..4
sequencer_store.GetSubdivisionIndex() → 1..6
sequencer_store.GetSubdivisionCount() → number (cached from SUBDIVISION_MODES[idx])
sequencer_store.GetCurrentSubStep() → 0..15
-- Setters: SetInversionIndex, SetSubdivisionIndex, SetCurrentSubStep

-- Slot entry schema (extended)
entry = {
  degree = number,
  root_index = number, scale_index = number, octave = number,
  chord_mode_index = number, velocity = number?, duration = number?,
  subs = nil | {{degree=N, velocity=O?}, ...}  -- new optional
}

-- midi.InvertChord(notes, inv_level) → number[]
-- Pure. inv_level=0 → root position, 1 → 1st inv, etc.
```

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Unit | InvertChord() pure function | Manual assertion (no test runner — per project standards) |
| Integration | TriggerChord + inversion | Verify MIDI note order and pitch output with different inv_idx |
| Integration | Sequencer sub-step | Verify note-off/note-on on sub-beat boundaries |
| E2E | UI island rendering | Visual inspection — new buttons render and respond to click |

## Migration / Rollout

No migration needed. New fields default to 1 (Base / 1/1). Old progression entries lack `subs` field → single-chord legacy path. Chained PRs: **PR-A** = Phase 1 (inversion) + Phase 2 data model + sequencer rewrite. **PR-B** = Phase 2 UI (grid lines, circles, dropdown).

## Open Questions

- [ ] Inversion island: exact button height ratio vs chord buttons (60%? 50%?)
- [ ] Subdivision dropdown: in Command Stack or Chord island?
- [ ] keyboard.lua: does `HandleKeyboard()` need to pass inversion to TriggerChord? (Yes — TriggerChord reads `sequencer_store.GetInversionIndex()` globally, so keyboard doesn't need changes)
