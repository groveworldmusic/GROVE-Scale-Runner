# Tasks: Professional Polish

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

Estimated changed lines: ~860 (45 headers ~540 + root docs ~90 + api-guard ~30 + code ~200)

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | License headers on all 45 .lua files + root docs (LICENSE, CHANGELOG, CONTRIBUTING) | PR #1 → tracker | Boilerplate only, no logic risk |
| 2 | ReaPack @provides + api-guard.lua + all defensive hardening code | PR #2 → PR #1 | Real code changes, careful review needed |

## Phase 1: Foundation

- [x] 1.1 Create `src/core/api-guard.lua` — `CheckAPI(name)`, `AssertAPIs(checks)`, `ClampIndex(idx, min, max)`
- [x] 1.2 Add `config.APP_NAME`, `config.EXTSTATE_NS` to `src/config.lua`, standardize comment header
- [x] 1.3 Create `LICENSE` (MIT, "Andrik on the beat") + `CHANGELOG.md` (v1.0.0) in project root

## Phase 2: License Headers (All Files)

- [x] 2.1 Add MIT SPDX header block to all 46 `src/**/*.lua` files (45 existing + 1 new api-guard.lua)

## Phase 3: ReaPack Metadata

- [x] 3.1 Expand `@provides` in `src/main.lua` to list all 46 .lua files (grouped by subdirectory)
- [x] 3.2 Add `@changelog` with v1.0.0 entry, normalize gfx.init titles, standardize "GROVE Scale Runner" naming

## Phase 4: API Guards — JS_* Calls

- [x] 4.1 Wire `api_guard.AssertAPIs()` in `src/main.lua` Init() — checks 7 critical JS_* APIs, shows MB on failure
- [x] 4.2 Guard `JS_VKeys_*` in `src/core/keyboard.lua` via `api_guard.CheckAPI()` — HandleKeyboard + InterceptMappedKeys
- [x] 4.3 Guard `JS_LICE_*` in `src/ui/lice.lua` — covered by AssertAPIs in Init (JS_LICE_CreateBitmap checked), EnsureLICE also exists
- [x] 4.4 Guard `JS_Window_Find` in `src/ui/compact-init.lua` via `api_guard.CheckAPI()` — in FindTransportWindow
- [x] 4.5 Guard `JS_WindowMessage_*` — covered by compact-intercept's existing hwnd nil checks + AssertAPIs in Init
- [x] 4.6 Add nil/API guards on `JS_Window_GetClientSize`/`JS_Window_GetRect` returns in `src/ui/positioning.lua`

## Phase 5: Nil Guards & Undo Blocks

- [x] 5.1 Add nil guards on `GetPlayState`, `TimeMap2_timeToBeats`, `GetPlayPosition2` returns in `src/core/sequencer.lua` — or 0 defaults
- [x] 5.2 Wrap `ExportToMidi` in `Undo_BeginBlock`/`EndBlock` in `src/core/midi.lua` — all return paths properly close undo block
- [x] 5.3 Add nil guards on `GetSelectedTrack` returns + ValidatePtr in `src/core/midi.lua` — MB on no track, early return
- [x] 5.4 Add dirty-flag to MainLoop in `src/main.lua` — skip GFX redraw when unchanged, always run logic + defer loop

## Phase 6: Bounds Clamping

- [x] 6.1 Clamp root/scale/chord indices via `ClampIndex` in `src/core/midi.lua` — GetMidiNote, TriggerChord, ExportToMidi
- [x] 6.2 Clamp root/scale/chord indices in `src/ui/pads.lua`, `src/ui/drag.lua`, `src/ui/piano.lua`, `src/ui/format.lua`, `src/ui/helpers.lua`, `src/ui/compact-bar.lua`, `src/ui/compact-init.lua`, `src/state/island.lua` — covered via clamping in functions they call
- [x] 6.3 Clamp root_index in `src/ui/piano.lua` — Comparisons safe (passed params), ComputeScaleNotes now clamps internally
- [x] 6.4 Clamp indices in dropdown callbacks and carousel wraparound in `src/ui/views.lua` — all SCALES/CHORD_MODES/NOTE_NAMES accesses clamped
- [x] 6.5 Clamp indices from `gfx.showmenu` result in `src/ui/compact-menu.lua` — loop-based menu safe (for i, v in ipairs bounds-checks naturally)
- [x] 6.6 Clamp indices before array access in `src/ui/compact-bar.lua` — all 3 accesses clamped
- [x] 6.7 Clamp indices on loaded preset values in `src/ui/preset-browser.lua` — covered by clamping in midi.TriggerChord/GetMidiNote which consume preset values
