# Tasks: Presets Full Features

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~980 (additions + deletions) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | 5 PRs (feature-branch-chain) |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Lines | Base Branch |
|------|------|-----------|-------|-------------|
| 1 | Stats store | PR 1 | ~150 | feature/tracker |
| 2 | .grove v3 + Metadata | PR 2 | ~200 | PR 1 branch |
| 3 | Preview + Thumbnails | PR 3 | ~200 | PR 2 branch |
| 4 | Badges + Auto-Save | PR 4 | ~180 | PR 3 branch |
| 5 | Versioning + Packs | PR 5 | ~250 | PR 4 branch |

## Phase 1: Foundation

- [x] 1.1 Stats Store: Add stats fields + IncrementPresetLoadCount + SaveStats/LoadStats to `preset-store.lua`; TickSaveStats in io.lua; LoadStats/IncrementPresetLoadCount hooks in io.lua Init/LoadPreset (deviation: stats live in preset-store.lua, not separate file; Init/Tick hooks in io.lua, not main.lua)
- [x] 1.2 .grove v3 Save: io.lua SavePreset writes version=3 + optional metadata (key, bpm, genre, difficulty, tags, notes); add metadata fields to preset-store.lua
- [x] 1.3 .grove v3 Load: io.lua LoadPreset detects version>=3, reads optional metadata into store; v2 files load identically (nil metadata)
- [x] 1.4 EditMetadataDialog: io.lua via 5x GetUserInputs (bpm, genre, diff, tags, notes) + "i" icon in preset-list.lua (deviation: 5 dialogs instead of 3, excludes key field from dialog)
- [ ] 1.5 Progression revision hash: Add GetProgressionRevision/SetProgressionRevision to progression.lua for auto-save dirty detect

## Phase 2: Media

- [x] 2.1 Preview module: `src/ui/preset-browser/preview.lua` — PlayPreview (StuffMIDIMessage note-ons, 0.5s auto-note-off via TickPreview) + StopPreview (module-local state, zero pollution of active-note store)
- [x] 2.2 Hover preview: Ctrl+Click in preset-list.lua → sandbox-load → PlayPreview; TickPreview auto-stops after 0.5s (deviation: no 300ms debounce, uses Ctrl+Click instead of hover-only; no hover-end stop needed since 0.5s auto-expire)
- [x] 2.3 Ctrl+Space trigger: Implemented as Ctrl+Click in preset-list.lua item loop (deviation: uses mouse click + Ctrl modifier instead of HandleKeyboard+VK_SPACE; cleaner UX since preview + multi-select can co-occur)
- [x] 2.4 ComputeThumbnailGrid: `m.ComputeThumbnail(notes)` in io.lua — pure 8×8 grid from note pitch/time distribution (empty, single note, dense)
- [x] 2.5 Thumbnail cache: `_thumbnail_cache{}` in preset-store.lua with Get/Set/Clear; lazy compute on first hover via `LoadSandboxed` in preset-list.lua (deviation: on-demand per hover, not scan-time batch; avoids loading all .grove files at startup)
- [x] 2.6 Thumbnail rendering: 36×36px dot grid in preset-list.lua between meta "i" icon and label (deviation: 36px instead of 16px for better visibility; blue cells `{0.4,0.7,1,0.6}` instead of theme primary)

## Phase 3: UX

- [ ] 3.1 Badge rendering: Derive from load_count in preset-list.lua — Today(Cyan) > Veteran(Gold) > Regular(Silver) > Used(Dim) > New(Green)
- [ ] 3.2 Auto-save timer: TickAutoSave in main.lua — 3s debounce on progression rev change, skip during playback
- [ ] 3.3 SaveSlotSnapshot: io.lua saves per-slot notes to `_autosave/slot_{page}_{idx}.grove`; evict oldest when >5 per slot
- [ ] 3.4 Versioning on save: SavePresetWithVersioning in io.lua — scan _vN files, rename existing, write new as base name
- [ ] 3.5 Version UI + context menu: Version count in preset-list.lua; "Load Previous Version" context menu → gfx.showmenu version picker
- [ ] 3.6 Theme color migration: Replace hardcoded colors in preset-list.lua (ITEM_HOVER, ITEM_SELECTED, FILE_COLOR) and folder.lua with theme.colors via helpers

## Phase 4: Sharing

- [ ] 4.1 ExportPresetsAsPack: io.lua serializes selected .grove files into Lua-table .grove-pack with manifest; context menu entry in preset-list.lua
- [ ] 4.2 ImportPack: io.lua loads sandboxed .grove-pack, extracts files to current directory, skips duplicates with warning; import button in main.lua

## Tests

- [ ] T1 Unit: ComputeThumbnailGrid edge cases (empty, single note, dense)
- [ ] T2 Unit: GetBadge thresholds at boundaries (0, 1, 2, 10, 11, 50, 51)
- [ ] T3 Unit: v3 save/load round-trip — notes + metadata preserve fidelity
- [ ] T4 Unit: SavePresetWithVersioning — version increment logic on collision

## Manual Testing Checklist (REAPER)

- [ ] P1: v3 file round-trip (save→load→re-save) preserves notes, progression, metadata; v2 file loads without error
- [x] P2: Ctrl+Click triggers ghost-note preview (0.5s); thumbnails render as 8×8 blue dot grid on hover (deviation: uses Ctrl+Click instead of Ctrl+Space; 36px instead of 16px)
- [ ] P3: badges appear after N loads; auto-save creates _autosave/ files; _vN suffix on save conflict; theme colors update on live switch
- [ ] P4: export creates valid .grove-pack; import creates .grove files; duplicate warning shown
