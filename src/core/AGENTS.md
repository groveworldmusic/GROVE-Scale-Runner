# src/core/ — Domain Logic

Core domain logic: MIDI operations, keyboard interception, sequencer loop, progression management, slot UI rendering, API guards, and snap grid.

## File Overview

| File | LOC | Functions | Dependencies | Reaper API? |
|------|-----|-----------|--------------|-------------|
| midi.lua | 232 | 9 exported + 3 fields + getter/setter | config, state.compact, state.sequencer, state.midi, state.ui, state.island, state.preferences, core.api-guard | Yes |
| keyboard.lua | 105 | 5 exported | config, core.midi, state.midi, state.preferences, core.sequencer, core.api-guard | Yes |
| sequencer.lua | 131 | 2 exported | state.sequencer, core.midi, core.progression | Yes |
| progression.lua | 33 | 5 exported | state.sequencer | No |
| slots.lua | 313 | 2 public + 2 private | config, state.drag, state.sequencer, state.ui, ui.helpers, ui.theme, ui.colors, ui.format, core.midi, core.progression | No (gfx.* only) |
| api-guard.lua | 44 | 3 exported | reaper.* (CheckAPI, AssertAPIs) | Yes |
| snap.lua | 26 | 1 exported | None (pure function) | No |

## Core Dependency Graph

```
progression.lua ──→ state.sequencer
      │
      ▼
sequencer.lua ──→ midi.lua ──→ sequencer_store (state)
                      │
         keyboard.lua ┘─────────► midi_store (state)
              │                        ▲
              ├─── preferences_store    │
              └─── core.sequencer ──────┘
                     (keyboard.Stop)

slots.lua ──→ lazy require ──→ ui.components

api-guard.lua ──→ (consumed by midi, keyboard, main)
snap.lua ──→ (pure function, consumed by ui)
```

**⚠️ REGLA CRÍTICA**: `sequencer.lua` SÍ requiere `midi.lua`. La regla real es: `midi.lua` NO puede requerir `sequencer.lua` — usa `sequencer_store` (state) para leer volumen y estado. La dependencia `sequencer → midi` es one-way y segura.

**⚠️ keyboard → sequencer**: `keyboard.lua` requiere `core.sequencer` (para shortcuts globales). NO hay ciclo porque `sequencer.lua` no requiere `keyboard.lua`.

---

## API Documentation

### midi.lua — 9 exported functions + 3 module fields

```lua
-- midi.GetMidiNote(root_idx, scale_idx, degree_idx, octave_val) → number (0-127)
--   Pure function. Calculates MIDI note from scale degree, root, and octave.
--   Formula: (octave+1)*12 + (root-1) + floor((deg-1)/n)*12 + intervals[((deg-1)%n)+1]
--   Result clamped via math.max(0, math.min(127, ...)).
--   Uses api_guard.ClampIndex for input validation.
-- Params:
--   root_idx:   number (1-12) — index into config.NOTE_NAMES
--   scale_idx:  number (1-21) — index into config.SCALES
--   degree_idx: number (1-N)  — wraps around per scale length
--   octave_val: number (0-8)  — MIDI octave
-- Depends on: config.SCALES, config.NOTE_NAMES

-- midi.SendMidi(note, on, velocity?, force?) → void
--   Sends MIDI note on/off via reaper.StuffMIDIMessage. Applies sequencer_store.GetVolume()
--   to note-on velocity. Maintains ref-counted active_notes in midi_store.
-- Params:
--   note:     number (0-127)
--   on:       boolean — true=0x90 (note-on), false=0x80 (note-off)
--   velocity: number? (0-127) — defaults to 100
--   force:    boolean? — if true, sends note-off even if ref-count > 0 (for cleanup)
-- Side effects: updates midi_store active notes (ref-count), last note played, draw timer

-- midi.TriggerChord(degree, on, ctx?, velocity?, inversion_index?) → number[]
--   Plays all notes of the current chord mode at the given degree.
--   ctx overrides current state (used by keyboard for temp_ctx octave offset).
--   Applies inversion via midi.InvertChord() if inversion_index > 1.
-- Params:
--   degree:          number — scale degree (1-N)
--   on:              boolean
--   ctx:             table? — optional override with root_index, scale_index, chord_mode_index, octave
--   velocity:        number? — applied to each SendMidi call
--   inversion_index: number? — 1=Base, 2=1st, 3=2nd, 4=3rd (default from preferences_store)
-- Returns: number[] — MIDI note numbers sent (post-inversion)
-- Side effects: calls SendMidi for each chord offset (config.CHORD_MODES)

-- midi.InvertChord(notes, inv_idx, direction) → number[]
--   Pure function. Reorders chord notes by moving N notes up/down an octave.
-- Params:
--   notes:     number[] — MIDI note numbers
--   inv_idx:   number (1-4) — 1=Base, 2=1st, 3=2nd, 4=3rd
--   direction: number (0|1) — 0=UP (standard), 1=DN (notes move down)
-- Returns: number[] — inverted note numbers, sorted (DN only)

-- midi.AllNotesOff(force?) → void
--   CC 123 + explicit note-offs for every held note in key states and mouse pad.
--   Clears midi_store active notes. Does NOT call sequencer.Stop().
-- Params:
--   force: boolean? — if true, bypasses ref-count gate (used in cleanup)
-- Side effects: sends MIDI note-offs, clears all key/mouse-pad state, clears active notes
-- Note: caller must also call sequencer.Stop() for full silence (avoid circular dep)

-- midi.ExportToMidi() → void
--   Creates MIDI items in REAPER from the current progression. Uses last filled slot
--   to determine item length. Validates track/item/take pointers via ValidatePtr.
--   Fails gracefully if no track selected or pointer invalid.
-- Side effects: creates MIDI take, inserts notes, calls MIDI_Sort and UpdateArrange

-- midi.ToggleIsland() → void
--   Toggles MIDI island expanded/collapsed via gfx.quit()+gfx.init() (720×497 ↔ 720×793).
--   Early return if docked (ui_store.GetDockedMode()). Saves pre-toggle state to island_store.
--   Sets island_transitioning flag during window recreation.
-- Side effects: destroys and recreates the GFX window

-- midi.GetMidiChannel() → number (1-16)
-- midi.SetMidiChannel(ch) → void
--   Gets/sets the internal MIDI channel. Internal via _midi_channel closure.

-- Module fields:
--   midi_island_expanded: bool — tracks island expanded/collapsed state
--   midi_island_toggled:  bool — set true after toggle, consumed by MainLoop
```

