# Delta for Refactor — Project Refactor Phase 3b (Piano, Pads, Slots, Drag)

## Nature of Change

**Pure structural refactor.** No behavioral changes. No new capabilities. No modified capabilities. All extractions are internal code moves that preserve every existing behavior identically.

All existing behaviors MUST be preserved identically after each extraction. The system SHALL behave exactly as before the refactor across all entry points, inputs, and UI states.

## Extractions

| # | Extract | Source | Target | Nature |
|---|---------|--------|--------|--------|
| 1 | `PIANO_LAYOUT`, cache vars, `DrawPianoKeyboard` | `src/ui/components.lua` | `src/ui/piano.lua` | Logic move, calls DrawRoundedRect + helpers/theme/colors internally |
| 2 | `DEGREE_KEY_LABELS`, `DrawScalePad` | `src/ui/components.lua` | `src/ui/pads.lua` | Logic + constant move, calls DrawRoundedRect + helpers/theme/colors/format/midi internally |
| 3 | `DrawSlotBackground`, `DrawSlotLabel`, `HandleSlotInteraction`, `DrawProgressionSlot` | `src/ui/components.lua` | `src/ui/slots.lua` | Logic move (includes 3 private + 1 public), calls DrawRoundedRect + helpers/theme/colors/format/midi/progression internally |
| 4 | `DrawDragPreview` | `src/ui/components.lua` | `src/ui/drag.lua` | Logic move, calls DrawRoundedRect + helpers/theme/colors/format internally |
| 5 | Barrel re-export | — | `src/ui/components.lua` | `components.lua` requires all 4 modules and re-exports their functions |
| 6 | Keep in place | `DrawRoundedRect`, `DrawIsland` | — | Remain in `components.lua`, unchanged |

## Constraints

- Every extracted function MUST behave identically to its previous inline definition.
- No function signature MAY change.
- No constant value MAY change.
- No state initialization semantics MAY change.
- The Lua module system (`local m = {}` + `return m`) SHALL be used for all new files.
- `components.lua` MUST re-export all extracted functions so consumer imports remain unchanged.
- No consumer file (`views.lua`, `compact.lua`, etc.) MAY require the new modules directly — all access SHALL remain through `components.*`.
- `DrawRoundedRect` SHALL remain accessible to extracted modules — either via shared import or parameter passing (design decision).
- `DEGREE_KEY_LABELS` SHALL reside in `pads.lua` (its sole consumer) — NOT in `piano.lua`.
- Cached scale note tables (`cached_scale_root`, `cached_scale_idx`, `cached_scale_notes`, `cached_note_to_degree`) SHALL move with `DrawPianoKeyboard` into `piano.lua`.
- `DrawIsland` and `DrawRoundedRect` SHALL NOT be moved in this phase.
- Each extraction SHALL be an independent commit with its own verification.

## Verification

- After each extraction commit, the script SHALL start without runtime errors (REAPER load + GFX init).
- Piano keyboard SHALL render all 73 keys, respond to click (root note change), and show scale note indicators identically before and after.
- Scale pads SHALL render chord labels and roman numerals, respond to hover, click-to-play, and QWERTY shortcuts identically before and after.
- Progression slots SHALL render background, label, slot number, progress bar, and flash overlay identically before and after.
- Drag-from-pad → drop-on-slot SHALL create a new slot entry identically before and after.
- Drag-from-slot → drop-on-another-slot SHALL swap slots identically before and after.
- Drag preview (compact floating card) SHALL follow cursor and display correct label identically before and after.
- Right-click delete on slots SHALL work identically before and after.
- Slot flash on drop SHALL render identically before and after.
- Pad flash on activation SHALL render identically before and after.
- Both expanded and collapsed UI modes SHALL work without errors.
- `DrawRoundedRect` and `DrawIsland` SHALL render identically in all remaining contexts.
