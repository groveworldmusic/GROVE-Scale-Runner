# Proposal: Presets Full Features

## Intent

The preset browser is functional (Phase 1-2) but lacks discoverability and polish. 9 remaining features — stats, tags, preview, thumbnails, badges, versioning, auto-save, dark/light sync, pack export — turn it from a file picker into a productive tool. Each feature is shallow; together they multiply preset value.

## Scope

### In Scope (4 phases, 9 features)

- **P1 Foundation**: Stats de Uso (#4), .grove v3 with Tags+Metadatos (#3), Notas por Preset (#6)
- **P2 Media**: Preview Auditivo (#1), Miniaturas de Patrón (#8)
- **P3 UX**: Badges por Uso (#7), Auto-save por Slot (#2), Versionado Automático (#9), Dark/Light Sync (#10)
- **P4 Sharing**: Export/Import Packs (#5)

### Out of Scope

- Cloud sync or remote preset storage
- MIDI learn or hardware controller mapping for presets
- Preset comparison/diff tool
- Renaming `config.state.xxx` remnant keys (view_offset_x/y)

## Capabilities

### New Capabilities
- `preset-stats`: tracks usage count per preset, persisted across sessions
- `preset-metadata`: .grove v3 format with key, bpm, genre, tags, notes fields
- `preset-audio-preview`: ghost MIDI playback on hover + Ctrl+Space trigger
- `preset-thumbnails`: 8×8 note-density mini-map rendered per preset
- `preset-badges`: Veteran/Regular/New badges based on usage stats
- `preset-autosave`: auto-saves snapshot per progression slot (debounced)
- `preset-versioning`: _v1, _v2 suffix on save when file exists
- `preset-packs`: .grove-pack bundle import/export
- `preset-theme-sync`: inherits `ui_store.color_mode` and `theme.colors`

### Modified Capabilities
- `preset-browser`: IO module extended for v3 format, stats flush, pack serialization

## Approach

- **.grove v3**: extend `io.lua` serializer — additive fields (tags, notes, bpm, genre, key) in the same `return {}` table. Version field jumps to 3. Loader reads v2 compatibly.
- **Stats**: new `src/state/preset-stats.lua` store + ExtState persist via `preferences_store.TickSaveDebounce` pattern. Flush on preset load/save.
- **Preview**: ghost MIDI via `midi.TriggerChord` with `force=false` and immediate flush on hover end. No ref-count pollution — separate temporary context.
- **Thumbnails**: 8×8 grid analysis at scan time, stored in `preset_files` entry. Rendered as tiny dots in `preset-list.lua` next to filename.
- **Auto-save**: hook into `progression.Add` — after N seconds idle (debounced), snapshot notes to `~/grove-presets/_autosave/<slot>.grove`.
- **Packs**: .grove-pack = concatenated .grove files with a manifest header. `io.lua` parse + batch extract to directory.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/state/preset-store.lua` | Modified | +stats, +tags, +version fields, +pack metadata |
| `src/state/preset-stats.lua` | **New** | Usage count store + ExtState persist |
| `src/ui/preset-browser/io.lua` | Modified | .grove v3 ser/deser, pack I/O, stat increment |
| `src/ui/preset-browser/main.lua` | Modified | Badge rendering, thumbnail slot, auto-save tick |
| `src/ui/preset-browser/preset-list.lua` | Modified | Thumbnail dots, badge icon, preview hover zone |
| `src/ui/preset-browser/folder.lua` | Modified | Color-mode aware folder icons |
| `src/core/midi.lua` | Modified | Expose `SendMidi` batch for ghost preview |
| `src/core/progression.lua` | Modified | Fire auto-save hook on Add |
| `src/ui/theme.lua` | — | No changes needed; dark/light sync reads `color_mode` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| .grove v3 breaks backward compat with v2 loads | Low | Loader detects `version >= 3`, treats missing fields as optional; v2 files load identically |
| Ghost preview pollutes active notes | Med | Separate temp_ctx, no ref-count increment, flush-all on preview end |
| Pack format lock-in (can't evolve) | Low | Manifest hash + `version` field at pack header; future versions extend, not break |
| Auto-save floods disk writes | Low | 3s debounce timer; only saves when progression changed |

## Rollback Plan

1. Revert `io.lua` SavePreset version field to 2 (additive v3 fields become dead data but don't break)
2. Remove `src/state/preset-stats.lua` and revert preset-store.lua additions
3. Replace `preset-browser/main.lua` and `preset-list.lua` with Phase 2 versions (git checkout)
4. Packs: manual deletion of any .grove-pack files — no side effects on .grove loading

## Dependencies

| Phase | Depends On | External |
|-------|------------|----------|
| P1 | preset-store.lua, io.lua | ExtState (reaper.GetExtState/SetExtState) |
| P2 | midi.lua (ghost preview) | None |
| P3 | preset-stats store (from P1) | None |
| P4 | All prior phases stable | io.* for pack read/write |

## Success Criteria

- [ ] P1: .grove v3 files load on REAPER restart without errors; stats persist across sessions; notes field round-trips
- [ ] P2: Hover preset shows ghost notes in piano roll; Ctrl+Space triggers preview MIDI; 8×8 dot grid renders
- [ ] P3: Badge appears after N loads; auto-save creates files in _autosave/; _vN suffix on conflict
- [ ] P4: Export pack creates valid .grove-pack; reimport populates directory with identical files