### keyboard.lua — 5 exported functions

```lua
-- keyboard.HandleKeyboard() → void
--   Reads JS_VKeys_GetState for each tracked key. Triggers note-on for newly pressed keys,
--   note-off for releases. Uses module-level temp_ctx (line 16) for octave-override per map entry.
--   Reads preferences from preferences_store (root/scale/octave/chord/inversion).
--   Applies velocity humanization: (85 + math.random(30)) when midi_store.GetUseVelocity().
-- Side effects: calls midi.TriggerChord / midi.SendMidi, updates key states in midi_store
-- Dependencies: preferences_store, midi_store, midi, api_guard

-- keyboard.InterceptMappedKeys(state) → void
--   Intercepts (state=true) or releases (state=false) only VKEY_MAP keys via JS_VKeys_Intercept.
--   Unmapped keys pass through to REAPER normally.
-- Params:
--   state: boolean — true=intercept, false=release

-- keyboard.IsPluginOrScriptFocused() → boolean
--   Checks if our script window (gfx.hwnd) or an actively focused plugin has focus.
--   GetFocusedFX2() bitmask: bits 1/2 = track/take FX focused, bit 4 = unfocused window.
-- Returns: boolean

-- keyboard.CheckFocus() → void
--   Throttled to 0.2s. Intercepts on focus gain, releases + midi.AllNotesOff() on focus loss.
-- Side effects: may call InterceptMappedKeys, midi.AllNotesOff

-- keyboard.Cleanup() → void
--   Releases key intercept if active. Called by main.lua's CleanupAll on script stop.
```

### sequencer.lua — 2 exported functions

```lua
-- sequencer.Stop() → void
--   Stops playback: note-offs for all held MIDI notes, resets step, progress, measure, and
--   internal clock. Sets IsPlaying = false.
-- Side effects: sends MIDI note-offs via midi.SendMidi, resets sequencer store state
-- Depends on: midi.SendMidi, seq_store (state.sequencer)

-- sequencer.Run() → void
--   Main tick (called each defer cycle). Syncs to REAPER transport (measure-based via
--   TimeMap2_timeToBeats) or internal clock (4/4, time_precise-based).
--   Advances step on measure boundary, triggers chords, catches up skipped measures
--   if frame was delayed, auto-paginates to current measure.
--   If progression is empty (GetLastFilled() == 0), calls Stop().
-- Side effects: midi.TriggerChord / midi.SendMidi, updates sequencer store state
```

### progression.lua — 5 exported functions

