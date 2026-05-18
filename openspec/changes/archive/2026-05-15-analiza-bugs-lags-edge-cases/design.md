# Design: Codebase Bug, Lag & Edge-Case Fix

## Technical Approach

Five independent phases executed as a feature-branch chain. Each phase is zero-risk: no API changes, no new capabilities, no state schema evolution. Every fix follows the project's existing patterns (ref-counted notes, lazy require, event-bus consumables). No new stores or modules — only targeted mutations to existing functions.

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5
(HIGH perf)  (MEDIUM)     (LOW)        (issues)    (migration)
```

The delta between mainline state stores (`persist.Load/SyncFromState` in main.lua lines 341-344) and the preference store is already handled — Phase 5 is pure find-&-replace `config.state.X` → `store.GetX()`, not schema migration.

## Architecture Decisions

### Decision: Frame-counter defer (not reaper.defer) for zero-duration note-off

| Option | Tradeoff |
|--------|----------|
| `reaper.defer` callback | Cascading defer chains, harder to cancel, breaks MainLoop sync |
| **Frame counter in MainLoop** | One-shot decrement, no new closures, zero GC, naturally synchronized |

**Choice**: Add `slot_click_noteoff_counter` module field in `slots.lua`. Increment on click-play, decrement each MainLoop call in `DrawProgressionSlot`. When counter hits 1 → fire note-off. The counter lives in `slots.lua`'s module scope, not a store, because it's a UI timing concern local to one module.

### Decision: Cache JS_VKeys_GetState once per frame, not per-key

Current code calls `reaper.JS_VKeys_GetState(0)` 28 times per frame (once per `VKEY_MAP` entry). The function returns a snapshot — same value every call within one frame.

**Choice**: Move the call outside the `for k_code, state in pairs(...)` loop in `keyboard.HandleKeyboard()`. Assign to local variable, check `nil` once, reuse. Zero behavioral change — same exact data.

### Decision: Pre-computed degree lookup vs pairs() iteration in pads

`pads.lua` iterates `midi_store.GetKeyStates()` (28 entries) for each of 7 pads per frame → 196 iterations worst-case.

**Choice**: Compute `active_degrees` lookup table once per DrawPerformanceArea call outside the pad loop. `active_degrees[degree]` → boolean. Each pad checks `active_degrees[degree]` O(1). Store the table in `pads.lua` module scope, rebuild it at the top of the DrawPerformanceArea entry point. Cost: one O(28) pass per frame instead of 7×O(28).

### Decision: Revision counter for piano active_mod12 cache

`piano.lua` rebuilds `active_mod12` every frame via `pairs(midi_store.GetActiveNotes())`. Active notes change only on note-on/note-off events (~50/frame max).

**Choice**: Add `active_notes_revision` to `midi_store` as a mono-increasing integer. `midi.lua`'s `SendMidi` increments it on each state change. `piano.lua` stores `cached_active_mod12` + `cached_active_revision` at module level, rebuilds only when store revision diverges.

### Decision: silent clamp (no ShowConsoleMsg)

`api_guard.ClampIndex` floods the REAPER console on every boundary hit during normal operation (dropdown wraps, scroll wraps). This is debug noise in a production script.

**Choice**: Remove the `ShowConsoleMsg` call entirely. Keep clamping behavior unchanged. The function's return value is already correct — the console log adds zero value at runtime.

## Data Flow

No data flow changes. All fixes are local to individual functions with no cross-module data path alterations. Example:

```
Before: HandleKeyboard → for each key: JS_VKeys_GetState(0) × 28
After:  HandleKeyboard → vk_state = JS_VKeys_GetState(0) × 1 → for each key: reuse vk_state
```

The only new "data" is the frame-counter in `slots.lua` and the revision counter in `midi_store`:

```
SendMidi() ──► midi_store.SetActiveNote() ──► midi_store.SetActiveNotesRevision(rev+1)
piano.lua   ──► cached_revision == rev? skip : rebuild active_mod12
```

## File Changes

### Phase 1 — HIGH perf + MEDIUM bug

| File | Action | Description |
|------|--------|-------------|
| `src/core/keyboard.lua` | Modify | Hoist `reaper.JS_VKeys_GetState(0)` outside the `for k_code, state in pairs()` loop (line 22→22a). Assign to `local vk_state` before loop. |
| `src/core/slots.lua` | Modify | Add `local slot_click_noteoff_counter = 0` module field. In `HandleSlotInteraction` left-click branch (line 189-191): set counter to 2, call only `TriggerChord(key, true)`. In `DrawProgressionSlot` (line 283): if `slot_click_noteoff_counter > 0`, decrement, and when it hits 1 call `TriggerChord(key, false)` for the pending slot. |

### Phase 2 — MEDIUM remaining

| File | Action | Description |
|------|--------|-------------|
| `src/ui/pads.lua` | Modify | Add `local active_degrees_cache = {}` module field. Add function `m.ComputeActiveDegrees()` called at top of each draw frame (in DrawPerformanceArea in views.lua). Replace `for _, state in pairs(...)` inner loop (line 32) with `active_degrees_cache[degree]` lookup. |
| `src/core/keyboard.lua` | Modify | Replace literal `0` on line 23 with module-level `local key_state_buffer = 0`. Pass `key_state_buffer` to `JS_VKeys_GetState`. |
| `src/state/preferences.lua` | Modify | Add `local save_counter = 0` module field. Add `m.TickSaveDebounce()` called from MainLoop. Setters increment counter but skip `persist.Save` unless `save_counter >= 3` frames since last save. |

### Phase 3 — LOW items

| File | Action | Description |
|------|--------|-------------|
| `src/ui/piano.lua` | Modify | Add `cached_active_mod12` + `cached_active_revision` module fields. Check `midi_store.GetActiveNotesRevision()` before rebuilding `active_mod12` table. |
| `src/state/midi.lua` | Modify | Add `active_notes_revision = 0` to state. Add `GetActiveNotesRevision()` getter. `SetActiveNote()` increments it. |
| `src/ui/dropdown.lua` | Modify | Hoist `local function GetFitText(str, max_w, f_size)` to module level (before `m.DrawDropdown`). Remove inner function definition. Keep logic identical. |
| `src/core/midi.lua` | Modify | Replace `local notes = {}` (line 91) with pre-allocated table. `midi.chord_note_buffer = {}` — reuse via `for i=1,#notes do buffer[i] = nil end`. Make `midi_channel` configurable via `reaper.GetExtState` with `preferences_store` fallback. |
| `src/core/slots.lua` | Modify | Add `cached_sub_idx` module field + `cached_sub_revision`. Cache subdivision index reads in `DrawSlotBackground` (line 71), recompute only when preferences_store changes. |
| `src/ui/layout.lua` | Modify | Add `function m.IsScaleValid() return _S > 0 end` guard. Expose as public so consumers can skip UX/UY/US when scale is not initialized (compact/docked modes). |
| `src/core/api-guard.lua` | Modify | Remove `reaper.ShowConsoleMsg` call from `ClampIndex` (lines 48-52). |

