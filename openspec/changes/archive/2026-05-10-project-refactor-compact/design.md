# Design: Project Refactor — Desacoplar compact.lua

## Technical Approach

Extracción ascendente por capa de dependencia. `compact.lua` (721 LOC) se descompone en 7 módulos especializados + barrel (~80 LOC). Sigue exactamente el mismo patrón barrel que `components.lua`: cada módulo nuevo exporta funciones en tabla `local m = {}`, y `compact.lua` re-exporta todo para que consumers (`main.lua`, `views.lua`) no cambien.

Split en 2 PRs encadenados para respetar budget de 400 LOC por PR. Cada PR es autónomo y verificable sin el siguiente.

## Architecture Decisions

| Decisión | Opciones | Elección | Rationale |
|----------|----------|----------|-----------|
| `menu_dismiss_time` ownership | compact.lua vs menu_compact.lua | menu_compact.lua + getter | Intercept solo lee, Menu escribe. Getter rompe dependencia circular. Misma dataflow que `restore_btn_x` |
| `restore_btn_x` ownership | compact.lua vs bar.lua | bar.lua + getter `GetRestoreBtnX()` | Bar escribe (DrawCompactBar), Intercept lee (GetCompactZone). Sin getter habría shared state cross-module |
| `cv_x/y/w/h` ownership | Módulo separado vs compact.lua | compact.lua como shared state | Positioning recalcula, Bar/Intercept leen. Son el "contrato espacial" — tenerlos en el padre evita acoplamiento fuerte |
| LICE + config cycle | require("config") vs parámetros | Parámetros directos (bm, font) | `lice.lua` requiere `config.state.compact.lice_bitmap/font` — pasar como params rompe el ciclo require |
| Naming convention | bar vs compact-bar | compact-* prefix | Consistente con "compact view" naming. Evita colisión mental con docked transport bar |

## Data Flow

```
main.lua MainLoop
  │
  ├── compact.Run()  ← compact-init.lua
  │     │
  │     ├── compact_intercept.HandleWheel(ctx)
  │     ├── compact_intercept.HandleClick(ctx)
  │     ├── compact_intercept.HandleDrag(ctx)
  │     │
  │     ├── compact_bar.CompactBar(ctx)
  │     │     ├── lice.DrawLICERect(bm, ...)
  │     │     └── lice.DrawLICEText(bm, font, ...)
  │     │
  │     ├── compact_panel.CompactPanel(ctx)
  │     │     ├── components.*
  │     │     └── positioning.GetTransportScreenRect()
  │     │
  │     └── compact_intercept.ProcessMouseInterception(ctx)
  │           ├── compact_intercept.GetActiveItem(ctx)
  │           ├── compact_bar.GetRestoreBtnX()
  │           └── compact_menu.GetMenuDismissTime()
  │
  ├── compact.SwitchViewMode(mode)     ← compact-init.lua
  ├── compact.InitOverlay()               ← compact-init.lua
  └── compact.Cleanup()                   ← compact-init.lua
```

## Shared State Plan

| Variable | Dueño | Acceso | Tipo |
|----------|-------|--------|------|
| `cv_x, cv_y, cv_w, cv_h` | compact.lua | getters: `GetCvX/Y/W/H()` | number |
| `restore_btn_x` | compact-bar.lua | getter: `GetRestoreBtnX()` / setter: `SetRestoreBtnX(val)` | number |
| `menu_dismiss_time` | compact-menu.lua | getter: `GetMenuDismissTime()` / setter: `SetMenuDismissTime(val)` | number |
| `panel_*` (open, inited, hwnd, etc.) | compact-panel.lua | encapsulado en el módulo | various |

## File Changes

| File | Acción | LOC | Descripción |
|------|--------|-----|-------------|
| `src/ui/lice.lua` | Crear | ~45 | Wrappers LICE (DrawLICERect, DrawLICEText, EnsureLICE) — sin require("config") |
| `src/ui/positioning.lua` | Crear | ~80 | Layout math puro (FindTransportWindow, FindTransportEmptyArea, GetTransportScreenRect) |
| `src/ui/compact-bar.lua` | Crear | ~130 | DrawCompactBar, UpdateCompactView, restore_btn_x getter/setter |
| `src/ui/compact-panel.lua` | Crear | ~175 | HandlePanel, TogglePanel, ClosePanel, IsPanelOpen + panel state |
| `src/ui/compact-intercept.lua` | Crear | ~95 | ProcessMouseInterception, GetCompactZone + intercept_* state |
| `src/ui/compact-menu.lua` | Crear | ~80 | ShowContextMenu + menu_dismiss_time getter/setter |
| `src/ui/compact-init.lua` | Crear | ~60 | SwitchViewMode, InitOverlay, Cleanup — orquestación |
| `src/ui/compact.lua` | Modificar | 721→~80 | Barrel: requires + re-exports. Solo shared state cv_x/y/w/h |

Total: ~665 LOC nuevos, ~641 LOC eliminados de compact.lua.

## Interfaces / Contracts

### `lice.lua`
```lua
local m = {}
function m.EnsureLICE() end                    -- crea bitmap/font si no existen
function m.DrawLICERect(bm, x, y, w, h, color, fill, r) end
function m.DrawLICEText(bm, font, x, y, text, color) end
function m.DrawArrowIcon(bm, x, y, w, h, direction, color) end
return m
```

