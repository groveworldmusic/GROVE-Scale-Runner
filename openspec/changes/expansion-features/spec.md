# Expansion Features — Delta Specs

**Change name**: expansion-features
**Mode**: hybrid (engram + filesystem)

---

## Summary

| # | Domain | Type | Path |
|---|--------|------|------|
| P1 | color-themes | NEW full spec | `openspec/specs/color-themes/spec.md` |
| P2 | key-mapping | NEW full spec | `openspec/specs/key-mapping/spec.md` |
| P3 | midi-input-recording | NEW full spec | `openspec/specs/midi-input-recording/spec.md` |
| — | midi-island | DELTA (header additions) | `openspec/changes/expansion-features/specs/midi-island/spec.md` |
| — | note-store | DELTA (origin + open-note tracking) | `openspec/changes/expansion-features/specs/note-store/spec.md` |

---

## P1: Color Themes

### Requirement
3 built-in color palettes with persistence and UI selector. Transparent to all ~37 UI consumers — `theme.colors.*` API unchanged.

### Context
`src/ui/theme.lua` defines one fixed palette. `src/ui/colors.lua` maps grade→color. No customization exists.

### Requirements
- `preferences_store` adds `theme_index` (int, 1-3, default 1) with debounced ExtState save
- `src/ui/themes.lua` exports 3 theme tables with identical-shape `colors` (18 keys) + `grade_colors[7]`
- `theme.lua` becomes loader: `theme.colors = themes[prefs.GetThemeIndex()].colors`
- Dropdown in MIDI island header between PRESETS toggle and RELOAD button

### Scenarios
- GIVEN user selects "Dark" in dropdown, WHEN frame renders, THEN `theme.colors.bg` = Dark palette.
- GIVEN no `theme_index` in ExtState, WHEN Init, THEN defaults to 1 (Current).
- GIVEN `theme_index=2` persisted, WHEN reload, THEN `SyncFromState()` restores it.

### Non-Goals
Custom themes, color picker, per-component overrides, `colors.lua` changes.

---

## P2: Configurable Keyboard Shortcuts

### Requirement
Users remap which degree/octave each keyboard key triggers without editing `config.lua`. 28 VK codes fixed — only `{deg, oct}` configurable.

### Context
`config.lua` VKEY_MAP hardcodes 28 entries (4 rows × 7 degrees). Editing source required to remap.

### Requirements
- `src/core/vkey-map.lua` loads from ExtState fallback to `config.VKEY_MAP`
- `SetVKeyMapping(vk_code, deg, oct)` serializes full map via `persist.Save`
- `keyboard.lua` imports from vkey-map instead of config
- `RebuildKeyStates()` called on every VKEY_MAP change (clears stale `midi_store.key_states`)
- Remap UI in settings panel: 4×7 grid with dropdown per key + "Reset to Defaults"
- `ResetToDefaults()` clears ExtState override, restores `config.VKEY_MAP`, rebuilds key_states

### Scenarios
- GIVEN `SetVKeyMapping(0x51, 5, 0)`, WHEN Q pressed, THEN plays degree 5.
- GIVEN persisted override, WHEN reload, THEN override used, not config default.
- GIVEN VKEY_MAP changed, WHEN save completes, THEN key_states rebuilt — no stale entries.
- GIVEN no override, WHEN `GetVKeyMap()`, THEN returns `config.VKEY_MAP`.

### Non-Goals
Per-scale maps, per-mode maps, generic action binding, MIDI learn, VK code changes.

---

## P3: MIDI Input Recording

### Requirement
Frame-by-frame polling of REAPER MIDI input buffer converts external controller play into piano roll notes with beat-accurate timing.

### Context
Script is MIDI-output only (QWERTY → MIDI notes). No external MIDI capture exists.

### Requirements
- `src/core/midi-input.lua` polls via `MIDI_GetRecentInputEvent()` each frame
- Note-on → `note_store.AddNote({pitch, start_beat, duration=0, velocity, muted=false, origin="midi-input"})`
- Timing via `reaper.time_precise()` + `Master_GetTempo()` → `TimeMap2_timeToBeats()`
- Note-off → `UpdateOpenNoteDuration(pitch, beat_diff)` fills duration in-place
- Record-arm toggle in header (armed=glow, disarmed=dim)
- `SetArmed(false)` finalizes all open (unpaired) notes
- CleanupAll → `AllNotesOff(true)` + stop polling
- Only note-on/off captured (0x90/0x80) — all other MIDI messages ignored

### Scenarios
- GIVEN record armed, WHEN C4 note-on arrives, THEN `AddNote({pitch=60, origin="midi-input"})`.
- GIVEN open note pitch 60, WHEN note-off arrives, THEN duration set to beat diff.
- GIVEN record disarmed, WHEN MIDI arrives, THEN ignored.
- GIVEN 2 unpaired notes, WHEN disarm, THEN both get positive duration.
- GIVEN tempo change mid-note, WHEN note ends, THEN start/end beats use tempo-at-event.

### Non-Goals
CC/aftertouch recording, MIDI clock sync, multi-track, MIDI learn, channel filtering, sample-accurate timing, count-in metronome, record quantize.

---

## Modified: MIDI Island Header

### ADDED Requirements
- **Theme dropdown**: between PRESETS and RELOAD, follows `DrawRoundedRect` + `ConsumeMouseClick` pattern
- **Record toggle**: next to CH selector, armed=active glow, disarmed=dim
- **Remap button**: gear icon, toggles settings modal visibility
- All 3 fit within existing header width (uses `math.floor(b_w * 0.55)` icon pattern)

## Modified: Note Store

### MODIFIED
`AddNote()` SHALL accept and preserve any `origin` value (not overwrite to `"manual"`). Default remains `"manual"`.

### ADDED
`UpdateOpenNoteDuration(pitch, new_duration)` SHALL find the most recent open note (`duration == 0`) with matching pitch and set its duration. No-op if no match.

---

## Spec Location Index

| File | Content |
|------|---------|
| `openspec/specs/color-themes/spec.md` | Full domain spec: 4 requirements, 5 scenarios, test matrix |
| `openspec/specs/key-mapping/spec.md` | Full domain spec: 4 requirements, 5 scenarios, test matrix |
| `openspec/specs/midi-input-recording/spec.md` | Full domain spec: 5 requirements, 7 scenarios, test matrix |
| `openspec/changes/expansion-features/specs/midi-island/spec.md` | Delta: 4 ADDED requirements, 4 scenarios |
| `openspec/changes/expansion-features/specs/note-store/spec.md` | Delta: 1 MODIFIED, 1 ADDED requirement, 3 scenarios |
