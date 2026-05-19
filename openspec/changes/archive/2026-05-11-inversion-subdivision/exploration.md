# Exploration: Inversion Island + Slot Subdivisions

## 1. Current State

### Chord Generation (no inversion concept exists)
The chord system in `core/midi.lua` works via `TriggerChord()`:
- Reads `config.CHORD_MODES` offsets (e.g., Tri = `{0, 2, 4}`, 7ma = `{0, 2, 4, 6}`)
- Each offset is added to the scale degree, then `midi.GetMidiNote()` computes the MIDI pitch
- Chords are stacked in the SAME octave — notes are on the same octave, no voicing/inversion logic
- The offsets are SEMITONE intervals from the root, not scale-degree voicings

**There is ZERO existing inversion concept**. The grep for "inversion" only found comments about "inverted Y" in piano-roll coordinate systems.

### Slot Data Model
Each progression slot entry (`sequencer.progression[i]`) is:
```lua
{
    degree = number,           -- 1-7 scale degree
    root_index = number,       -- 1-12 (index into NOTE_NAMES)
    scale_index = number,      -- 1-21 (index into SCALES)
    octave = number,           -- 0-8
    chord_mode_index = number, -- 1-4 (Off/Tri/7ma/9na)
    velocity = number|nil,     -- optional, defaults to 100 (ALREADY EXISTS)
    duration = number,         -- beats, currently always 4 (ALREADY EXISTS)
}
```

**CRITICAL FINDING**: Both `velocity` and `duration` already exist in the slot entry! `duration=4` is set at `core/slots.lua:166`. The `island_store.ProgressionToNotes()` function already accepts a `beats_per_slot` parameter (default 4) and reads `entry.duration`.

### Sequencer Playback
`core/sequencer.lua` `Run()` is designed for ONE chord per measure (4 beats):
- Advances ONLY on measure boundaries (`cur_m ~= seq_store.GetLastMeasure()`)
- Each step = 1 measure = 4 beats
- Progress is `0..1` per measure
- Step = `(cur_m % loop) + 1`
- No sub-beat stepping exists

### Islands UI Pattern
Islands are drawn in `views.lua:DrawIslands()`:
- 4 fixed islands: Scale & Piano, Octava, Chord, Command Stack
- The MIDI island is a toggle (not a fixed island) — `midi.ToggleIsland()` changes window height
- Each island uses `components.DrawIsland()` for background frame
- Islands contain buttons, dropdowns, sliders, piano keyboard
- The Command Stack has the MIDI toggle button (line 314-329)

### Piano Roll Grid
`piano-roll.lua` `DrawPianoRollGrid()`:
- Strong lines every 4 beats (`beat % 4 == 0`)
- Weak lines for non-measure beats (`(beat % 4) ~= 0`)
- No subdivision grid lines exist

### Timeline
`timeline.lua` `DrawBeatTicks()`:
- Measure ticks every 4 beats
- Beat ticks for individual beats
- Playback head position from `island_store.GetPlaybackPos()`

### Export
`midi.ExportToMidi()`:
- Hardcodes 4 beats per slot (`q0 + (i-1)*4`, `q0+4`)
- Each slot = 1 chord = 4 quarter notes

---

## 2. Affected Areas

| File | Why affected |
|------|-------------|
| `src/config.lua` | New inversion modes constant + possibly subdivision options |
| `src/core/midi.lua` | `TriggerChord()` needs inversion parameter; new `InvertChord()` function |
| `src/state/sequencer.lua` | New fields: `inversion_index`, `subdivision_index` |
| `src/core/sequencer.lua` | `Run()` must handle sub-beat stepping; `Stop()` reset |
| `src/core/progression.lua` | `Add()` needs to handle sub-slot chord additions |
| `src/core/slots.lua` | Slot rendering needs multi-chord display + progress circles |
| `src/ui/views.lua` | DrawIslands: +1 island (Inversion); DrawPerformanceArea: sub-slot rendering |
| `src/ui/components.lua` | Barrel update; new inversion-mode button component? |
| `src/ui/piano-roll.lua` | Grid lines need subdivision rendering |
| `src/ui/timeline.lua` | Beat ticks need subdivision markers |
| `src/ui/format.lua` | Possibly new label formatting for inverted chords |
| `src/state/island.lua` | `ProgressionToNotes()` already has `beats_per_slot` (needs inversion param too) |
| `src/main.lua` | Init order (new store), MainLoop (new island state) |

---

## 3. Approaches

### Feature A: Inversion Island

