# Delta for Refactor — Desacoplar compact.lua

## Nature of Change

**Pure structural refactor.** No behavioral changes. No new capabilities. No modified capabilities. All extractions are internal code moves that preserve every existing behavior identically.

All existing behaviors MUST be preserved identically after each extraction. The system SHALL behave exactly as before the refactor across all entry points, inputs, and UI states.

## Extractions

| # | Module | Source | Target | Contents |
|---|--------|--------|--------|---------|
| 1 | LICE | `src/ui/compact.lua` (lines 75–115) | `src/ui/lice.lua` | `DrawRoundedRectFill`, `DrawArrowIcon`, `DrawProgressBar`, `DrawModeHint` — LICE wrappers that receive bitmap/font as parameters (no direct `require("config")`) |
| 2 | Positioning | `src/ui/compact.lua` (lines 121–203) | `src/ui/positioning.lua` | `FindTransportWindow`, `ResetAutoPosition`, `SetManualPosition`, `FindTransportEmptyArea`, `GetTransportScreenRect` — layout math, reads `config.state` via parameter; `cv_x/y/w/h` exposed via getters |
| 3 | CompactBar | `src/ui/compact.lua` (lines 470–588) | `src/ui/bar.lua` | `DrawCompactBar`, `UpdateCompactView` — header draw, progress bar, mode icons, JS_Composite render; `restore_btn_x` exposed via getter |
| 4 | CompactPanel | `src/ui/compact.lua` (lines 213–330) | `src/ui/panel.lua` | `ClosePanel`, `HandlePanel`, `TogglePanel`, `IsPanelOpen` — floating GFX window, keyboard, pads, dropdowns, VEL toggle |
| 5 | Intercept | `src/ui/compact.lua` (lines 596–681) | `src/ui/intercept.lua` | `GetCompactZone`, `ProcessMouseInterception` — WM_LBUTTONDOWN/WM_RBUTTONDOWN routing, hit-test, post-menu guard; reads `menu_dismiss_time` via getter |
| 6 | CompactMenu | `src/ui/compact.lua` (lines 336–406) | `src/ui/menu_compact.lua` | `ShowContextMenu`, `menu_dismiss_time` setter — context menu build, `gfx.showmenu`, `gfx.init`/`gfx.quit` lifecycle; `menu_dismiss_time` exposed via getter |
| 7 | Remains in compact.lua | — | `src/ui/compact.lua` | `SwitchViewMode`, `InitOverlay`, `Cleanup`, barrel re-exports, shared state (`cv_x`, `cv_y`, `cv_w`, `cv_h`) |

## Constraints

- Every extracted function MUST behave identically to its previous inline definition.
- No function signature MAY change. `compact.CompactInit(params_table)`, `compact.Run()`, and all existing public function signatures SHALL remain identical.
- No constant value MAY change. `BAR_H=26`, `CV_W=156`, `RESTORE_BTN_SIZE=12`, panel dimensions, and all dropdown option tables SHALL remain identical.
- No state initialization semantics MAY change. Panel state (`panel_open`, `panel_inited`, etc.), intercept state (`intercept_active_l/r`), and positioning cache (`cv_auto_x`, `use_auto_pos`) SHALL init at module load time exactly as before.
- The Lua module system (`local m = {}` + `return m`) SHALL be used for all new files.
- `compact.lua` MUST re-export all extracted public functions so consumer imports (`main.lua`, `views.lua`) remain unchanged.
- No consumer file MAY require the new modules directly — all access SHALL remain through `compact.*`.
- `lice.lua` MUST NOT call `require("config")` — bitmap/font SHALL be received as function parameters to avoid circular dependency.
- `cv_x`, `cv_y`, `cv_w`, `cv_h` SHALL remain as shared state in `compact.lua`, exposed via getter functions.
- `menu_dismiss_time` SHALL reside in `menu_compact.lua` and be exposed via `menu_compact.GetLastDismissTime()`, read by `intercept.lua`.
- `restore_btn_x` SHALL reside in `bar.lua` and be exposed via `bar.GetRestoreBtnX()`, read by `intercept.lua`.
- The MainLoop call order (`ProcessMouseInterception` → `UpdateCompactView` → `HandlePanel`) MUST be preserved in `compact.Run()`.
- Each extraction SHALL be an independent commit with its own verification.

## Verification

- After each extraction commit, the script SHALL start without runtime errors (REAPER load + GFX init).
- The compact bar (JS_Composite) SHALL render key/scale/octave/chord text and restore button identically before and after.
- Left-click on bar content SHALL toggle the floating panel identically before and after.
- Left-click on restore button SHALL switch view mode identically before and after.
- Right-click on bar content SHALL show context menu identically before and after.
- Right-click on restore button SHALL switch view mode identically before and after.
- Context menu SHALL set root/scale/octave/chord, export MIDI, panic, adjust position identically before and after.
- Floating panel SHALL init, render piano + dropdowns + VEL toggle, auto-reposition, and close identically before and after.
- `compact.Cleanup()` SHALL release all intercepts, destroy LICE resources, close panel, and reset state identically before and after.
- `compact.InitOverlay()` SHALL set up overlay mode identically before and after.

## Review Workload

- Estimated extraction: ~620 LOC across 6 new files + compact.lua reduction (~721→~80 LOC)
- **400-line budget risk**: High — 2 chained PRs recommended:
  - **PR 1**: lice + positioning + bar (~300 LOC, zero circular deps)
  - **PR 2**: panel + intercept + menu_compact + compact.lua wiring (~355 LOC)
