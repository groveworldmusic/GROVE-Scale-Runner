# Tasks: Production-Readiness Polish

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~447 (330 extraction diff + 117 new/changed) |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 → PR 4 |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Base Branch |
|------|------|-----------|-------------|
| 1 | Foundation (persist.lua + gfx-safe.lua + PREF_KEYS) | PR 1 | `feature/production-ready-polish` |
| 2 | Split DrawMIDIIsland (pure relocation) | PR 2 | PR 1 branch |
| 3 | Wire persistence + namespace migration | PR 3 | PR 2 branch |
| 4 | GFX safety (SafeGfx*) + cleanup | PR 4 | PR 3 branch |

## Phase 1 — Foundation (persist.lua + gfx-safe.lua + PREF_KEYS)

- [x] 1.1 Create `src/state/persist.lua` — `Load(state)` reads `GROVE_Scale_Runner` keys, falls back to legacy `GROVE_FL_MIDI`, migrates silently; `Save(key, value)` writes to `GROVE_Scale_Runner`; key registry for 7 preference keys
- [x] 1.2 Create `src/ui/gfx-safe.lua` — 3 exports: `SafeGfxInit(title, w, h, dock, x, y)` wraps `gfx.init()` in pcall, `SafeGfxQuit()` wraps `gfx.quit()` in pcall, `ShowError(context, err)` prints via `reaper.ShowConsoleMsg()`
- [x] 1.3 Add `config.PREF_KEYS` table in `config.lua` — list of `{"root_index", "scale_index", "octave", "chord_mode_index", "inversion_index", "volume", "color_mode"}`

## Phase 2 — Split DrawMIDIIsland (~165 LOC relocated)

- [x] 2.1 Extract `DrawKeyboardShortcutOverlay(char)` (lines 594-615) as top-level function in `views.lua` — identical logic, same signature (adapted: accepts `tool_mode` param since `local tool_mode` remains needed in DrawMIDIIsland for later use)
- [x] 2.2 Extract `DrawToolModeRow(ch_x, b_w, b_h, header_y)` (lines 757-794) as top-level function in `views.lua`
- [x] 2.3 Extract `DrawSnapControls(presets_x, b_w, b_h, header_y)` (lines 676-755) as top-level function in `views.lua`
- [x] 2.4 Extract `DrawPresetPanel(island_x, y, preset_w, h)` (lines 842-858) as top-level function in `views.lua`
- [x] 2.5 Replace extracted blocks in `DrawMIDIIsland` body with calls to the 4 new helpers — verify no behavioral change

## Phase 3 — Wire Persistence + Namespace Migration

- [x] 3.1 Add `persist.Load(config.state)` call in `main.lua Init()` between store inits and `gfx.init()` (line ~273) — loads 7 preference keys from ExtState
- [x] 3.2 In `views.lua`: add `persist.Save("root_index", v)` at root_index mutation points; repeat for `scale_index`, `octave`, `chord_mode_index`, `inversion_index`, `color_mode`
- [x] 3.3 In `src/state/sequencer.lua`: add `persist.Save("volume", v)` inside `SetVolume(v)` — single gate for all volume writes
- [x] 3.4 In `src/ui/preset-browser.lua`: change `GROVE_FL_MIDI` namespace references (lines 118, 144) to `GROVE_Scale_Runner` for `preset_favorites` reads/writes

## Phase 4 — GFX Safety + Cleanup

- [x] 4.1 In `main.lua`: replace `gfx.init(...)` (line 273) with `SafeGfxInit(...)`; replace `gfx.quit()` (line 253) with `SafeGfxQuit()`; add `require("ui.gfx-safe")`
- [x] 4.2 In `src/ui/compact-init.lua`: replace `gfx.quit()` calls (lines 74, 122, 165) with `SafeGfxQuit()`; replace `gfx.init(...)` (lines 86, 131) with `SafeGfxInit(...)`; add `"gfx-safe"` require at top
- [x] 4.3 Verify backward compat: legacy `GROVE_FL_MIDI` keys are NEVER deleted; canonical namespace always wins if both exist — confirmed via code review of persist.lua
