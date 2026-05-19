# Tasks: expansion-features

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1080 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | P1 (Themes) → P2 (Shortcuts) → P3 (Recording) |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Base |
|------|------|-----------|------|
| 1 | Color Themes | PR 1 | `feature/expansion-features` |
| 2 | Key Mapping | PR 2 | PR #1 branch |
| 3 | MIDI Recording | PR 3 | PR #2 branch |

## Phase 1: Color Themes (P1) — ~200 LOC

- [x] **T1** Create `src/ui/themes.lua`: export THEMES[3] with full color set (40+ keys matching existing theme.colors shape + grade_colors[7] per palette)
- [x] **T2** Modify `src/ui/theme.lua`: import themes.lua, replace static `theme.colors = {...}` with `theme.colors = themes[prefs.GetThemeIndex()]` called on first require and after SetThemeIndex (SetThemeIndex added)
- [x] **T3** Add `theme_index` (int 1-3, default 1) to `preferences.lua` (state/getter/setter/init/SyncFromState), `persist.lua` (PREF_KEYS), `config.lua` (PREF_KEYS + config.state default)
- [x] **T4** Add theme dropdown to `src/ui/midi-island/header.lua` between PRESETS and SAVE (reuse DrawDropdown pattern, 3 items: Current/Dark/HighContrast, calls prefs.SetThemeIndex + theme.SetThemeIndex)
- [x] **T5** Update (verify) `colors.lua` — already uses `theme.colors.grade_colors` dynamically, no changes needed
- [ ] **T14** Verify P1: theme dropdown switches palette → colors update next frame → reload persists theme_index → all 3 palettes produce non-nil 3-element colors for every key

## Phase 2: Key Mapping (P2) — ~400 LOC

- [ ] **T5** Create `src/core/vkey-map.lua`: `GetVkeyMap()` returns map from ExtState or config.VKEY_MAP fallback, `SetEntry(vk,deg,oct)` serializes full 28-entry map to string via `persist.Save("vkey_map_raw", ...)`, `ResetToDefaults()` clears override. Deserialize via `load("return "..str)()`
- [ ] **T6** Modify `src/core/keyboard.lua`: replace `config.VKEY_MAP` → `vkey_map.GetVkeyMap()` (lines 34, 62). Add `RebuildKeyStates()` that clears midi_store key_states and re-inits from current map. Call from InterceptMappedKeys and vkey-map setters
- [ ] **T7** Add `vkey_map_raw` (string) + `vkey_map_modified` (bool) to `preferences.lua`, `persist.lua`, `config.lua` PREF_KEYS
- [ ] **T8** Add remap modal overlay: 4×7 grid showing current VK→degree mapping, per-cell dropdown to reassign deg/oct, conflict detection (reject duplicate VK via `reaper.MB`), "Reset to Defaults" button calls `vkey_map.ResetToDefaults()` + `keyboard.RebuildKeyStates()`
- [ ] **T9** Add remap gear button to `header.lua` (between SYNC and SNAP, icon → toggles remap modal visibility)

## Phase 3: MIDI Input Recording (P3) — ~480 LOC

- [ ] **T10** Create `src/core/midi-input.lua`: `Poll()` iterates `MIDI_GetRecentInputEvent()`, note-on→`note_store.AddNote({origin="midi-input", ...})`, note-off→`note_store.UpdateOpenNoteDuration()`. Tracks `_open_notes[pitch]=uuid`. 5s timeout auto-closes unpaired notes. `SetArmed(bool)` / `IsArmed()`. `Cleanup()` finalizes all open notes
- [ ] **T11** Modify `src/state/note-store.lua`: add `UpdateOpenNoteDuration(pitch, dur)` — find most recent note with matching pitch and duration==0, set duration; silent no-op if no match. (origin field already handled — AddNote defaults to "manual")
- [ ] **T12** Add record-arm toggle to `header.lua` (next to CH selector, red circle icon, glows when armed, calls `midi_input.SetArmed()`)
- [ ] **T13** Wire midi_input into `main.lua`: require in Init, call `midi_input.Poll()` in MainLoop after HandleKeyboard (all 3 branches), add `midi_input.Cleanup()` to CleanupAll, apply theme after SyncFromState in Init

## Phase 4: Verification

- [ ] **T14** Verify P1: theme dropdown switches palette → colors update next frame → reload persists theme_index → all 3 palettes produce non-nil 3-element colors for every key
- [ ] **T15** Verify P2: remap a key → press key → correct MIDI note fires → reload → mapping persists → ResetToDefaults restores config.VKEY_MAP → stale VK removed from key_states
- [ ] **T16** Verify P3: arm → external MIDI note-on→AddNote with origin="midi-input" → note-off→duration set → disarm finalizes open notes → CleanupAll silences stuck notes → all MIDI messages besides note-on/off ignored
- [ ] **T17** Verify header layout: all new controls (theme dropdown, record toggle, remap gear) render within header bounds without clipping or displacing existing buttons
