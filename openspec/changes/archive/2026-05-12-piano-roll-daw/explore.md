# Exploration: DAW-Style Piano Roll Improvements

## Current State

The piano roll (`src/ui/piano-roll.lua`, 498 LOC) renders a horizontal pitch × time grid with:
- A **key strip** on the left (40px `PITCH_LABEL_W`) using flat colored rectangles with text labels — no actual piano key shapes
- A **grid** with 3 line levels: measure (bold), beat (medium), subdivision (faint)
- **Note blocks** drawn as flat filled rounded rectangles with a text label when wide enough — no gradient, no velocity-based opacity
- **Single-note selection** via `island_store.selected_note_index` (one `number | nil`)
- **No tool modes** — the only interaction is click-to-select and right-click-to-mute

The `piano.lua` module (173 LOC) already defines `PIANO_LAYOUT` with `white_key_note_indices`, `black_key_specs`, etc. — currently used for the horizontal keyboard on the main island (#1) but directly reusable for the vertical piano roll keyboard.

## Affected Areas

| File | LOC | Why affected |
|------|-----|-------------|
| `src/ui/piano-roll.lua` | 498 | Primary target: keyboard strip, grid hierarchy, note gradient, lasso, tool routing |
| `src/ui/velocity.lua` | 294 | Bulk velocity editing on selected notes (multi-select-aware) |
| `src/ui/views.lua` | 1037 | DrawMIDIIsland: tool selector buttons in header, keyboard Delete key routing |
| `src/ui/timeline.lua` | 193 | No changes needed, but grid hierarchy should mirror piano-roll |
| `src/state/island.lua` | 269 | New state: selected_indices (set), lasso state, tool_mode |
| `src/ui/theme.lua` | 53 | Possible new colors for grid hierarchy levels, lasso rect |
| `src/ui/components.lua` | 91 | Barrel: will re-export new piano-strip module if extracted |
| `src/ui/helpers.lua` | 95 | Possible helper for velocity → opacity mapping |

## Approaches

### 1. Vertical Piano Keyboard

#### Approach A: Inline replacement in piano-roll.lua
Replace the key-strip drawing loop (lines 148–172) with real keyboard rendering using `PIANO_LAYOUT` constants via `piano.lua`.

**Implementation sketch**:
- White keys: full `PITCH_LABEL_W` × `PITCH_ROW_H`, drawn for pitch classes {C, D, E, F, G, A, B}
- Black keys: shorter height (`PITCH_ROW_H * 0.65`), narrower width (`PITCH_LABEL_W * 0.7`), right-aligned to the grid edge and centered vertically in the row, drawn for {C#, D#, F#, G#, A#}
- Labels on white keys centered; black keys either omit or show tiny sharps
- Use `piano.lua`'s `PIANO_LAYOUT.white_key_note_indices` and `black_key_specs` for pitch-class lookup (already used by horizontal keyboard — consistent)

**Key detail**: Black keys sit ON TOP of the white key row they belong to. For example, C# is drawn inside the same row as C, but shorter and offset to the right edge. This matches FL Studio / Ableton convention.

**Example pixel math** (PITCH_ROW_H = 12, PITCH_LABEL_W = 42, allow 2px extra):

```
For a black key row (e.g., pitch where pitch%12 == 2):
  black_w = 30
  black_h = 8
  bx = grid_edge - black_w        (right-aligned)
  by = row_top + (12 - 8) / 2     (vertically centered)
```

- Pros: No new module, access to private row data (`top_pitch`, `visible_rows`), single file change
- Cons: Tightens piano-roll.lua's scope (it now does grid + notes + keyboard), harder to maintain separately

#### Approach B: Extract to piano-strip.lua
Create `src/ui/piano-strip.lua` that takes `(x, y, w, h, pitch_start, pitch_end, top_pitch, scroll_y)` and renders the keyboard. piano-roll.lua delegates.

- Pros: Clean separation of concerns, matches `timeline.lua` pattern (ruler as separate module), independently testable
- Cons: Slightly more files, needs shared constants (`PITCH_ROW_H`, `PITCH_LABEL_W`), IPC between caller and callee

**Recommendation**: **Approach A** for first pass. The keyboard logic is tightly integrated with the virtual scrolling and row math of `DrawPianoRollGrid`. Extract to `piano-strip.lua` only if another consumer appears (e.g., compact view piano roll).

- Effort: **Medium** (~1.5–2 hr)
- Complexity: 3/5 (need to map pitch classes to visual positions correctly, handle octave labels at C positions only)

---

### 2. Grid Hierarchy

#### Single approach: Extend existing subdivision color system

Current colors (lines 22–26, 201–219):
```
BEAT_STRONG  {0.4, 0.4, 0.4, 0.5}  — measure (every 4 beats)
BEAT_WEAK    {0.3, 0.3, 0.3, 0.3}   — beats
SUB_COLOR    {0.25, 0.25, 0.25, 0.12} — all subdivisions
```

Proposed 4-level hierarchy:

| Level | Condition | Opacity | Pixel width |
|-------|-----------|---------|-------------|
| Measure | `beat % 4 == 0` | 0.6 (bold) | 2px (gfx.line with gfx.setlinewidth) or highest alpha |
| Beat | `beat == floor(beat)` | 0.35 (medium) | 1px |
| 1/8 | `sub_step == 2` when subdivision ≥ 4 | 0.15 (faint) | 1px |
| 1/16 | all other subdivisions | 0.08 (very faint) | 1px |

**Implementation**: Modify the subdivision loop in `DrawPianoRollGrid` (lines 201–219):

```lua
-- For subdivision >= 4 (1/16 mode): distinguish 1/8 from 1/16
if subdivision >= 4 then
    local is_eighth = (s % 2 == 0)  -- every 2nd sixteenth note
    if is_eighth then
        helpers.SetColor(SUBDIV_MEDIUM)    -- {0.25, 0.25, 0.25, 0.18}
    else
        helpers.SetColor(SUBDIV_FAINT)     -- {0.20, 0.20, 0.20, 0.08}
    end
else
    helpers.SetColor(SUBDIV_DEFAULT)       -- {0.25, 0.25, 0.25, 0.12}
end
```

Apply the same hierarchy to `timeline.lua`'s `DrawBeatTicks` for visual consistency.

**Note**: GFX API has no `gfx.setlinewidth` — line thickness is always 1px. "Bold" means higher alpha or double-draw.

- Effort: **Low** (~30 min)
- Complexity: 1/5

---

### 3. Note Design with Gradient + Velocity Opacity

#### Approach A: Multi-rect gradient (recommended)
Replace the single `helpers.SetColor(color); DrawRoundedRect(...)` in `DrawNoteBlock` (line 240) with 3–4 thin horizontal strips, each slightly darker. Apply velocity as alpha multiplier.

```lua
local function DrawNoteWithGradient(nx, ny, nw, nh, base_color, velocity, selected)
    local vel_alpha = 0.35 + (velocity / 127) * 0.65  -- 0 → 35%, 127 → 100%
    local strips = math.max(1, math.floor(nh / 4))  -- 3 strips for 12px rows
    local sh = math.floor(nh / strips)
    for i = 0, strips - 1 do
        local t = i / strips  -- 0 at top, 1 at bottom
        local r = base_color[1] * (1 - t * 0.3)
        local g = base_color[2] * (1 - t * 0.3)
        local b = base_color[3] * (1 - t * 0.3)
        local a = vel_alpha
        helpers.SetColor({r, g, b, a})
        components.DrawRoundedRect(nx, ny + i * sh, nw, sh, 2, true)
    end
    -- selection border on top
    if selected then
        helpers.SetColor(NOTE_SELECTED_BORDER)
        gfx.roundrect(nx, ny, nw, nh, 3, 0)
    end
end
```

- Pros: Pure GFX, no external resources, works at any `PITCH_ROW_H` by adjusting strip count
- Cons: 3–4× more gfx calls per note (but with virtual scroll, at most ~30 visible notes → ~120 rect calls, negligible)

#### Approach B: Pre-rendered gradient bitmap
Create a small LICE bitmap with the gradient, blit it as note background, draw flat color overlay with alpha.

- Pros: Single draw call per note
- Cons: Requires LICE (only available in compact view context), adds resource management, overkill for 30 notes/frame

**Recommendation**: **Approach A** — simple, works everywhere, no new dependencies.

- Effort: **Low-Medium** (~1 hr)
- Complexity: 2/5

---

### 4. Lasso Multi-Select

#### Single viable approach: Rectangle hit test + selection set

Given GFX immediate mode constraints (no retained DOM, no event loop), the lasso must work within the frame-by-frame model:

**State changes** (island_store):
```
selected_note_index (number|nil)  →  selected_indices (table: {[i] = true})
lasso_active (boolean)
lasso_start_x / lasso_start_y
lasso_end_x / lasso_end_y
```

**Frame loop**:

1. **On mousedown on empty grid** (no note hit at click position):
   - Set `lasso_active = true`
   - Record `lasso_start_x/y = mouse position`
   - Record `lasso_end_x/y = mouse position`

2. **While mouse is held** (`mouse_cap & 1`):
   - Update `lasso_end_x/y = current mouse position`
   - Draw semi-transparent filled rectangle from `(start, end)` with border
   - This is a multi-frame operation — drawn every frame until release

3. **On mouse release**:
   - Convert rectangle corners to (beat_min, beat_max, pitch_min, pitch_max) using inverted Y
   - Iterate all notes; if `note.start_beat` >= beat_min, `note.start_beat + note.duration` <= beat_max, `note.pitch` between pitch_min and pitch_max → add to `selected_indices`
   - Reset lasso state

4. **Bulk operations**:
   - **Mute**: Right-click on any selected note → toggle mute on ALL `selected_indices`
   - **Delete**: Check for Delete key in HandleKeyboard → remove all `selected_indices` from `island_store.notes`
   - **Velocity**: `HandleVelocityMouse` should adjust velocity for ALL `selected_indices` proportionally (relative drag, not absolute)

**Edge cases**:
- Shift+click: add single note to existing selection (not implemented initially — can be v2)
- Empty lasso: no notes in rectangle → clear selection
- Double-buffering: since GFX is immediate mode, the lasso rect is drawn each frame naturally

**Why only one approach**: The GFX API provides no alternative for multi-point interaction. Hit testing must use simple AABB rectangle intersection. No retained element tree exists.

- Effort: **High** (~3–4 hr)
- Complexity: 4/5

---

### 5. Tool Selector

#### Single viable approach: Enum state + routing in DrawMIDIIsland

**State** (island_store):
```
tool_mode: "pointer" | "pencil" | "eraser"
````

**Visual: Three icon buttons in MIDI island header** (beside the CH / PRESETS area, around views.lua line 600):

```
[ ⇱ | ✎ | ✗ ]
  Ptr  Pen  Ers
```

Simple 28×18px buttons with text or unicode symbols. Active tool highlighted with `btn_active` color.

**Behavior routing** (modify `HandleMouseClick` and mouse handling in `DrawMIDIIsland`, around lines 751–787):

```lua
if tool_mode == "pointer" then
    -- existing: select/move/resize
    if click then piano_roll.HandleMouseClick(...) end
    if right_click then piano_roll.HandleRightClickMute(...) end
elseif tool_mode == "pencil" then
    local beat = converted_x(click_pos)
    local pitch = converted_pitch(click_pos)
    -- Add {pitch, start_beat=beat, duration=1, velocity=100, muted=false}
    island_store.AddNote({...})  -- new function
elseif tool_mode == "eraser" then
    local idx = piano_roll.NoteBlockHitTest(...)
    if idx then island_store.RemoveNoteAtIndex(idx) end
end
```

**Pencil tool detail**: Notes created by Pencil go directly into `island_store.notes[]` as free-form note entries. They have `pitch`, `start_beat`, `duration`, `velocity`, `muted` — same schema as notes from `ProgressionToNotes`. The only difference is origin: they exist as "manual" notes until the user clears them or the island resets.

**Existing patterns for toolbar**: `buttons.DrawToolIcon` (line 81 of components.lua) already handles tool icon rendering with hover/active states. We can extend this pattern with new tool types `"pointer"`, `"pencil"`, `"eraser"` or create inline buttons.

- Effort: **Medium** (~1.5–2 hr)
- Complexity: 2/5

---

## Dependencies Between Features

```
Tool Selector ◄── Lasso (pointer tool enables lasso)
     │
     ├── Pointer ──► Lasso multi-select + selection set
     ├── Pencil  ──► island_store.AddNote() (needs island_store change)
     └── Eraser  ──► island_store.RemoveNoteAtIndex()

Grid Hierarchy ──► none (isolated)
Keyboard      ──► none (isolated, could share PIANO_LAYOUT)
Note Gradient ──► velocity opacity uses existing velocity field

Lasso:
  ──► requires selected_indices (breaking change for single-select consumers)
```

**Important**: Features 1, 2, and 3 are independent and can be implemented in any order. Feature 4 (lasso) and 5 (tool selector) share the `selected_indices` state change and should be implemented together.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Single → multi-select breaking change** | `island_store.GetSelectedNoteIndex()` returns `number|nil`. Changing to `GetSelectedIndices()` returns `table` breaks consumers (`views.lua` info bar, `velocity.lua` single-note editing). | Keep backward compat: `GetSelectedNoteIndex()` returns first or last selected index, or introduce both `GetSelectedIndices()` + keep old getter. |
| **GFX gradient performance** | Multi-rect gradient adds 3-4× draw calls per note. With 30 visible notes = ~90-120 rect calls/frame vs 30. | Negligible at 60fps. GFX gfx.rect is fast. Profile if needed. |
| **Lasso rect flicker** | Since GFX is immediate mode, the selection rect might flicker if not drawn every frame during drag. | Already handled — DrawMIDIIsland runs every frame. Lasso draws in the same render pass. |
| **Pencil note origin tracking** | Notes from Pencil vs notes from Progression need different handling (island reset, save/load). | Add `origin` field to note schema: `"progression"` or `"manual"`. Pencil notes set `origin = "manual"`. On island reload or clear, manual notes are removed first. |
| **Keyboard Delete key routing** | REAPER GFX doesn't provide text input. Delete key must be detected via VK map. | Add Delete (0x2E) to key intercept OR use `gfx.getchar()` non-blocking check. More reliable: check in MainLoop similar to Ctrl+D for dock. |

## Ready for Proposal

**Yes** — all 5 features have clear, feasible approaches within REAPER GFX constraints. The main architectural decision is **how to handle the single→multi selection state change**, which cascades to velocity editor and info bar. No blockers, no unknown unknowns.

The recommended implementation order is:

1. **Grid hierarchy** (isolated, low effort, fast win)
2. **Vertical piano keyboard** (medium, independent)
3. **Note gradient + velocity opacity** (low-medium, independent)
4. **Tool selector** (medium, enables interaction framework)  
5. **Lasso multi-select** (high, depends on tool selector for pointer tool)

Phases 4 and 5 are tightly coupled (both need `selected_indices`, both modify `HandleMouseClick` routing) and should share a design spec.
