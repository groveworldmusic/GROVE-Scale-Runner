## Exploration: Desacoplar compact.lua (Phase 3c)

### Current State

`src/ui/compact.lua` tiene **721 líneas** — es el último archivo grande del proyecto tras Phases 1-3b. Es el panel compacto de REAPER: un composite incrustado en la barra de transporte (JS_Composite) más un panel flotante GFX para control de escala/acorde/octava.

El archivo maneja **6 responsabilidades distintas** en un solo módulo:
1. **LICE** — wrappers de bajo nivel para JS_LICE (creación/dibujo de bitmaps y fonts)
2. **Bar** — dibujo del composite incrustado en la ventana de transporte
3. **Panel** — ventana GFX flotante con teclado, dropdowns y toggle VEL
4. **Intercept** — intercepción de mensajes WM_LBUTTONDOWN/WM_RBUTTONDOWN
5. **Menu** — menú contextual (gfx.showmenu)
6. **Init/View Switch** — switch entre vista completa y compacta, overlay, cleanup

Tiene **11 funciones públicas** y **10 funciones privadas**, con ~15 upvalues de módulo compartidos entre categorías.

### Affected Areas

- `src/ui/compact.lua` — archivo a descomponer (721 LOC → ~100-150 LOC de coordinación)
- Los nuevos módulos: `src/ui/lice.lua`, `src/ui/bar.lua`, `src/ui/panel.lua`, `src/ui/intercept.lua`, `src/ui/menu_compact.lua`, `src/ui/positioning.lua`
- `src/config.lua` — no debería cambiar (config.state.compact ya es un namespace separado)
- `src/main.lua` — no debería cambiar (ya llama compact.* como interfaz pública)
- `src/ui/views.lua` — no debería cambiar (ya usa compact.* público)

### Function Map Completa

#### PUBLIC (en tabla compact)

| # | Función | Línea | Categoría | Dependencias |
|---|---------|-------|-----------|-------------|
| 1 | `compact.FindTransportWindow()` | 121-134 | Positioning | REAPER API |
| 2 | `compact.ResetAutoPosition()` | 140-142 | Positioning | — |
| 3 | `compact.SetManualPosition(x,y)` | 144-147 | Positioning | config.state |
| 4 | `compact.HandlePanel()` | 218-330 | Panel | Panel privadas, LICE, components, helpers |
| 5 | `compact.ShowContextMenu()` | 336-406 | Menu | Panel (ClosePanel), Init (SwitchViewMode), Positioning, midi |
| 6 | `compact.SwitchViewMode()` | 412-446 | Init | Panel (ClosePanel), LICE (EnsureLICE), Positioning |
| 7 | `compact.IsPanelOpen()` | 450 | Panel | — |
| 8 | `compact.InitOverlay()` | 452-464 | Init | LICE (EnsureLICE), Positioning |
| 9 | `compact.UpdateCompactView()` | 546-588 | Bar | LICE, Positioning, helpers |
| 10 | `compact.ProcessMouseInterception()` | 610-681 | Intercept | Bar (TogglePanel), Menu, Init |
| 11 | `compact.Cleanup()` | 687-719 | Cleanup | Panel, Intercept (release), LICE |

#### PRIVADA (local)

| # | Función | Línea | Categoría |
|---|---------|-------|-----------|
| 1 | `PanelTitle()` | 69 | Panel |
| 2 | `EnsureLICE()` | 75-85 | LICE |
| 3 | `DrawLICERect()` | 87-109 | LICE |
| 4 | `DrawLICEText()` | 111-115 | LICE |
| 5 | `FindTransportEmptyArea()` | 149-173 | Positioning |
| 6 | `GetTransportScreenRect()` | 179-203 | Positioning |
| 7 | `ClosePanel()` | 213-216 | Panel |
| 8 | `DrawCompactBar()` | 470-494 | Bar |
| 9 | `TogglePanel()` | 500-544 | Panel |
| 10 | `GetCompactZone()` | 596-604 | Intercept |

### Upvalues del Módulo (con dueño sugerido)