#### Approach A1: Global inversion mode (RECOMMENDED)
Add `inversion_index` (1-4) as a global state field, like `chord_mode_index`. A new island in the right-side column shows 4 buttons: Base, 1 Inv, 2 Inv, 3 Inv. `TriggerChord()` accepts an inversion parameter and re-orders/re-pitches the generated notes.

- **Pros**: Simple data model (one field, no per-slot changes); follows the `chord_mode_index` pattern; UI is 4 buttons in a new island (already-proven pattern)
- **Cons**: Can't have different inversions per slot
- **Effort**: Medium (~40 LOC: new store field, inversion function, island UI)

#### Approach A2: Per-slot inversion
Add `inversion_index` to each slot entry. Each slot can have its own inversion.

- **Pros**: Maximum flexibility; each chord can be voiced independently
- **Cons**: More complex UI (inversion selector per slot or drag-and-drop inversion); more complex data model; slot rendering gets more complex
- **Effort**: High (~100 LOC: data model change, per-slot UI, drag interaction)

### Feature B: Slot Subdivision System

#### Approach B1: Global subdivision (RECOMMENDED for initial implementation)
Add `subdivision_index` (1-6, mapping to 1/1 through 1/16) as a global state field. All 16 slots use the same subdivision. The sequencer Run() iterates sub-beats within each measure.

- **Pros**: Simpler data model; consistent grid; single dropdown UI; matches "one setting for all" pattern (root, scale, octave, chord_mode are all global)
- **Cons**: Can't mix subdivisions per slot
- **Effort**: HIGH (~200 LOC: sequencer run loop rewrite, slot rendering multi-chord, progress circles, grid lines)

#### Approach B2: Per-slot subdivision
Each slot has its own subdivision. Allows mixing e.g., slot 1 at 1/4 and slot 2 at 1/2.

- **Pros**: Maximum flexibility for complex arrangements
- **Cons**: EXTREMELY complex (sequencer must handle variable-length steps; rendering varies per slot; drag-and-drop must target sub-slots; much more)
- **Effort**: Very High (~400 LOC)

### Inversion Math Approach

#### Approach C1: Note reordering (RECOMMENDED)
Generate all chord notes as normal, then apply inversion reordering by moving bottom notes up an octave.

For a Tri chord (notes N1, N2, N3 at octave O):
- Base: N1, N2, N3 (same octave)
- 1st Inv: N2, N3, N1+12 (bass note moved up octave)
- 2nd Inv: N3, N1+12, N2+12