### `positioning.lua`
```lua
local m = {}
function m.FindTransportWindow() end
function m.ResetAutoPosition() end
function m.SetManualPosition(x, y) end
function m.FindTransportEmptyArea(cv_w) end
function m.GetTransportScreenRect(cv_x, cv_y, cv_w, cv_h) end
return m
```

### `compact-bar.lua`
Dependencias: config, theme, helpers, lice, positioning.
```lua
local m = {}
function m.DrawCompactBar(bm, y_off) end
function m.UpdateCompactView() end            -- llama DrawCompactBar + JS_Composite
function m.GetRestoreBtnX() end
function m.SetRestoreBtnX(val) end
return m
```

### `compact-panel.lua`
Dependencias: config, theme, helpers, midi, components, positioning.
```lua
local m = {}
function m.HandlePanel() end
function m.TogglePanel() end
function m.ClosePanel() end
function m.IsPanelOpen() end
return m
```

### `compact-intercept.lua`
Dependencias: config, theme, components, positioning, compact-bar.
```lua
local m = {}
function m.ProcessMouseInterception() end
function m.GetCompactZone(rel_x) end
return m
```

### `compact-menu.lua`
Dependencias: config, components.
```lua
local m = {}
function m.ShowContextMenu() end
function m.GetMenuDismissTime() end
function m.SetMenuDismissTime(val) end
return m
```

### `compact-init.lua`
Dependencias: ALL modules.
```lua
local m = {}
function m.SwitchViewMode(mode) end
function m.InitOverlay() end
function m.Cleanup() end
return m
```

### `compact.lua` (Barrel final)
```lua
local config = require("config")
local lice = require("ui.lice")
local positioning = require("ui.positioning")
local compact_bar = require("ui.compact-bar")
local compact_panel = require("ui.compact-panel")
local compact_intercept = require("ui.compact-intercept")
local compact_menu = require("ui.compact-menu")
local compact_init = require("ui.compact-init")

local m = {}
-- Shared state (cv_x, cv_y, cv_w, cv_h)
local cv_x, cv_y, cv_w, cv_h = 0, 0, 0, 26
function m.GetCvX() return cv_x end
function m.GetCvY() return cv_y end
function m.GetCvW() return cv_w end
function m.GetCvH() return cv_h end

-- Barrel re-exports
m.FindTransportWindow = positioning.FindTransportWindow
m.ResetAutoPosition = positioning.ResetAutoPosition
m.SetManualPosition = positioning.SetManualPosition
m.HandlePanel = compact_panel.HandlePanel
m.ShowContextMenu = compact_menu.ShowContextMenu
m.IsPanelOpen = compact_panel.IsPanelOpen
m.UpdateCompactView = compact_bar.UpdateCompactView
m.ProcessMouseInterception = compact_intercept.ProcessMouseInterception
m.SwitchViewMode = compact_init.SwitchViewMode
m.InitOverlay = compact_init.InitOverlay
m.Cleanup = compact_init.Cleanup
return m
```

## Split Strategy (2 PRs)

| PR | Módulos | LOC new | LOC del | Dependencia |
|----|---------|---------|---------|-------------|
| **PR1** | lice + positioning + compact-bar | ~280 | ~260 | Ninguna circular. Bar requiere lice + positioning |
| **PR2** | compact-panel + compact-intercept + compact-menu + compact-init + barrel | ~375 | ~355 | Prerequisito: PR1. Init requiere todos |

## Conflict Avoidance

- `menu_dismiss_time` → getter/setter en compact-menu, Intercept solo llama `compact_menu.GetMenuDismissTime()` — no hay dependencia circular porque son valores planos, no módulos
- `restore_btn_x` → GetRestoreBtnX() en compact-bar, Intercept lo lee directo
- `cv_x/y/w/h` → quedan en compact.lua con getters. Positioning recalcula, Bar/Intercept leen. UpdatePositioning(state) recibe config.state como parámetro
- Orden MainLoop preservado en compact-init.Run(): HandleWheel → CompactBar → CompactPanel → HandleClick → HandleDrag

## Testing Strategy

| Layer | Qué probar | Cómo |
|-------|-----------|------|
| Static | TODAS las referencias cross-module | Verificar que cada require() existe y no hay nil dereferences |
| Manual | Carga REAPER + GFX init | Script inicia sin error después de cada PR |
| Manual | Barra composite | JS_Composite renderiza key/scale/octave/chord + restore button |
| Manual | Panel flotante | Left-click toggle, right-click menú, VEL toggle, dropdowns |
| Manual | Switch view mode | FULL↔COMPACT sin crash, overlay mode funcional |
| Manual | Cleanup | Sin leaks de LICE resources, intercepts liberados |

No hay test runner disponible (config.yaml: tdd: false, test_command: ""). Toda verificación es manual en REAPER o análisis estático.

## Migration / Rollout

No migration required. Por PR: revertir commit de merge. Zero cambios en config.state structure.

## Open Questions

- [ ] `CompactBar(ctx)` — ¿ctx incluye bitmap LICE o se accede via config.state.compact.lice_bitmap? La propuesta actual: CompactBar recibe ctx con posición, y usa config.state.compact.lice_bitmap internamente (mismo patrón actual). Confirmar en apply.
- [ ] `CompactInit(params_table)` — ¿parámetros de init (auto_start, view_offset_x/y, etc.)? Definir en tareas.
