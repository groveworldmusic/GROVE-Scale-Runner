# Exploration: Decompose components.lua — Phase 3a

## Current State

`src/ui/components.lua` is 830 lines containing 14 public functions, 3 private helpers, 2 module-level tables, and 4 cache variables. Everything routes through it. Phase 2 extracted `colors.lua`, `format.lua`, and `progression.lua` — but the file is still the fat controller.

External consumers:
- `views.lua` — imports `ui.components`, uses 12 functions (DrawButton, DrawToolIcon, DrawIsland, DrawPianoKeyboard, DrawDropdown, DrawNoteDisplay, DrawProgressionSlot, DrawPaginator, DrawDragPreview, DrawTransportButton, DrawRoundedRect)
- `compact.lua` — imports `ui.components`, uses 3 functions (DrawPianoKeyboard, DrawDropdown, DrawRoundedRect)

## Complete Function Inventory

### Module-Level State / Constants

| Item | Lines | Description |
|------|-------|-------------|
| `cached_scale_root` | 12 | Cache key for piano keyboard scale root |
| `cached_scale_idx` | 13 | Cache key for piano keyboard scale index |
| `cached_scale_notes` | 14 | Cached set of scale pitch-classes |
| `cached_note_to_degree` | 15 | Cached pitch-class → degree lookup |
| `DEGREE_KEY_LABELS` | 18 | QWERTY labels for degrees 1-7 |
| `PIANO_LAYOUT` table | 22-46 | Shared keyboard layout constants (EXPORTED) |

### Public Functions (components.*)

| Function | Lines | Lines of Code | Category | Return Value |
|----------|-------|---------------|----------|-------------|
| `DrawIsland` | 48-59 | 12 | Misc/Decorator | nil |
| `DrawToolIcon` | 61-140 | 80 | Button primitives | bool (clicked) |
| `DrawNoteDisplay` | 142-152 | 11 | Button primitives | nil |
| `DrawRoundedRect` | 154-168 | 15 | **Foundation** | nil |
| `DrawButton` | 170-213 | 44 | Button primitives | bool (clicked) |
| `DrawPaginator` | 215-242 | 28 | Paginator | nil |
| `DrawProgressionSlot` | 401-415 | 15 | Slot system (orchestrator) | nil |
| `DrawDropdown` | 417-481 | 65 | Dropdown | int (choice) or nil |
| `DrawPianoKeyboard` | 483-607 | 125 | Piano keyboard | nil |
| `DrawScalePad` | 609-723 | 115 | Pad | nil |
| `DrawDragPreview` | 725-812 | 88 | Drag/drop | nil |
| `DrawTransportButton` | 815-828 | 14 | Button primitives | bool (clicked) |

### Private (Local) Helpers

| Function | Lines | Lines of Code | Category |
|----------|-------|---------------|----------|
| `DrawSlotBackground` | 245-290 | 46 | Slot system |
| `DrawSlotLabel` | 293-316 | 24 | Slot system |
| `HandleSlotInteraction` | 319-399 | 81 | Slot system |

### Nesting Note

`DrawSlotBackground`, `DrawSlotLabel`, and `HandleSlotInteraction` are local functions used ONLY by `DrawProgressionSlot` (line 401-415). They must be extracted together with it.

## Category Breakdown

### Category 1: Foundation — DrawRoundedRect
- **Lines**: 154-168 (15 lines)
- **Self-contained**: Pure gfx primitive, calls nothing except gfx.*
- **config.state access**: NONE
- **Used by**: EVERYTHING (both inside and outside components.lua — 40 call sites total)
- **Recommendation**: **STAY in components.lua** as the shared re-export. Every consumer already does `components.DrawRoundedRect(...)`. Moving it would require updating ~15 import lines across views.lua and compact.lua. Not worth the churn for 15 lines.

### Category 2: Button Primitives (~156 lines)
| Function | Lines | config.state access | Internal deps |
|----------|-------|---------------------|---------------|
| `DrawButton` | 170-213 | READ: `mouse_click`, `drag.is_dragging` | DrawRoundedRect |
| `DrawTransportButton` | 815-828 | READ: `mouse_click` | DrawRoundedRect |
| `DrawToolIcon` | 61-140 | READ: `mouse_click` (return only) | helpers.SetColor |
| `DrawNoteDisplay` | 142-152 | NONE | DrawRoundedRect |

