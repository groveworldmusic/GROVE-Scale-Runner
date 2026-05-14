# Design: Project Refactor — Phase 2

## Technical Approach

4 sequential extractions, each as a separate commit, pulling formatting, color semantics, and progression CRUD out of `components.lua` (853→~500 lines) into dedicated modules. Pure code moves — no behavioral changes. Follows the same pattern as Phase 1 (layout.lua, keyboard.lua).

## Architecture Decisions

### Decision: `format.NoteName(ctx)` instead of per-slot binding

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `FormatNoteLabel(slot)` — single slot binding | Can't reuse for drag-from-pad path (uses config.state) | Rejected |
| `FormatChordLabel(degree, chord_mode)` — scalar params | Caller must extract fields manually | Rejected |
| `NoteName({root_index, scale_index, degree, octave})` | Single function handles slot, config.state, any context | **Chosen** |

`NoteName` / `ChordLabel` accept a context table with `root_index`, `scale_index`, `degree`, `octave` (and optionally `chord_mode_index`). Both call sites — slot and config.state — construct a compatible table trivially.

### Decision: `progression.Add(idx, slot)` takes explicit index

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `Add(slot)` — implicit append | Doesn't match drag-drop insert-at-index semantics | Rejected |
| `Add(idx, slot)` — explicit index | Caller (HandleSlotInteraction) already has global_idx; maps 1:1 | **Chosen** |

`Add` also manages the slot_flash side effect (timer + idx) since that's part of the "add" contract.

### Decision: `HoverColor()` / `ActiveColor()` scoped out of Phase 2

The proposal mentions them as new wrappers, but each has only 1-2 call sites in components.lua. Creating them adds indirection without reducing coupling. Phase 3 (full decomposition) can introduce them when they serve actual callers. `colors.lua` exports only `DegreeColor` + `ROMAN_NUMERALS` table.

## Data Flow

```
Before:
  components.lua ──(inline formatting, DegreeColor, drag CRUD)──→ config.state.progression
  sequencer.lua  ──GetLastFilledSlot()──→ config.state.progression
  views.lua      ──progression.Clear inline──→ config.state.progression

After:
  components.lua ──→ format.lua (label rendering)
                 ──→ colors.lua (degree→color)
                 ──→ progression.lua (CRUD)
  sequencer.lua  ──→ progression.lua.GetLastFilled()
  views.lua      ──→ progression.lua.Clear()
  midi.lua       unchanged — reads config.state.progression directly (ExportToMidi)
```

No new circular dependencies. Progression depends only on config (config.state reads/writes). Format depends on config + midi (GetMidiNote). Colors depend on config + theme.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/colors.lua` | **Create** | DegreeColor(degree), ROMAN_NUMERALS table |
| `src/ui/format.lua` | **Create** | NoteName(ctx), ChordLabel(ctx), RomanNumeral(degree) |
| `src/core/progression.lua` | **Create** | Add(idx, slot), Remove(idx), Swap(a, b), Clear(), GetLastFilled() |
| `src/ui/components.lua` | Modify | Import format/colors/progression; remove inline code; keep midi for TriggerChord only |
| `src/core/sequencer.lua` | Modify | Remove GetLastFilledSlot; use progression.GetLastFilled() |
| `src/ui/views.lua` | Modify | Inline Clear → progression.Clear() |
| `src/ui/compact.lua` | — | No changes (confirmed: no references to moving functions) |

## Interfaces / Contracts

```lua
-- ui/colors.lua
local colors = {}
local ROMAN_NUMERALS = {"I","II","III","IV","V","VI","VII"}  -- reused by format.lua
function colors.DegreeColor(degree) return {r,g,b} end
return colors

-- ui/format.lua
local format = {}
-- ctx: {root_index, scale_index, degree, octave}
function format.NoteName(ctx) return string end           -- "C", "D#", etc.
-- ctx adds chord_mode_index; returns note-only if mode==1
function format.ChordLabel(ctx) return string end         -- "C" or "C Maj"
function format.RomanNumeral(degree) return string end     -- "I".."VII" or "?"
return format

-- core/progression.lua
local progression = {}
function progression.Add(idx, slot) ... end    -- assign + flash
function progression.Remove(idx) ... end       -- nil at idx
function progression.Swap(a, b) ... end        -- swap values
function progression.Clear() ... end           -- nil all 16
function progression.GetLastFilled() ... end   -- last non-nil idx or 0
return progression
```

### Import Map

| File | Adds | Keeps | Removes |
|------|------|-------|---------|
| components.lua | format, colors, progression | config, theme, helpers, midi | _(inline code)_ |
| sequencer.lua | progression | config, midi | _(GetLastFilledSlot func)_ |
| views.lua | progression | config, theme, components, helpers, midi, compact, layout | _(inline Clear)_ |

## Testing Strategy

Manual (no Lua test infra exists for REAPER GFX):

| Slice | What to Verify |
|-------|---------------|
| 1. colors.lua | Script loads; all degree pads render correct grade/flat colors; color_mode toggle works |
| 2. format.lua | Slot labels show correct note name + chord type; drag preview labels match originals |
| 3. progression.lua | Drag-to-add creates slot; drag-to-swap exchanges slots; right-click deletes; clear button clears all; sequencer auto-stops on empty |
| 4. Import wiring | No "nil value" errors on load; all modes (compact, full, docked) work; drag/drop/play behavior unchanged |

Test after EACH commit. If any slice breaks, revert that commit.

## Migration / Rollout

Feature branch: `refactor/project-refactor-phase-2`. Each extraction is a separate commit — `git revert` undoes individual slices. No data migration or config changes needed.

## Open Questions

None — codebase analysis confirms all 4 slices are safe extractions with verified call sites.
