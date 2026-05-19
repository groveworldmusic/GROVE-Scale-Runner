# Design: Professional Polish

## Technical Approach

Three independent work areas executed sequentially: **A** ReaPack metadata completeness, **B** defensive hardening at every API boundary, **C** licensing & documentation infrastructure. Each is independently revertible per-area commit.

## Architecture Decisions

### A: API Guard Module

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Inline `if not reaper.JS_*` in each file | Duplicated boilerplate, 7 files to touch | ❌ |
| Single `src/api-guard.lua` module | One require, consistent error UX | ✅ |

**Rationale**: 27 distinct `JS_*` functions across 7 files. Centralizing in `api-guard.lua` with `api_guard.Exists(name)` avoids scattered checks and provides uniform "Dependency missing: js_ReaScriptAPI" errors.

### B: Dirty-Flag Scope

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Skip entire MainLoop frame | Misses timer decrements, focus checks | ❌ |
| Skip only GFX draw when no state change | Logic always runs, draw skips | ✅ |

**Rationale**: State logic (sequencer tick, keyboard, focus, timers) is cheap. GFX draw (`views.DrawFullView`, `views.DrawDockedTransportBar`) is the expensive path. Flag set on key press, mouse click, sequencer step, or explicit `gfx.update()` request.

### C: Index Clamping

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Clamp at every array access | ~40 change sites, easy to miss | ❌ |
| Clamp helper in config.lua, used in all SET paths | Single point per index | ✅ |

**Rationale**: ~90 references to `config.state.*_index`. Adding `config.ClampIndex(val, min, max)` and applying it in the SET paths (dropdown callbacks, compact-menu result handlers, preset-browser loaders) covers all downstream reads.

### D: Undo Block Scope

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Per-item undo blocks | Overkill for single operation | ❌ |
| Single `Undo_BeginBlock/EndBlock` around ExportToMidi | Correct, minimal | ✅ |

### E: License Header Strategy

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Manual edit 44 files | Error-prone, inconsistent | ❌ |
| Single MIT template applied to all 44 files | Consistent, auditable | ✅ |

## Data Flow

```
Init()
 ├── api_guard.Check()          ← NEW: validates js_ReaScriptAPI presence
 ├── persist.Load(config.state)
 ├── clamp persisted indices     ← NEW: clamp root/scale/chord indices after load
 └── gfx.init() → MainLoop

MainLoop()
 ├── sequencer.Run()            ← always runs
 ├── keyboard.HandleKeyboard()  ← always runs
 ├── SetDirty() on state change ← NEW: key press, mouse, sequencer step
 ├── if dirty: views.Draw*()    ← NEW: skip if not dirty
 └── defer(MainLoop)

ExportToMidi()
 ├── Undo_BeginBlock()          ← NEW
 ├── create track, MIDI item
 ├── insert notes, MIDI_Sort
 ├── Undo_EndBlock("Export Progression", -1)  ← NEW
 └── UpdateArrange()
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/api-guard.lua` | Create | `api_guard.Exists(name)`, `api_guard.CheckAll()` — centralized API validation |
| `src/config.lua` | Modify | Add `ClampIndex(val, min, max)`, n_* constants for array sizes |
| `src/main.lua` | Modify | Expand `@provides` to 44 files, add `@changelog`, dirty-flag in MainLoop, `api_guard.Check()` in Init, "GROVE SCALE RUNNER" name normalization |
| `src/core/midi.lua` | Modify | Undo blocks around ExportToMidi, nil guard on GetTrack, nil guard on GetSelectedTrack |
| `src/core/sequencer.lua` | Modify | Nil guards on GetPlayState, GetPlayPosition2, Master_GetTempo, TimeMap2_timeToBeats |
| `src/core/keyboard.lua` | Modify | API guard on JS_VKeys_GetState/Intercept, validate JS_Window_GetFocus return |
| `src/ui/lice.lua` | Modify | API guard on all JS_LICE_* calls (already encapsulated here) |
| `src/ui/compact-init.lua` | Modify | API guards on all JS_Window_* calls in FindTransportWindow, SwitchViewMode, HandlePanel |
| `src/ui/compact-intercept.lua` | Modify | API guards on JS_WindowMessage_* calls |
| `src/ui/positioning.lua` | Modify | Nil guards on JS_Window_GetRect/GetClientSize |
| `src/core/slots.lua` | Modify | Bounds-clamp root/scale/chord indices before array access |
| `src/ui/pads.lua` | Modify | Bounds-clamp indices in TriggerChord call |
| `src/ui/piano.lua` | Modify | Bounds-clamp root_index in click handler |
| `src/ui/views.lua` | Modify | Bounds-clamp indices in dropdown callbacks and carousel wraparounds |
| `src/ui/compact-init.lua` (panel) | Modify | Bounds-clamp indices in dropdown callbacks |
| `src/ui/compact-menu.lua` | Modify | Bounds-clamp indices from gfx.showmenu result |
| `src/ui/compact-bar.lua` | Modify | Bounds-clamp before array access |
| `src/ui/preset-browser.lua` | Modify | Bounds-clamp on loaded preset values |
| `LICENSE` | Create | MIT license text |
| `CHANGELOG.md` | Create | Unreleased section, per-version changelog |
| `CONTRIBUTING.md` | Create | PR workflow, code standards |
| `All 44 src/*.lua` | Modify | Add MIT license header block |

## Interfaces / Contracts

### api_guard.lua

```lua
-- api_guard.Exists(name) → boolean
--   Checks if reaper[name] is callable. No error, just returns false.

-- api_guard.Check() → void
--   Hard fail: reaper.MB() if js_ReaScriptAPI missing. Called once in Init().
```

### config.lua additions

```lua
config.N_ROOT_NAMES = 12    -- #NOTE_NAMES
config.N_SCALES = 21        -- #SCALES
config.N_CHORD_MODES = 4    -- #CHORD_MODES
config.N_SUBDIVISIONS = 6   -- #SUBDIVISION_MODES
config.N_INVERSIONS = 4     -- #INVERSION_MODES

function config.ClampIndex(val, n)
    return math.max(1, math.min(n, math.floor(val or 1)))
end
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Static | @provides count = 44 | Visual audit after edit |
| Static | All JS_* calls guarded | `rg 'reaper\.JS_' src/ \| grep -v 'api_guard\|Exists'` |
| Static | All config.state.*_index clamped | `rg 'config\.state\.\w+_index' src/` confirm all SET paths use ClampIndex |
| Static | Dirty-flag set on every state mutation | Trace MainLoop: key/mouse/sequencer paths set dirty |

## Migration / Rollout

No migration required. Each area commits independently so revert is per-area:
- **A**: revert main.lua header + @provides
- **B**: revert api-guard.lua + all guards/clamps
- **C**: delete LICENSE + CHANGELOG.md + CONTRIBUTING.md, revert headers

## Open Questions

- [ ] Dirty-flag granularity: one combined flag or per-component (keyboard vs. sequencer vs. mouse)?