- **External deps**: helpers, theme, DrawRoundedRect
- **config.state**: READ-ONLY (mouse_click, drag.is_dragging)
- **Independence**: Fully independent — no calls to colors, format, progression, or midi
- **Estimated new module**: `src/ui/buttons.lua` — ~156 lines

### Category 3: Dropdown (~65 lines)
| Function | Lines | config.state access | Internal deps |
|----------|-------|---------------------|---------------|
| `DrawDropdown` | 417-481 | READ: `use_scroll`, `mouse_wheel_delta`; WRITE: `mouse_wheel_delta` | DrawRoundedRect |

- **External deps**: helpers, theme, DrawRoundedRect
- **config.state**: READ-ONLY (plus one write-reset of mouse_wheel_delta)
- **Independence**: Fully independent
- **Estimated new module**: `src/ui/dropdown.lua` — ~65 lines

### Category 4: Paginator (~28 lines)
| Function | Lines | config.state access | Internal deps |
|----------|-------|---------------------|---------------|
| `DrawPaginator` | 215-242 | READ: `current_page`, `show_tooltips`, `mouse_click`; **WRITE**: `current_page` | DrawRoundedRect |

- **External deps**: helpers, theme, DrawRoundedRect
- **config.state**: READ + WRITE (current_page mutation)
- **Independence**: Fully independent
- **Estimated new module**: `src/ui/paginator.lua` — ~28 lines

### Category 5: Piano Keyboard (~155 lines)
| Item | Lines | config.state access |
|------|-------|---------------------|
| `PIANO_LAYOUT` (exported) | 22-46 | NONE |
| `DEGREE_KEY_LABELS` | 18 | NONE |
| `cached_*` vars | 12-15 | NONE (internal cache) |
| `DrawPianoKeyboard` | 483-607 | READ: `root_index`, `scale_index`, `active_notes`, `mouse_click`, `NOTE_NAMES`, `SCALES`; **WRITE**: `root_index` |

- **External deps**: helpers, theme, colors.DegreeColor, DrawRoundedRect
- **config.state**: READ (heavy) + WRITE (root_index on click)
- **Independence**: Depends on colors module (already extracted). No calls to format, progression, or midi.
- **Estimated new module**: `src/ui/piano.lua` — ~155 lines

### Category 6: Pad (DrawScalePad) — ~115 lines
| Function | Lines | config.state access |
|----------|-------|---------------------|
| `DrawScalePad` | 609-723 | READ: `root_index`, `scale_index`, `octave`, `chord_mode_index`, `key_states`, `mouse_pad_state`, `drag.*`, `pad_flash`, `mouse_click`, `mouse_cap`, `slider_dragging`; WRITE: `pad_flash`, `mouse_pad_state`, `drag.*` |

- **External deps**: helpers, theme, colors, format.ChordLabel, format.RomanNumeral, midi.TriggerChord, midi.SendMidi, DrawRoundedRect
- **config.state**: READ + WRITE (modifies drag protocol state, mouse_pad_state, pad_flash)
- **Key coupling**: Initiates drag via `drag.pending_degree` → `drag.source_degree`. This is the **drag protocol** shared with Slot and DragPreview.
- **Estimated new module**: `src/ui/pads.lua` — ~115 lines

### Category 7: Slot System — ~166 lines
| Function | Lines | config.state access |
|----------|-------|---------------------|
| `DrawSlotBackground` (local) | 245-290 | READ: `drag.is_dragging`, `slot_flash`; WRITE: `slot_flash` |
| `DrawSlotLabel` (local) | 293-316 | NONE (reads slot data via params; uses format which reads config internally) |
| `HandleSlotInteraction` (local) | 319-399 | READ/WRITE: heavy drag protocol (pending_slot_idx, source_slot_idx, is_dragging), `slider_dragging`, `mouse_cap`, `last_mouse_cap`, `progression`, `root_index`, `scale_index`, `octave`, `chord_mode_index` |
| `DrawProgressionSlot` | 401-415 | READ: `progression`, `sequencer`; WRITE: `drag.pending_slot_idx` cleanup |

