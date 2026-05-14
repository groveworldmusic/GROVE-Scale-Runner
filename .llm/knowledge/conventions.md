# Convenciones de Código

## Naming

- **Archivos**: PascalCase (`components.lua`, `compact-init.lua`, `GetMidiNote`)
- **Funciones**: snake_case (`DrawButton`, `HandleSlotInteraction`, `GetMidiNote`)
- **Módulos**: snake_case en requires (`require("ui.components")`, `require("state.drag")`)
- **Constantes**: UPPER_SNAKE_CASE (`CANVAS_W`, `BAR_H`, `VIEW_MODES.FULL`)
- **Variables locales**: snake_case (`local cv_x`, `local panel_open`)
- **Módulo export table**: `local m = {}`

## Patrón de Módulo

```lua
-- Descripción del módulo
-- Dependencias: lista de requires
local dep = require("path.to.dep")

local m = {}

function m.PublicFunction(param)
    -- lógica
end

return m
```

## Patrón de Store

```lua
local state = { key = default }
local m = {}
function m.Init(defaults)
    if defaults.key ~= nil then state.key = defaults.key end
end
function m.GetKey() return state.key end
function m.SetKey(v) state.key = v end
return m
```

## Requires

- Usar dots, no paths absolutos: `require("ui.components")`, no `require("src.ui.components")`
- `package.path` se extiende en runtime desde `main.lua`
- Para dependencias circulares: lazy require dentro del cuerpo de la función

## GFX

- `gfx.mouse_wheel` debe zerearse CADA FRAME en CADA contexto GFX
- `mouse_click` es evento de 1 frame, no persistente
- Componentes de UI no deberían requerir `config` directamente — usan stores

## Testing

- Tests con mocks, no dependencia de REAPER
- Cada test archivo tiene `local test = require("tests.helpers")`
- `test.check(condición, "mensaje")` + `test.summary()` al final
- `os.exit(1)` si hay fallos
