# Design: DAW-Style Piano Roll

## Technical Approach

Four independent phases applied to the existing piano roll (`piano-roll.lua`, 498 LOC). Phase 1–3 modify rendering only — grid line opacities, note block draw pipeline, and key strip replacement. Phase 4 requires a store schema change (`selected_note_index` → `selected_indices` set) with a backward-compat shim for `velocity.lua` and the info bar. All phases respect the existing virtual scrolling and cached visible-range math.

## Architecture Decisions

### Decision: Vertical Keyboard — Inline vs Extract

| Option | Tradeoff | Decision |
|--------|----------|----------|
| **Inline** (Approach A) | Single-file change, tight coupling with virtual scroll and row math | ✅ **Choose** — no other consumer exists yet; extraction is premature |
| Extract to `piano-strip.lua` | Cleaner separation, but same constants duplicated, no re-use elsewhere | Rejected — only piano-roll.lua needs it |

### Decision: Note Gradient — Multi-Rect vs Pre-Rendered

| Option | Tradeoff | Decision |
|--------|----------|----------|
| **Multi-rect** (Approach A) | 3–4× draw calls per note (~120 rect calls at 30 visible notes) | ✅ **Choose** — GFX `gfx.rect` is fast; negligible at 60fps |
| LICE bitmap | Single draw, but resource management overhead, complex context handling | Rejected — overkill for 30 notes/frame |

### Decision: Selection Schema — Breaking vs Dual-API

| Option | Tradeoff | Decision |
|--------|----------|----------|
| **Dual-API** | Keep `GetSelectedNoteIndex()` as compat shim wrapping `GetPrimarySelectedIndex()` | ✅ **Choose** — zero regression for velocity.lua and info bar |
| Breaking change only | Cleaner API but requires updating 3 consumers simultaneously | Rejected — unnecessary risk for no benefit |

### Decision: Tool Routing — views.lua vs piano-roll.lua

| Option | Tradeoff | Decision |
|--------|----------|----------|
| **views.lua** | Mouse events already routed there (lines 751–787) | ✅ **Choose** — `DrawMIDIIsland` already dispatches clicks based on zone hit test |
| piano-roll.lua | Would need views.lua to pass tool_mode back — more indirection | Rejected — adds coupling without gain |

## Data Flow

```
views.DrawMIDIIsland
  ├── Read tool_mode from island_store
  ├── Render tool buttons in header area
  ├── Route mouse events:
  │   ├── pointer → piano_roll.HandleMouseClick / HandleLasso
  │   ├── pencil  → piano_roll.HandlePencilClick
  │   └── eraser  → piano_roll.HandleEraserClick
  └── Per-frame render:
      ├── DrawPianoRollGrid       ← P1: 4-level grid opacities
      │   └── DrawBeatTicks       ← P1: mirror hierarchy
      ├── DrawNoteBlocks          ← P2: gradient + velocity alpha
      │   └── DrawNoteBlock → DrawNoteWithGradient (3-strip, vel→alpha)
      ├── DrawVerticalKeyboard    ← P3: real key shapes
      └── Lasso selection rect    ← P4: semi-transparent fill + border
```

## File Changes

| File | Action | Phase | Description |
|------|--------|-------|-------------|
| `src/ui/piano-roll.lua` | Modify | 1–4 | Grid opacities, gradient draw, vertical keyboard, lasso + tool handlers |
| `src/state/island.lua` | Modify | 4 | `selected_indices`, `tool_mode`, lasso state; compat shim for `GetSelectedNoteIndex()` |
| `src/ui/views.lua` | Modify | 4 | 3 tool buttons in MIDI island header, route `Delete` key, tool-specific click dispatch |
| `src/ui/velocity.lua` | Modify | 4 | Bulk velocity edit across all `selected_indices`; proportional relative drag |
| `src/ui/theme.lua` | Modify | 1,4 | New grid hierarchy colors (`SUBDIV_MEDIUM`, `SUBDIV_FAINT`), lasso rect fill/border |
| `src/ui/timeline.lua` | Modify | 1 | Mirror grid hierarchy in `DrawBeatTicks` subdivision ticks |