```lua
-- progression.Add(idx, slot) → void
--   Sets progression entry at idx and triggers flash highlight animation.
-- Params:
--   idx:  number (1-16)
--   slot: table — {degree, root_index, scale_index, octave, chord_mode_index}

-- progression.Remove(idx) → void
--   Sets progression entry at idx to nil.

-- progression.Swap(a, b) → void
--   Swaps entries at indices a and b via temporary variable.

-- progression.Clear() → void
--   Clears all 16 progression slots via seq_store.ClearProgression().

-- progression.GetLastFilled() → number (0-16)
--   Scans 16→1, returns index of last non-nil slot. Returns 0 if empty.
--   Used by sequencer.Run() for loop length and by ExportToMidi() for item length.
-- Performance: O(n) scan each call — cached by caller when called in a loop.
```

### slots.lua — 2 public + 2 private functions

```lua
-- Public:
-- m.HandleSlotInteraction(global_idx, x, y, w, h, slot, hover) → void
--   Handles right-click delete, left-click play, drag-start (8px Euclidean threshold, line 127),
--   drag-drop SWAP (source slot exists, line 149) vs NEW (from pad, line 152), and tooltips.
--   Cleans up drag state immediately after drop (lines 162-166).

-- m.DrawProgressionSlot(global_idx, x, y, w, h) → void
--   Entry point for slot rendering. Resolves ui.components lazily. Draws background, label,
--   and runs interaction handler. Also clears pending_slot_idx on mouse release outside.

-- Private:
-- DrawSlotBackground(global_idx, x, y, w, h, slot, play) → void
--   Background rect (filled or outline), playing glow, empty-state "+" hint, drop flash
--   animation, and progress bar overlay when playing. Uses lazy require("ui.components").

-- DrawSlotLabel(global_idx, x, y, w, h, slot) → void
--   Slot number (top-left), ChordLabel (center, large), RomanNumeral (below center, small).
```

### api-guard.lua — 3 exported functions

```lua
-- api_guard.CheckAPI(name) → boolean
--   Checks if a REAPER API function exists. Uses reaper.APIExists when available,
--   falls back to checking type(reaper[name]).
-- Params:
--   name: string — API function name (e.g. "JS_VKeys_GetState")

-- api_guard.AssertAPIs(checks) → boolean
--   Asserts that all required API functions exist. Shows MB with missing APIs.
-- Params:
--   checks: table — {[api_name] = "human-readable description"}
-- Returns: true if all exist, false otherwise (with error dialog)

-- api_guard.ClampIndex(idx, min, max) → number
--   Pure function. Clamps an index to valid range [min, max].
-- Params:
--   idx: number
--   min: number (default 1)
--   max: number (default 1)
-- Returns: math.floor()'d, clamped value
```

### snap.lua — 1 exported function

```lua
-- snap.SnapBeat(beat, resolution, triplet) → number
--   Pure function. Snaps a raw beat value to the nearest grid boundary.
-- Params:
--   beat:       number — raw beat position
--   resolution: number — subdivisions per whole note (1, 2, 4, 8, 16, 32); 0/nil = identity
--   triplet:    boolean? — if true, effective step = 4 / (resolution * 1.5)
-- Returns: number — snapped beat
-- Formula: step = 4 / eff_res; return math.floor(beat / step + 0.5) * step
```

---

## Patterns

### Patrón: Ref-counted Active Notes
**Contexto**: Multiple note-on events may target the same MIDI note (e.g., overlapping chord triggers from keyboard + mouse pad). A simple boolean toggles incorrectly on concurrent note-offs.
**Implementación**: `midi.lua` lines 41-68 — `midi_store.SetActiveNote(note, (cur or 0) + 1)` on note-on; decrement on note-off; `nil` when count reaches 0. `force` param in SendMidi bypasses gate for cleanup.
**Por qué**: Ensures note-off only fires when ALL triggers release the note, preventing stuck notes.
**Riesgos**: Store state leaks if caller forgets to pair note-on/note-off counts.

### Patrón: temp_ctx Reusable
**Contexto**: Each key press in `HandleKeyboard` needs a context table for `TriggerChord`, but allocating per-press is GC-heavy at 60fps.
**Implementación**: `keyboard.lua` line 16: `local temp_ctx = {}` — module-level table mutated in-place (lines 36-39) before each `TriggerChord` call.
**Por qué**: Zero-allocation hot path. The table is used synchronously so mutation is safe.
**Riesgos**: Stale state if caller stores the reference for async use.

