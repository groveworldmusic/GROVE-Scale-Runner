# Design: Expansion Features

## Technical Approach

Three independent features sequenced P1→P2→P3, sharing the finite island header width resource. Each builds on existing patterns: preference store debounce (P1), dependency inversion over config.lua (P2), frame-pooled polling in MainLoop (P3).

---

## Architecture Decisions

### Decision: Theme loading — mutate `theme.colors` reference in place

**Choice**: `theme.colors = themes[idx]` — replace the table reference on the shared module table.
**Alternatives**: Each module stores its own color reference; event bus broadcasts theme changes.
**Rationale**: Lua `require` caches the module table. Every consumer reads `theme.colors.XXX` at runtime (143 references checked, zero destructured at module level). Changing the reference on the module table is a single assignment — all consumers see new colors next frame. Zero breakage, zero coordination.

### Decision: VKEY_MAP serialization — compact Lua table output

**Choice**: Single ExtState string `"31=1,1;32=2,1;..."` format.
**Alternatives**: JSON via bundled serializer; one ExtState per entry (28 calls).
**Rationale**: ~560 bytes total — well under ExtState limits. Single string = single save call. Custom format keeps no dependencies. Lua `load("return "..str)()` for deserialization.

### Decision: VKEY_MAP conflict detection — scan + warn

**Choice**: On remap, scan all entries for target VK. If found, reject with user prompt via `reaper.MB`.
**Alternatives**: Auto-swap; silent overwrite.
**Rationale**: Silent data loss is worse than a dialog. Auto-swap is surprising. Reject + manual reassign is clearest.

### Decision: MIDI input polling — `MIDI_GetRecentInputEvent`

**Choice**: `reaper.MIDI_GetRecentInputEvent(idx, note_out, chan_out)` — frame-polled global MIDI queue.
**Alternatives**: Track-based APIs (track+item required); JS_MIDI_* (optional extension).
**Rationale**: No track dependency, no item requirement, works at any time. Queue depth (~32 events) is sufficient for real-time capture at 60fps. Falls back cleanly (poll yields nil if no events).

### Decision: Timing — `TimeMap2_timeToBeats` for beat-accurate positions

**Choice**: Convert `reaper.time_precise()` to absolute beats via `reaper.TimeMap2_timeToBeats(0, t)`.
**Alternatives**: Accumulated frame-count (drifts on dropped frames); wall-clock * BPM (ignores tempo map).
**Rationale**: Respects REAPER's tempo map and time signature changes. Frame-dropping safe — time is wall-clock, beats are tempo-map aware.

---

## Data Flow

```
P1 (Theme):
  Prefs.SetThemeIndex(n) → dirty_keys → TickSaveDebounce → persist.Save("theme_index", n)
  theme.SetThemeIndex(n) → theme.colors = themes[n]
  ALL consumers: theme.colors.xxx next frame → new color renders

P2 (Key Remap):
  Gear btn → modal overlay → cell click → gfx.getchar() → vkey_map.SetEntry(vk, deg, oct)
  → midi_store.ClearKeyStates() → re-init key_states from new map
  → keyboard.InterceptMappedKeys(false) + (true) → HandleKeyboard reads new map

P3 (MIDI Input):
  REC armed → midi_input.Poll() each frame
  → MIDI_GetRecentInputEvent(0, note, chan) → parse note-on/off
  → time_precise() + TimeMap2_timeToBeats → beat
  → AddNote() / UpdateOpenNoteDuration() → note-store
  → notes appear in piano roll next redraw
```

