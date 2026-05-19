# Design: Production-Readiness Polish

## Technical Approach

Four independent refactors, each one commit. Zero behavioral changes to MIDI/keyboard/sequencer logic. All 382 existing tests must pass untouched.

---

## Architecture Decisions

### Decision: DrawMIDIIsland split strategy

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Extract 4 named helpers only | Remaining body still ~300 LOC | ✅ Proposal-aligned, minimal diff |
| Aggressive extraction (header bar, scrollbar) | More LOC removed but churn risk up | ❌ Not needed; each helper is independently maintainable |

**Chosen**: Extract `DrawKeyboardShortcutOverlay(char)`, `DrawToolModeRow(...)`, `DrawSnapControls(...)`, `DrawPresetPanel(...)` as top-level functions in `views.lua`. Identical parameter shapes — pure relocation, no logic change.

### Decision: ShowError location

**Choice**: New module `src/ui/gfx-safe.lua`
**Alternatives**: Inline pcall at each site, config.lua, main.lua helper
**Rationale**: Both `main.lua` and `compact-init.lua` need it. A shared module avoids duplication. Follows the existing pattern (helpers.lua, lice.lua are shared utilities). Exports: `SafeGfxInit()`, `SafeGfxQuit()`, `ShowError()`.

### Decision: Persistence approach

**Choice**: New module `src/state/persist.lua` with `Load(state)` + `Save(key, value)`
**Rationale**: Existing code mutates `config.state` directly (~72 sites). Adding a proxy or store would be high-risk. Instead, load all at Init(), and add `persist.Save()` calls at mutation points in UI code. For `volume`, embed persistence inside `sequencer_store.SetVolume()` — single gate for all volume writes.

### Decision: ExtState migration

**Chosen**: `GROVE_Scale_Runner` is the canonical namespace; `GROVE_FL_MIDI` is legacy. In `persist.Load()`, read `GROVE_Scale_Runner` first; if a key is missing, read from legacy `GROVE_FL_MIDI` → migrate to `GROVE_Scale_Runner`. `GROVE_Scale_Runner` always wins if both exist. Legacy keys are NEVER deleted.

---

## Data Flow

```
 Init()
   │
    ├── persist.Load(state)
    │     ├── Read GROVE_Scale_Runner → apply to config.state + sequencer_store
    │     ├── If missing: read legacy GROVE_FL_MIDI → migrate → write GROVE_Scale_Runner
    │     └── If both exist: GROVE_Scale_Runner wins (no migration needed)
    │
    ├── gfx.init(...) → SafeGfxInit(...) wraps in pcall
    │     └── Failure → ShowError() → reaper.ShowConsoleMsg() + continue
    │
    └── MainLoop
          └── User changes value
                └── persist.Save(key, value) → SetExtState("GROVE_Scale_Runner", key, value, true)
```

---

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/views.lua` | Modify | Extract 4 helpers from DrawMIDIIsland; add persist.Save at mutation points |
| `src/main.lua` | Modify | Replace gfx.init/gfx.quit with SafeGfx*; call persist.Load() in Init() |
| `src/ui/compact-init.lua` | Modify | Replace gfx.quit/gfx.init with SafeGfx* in SwitchViewMode + HandlePanel |
| `src/state/sequencer.lua` | Modify | Add persist.Save("volume", v) inside SetVolume() |
| `src/state/persist.lua` | Create | Load/Save functions, legacy migration, key registry |
| `src/ui/gfx-safe.lua` | Create | SafeGfxInit, SafeGfxQuit, ShowError |
| `src/config.lua` | Modify | Add `config.PREF_KEYS` list for persistence keys |

---

## Extracted Helpers (DrawMIDIIsland)

```lua
-- views.DrawKeyboardShortcutOverlay(char) → void
--   Lines 594-615: Escape cancel, piano roll keyboard shortcuts (pointer/eraser)
-- views.DrawToolModeRow(ch_x, b_w, b_h, header_y) → void
--   Lines 757-794: 3 tool buttons (pointer/pencil/eraser) + tooltips
-- views.DrawSnapControls(presets_x, b_w, b_h, header_y) → void
--   Lines 676-755: SNAP toggle, resolution dropdown, triplet toggle
-- views.DrawPresetPanel(island_x, y, preset_w, h) → void
--   Lines 842-858: Collapsible preset panel wrapper + background
```

Remaining body stays in DrawMIDIIsland: revision check, CH/PRESETS header, island background, layout math, right-area drawing, mouse events, scrollbar.

---

## Persistence Key Registry

| Key | Source | Range |
|-----|--------|-------|
| `root_index` | `config.state` | 1-12 |
| `scale_index` | `config.state` | 1-21 |
| `octave` | `config.state` | 0-8 |
| `chord_mode_index` | `config.state` | 1-4 |
| `inversion_index` | `config.state` | 1-4 |
| `volume` | `sequencer_store` | 0-100 |
| `color_mode` | `ui_store` | "grade"\|"flat" |

---

## Testing Strategy

| Layer | Approach |
|-------|----------|
| Existing tests (382) | All must pass unchanged — pure refactors + additive code only |
| Static verification | Code review against spec scenarios for each deliverable |
| Manual REAPER | Change root/scale/octave → close script → reopen → verify values restored |
| Manual REAPER | Store legacy ExtState → launch → verify migration + legacy intact |

---

## Migration Plan (Namespace Unification)

1. On first launch after update:
   - `persist.Load()` checks `GROVE_Scale_Runner` keys first (canonical)
   - If key missing, reads from legacy `GROVE_FL_MIDI` → migrates to `GROVE_Scale_Runner`
   - Legacy `GROVE_FL_MIDI` keys are NEVER deleted
2. All NEW writes use `GROVE_Scale_Runner` exclusively (views.lua + main.lua already do)
3. `preset-browser.lua` writes need updating from `GROVE_FL_MIDI` → `GROVE_Scale_Runner`

---

## Open Questions

- None — design is complete. Proceed to task planning.