For 7ma (4 notes): 3rd Inv = N4, N1+12, N2+12, N3+12
For 9na (5 notes): limited to 3rd Inv (can't go beyond 4 inversions for 4-note chords)

- **Pros**: Pure function, easy to test, no config changes needed
- **Effort**: Low (~15 lines in a new `midi.InvertChord()` function)

#### Approach C2: Alternative offset tables
Define inversion offsets for each chord mode × inversion combination.

- **Pros**: Pre-computed, no runtime math
- **Cons**: Bloat (4 modes × 4 inversions × variable offsets = 16 tables); hard to maintain
- **Effort**: Medium

---

## 4. Recommendation

**Implement both features sequentially**, starting with Inversion Island (lower risk, clean dependency) and then Slot Subdivision (higher complexity).

### Phase 1: Inversion Island
1. Add `inversion_index` (1-4) to `config.state` (like `chord_mode_index`)
2. Add `midi.InvertChord(notes, inversion_index)` function — reorders notes by moving bottom N notes up an octave
3. Modify `midi.TriggerChord()` to accept an `inversion` parameter and call `InvertChord()`
4. Pass `config.state.inversion_index` from `sequencer.Run()` and `slots.HandleSlotInteraction()`
5. Add an "Inversion" island to `views.lua:DrawIslands()` with 4 buttons (Base/1st/2nd/3rd)
6. Update format labels to show inversion info

### Phase 2: Slot Subdivision (conditional on Phase 1 success)
1. Add `subdivision_index` (1-6) to config.state — maps to 1/1, 1/2, 1/3, 1/4, 1/8, 1/16
2. Modify slot to hold TABLE of chords instead of single chord → `entry.chords[{degree, root_index, ...}]`
3. Rewrite `sequencer.Run()` to advance on sub-beats
4. Add progress circles to slot rendering (bottom of slot)
5. Add subdivision grid lines to piano roll + timeline
6. Modify drag-to-slot to target sub-slot
7. Update `ExportToMidi()` and `ProgressionToNotes()` for subdivision

### Rationale
- Inversion is self-contained, small, and follows established patterns (4-button island like Chord mode)
- Subdivision touches EVERYTHING (data model, sequencer core, UI rendering, grid lines, drag interaction)
- Doing inversion first proves the process with a contained change
- Subdivision can reuse the pattern established by inversion (new island, new dropdown)

---

## 5. Risks

### Inversion Island
- **Inversion beyond chord size**: 3rd inversion on a Tri chord (3 notes) doesn't exist. Must cap inversion to `#offsets - 1`. For Tri: max 2nd inv. For Note (single note): no inversion applies.
- **Global vs per-slot tension**: User may want per-slot inversion immediately after global implementation. Design for upgrade path.
- **GFX layout**: The right-side column already has 5 items (VEL, PLAY/STOP, CLEAR+EXPORT, MIDI, VOL). Adding another button stack may require layout reflow or condensing existing buttons.

### Slot Subdivision
- **Circular dependency risk**: `sequencer.lua` already has careful dependency management (requires midi.lua but midi.lua does NOT require sequencer.lua). The sub-beat stepping logic could accidentally create new deps.
- **Sequencer performance**: Sub-beat stepping means more `midi.TriggerChord()` calls per frame. At 1/16, a single measure triggers 16 chords — need to ensure note-offs happen correctly.
- **Drag-and-drop complexity**: Dragging pads into sub-slots requires the drag system to track both slot AND sub-slot index. Current drag state uses `source_slot_idx` (single number) — needs to become `source_slot_idx + source_sub_idx`.
- **Slot rendering space**: Current slots are ~9350×6760 virtual units. Fitting multiple chord labels + progress circles at high subdivisions (1/16 = 16 circles) may need space optimization.
- **Backwards compatibility**: Existing progression data has no subdivision concept. Old entries (single chord per slot) must work with the new system — subdivision of 1/1 means "single chord, fill whole slot."
- **400-line PR budget**: This is a BIG change. The subdivision alone likely exceeds 400 lines across all modified files. Recommend chained PRs: Phase 1 (inversion) as PR1, Phase 2A (data model + sequencer) as PR2, Phase 2B (grid + rendering) as PR3.

---

## 6. Data Model Decisions (preliminary)

### New state fields (to be confirmed in design phase)
```lua
-- Inversion modes (in new store or config.state)
config.INVERSION_MODES = {
    {name = "Base"},
    {name = "1st Inv"},
    {name = "2nd Inv"},
    {name = "3rd Inv"},
}

-- Global inversion index (like chord_mode_index)
state.inversion_index = 1  -- 1-4, default 1 (Base)

-- Subdivision options
config.SUBDIVISION_OPTIONS = {"1/1", "1/2", "1/3", "1/4", "1/8", "1/16"}
-- Or as a value: subdivision_beats = 4, 2, 1.333, 1, 0.5, 0.25

-- Global subdivision index
state.subdivision_index = 1  -- 1-6, default 1 (1/1 = 4 beats)
```

### New slot entry shape (subdivision)
```lua
-- Current (remains working for 1/1):
entry = {degree=1, root_index=1, scale_index=1, octave=4, chord_mode_index=2, velocity=85, duration=4}

-- Future (subdivision > 1/1):
entry = {
    degree = 1,                    -- default if chords[1] not set
    root_index = 1,                -- applies to all sub-chords
    scale_index = 1,              -- applies to all sub-chords
    octave = 4,                   -- applies to all sub-chords
    chord_mode_index = 2,         -- applies to all sub-chords
    velocity = 85,                -- default velocity
    duration = 4,                 -- total slot duration in beats
    subdivision = 2,              -- beats per sub-slot (2 = 1/2)
    chords = {                    -- individual chord entries per sub-slot
        {degree=1, velocity=85},
        {degree=5, velocity=90},
    },
}
```

The `chords` array is ONLY set when the slot has explicit chords placed in sub-slots. With `subdivision = 1` (1/1), `chords` is nil and the system uses `degree` as today.

---

## 7. Ready for Proposal

**Yes.** Both features have clear scope, known patterns to follow, and manageable risks. Recommend starting with Inversion Island first (lower complexity, clean patterns) and then Slot Subdivision (requires careful sequencing).

Key points for the orchestrator:
1. These are TWO independent features that CAN be split into separate SDD cycles
2. Inversion is self-contained (~40-60 LOC total)
3. Subdivision is cross-cutting (~200-300 LOC, affects 8+ files)
4. Recommend stacked PRs: Inversion → Subdivision data model → Subdivision UI/grid