---

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/themes.lua` | Create | 3 palette tables (Current/Dark/High Contrast) + theme.SetThemeIndex() |
| `src/ui/theme.lua` | Modify | Remove static colors table; import themes.lua; delegate colors via `theme.colors = themes[idx]` |
| `src/state/preferences.lua` | Modify | Add `theme_index` key (default 1), getter/setter, SyncFromState, Init |
| `src/state/persist.lua` | Modify | Add `theme_index` to PREF_KEYS |
| `src/config.lua` | Modify | Add `theme_index` to `config.state` defaults and PREF_KEYS |
| `src/core/vkey-map.lua` | Create | Load/save VKEY_MAP from ExtState, GetEntry/SetEntry/ResetToDefaults, serialization helpers |
| `src/core/keyboard.lua` | Modify | Replace `config.VKEY_MAP` → `vkey_map.GetVkeyMap()` (2 references); add `RebuildKeyStates()` helper |
| `src/core/midi-input.lua` | Create | Poll REAPER MIDI input, convert to notes, open-note tracking, timeout safety |
| `src/ui/midi-island/header.lua` | Modify | Add 3 controls: REC toggle (next to CH), THEME button (between PRESETS+SAVE), REMAP gear (between SYNC+SNAP) |
| `src/ui/midi-island/input.lua` | Modify | Add REMAP modal overlay drawing + keyboard capture |
| `src/main.lua` | Modify | Add `midi_input.Poll()` in MainLoop after HandleKeyboard; apply theme after SyncFromState in Init |
| `src/state/note-store.lua` | Modify | `AddNote`: accept custom `origin` param (default `"manual"`). Add `UpdateOpenNoteDuration(pitch, dur)` |

---

## Interfaces / Contracts

```lua
-- src/ui/themes.lua
local themes = {
    [1] = { bg={...}, text={...}, ... },  -- Current
    [2] = { bg={...}, text={...}, ... },  -- Dark
    [3] = { bg={...}, text={...}, ... },  -- High Contrast
}
function themes.SetThemeIndex(idx) → void  -- sets theme.colors on theme module

-- src/core/vkey-map.lua
function vk.GetVkeyMap() → table  -- {[vk_code]={deg, oct}}
function vk.SetEntry(vk_code, deg, oct) → void
function vk.ResetToDefaults() → void
function vk.LoadFromPersist() → void  -- called at init

-- src/core/midi-input.lua
function mi.SetArmed(bool) → void
function mi.GetArmed() → bool
function mi.Poll() → void  -- called each frame from MainLoop
function mi.Cleanup() → void  -- close all open notes, AllNotesOff

-- src/state/note-store.lua extension
function ns.AddNote(note)  -- accepts note.origin, defaults "manual"
function ns.UpdateOpenNoteDuration(pitch, new_duration) → void  -- find most recent open note by pitch, set duration
```

---

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Unit | vkey-map serialization | Round-trip: serialize 28 entries → string → deserialize → match original |
| Unit | theme.SetThemeIndex | Verify theme.colors reference changes; verify all 40+ keys exist in each theme |
| Unit | Note-store AddNote origin | Insert with `origin="midi-input"`, verify preserved; insert without, verify `"manual"` |
| Unit | Note-store UpdateOpenNoteDuration | Insert with dur=0, update, verify; no-op on missing pitch |
| Integration | MainLoop polling hook | Arm → Poll → verify notes added to store; disarm → verify open notes closed |
| E2E | Record → piano roll appears | Arm via header click → send MIDI input → verify note block rendered |

---

## Migration / Rollout

No migration needed. `theme_index` defaults to 1 (Current) if absent. VKEY_MAP defaults to `config.VKEY_MAP` if no ExtState key found. MIDI recording is opt-in (click REC). Each P is independently revertible via `git revert`.

---

## Open Questions

- [ ] Exact header spacing: REC toggle may need PRESETS width trimmed from 1.2× to 1.0× to fit all 3 new controls. Validate pixel math in implementation.
- [ ] REMAP modal: dedicated overlay panel (like preset browser) or inline dropdown menu? Proposal suggests "dropdown-based remap" which is simpler but less ergonomic for 28 keys.
- [ ] REAPER `MIDI_GetRecentInputEvent` — confirm exact signature and return types. May need version guard.