### Phase 4 — Known issues

| File | Action | Description |
|------|--------|-------------|
| `src/ui/views.lua` | Modify | Issue #6 (line 681-683): replace `gfx.triangle` undraw with proper left-pointing triangle drawn via `gfx.triangle` but sized/colored to match theme. The U+25C4 glyph is unnecessary — the triangle approach IS the fix, just needs visual polish. Verify triangle renders correctly in all dock modes. |
| `src/ui/views.lua` | Modify | Issue #9 (line 243): fix octave dropdown `open_up` parameter. The dropdown currently passes `oct_open_up` based on `y_start > gfx.h / 2` but the octave island is in the top half of the screen — should be `false` (open down). |

### Phase 5 — Migration

| File | Action | Description |
|------|--------|-------------|
| Source-wide (~22 refs) | Modify | Replace all `config.state.view_offset_x`, `config.state.view_offset_y`, `config.state.use_scroll`, `config.state.root_index`, `config.state.scale_index`, `config.state.octave`, `config.state.chord_mode_index` references with corresponding store getter pattern. |
| `src/config.lua` | Modify | Remove migrated keys from `config.state` block (lines 67-106). Keep constants (SCALES, CHORD_MODES, VKEY_MAP, NOTE_NAMES). |

## Interfaces / Contracts

```lua
-- NEW: midi_store
function m.GetActiveNotesRevision() return midi_state.active_notes_revision end
-- SetActiveNote() internally increments revision

-- NEW: midi.lua (configurable channel)
-- midi.midi_channel is now loaded from ExtState on init:
--   local ch = reaper.GetExtState("GROVE_Scale_Runner", "midi_channel")
--   if ch ~= "" then midi.midi_channel = tonumber(ch) or 1 end

-- NEW: slots.lua (deferred note-off)
local slot_click_noteoff_counter = 0
-- Incremented in HandleSlotInteraction on click-play
-- Decremented in DrawProgressionSlot; fires note-off at counter == 1

-- NEW: preferences.lua (debounce)
local save_debounce_counter = 0
-- m.TickSaveDebounce() decrements counter each frame; persist.Save() only fires
-- when counter <= 0 on the setter call.

-- NEW: layout.lua guard
function m.IsScaleValid() return _S > 0 end
-- Call before UX/UY/US when not in DrawFullView context
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Manual — Phase 1 | JS_VKeys_GetState hoisting | Open REAPER, verify no stuck keys, verify key response identical to before. Open ReaScript console, confirm no errors. |
| Manual — Phase 1 | Zero-duration note fix | Click a slot. Verify MIDI note plays for ~2 frames (~33ms) instead of zero-duration glitch. Listen for audible click artifact. |
| Manual — Phase 2 | Pad performance | Wire `reaper.ShowConsoleMsg` with frame counter. Verify pad hover iteration count drops from 196 to 7+28 per frame. |
| Manual — Phase 3 | Piano active note cache | Play keyboard chords. Verify piano display updates within 1 frame. No stale highlights. |
| Manual — Phase 3 | Silent clamp | Trigger boundary condition (e.g., scroll past scale index 21). Verify no console messages appear. |
| Manual — Phase 4 | Undock button | Dock. Verify triangle renders correctly. Click undock. Verify window floats. |
| Manual — Phase 5 | Migration | Launch after Phase 5. Verify all preferences load correctly. Verify no `nil` field errors. |

## Migration / Rollout

Feature-branch chain per proposal:

```
main ← Phase1 ← Phase2 ← Phase3 ← Phase4 ← Phase5
```

Each phase targets the previous phase's branch (PR #2 targets PR #1 branch, etc.). No migration needed between phases because each is a subset of changes that don't overlap files except Phase 5 (config.lua cleanup touches no new logic).

Rollback: `git revert <phase-merge>` per phase.

## Open Questions

None. Every item has a clear, bounded fix verified by reading the source code.