- **External deps**: helpers, theme, colors, format, midi, progression (three progression calls: Remove, Swap, Add), DrawRoundedRect
- **config.state**: HEAVY READ + WRITE across drag protocol, progression data, sequencer state
- **Key coupling**: Receives drag from Pad (reads `drag.source_degree` for "new from pad" on drop). Writes `drag.source_slot_idx` for slot-to-slot drag.
- **Estimated new module**: `src/ui/slots.lua` — ~166 lines

### Category 8: Drag Preview — ~88 lines
| Function | Lines | config.state access |
|----------|-------|---------------------|
| `DrawDragPreview` | 725-812 | READ: `drag.*`, `progression`, `root_index`, `scale_index`, `octave`, `chord_mode_index`; WRITE: `drag.*` cleanup |

- **External deps**: helpers, theme, colors, format.ChordLabel, format.RomanNumeral, DrawRoundedRect
- **config.state**: READ heavy (all drag fields) + WRITE (cleanup on mouse release)
- **Key coupling**: Renders ghost based on BOTH `drag.source_degree` (set by Pad) and `drag.source_slot_idx` (set by Slot). Cannot work without both being set.
- **Estimated new module**: `src/ui/drag.lua` — ~88 lines

### Category 9: Misc/Decorator — ~12 lines
| Function | Lines | config.state access |
|----------|-------|---------------------|
| `DrawIsland` | 48-59 | NONE |

- **External deps**: helpers, theme, DrawRoundedRect
- **config.state**: NONE
- **Independence**: Fully independent
- **Estimated new module**: Could stay in components or merge into a `decorators.lua`

## Dependency Graph

```
Foundation (15 LOC, stays in components)
└── DrawRoundedRect ←── used by ALL categories below

Button Primitives (~156 LOC) ── reads config.state (RO)
├── DrawButton
├── DrawTransportButton
├── DrawToolIcon
└── DrawNoteDisplay

Paginator (~28 LOC) ── reads + writes config.state.current_page
└── DrawPaginator

Dropdown (~65 LOC) ── reads config.state (RO + wheel reset)
└── DrawDropdown

Piano Keyboard (~155 LOC) ── reads config.state (RO), writes root_index
├── PIANO_LAYOUT (exported constant)
├── DEGREE_KEY_LABELS
├── cached_* state
└── DrawPianoKeyboard
    └── colors.DegreeColor

Pad (~115 LOC) ── reads + writes config.state
└── DrawScalePad
    ├── colors.DegreeColor
    ├── format.ChordLabel / RomanNumeral
    ├── midi.TriggerChord / SendMidi
    └── drag protocol → [drag.source_degree]

Slot System (~166 LOC) ── reads + writes config.state heavily
├── DrawSlotBackground (local)
├── DrawSlotLabel (local)
├── HandleSlotInteraction (local)
│   ├── colors.DegreeColor
│   ├── format.ChordLabel
│   ├── midi.TriggerChord
│   └── progression.Remove / Swap / Add
└── DrawProgressionSlot (orchestrator)
    └── drag protocol → [drag.source_slot_idx]

Drag Preview (~88 LOC) ── reads + writes config.state
└── DrawDragPreview
    ├── colors.DegreeColor
    ├── format.ChordLabel / RomanNumeral
    └── drag protocol ← [reads BOTH source_degree AND source_slot_idx]

Misc (~12 LOC)
└── DrawIsland
```

### Cross-Category Coupling: The Drag Protocol

This is the single most important coupling in the file. Three categories share `config.state.drag` as a message bus:

```
  Pad                                        Slot
  │                                          │
  ├─ drag.pending_degree                     ├─ drag.pending_slot_idx
  ├─ drag.start_x/y                          ├─ drag.start_x/y
  ├─ drag.source_degree ←┐                   ├─ drag.source_slot_idx ←┐
  └─ drag.is_dragging ←─┤                   └─ drag.is_dragging ←─┤
                        │                                          │
                        ▼                                          ▼
               DragPreview reads both source_degree and source_slot_idx
               Slot (on drop) reads source_slot_idx OR source_degree
```