## Interfaces / Contracts

### island_store — New API (Phase 4)

```lua
-- State fields
island_state.tool_mode = "pointer"              -- "pointer"|"pencil"|"eraser"
island_state.selected_indices = {}              -- {[idx]=true} replaces selected_note_index
island_state.lasso_active = false
island_state.lasso_start_x = 0
island_state.lasso_start_y = 0
island_state.lasso_end_x = 0
island_state.lasso_end_y = 0

-- New getters/setters
function m.GetToolMode()        return island_state.tool_mode end
function m.SetToolMode(v)       island_state.tool_mode = v end
function m.GetSelectedIndices() return island_state.selected_indices end
function m.SetSelectedIndices(t) island_state.selected_indices = t end
function m.ClearSelection()     island_state.selected_indices = {} end
function m.GetPrimarySelectedIndex()
    -- Returns the first key in selected_indices, or nil
    local idx = next(island_state.selected_indices)
    return idx
end

-- Compat shim (unchanged signature for velocity.lua / info bar)
function m.GetSelectedNoteIndex() return m.GetPrimarySelectedIndex() end
function m.SetSelectedNoteIndex(v)
    if v == nil then m.ClearSelection()
    else m.SetSelectedIndices({[v] = true}) end
end
```

### DrawNoteWithGradient — New Signature (Phase 2)

```lua
--- @param nx number Pixel x
--- @param ny number Pixel y
--- @param nw number Pixel width
--- @param nh number Pixel height (row height)
--- @param velocity number 0-127
--- @param selected boolean
--- @param muted boolean
function DrawNoteWithGradient(nx, ny, nw, nh, velocity, selected, muted)
    local vel_alpha = 0.35 + (velocity / 127) * 0.65
    local strips = math.max(1, math.floor(nh / 4))
    local sh = math.floor(nh / strips)
    for i = 0, strips - 1 do
        local t = i / strips
        -- Top strip lighter (t=0), bottom darker (t=1)
        local darken = 1 - t * 0.3
        -- ... SetColor with base_note_color * darken * vel_alpha
        -- ... DrawRoundedRect for each strip
    end
    -- Selection border on top (full opacity, muted ignores vel_alpha)
end
```

### Tool Routing Contract (Phase 4)

```lua
-- In DrawMIDIIsland, replace the existing click block (lines 751–760):
local tool_mode = island_store.GetToolMode()
if tool_mode == "pointer" then
    piano_roll.HandleMouseClick(...)       -- select + lasso
elseif tool_mode == "pencil" then
    piano_roll.HandlePencilClick(...)      -- add note
elseif tool_mode == "eraser" then
    piano_roll.HandleEraserClick(...)      -- remove note
end
```

### Note Schema — Origin Field (Phase 4 Pencil)

```lua
-- Pencil-created notes include an `origin` field:
{
    pitch = 60,
    start_beat = 4,
    duration = 1,
    velocity = 100,
    muted = false,
    origin = "manual",       -- NEW: "progression" (default) | "manual"
}
```

## Migration / Rollout

P1–P3 revert individually — each touches isolated rendering code. P4 must revert atomically (island_store schema + all 4 consumers). No data migration needed: island state is ephemeral per session. `config.state` untouched.

## Open Questions

- [ ] **Delete key detection**: `gfx.getchar()` is non-blocking in MainLoop but may not fire during drag (mouse_cap held). Fallback: check in `HandleKeyboard` routing alongside existing VK map intercept.
- [ ] **Pencil note origin conflict on island reload**: `LoadNotesFromProgression` currently replaces all notes. Need to either preserve manual notes or clear on reload. Decision: manual notes cleared on progression change (`cur_rev` check in DrawMIDIIsland line 579).
- [ ] **Lasso on key strip area**: Should lasso work when the drag starts on the key strip? Decision: lasso only activates when mousedown is in the grid area (right of PITCH_LABEL_W), not on the keyboard strip.