### Patrón: Drag Threshold 8px
**Contexto**: Click-to-play and drag-to-move share the same mouse-down event. Need to distinguish a click from a drag.
**Implementación**: `slots.lua` line 127: `if math.sqrt(dx*dx + dy*dy) >= 8 then` — Euclidean distance from mouse-down origin.
**Por qué**: Prevents accidental drags from hand tremor or trackpad noise.

### Patrón: Swap vs Overwrite
**Contexto**: Dragging a slot onto another slot should swap, not overwrite. Dragging from a pad (no source slot) should create a new entry.
**Implementación**: `slots.lua` lines 148-149: `progression.Swap(SourceSlotIdx, global_idx)` vs lines 150-158: `progression.Add(...)` with degree from drag source.
**Por qué**: Swap preserves existing progression data; overwrite would lose it silently. Pads create new entries because there is no existing slot to swap.

### Patrón: Velocity Humanization
**Contexto**: Repeated notes at fixed velocity (100) sound mechanical and unnatural.
**Implementación**: `keyboard.lua` line 33: `local vel = midi_store.GetUseVelocity() and (85 + math.random(30)) or 100`.
**Por qué**: Adds ±15 random variation around 85 for organic velocity spread.

### Patrón: AllNotesOff on Focus Loss
**Contexto**: When REAPER focus shifts away from the script/plugin, held MIDI notes would hang indefinitely.
**Implementación**: `keyboard.lua`: `midi.AllNotesOff()` called by `CheckFocus` when intercept is released.
**Por qué**: Prevents stuck notes when user alt-tabs or clicks another window.

### Patrón: API Guard
**Contexto**: REAPER scripts may fail if optional APIs are missing. Need graceful validation at startup.
**Implementación**: `api-guard.lua` — `AssertAPIs` checks each API via `reaper.APIExists`, shows error dialog listing all missing dependencies.
**Por qué**: Clear error message prevents confusion about why the script doesn't load.

### Patrón: Snap Grid (Pure Function)
**Contexto**: Piano roll needs beat snapping without side effects.
**Implementación**: `snap.lua` — `SnapBeat(beat, resolution, triplet)` is a pure function using `math.floor(beat / step + 0.5) * step`.
**Por qué**: Zero side effects, easy to test, reusable anywhere.

---

## Pitfalls

> ⚠️ **Pitfall: sequencer.lua SÍ requiere midi.lua**
> **Causa**: El AGENTS.md anterior afirmaba lo contrario por miedo a dependencia circular.
> **Verdad**: `sequencer.lua` line 2: `local midi = require("core.midi")`. La dependencia real es one-way: `sequencer → midi`. `midi.lua` evita el ciclo usando `sequencer_store` (state) en vez de requerir `sequencer.lua` directamente.

> ⚠️ **Pitfall: AllNotesOff no llama Stop**
> **Causa**: `midi.AllNotesOff()` no llama `sequencer.Stop()` porque eso crearía una circular dep (sequencer → midi → sequencer).
> **Solución**: En `main.lua`, cuando se necesita silencio completo, el caller DEBE ejecutar AMBOS: `midi.AllNotesOff()` y `sequencer.Stop()`.

> ⚠️ **Pitfall: Lazy require circular en slots.lua**
> **Causa**: `slots.lua` y `ui.components` se requieren mutuamente. `components.lua` dibuja slots y llama a funciones de `slots.lua`.
> **Solución**: `slots.lua` resuelve `local components = require("ui.components")` dentro de CADA función (lazy), no al tope del módulo.

> ⚠️ **Pitfall: slots.lua usa gfx.* pero no reaper.***
> **Causa**: Los slots no tienen acceso directo a API de REAPER, pero usan `gfx.*` extensivamente.
> **Solución**: `slots.lua` solo funciona dentro del contexto GFX de REAPER. No puede testearse fuera de ese entorno.

> ⚠️ **Pitfall: config.state fallback en TriggerChord (line 94)**
> **Causa**: `local c = ctx or config.state` — si ctx no se provee, lee de `config.state` directamente.
> **Solución**: Keyboard ahora pasa `temp_ctx` con valores de `preferences_store`, pero llamadas desde sequencer aún usan `config.state`. Pendiente migrar.

---

## Cross-References

- **`src/AGENTS.md`** — main.lua lifecycle (run loop, CleanupAll), delegation rules between core/ui/state
- **`src/state/AGENTS.md`** — sequencer_store, midi_store, drag_store, compact_store, preferences_store
- **`src/ui/AGENTS.md`** — components.lua (DrawRoundedRect, lazy-required by slots.lua), helpers.lua, theme/colors/format
- **`AGENTS.md` (root)** — circular dependency map (full project), pattern glossary, project standards
