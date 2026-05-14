# Proposal: Project Refactor — Desacoplar compact.lua

## Intent

Compact.lua (721 LOC) es el último archivo grande tras Phases 1-3b. Alberga 7 responsabilidades (LICE, Positioning, Bar, Panel, Intercept, Menu, Init) en un solo módulo. Se extrae cada categoría a su propio archivo, reduciendo compact.lua a ~80-100 LOC de coordinador + barrel. Zero cambios en consumers.

## Scope

### In Scope
- 6 nuevos módulos: lice, positioning, bar, panel, intercept, menu_compact
- compact.lua → coordinador + barrel + shared state (cv_x/y/w/h, menu_dismiss_time)
- Cross-module state con getters: menu_compact.GetLastDismissTime(), bar.GetRestoreBtnX()
- Split en 2 PRs encadenados (~300 + ~355 LOC) por budget de 400 líneas

### Out of Scope
- NO refactor de components (Phase 3a/3b)
- NO cambios en config.lua, main.lua, views.lua
- NO cambios de comportamiento (compact-bar-click-handling spec intacto)
- NO cambios en DrawRoundedRect/DrawIsland

## Capabilities

### New Capabilities
None — pure structural refactor.

### Modified Capabilities
None — no spec-level behavior changes.

## Approach

Extracción ascendente por dependencia: LICE (0 deps) → Positioning (0 deps) → Bar → Panel → Intercept → Menu. Init/Cleanup/SwitchViewMode se quedan en compact.lua como orquestadores. Sigue el mismo barrel pattern que components.lua.

| PR | Módulos | LOC | Contenido |
|----|---------|-----|-----------|
| 1 | lice + positioning + bar | ~300 | Base sin dependencias circulares |
| 2 | panel + intercept + menu_compact + init wiring | ~355 | UI modules + orquestación final |

**Ciclo require**: LICE usa `config.state.compact.lice_bitmap`. Solución: LICE recibe bitmap/font como parámetros — no hace `require("config")`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/compact.lua` | Modified | 721→~80 LOC: coordination + barrel |
| `src/ui/lice.lua` | New | LICE wrappers (~55 LOC) |
| `src/ui/positioning.lua` | New | Layout math (~80 LOC) |
| `src/ui/bar.lua` | New | CompactBar draw (~130 LOC) |
| `src/ui/panel.lua` | New | Panel GFX (~180 LOC) |
| `src/ui/intercept.lua` | New | Click/wheel handling (~95 LOC) |
| `src/ui/menu_compact.lua` | New | Context menu (~80 LOC) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Ciclo require LICE→config→compact | High | LICE recibe dependencias como parámetros |
| menu_dismiss_time race cross-module | Med | Getter en menu_compact, read-only en Intercept |
| Orden MainLoop alterado (Intercept→Bar→Panel) | Low | Init en compact.lua preserva orden |
| restore_btn_x desync (Bar escribe, Intercept lee) | Low | Getter bar.GetRestoreBtnX(), update in place |

## Rollback Plan

Por PR: revertir commit de merge. No hay migración de datos ni estado que reverter. Cada PR es autónomo.

## Dependencies

- Ninguna externa. Presupone Phase 3a/3b completados.

## Success Criteria

- [ ] compact.lua pasa de 721→~80-100 LOC
- [ ] Tests de integración: carga REAPER + GFX init + click handling OK
- [ ] Zero cambios en main.lua, views.lua, config.lua
- [ ] Contrato público compact.* idéntico
- [ ] Cada PR < 400 LOC