| Variable | Tipo | Línea(s) | Dueño | Usada por |
|----------|------|-----------|-------|-----------|
| BAR_H | constante | 17 | shared/categoría Constantes | Bar, Panel, Positioning |
| CV_W | constante | 18 | shared/Bar | Bar, Positioning, Intercept |
| PANEL_PW | constante | 19 | Panel | Panel |
| PANEL_PH | constante | 20 | Panel | Panel |
| PANEL_PIANO_H | constante | 21 | Panel | Panel |
| PANEL_CONTROLS_Y | constante | 22 | Panel | Panel |
| PANEL_PAD | constante | 23 | Panel | Panel |
| FLOAT_GAP | constante | 24 | Panel | Panel |
| SCALE_OPTIONS | computada | 27-31 | Panel | Panel (HandlePanel) |
| SCALE_FULL | computada | 32 | Panel | Panel (HandlePanel) |
| OCTAVE_OPTIONS | computada | 33-37 | Panel | Panel (HandlePanel) |
| CHORD_OPTIONS | computada | 38-42 | Panel | Panel (HandlePanel) |
| cv_x | estado | 48 | Positioning | Bar, Positioning, Intercept |
| cv_y | estado | 48 | Positioning | Bar, Positioning, Intercept |
| cv_w | estado | 48 | Bar | Bar, Positioning, Intercept |
| cv_h | estado | 48 | Bar | Bar, Positioning, Intercept |
| intercept_active_l | estado | 49 | Intercept | Intercept, Cleanup |
| intercept_active_r | estado | 50 | Intercept | Intercept, Cleanup |
| cv_auto_x | estado | 51 | Positioning | Positioning, Bar |
| use_auto_pos | estado | 52 | Positioning | Positioning, Bar |
| last_l_time | estado | 53 | Intercept | Intercept, Cleanup |
| last_r_time | estado | 54 | Intercept | Intercept, Cleanup |
| menu_dismiss_time | estado | 55 | **compartida** | Menu (set), Intercept (read), Cleanup (reset) |
| last_transport_w | estado | 56 | Bar | Bar |
| panel_open | estado | 59 | Panel | Panel, Init, Menu, Cleanup |
| panel_inited | estado | 60 | Panel | Panel |
| panel_init_x | estado | 61 | Panel | Panel |
| panel_init_y | estado | 61 | Panel | Panel |
| panel_opened_bar_y | estado | 62 | Panel | Panel |
| panel_last_mouse_cap | estado | 63 | Panel | Panel |
| panel_hwnd | estado | 64 | Panel | Panel |
| panel_first_frame | estado | 65 | Panel | Panel |
| panel_open_up | estado | 66 | Panel | Panel |
| RESTORE_BTN_SIZE | constante | 67 | Bar | Bar |
| restore_btn_x | estado | 68 | Bar (set) | Bar (set), Intercept (read via GetCompactZone) |

### Análisis de Dependencias entre Categorías

```
LICE (40 LOC)     — Zero dependencies
  ↑
Positioning       — No module deps (solo REAPER API + config.state.compact)
(65 LOC)
  ↑
Bar (120 LOC)     → LICE, Positioning, helpers
  ↑
Panel (165 LOC)   → Positioning (GetTransportScreenRect), components, helpers
  ↑ ↓
Intercept (85 LOC)→ Panel (TogglePanel), Menu (ShowContextMenu), Init (SwitchViewMode)
  ↑
Menu (70 LOC)     → Panel (ClosePanel), Init (SwitchViewMode), Positioning, midi
  ↑
Init (55 LOC)     → Panel (ClosePanel), LICE (EnsureLICE), Positioning
  ↑
Cleanup (35 LOC)  → Panel (ClosePanel), Intercept (release intercepts), LICE (destroy)
```

Grafo de dependencia real (simplificado):

```
LICE → (nada)
Positioning → (nada)
Bar → LICE, Positioning
Panel → Positioning, components, helpers
Intercept → Bar (TogglePanel), Menu (ShowContextMenu)
Menu → Panel, Positioning, Init, midi
Init → Panel, LICE, Positioning
Cleanup → Panel, Intercept, LICE
```

**Problema clave**: `menu_dismiss_time` es compartido entre Intercept (lee) y Menu (escribe). Hay dos opciones:
1. Sacarlo a compact.lua como shared state con getter/setter
2. Ponerlo en Menu y que Intercept lo lea via `menu_compact.GetLastDismissTime()`

**Segundo problema**: `restore_btn_x` es escrito por Bar (en DrawCompactBar) y leído por Intercept (via GetCompactZone). Solución: Bar exporta `GetRestoreBtnX()`.

**Tercer problema**: `cv_x, cv_y, cv_w, cv_h` son escritos/modificados por Bar y Positioning simultáneamente, y leídos por Intercept. Son el "contrato" entre módulos — tiene sentido mantenerlos en el compact.lua padre como shared state.

### Recomendación de Orden de Extracción

**Criterio**: dependencias ascendentes (primero lo que nada necesita, luego lo que depende de lo anterior).

| Paso | Módulo | LOC estimadas | Extrae | Dependencias rotas |
|------|--------|--------------|--------|-------------------|
| 1 | `src/ui/lice.lua` | ~55 | EnsureLICE, DrawLICERect, DrawLICEText | Ninguna (0 deps) |
| 2 | `src/ui/positioning.lua` | ~80 | FindTransportWindow, ResetAutoPosition, SetManualPosition, FindTransportEmptyArea, GetTransportScreenRect | Ninguna (0 deps de módulo) |
| 3 | `src/ui/bar.lua` | ~130 | DrawCompactBar, UpdateCompactView | LICE, Positioning, helpers |
| 4 | `src/ui/panel.lua` | ~180 | PanelTitle, ClosePanel, HandlePanel, TogglePanel, IsPanelOpen | Positioning, components, helpers |
| 5 | `src/ui/intercept.lua` | ~95 | GetCompactZone, ProcessMouseInterception | Panel (TogglePanel), Menu (ShowContextMenu) |
| 6 | `src/ui/menu_compact.lua` | ~80 | ShowContextMenu | Panel (ClosePanel), Positioning, midi |
| 7 | **Queda en compact.lua** | ~100 | SwitchViewMode, InitOverlay, Cleanup + barrel + shared state | Init depende de Panel, LICE, Positioning |