**Key insight**: This is NOT function-level coupling (Pad doesn't call Slot functions). It's **protocol coupling** through a shared mutable table (`config.state.drag`). All three categories can be extracted independently because they only mutate/read keys on the shared table — they don't import each other.

However, there's a subtlety: `DrawDragPreview` imports `format.lua` and would create a circular dependency if slots.lua also imports drag.lua. Since there's no such import, we're fine.

## Recommendation: Execution Order

### ⚡ FIRST SLICE (Phase 3a — This Phase)

Extract the **independent widgets** — those with ZERO cross-category coupling and no dependencies beyond foundation:

1. **Button Primitives** → `src/ui/buttons.lua` (~156 lines)
   - `DrawButton`, `DrawTransportButton`, `DrawToolIcon`, `DrawNoteDisplay`
   - Zero coupling to other categories. Fastest win. No test needed.
   
2. **Paginator** → `src/ui/paginator.lua` (~28 lines)
   - `DrawPaginator` — tiny, independent. 
   
3. **Dropdown** → `src/ui/dropdown.lua` (~65 lines)
   - `DrawDropdown` — self-contained.

**Total removed from components.lua**: ~249 lines (830 → ~580).

**Why these three first**: They have NO dependencies on each other, NO dependencies on colors/format/progression/midi (beyond helpers and theme which are already external), and they can be extracted in parallel without any coordination. The `config.state` reads they do are simple boolean/primitive reads — no protocol coupling.

### SECOND SLICE

4. **Piano Keyboard** → `src/ui/piano.lua` (~155 lines)
   - Needs `colors.DegreeColor` already extracted. Self-contained beyond that.

### THIRD SLICE

5. **Pad** → `src/ui/pads.lua` (~115 lines)
6. **Slot System** → `src/ui/slots.lua` (~166 lines)
   These CAN be extracted independently (they only share protocol through config.state.drag, not function calls), but doing them together reduces risk.

### FOURTH SLICE

7. **Drag Preview** → `src/ui/drag.lua` (~88 lines)
   Must come after both Pad and Slot since it reads state set by both.

### AFTER ALL EXTRACTIONS

`components.lua` would be reduced to:
- DrawRoundedRect (15 lines — stays as foundation re-export)
- DrawIsland (12 lines — could stay or go to misc)
- Imports + re-exports from all new modules (~20-30 lines overhead)

Estimated final size: ~50-60 lines.

## Risks

1. **Import churn in views.lua and compact.lua**: Each extracted module creates a new require. views.lua calls 12 different component functions — after full extraction it would need ~7-8 requires instead of 1. Mitigation: use a barrel `components.lua` that re-exports everything (already the pattern).
   
2. **`PIANO_LAYOUT` is exported**: `components.PIANO_LAYOUT` is used by code OUTSIDE components.lua? Let me check... No — grep shows it's only used within components.lua (inside DrawPianoKeyboard). But it's exported on the table so external code COULD reference it. Low risk to keep or move.

3. **`DrawRoundedRect` is called directly from views.lua (12 times) and compact.lua (1 time)**: If we keep it in components as a re-export, zero impact. Views.lua already does `components.DrawRoundedRect(...)`.

4. **The drag protocol is fragile**: Extracting Pad, Slot, and DragPreview separately requires confidence that only `config.state.drag.*` keys are used for communication. As analyzed above, this is true — no functions from one category are called by another.

5. **Inline `GetFitText` in DrawDropdown**: This is a local closure (lines 423-440). If extracted to dropdown.lua, it becomes a module-local function. No external calls to it exist. Safe.

## Ready for Proposal

Yes. The analysis confirms that independent widgets (buttons, paginator, dropdown) can be extracted FIRST with zero risk. The drag-coupled group (pad, slot, drag preview) needs careful attention but is structurally safe to separate.

The orchestrator should tell the user: Phase 3a should extract buttons + paginator + dropdown as a first slice. Phase 3b piano, Phase 3c pads+slots+drag.
