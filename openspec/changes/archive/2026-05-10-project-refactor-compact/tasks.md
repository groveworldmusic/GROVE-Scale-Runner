# Tasks: Project Refactor — Desacoplar compact.lua

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,371 (665 new + 706 modified) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: lice + positioning + compact-bar (~580 LOC) → PR 2: panel + intercept + menu + init + barrel (~791 LOC) |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | LICE wrappers + positioning + CompactBar extraction | PR 1 (3c-a) | Base: `feature/project-refactor-compact`. Zero circular deps. |
| 2 | Panel + Intercept + Menu + Init + barrel | PR 2 (3c-b) | Base: PR 1 branch. Depends on PR 1 modules. |

## Phase 1: Foundation — PR 1 (3c-a)

- [x] 1.1 Create `src/ui/lice.lua` — `EnsureLICE()`, `DrawLICERect()`, `DrawLICEText()`. Sin `require("config")`, bitmap/font como parámetros. (pre-existing)
- [x] 1.2 Create `src/ui/positioning.lua` — `FindTransportWindow()`, `ResetAutoPosition()`, `SetManualPosition()`, `FindTransportEmptyArea()`, `GetTransportScreenRect()`. Layout math puro, lee `config.state` vía parámetro. (pre-existing)
- [x] 1.3 Create `src/ui/compact-bar.lua` — `DrawCompactBar()`, `UpdateCompactView()`. Incluye `restore_btn_x` getter/setter. Dependencias: config, theme, helpers, lice, positioning. (pre-existing)
- [x] 1.4 Update `src/ui/compact.lua` — eliminar lice/positioning/bar code (~260 LOC), agregar requires. Wrappers para ResetAutoPosition/SetManualPosition. UpdateCompactView simplificado, call sites actualizados a lice/positioning/compact-bar.
- [x] 1.5 Update `src/main.lua` — agregar `src/ui/lice.lua`, `src/ui/positioning.lua`, `src/ui/compact-bar.lua` al `@provides`.
- [ ] 1.6 **Verify PR 1** — carga REAPER sin error, barra composite renderiza key/scale/octave/chord + restore button.

## Phase 2: Core UI — PR 2 (3c-b)

- [x] 2.1 Create `src/ui/compact-panel.lua` — `TogglePanel()`, `ClosePanel()`, `IsPanelOpen()`. Panel state encapsulado (`panel.panel_state`). Dependencias: config, theme, helpers, components, positioning, lice.
- [x] 2.2 Create `src/ui/compact-intercept.lua` — `ProcessMouseInterception()`, `CleanupIntercept()`. Intercept state interno (intercept_active_l/r, last_l/r_time). Lazy requires para compact-init, menu, panel.
- [x] 2.3 Create `src/ui/compact-menu.lua` — `ShowContextMenu()`, `menu_dismiss_time` getter/setter/reset. Lazy requires para compact-init y compact-panel.
- [x] 2.4 Create `src/ui/compact-init.lua` — `SwitchViewMode()`, `InitOverlay()`, `HandlePanel()`, `UpdateCompactView()`, `Cleanup()`, `FindTransportWindow()`. Orquestación pura con top-level requires de todos los sub-módulos.
- [x] 2.5 Update `src/ui/compact.lua` — barrel re-export: requires + re-exports de compact-init, compact-panel, compact-intercept, compact-menu. 564→31 LOC.
- [x] 2.6 Update `src/main.lua` — agregar `compact-panel.lua`, `compact-intercept.lua`, `compact-menu.lua`, `compact-init.lua` al `@provides`.
- [ ] 2.7 **Verify PR 2** — panel flotante toggle, context menu, cleanup sin leaks, switch FULL↔COMPACT sin crash.

## Phase 3: Integración Final

- [ ] 3.1 **Cross-PR verify** — `compact.*` API idéntica pre/post refactor. Zero cambios en `main.lua` runtime, `views.lua`, `config.lua`.
