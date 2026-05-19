# Proposal: Expansion Features

## Intent

Add 3 quality-of-life features to GROVE Scale Runner: configurable color themes (accessibility + personalization), configurable keyboard shortcuts (user ergonomics), and MIDI input recording (capture external controller play into piano roll). These address the top missing pieces after the structural refactor.

## Scope

### In Scope
- P1: 3 built-in themes (Current/Dark/High Contrast) with UI selector + persistence
- P2: Remappable VKEY_MAP stored in preferences with basic remap UI
- P3: Real-time MIDI input recording into piano roll with record-arm toggle

### Out of Scope
- Custom user-created themes (P1: 3 built-in only)
- Full key-binding editor (P2: VKEY_MAP remap, not generic action system)
- MIDI CC/aftertouch recording (P3: note-on/off only)
- Non-MIDI input sources (computer keyboard as MIDI input)

## Capabilities

### New Capabilities
- `color-themes`: Built-in theme switching with 3 presets, persistence, and UI selector
- `key-mapping`: User-remappable VKEY_MAP persisted via ExtState with basic remap UI
- `midi-input-recording`: Real-time MIDI input capture from REAPER into piano roll notes

### Modified Capabilities
- `midi-island`: Header UI additions (theme dropdown, remap button, record-arm toggle)
- `note-store`: Programmatic note insertion during recording (non-UUID path)

## Approach

**P1**: Extract theme colors from `theme.lua` into `themes.lua` with 3 presets. `theme.lua` becomes a loader reading `theme.current = themes[prefs.GetThemeIndex()]`. Theme index persisted via existing debounced `preferences_store` pattern. UI: dropdown in MIDI island header. `colors.lua` unchanged.

**P2**: New `vkey-map.lua` loads VKEY_MAP from ExtState, falls back to `config.VKEY_MAP`. `keyboard.lua` imports from vkey-map instead of config. Persistence via serialized 28-entry table. UI: dropdown-based remap in settings. Risk: `key_states` must rebuild when VKEY_MAP changes.

**P3**: New `midi-input.lua` polls REAPER for incoming MIDI each frame. Integration in MainLoop: capture note-on/off, convert to `{pitch, start_beat, duration, velocity, muted}`. Timing via `reaper.time_precise()` + `Master_GetTempo()`. Record arm in island header. Stuck notes on cleanup handled via existing `AllNotesOff` pattern.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/themes.lua` | New | 3 theme presets + dynamic loader |
| `src/ui/theme.lua` | Modified | Becomes thin loader from themes.lua |
| `src/core/vkey-map.lua` | New | Loads/remaps VKEY_MAP from persist |
| `src/core/keyboard.lua` | Modified | Imports from vkey-map instead of config |
| `src/core/midi-input.lua` | New | REAPER MIDI polling + note conversion |
| `src/state/preferences.lua` | Modified | Adds theme_index key |
| `src/main.lua` | Modified | MainLoop integration for P3 |
| `src/ui/midi-island/header.lua` | Modified | Theme dropdown, remap button, record toggle |
| `src/state/note-store.lua` | Modified | AddNote for programmatic insertion |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| P2: key_states stale after VKEY_MAP change | Med | Rebuild key_states on VKEY_MAP write |
| P3: Stuck notes on deactivate/cleanup | Med | Existing AllNotesOff pattern + stop polling on cleanup |
| P3: Timing drift | Low | Use reaper.time_precise() per frame, not accumulated |
| Cross-batch merge conflict (keyboard.lua) | Med | P2 touches keyboard.lua — sequence after other batches |
| Serialization of 28-entry VKEY_MAP table | Low | JSON via Lua simple serializer or ExtState per entry |

## Rollback Plan

Revert individual features: `git revert` commits per P. No breaking schema changes — old ExtState keys ignored. P1/P2/P3 are independent; P3 rollback does not affect P1/P2.

## Dependencies

- REAPER APIs: `GetTrackMIDIInput`, `MIDI_GetEvt`, `time_precise`, `Master_GetTempo` (P3)
- Existing: `persist.Save`, `preferences_store.TickSaveDebounce`, barrel pattern

## Success Criteria

- [ ] P1: Switch between 3 themes via dropdown, persists across reload, all colors apply correctly
- [ ] P2: Remap any key to different degree/octave, persists, key_states function correctly after remap
- [ ] P3: Record external MIDI controller play into piano roll, notes appear with correct timing/pitch, stuck notes impossible on deactivate
