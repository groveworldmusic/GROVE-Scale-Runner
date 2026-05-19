# Proposal: Isla de Inversión + Subdivisión de Slots

## Intent
Add chord inversion voicing and slot subdivision to enable richer harmonic progressions. Currently all chords play in root position (same octave). Users cannot voice chords differently. Each slot holds one chord per measure with no rhythmic subdivision. These two features unlock realistic voice-leading and faster harmonic rhythms.

## Scope

### In Scope
- Inversion Island: 4-button island (Base, 1st, 2nd, 3rd) in DrawIslands()
- Global inversion mode via `inversion_index` (1-4), like `chord_mode_index`
- `midi.InvertChord(notes, inversion)` — reorders by moving bottom N notes up 12 semitones
- Inversion cap at `#offsets - 1` (Tri max 2nd inv, Note mode no inversion)
- Subdivision dropdown: 1/1, 1/2, 1/3, 1/4, 1/8, 1/16 (global)
- Multi-chord-per-slot with sub-beat sequencer stepping
- Progress circles in slots (bottom) reflecting current sub-chord
- Dynamic chord text during playback
- Subdivision grid lines in piano roll + timeline beat ticks
- Backward compat: old single-chord entries work as subdivision=1/1

### Out of Scope
- Per-slot inversion (deferred — design for upgrade path)
- Per-slot subdivision (deferred — extremely complex)
- Drag-to-sub-slot (deferred — current drag system tracks slot only)

## Capabilities

### New Capabilities
- `<inversion-control>`: Global chord inversion island with 4 modes (Base, 1st, 2nd, 3rd). Changes chord voicing by re-ordering notes across octaves. Pure math function.
- `<slot-subdivision>`: Global slot subdivision system with dropdown selector (1/1 through 1/16). Splits each measure into N sub-slots, each can hold a chord. Requires sequencer Run() rewrite for sub-beat stepping.

### Modified Capabilities
None.

## Approach
Two sequential phases:

1. **Phase 1: Inversion Island** (~40 LOC, 3 files) — Add `inversion_index` to state. New `midi.InvertChord()` pure function. Inversion island with 4 buttons in DrawIslands() right column. Follows chord_mode_index pattern exactly.

2. **Phase 2: Slot Subdivision** (~200-300 LOC, 8+ files) — Add `subdivision_index` to state. Rewrite `sequencer.Run()` for sub-beat stepping. Modify slot rendering for multi-chord + progress circles. Add grid lines to piano roll + timeline. Ship as chained PRs: (A) data model + sequencer, (B) UI + grid.

## Affected Areas

| File | Impact | Description |
|------|--------|-------------|
| `src/state/sequencer.lua` | Modified | New fields: inversion_index, subdivision_index |
| `src/core/midi.lua` | Modified | New InvertChord(), TriggerChord() inversion param |
| `src/ui/views.lua` | Modified | +1 island in DrawIslands(), slot sub-rendering |
| `src/core/sequencer.lua` | Modified | Sub-beat stepping in Run() (Phase 2) |
| `src/core/slots.lua` | Modified | Multi-chord display + progress circles (Phase 2) |
| `src/ui/piano-roll.lua` | Modified | Subdivision grid lines (Phase 2) |
| `src/ui/timeline.lua` | Modified | Subdivision beat ticks (Phase 2) |
| `src/core/midi.lua` | Modified | ExportToMIDI() subdivision-aware (Phase 2) |
| `src/main.lua` | Modified | New store fields init |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Inversion beyond chord size | Low | Cap at `#offsets-1` in InvertChord() |
| GFX layout reflow for new island | Med | Condense existing buttons or shrink gaps |
| Subdivision exceeds 400-line budget | High | Chained PRs: Phase 2A (data+sequencer), Phase 2B (UI+grid) |
| Subdivision circular dep in sequencer | Med | New sub-step logic same deps (midi → sequencer_store only) |
| Rendering at 1/16 (16 circles per slot) | Med | Scale circles down dynamically |

## Rollback Plan
Revert per-phase: Phase 1 (inversion) revert `inversion_index` + island draw code + InvertChord(). Phase 2 (subdivision) revert `subdivision_index`, sequencer Run() to original, slot rendering to single-chord. No migration needed — new fields default to 1 (Base/1/1).

## Dependencies
None.

## Success Criteria
- [ ] Inversion island buttons change chord voicing in real-time
- [ ] InvertChord() caps correctly (e.g., Tri max 2nd inv)
- [ ] Subdivision dropdown changes slot capacity and sequencer stepping
- [ ] Sequencer plays multi-chord slots at correct subdivision
- [ ] Progress circles reflect current sub-chord during playback
- [ ] Piano roll grid + timeline show subdivision lines
- [ ] Backward compatible: existing progressions play identically at 1/1