La categoría Init/SwitchViewMode y Cleanup se quedan en compact.lua porque:
- SwitchViewMode depende de casi todos los módulos extraídos
- Cleanup necesita estado de Intercept y Panel
- Son el "pegamento" orquestador

### Layout Final Estimado de compact.lua

```lua
local config = require("config")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local midi = require("core.midi")
local lice = require("ui.lice")
local positioning = require("ui.positioning")
local bar = require("ui.bar")
local panel = require("ui.panel")
local intercept = require("ui.intercept")
local menu_compact = require("ui.menu_compact")

local compact = {}

-- Shared state (cv_x, cv_y, cv_w, cv_h, menu_dismiss_time)
-- view_offset_x/y stays in config.state

function compact.SwitchViewMode() ... end
function compact.InitOverlay() ... end
function compact.Cleanup() ... end

-- Barrel re-exports
compact.FindTransportWindow = positioning.FindTransportWindow
compact.ResetAutoPosition = positioning.ResetAutoPosition
compact.SetManualPosition = positioning.SetManualPosition
compact.HandlePanel = panel.HandlePanel
compact.ShowContextMenu = menu_compact.ShowContextMenu
compact.IsPanelOpen = panel.IsPanelOpen
compact.UpdateCompactView = bar.UpdateCompactView
compact.ProcessMouseInterception = intercept.ProcessMouseInterception

return compact
```

Aproximadamente **80-100 LOC** vs los 721 actuales.

### Riesgos Específicos de compact.lua

1. **⚠️ ALTO: ciclo require**. LICE no puede require("config") por el ciclo config → compact. La solución actual (acceder a config.state.compact.lice_bitmap como upvalue global) debe replicarse. Alternativa: LICE recibe parámetros (lice_bitmap, lice_font, gdi_font) en cada llamada, o recibe `config.state.compact` como dependencia inyectada.

2. **⚠️ ALTO: menu_dismiss_time compartido**. Intercept lo lee (post-menu guard), Menu lo escribe, Cleanup lo resetea. Si Menu y Intercept están en módulos separados, necesitan un mecanismo de getter/setter o compartirlo via compact.lua padre.

3. **⚠️ MEDIO: restore_btn_x cross-module**. Bar lo escribe en DrawCompactBar (llamado desde UpdateCompactView), Intercept lo lee en GetCompactZone. Solución simple: Bar exporta `GetRestoreBtnX()`.

4. **⚠️ MEDIO: cv_x, cv_y, cv_w, cv_h shared**. Positioning los calcula, Bar los lee/escribe, Intercept los lee. Son el "contrato espacial" del composite. Deben mantenerse en el módulo padre y ser accesibles via getters.

5. **⚠️ BAJO: panel_* state ownership**. Todo el estado del panel (panel_open, panel_inited, etc.) está claramente en Panel. Pero Cleanup necesita `ClosePanel()` y SwitchViewMode necesita revisar `panel_open`. Mientras se exporten las funciones correctas, no hay problema.

6. **⚠️ BAJO: gfx.init/gfx.quit en múltiples módulos**. ShowContextMenu hace gfx.init/gfx.quit para el menú temporal. SwitchViewMode también. HandlePanel también. Cada módulo debe ser responsable de su propio lifecycle GFX.

7. **⚠️ MEDIO: el orden de UpdateCompactView → HandlePanel en main.lua**. MainLoop (líneas 114-117) llama `compact.ProcessMouseInterception()`, luego `compact.UpdateCompactView()`, luego `compact.HandlePanel()`. Este orden importa porque ProcessMouseInterception puede disparar TogglePanel que cambia panel_open. Si separamos módulos, el orden debe preservarse.

8. **⚠️ BAJO: BAR_H, CV_W como constantes compartidas**. Bar las necesita, Panel necesita PANEL_PW/PANEL_PH, Positioning usa BAR_H. Podemos poner constantes de cada dominio en su módulo o en un archivo de constantes compartido.

### Ready for Proposal

**Sí** — el análisis está completo. Recomiendo pasar a **sdd-propose** con los siguientes hallazgos clave:

1. Extracción en 6 módulos (lice, positioning, bar, panel, intercept, menu_compact)
2. compact.lua se reduce de 721 → ~80-100 LOC como coordinador + barrel
3. Riesgo principal: ciclo require con config (LICE accede a config.state.compact)
4. `menu_dismiss_time` y `restore_btn_x` son los puntos de acoplamiento cross-module a resolver
5. El orden de MainLoop (Intercept → Bar → Panel) debe preservarse
6. ~655 LOC de extracción total (bajo el budget de 400 → requiere 2 PRs encadenados)
