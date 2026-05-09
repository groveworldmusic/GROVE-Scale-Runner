# Tareas de Implementación: GROVE FL MIDI

## Fase 1: Arquitectura y Configuración Base
- `[x]` Crear estructura de directorios (`src/core/`, `src/ui/`).
- `[x]` Configurar `package.path` en el script principal para permitir `require` relativos.
- `[x]` Crear `src/config.lua` con el estado global (`state` ampliado a 16 slots y `current_page`) y constantes musicales.
- `[x]` Crear `src/ui/theme.lua` con los colores exactos extraídos de los SVG.

## Fase 2: Motor Core (MIDI y Secuenciador)
- `[x]` Crear `src/core/midi.lua` (cálculo de acordes, `TriggerChord`, `SendMidi`).
- `[x]` Crear `src/core/sequencer.lua` (lógica de reproducción atada al `GetPlayPosition2`, manejo del paginado).

## Fase 3: Interfaz de Usuario (UI)
- `[x]` Crear `src/ui/components.lua` (dibujo de pads, botones, y el nuevo `DrawPaginator`).
- `[x]` Crear `src/ui/views.lua` (ensamblaje de la vista Full y la vista Compacta vía LICE).
- `[x]` Implementar soporte de rueda del ratón (scroll) para cambiar las páginas en el paginador.

## Fase 4: Integración y Manejo de Foco
- `[x]` Crear `src/main.lua` como punto de entrada.
- `[x]` Implementar *throttle* para `GetFocusedFX` e inyección condicional de `JS_VKeys_Intercept`.
- `[x]` Unir todas las piezas y probar el ciclo diferido (`reaper.defer`).

## Fase 5: Selectores SVG y Performance Pads
- `[x]` Crear `components.DrawDropdown` para abrir menús nativos (`gfx.showmenu`).
- `[x]` Crear `components.DrawPianoKeyboard` para selección interactiva de nota raíz.
- `[x]` Actualizar `components.DrawScalePad` para reflejar el color dinámico y pulsing basado en pulsaciones.
- `[x]` Refactorizar `views.DrawFullView` para organizar los paneles Top (Piano+Dropdowns) y Middle (Pads).
- `[x]` Sincronizar zona de progresiones y paginador con SVG (Colores y signo '+').

## Fase 6: Réplica Exacta de UI (Islands & Header)
- `[x]` Implementar `views.DrawHeader` con título, copyright e iconos.
- `[x]` Implementar `components.DrawToolIcon` para Ajustes y Vista.
- `[x]` Refactorizar `views.DrawFullView` al sistema de "Islas" (4 contenedores independientes).
- `[x]` Implementar botones rápidos de Octava y Chord en sus respectivas islas.
- `[x]` Implementar visor de nota (NOTE) debajo del piano.
- `[x]` Ajustar dimensiones de ventana a 900x550.
- `[x]` Pulido profesional: Ajustar paddings, alineaciones y tipografía (Bold, Centrados).
