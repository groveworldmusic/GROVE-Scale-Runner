# GROVE FL MIDI - Refactorización y Paginado (Completado)

## Resumen de Cambios
Se completó la migración del script monolítico a una arquitectura profesional modular basada en los estándares del motor SDD.

### Arquitectura de Módulos Implementada
- `src/main.lua`: Punto de entrada del script. Se encarga de instanciar la ventana gráfica y correr el ciclo diferido (`reaper.defer`). Implementa un _throttle_ de 200ms para revisar eficientemente el estado de `reaper.GetFocusedFX()` e inyectar `JS_VKeys_Intercept` solo cuando corresponde, protegiendo los comandos base de Reaper.
- `src/config.lua`: Contiene las escalas, notas, acordes y maneja el **estado global**, el cual fue ampliado para alojar la progresión de 16 slots y la página actual activa.
- `src/core/midi.lua` y `src/core/sequencer.lua`: Extraen la capa matemática musical y el loop de reproducción, que ahora es capaz de iterar sobre 16 slots y actualizar automáticamente la variable de paginado en UI.
- `src/ui/theme.lua`: Consolidación del diseño extrayendo la paleta RGB estricta de la documentación SVG.
- `src/ui/components.lua` y `src/ui/views.lua`: Controladores de GFX que renderizan el nuevo `DrawPaginator` con soporte a clics y rueda del ratón (scroll), además de redibujar los contenedores de los acordes según la página visible.

### UI Completa Integrada (Fase 5)
El documento SVG provisto detalla una UI premium que ahora ha sido implementada fielmente en Reaper:
- **Teclado Piano Virtual**: Se eliminaron los botones de texto para la nota raíz y se creó una vista de piano a escala (`components.DrawPianoKeyboard`) interactiva y estilizada con los colores oscuros de la marca (teclas `#d9d9d9`, marcadores `#2e4668`).
- **Selectores Compactos (Dropdowns)**: Para conservar espacio como indica el SVG, las escalas y las- **Native-Style Dropdowns:** Implemented `components.DrawDropdown` using `gfx.showmenu()`. This provides a polished, space-efficient UX for selecting Scales and Octaves, as per the SVG specs.
- **Performance Pads:** Standardized `components.DrawScalePad` with Roman numeral labeling and visual feedback, integrated with the existing `key_states` engine.

### **Fase 6: Réplica Exacta de UI (Layout de Islas)**
*   **Header Completo:** Se implementó `views.DrawHeader` con el título "GROVE SCALE RUNNER", versión, copyright e iconos de herramientas (Ajustes y Vista) dibujados mediante vectores.
*   **Arquitectura de Islas:** La interfaz se divide ahora en 4 contenedores independientes ("islas") con fondo `#333`, organizados en una fila superior balanceada.
*   **Controles Rápidos:** Se añadieron botones de acceso directo para Octavas (C5, C4, C3) y tipos de acorde (Note, Triada, 7ma, 9na) directamente en sus respectivas islas, evitando clics extra en menús desplegables.
*   **Visor NOTE:** Se integró un visor dinámico debajo del teclado piano que muestra la última nota tocada o seleccionada, manteniendo la paridad con el diseño SVG.
*   **Dimensiones Finales:** Ventana optimizada a `900x550` para un layout profesional y despejado.
legante el pulso (`pulsing/decay`) cuando tocas el teclado QWERTY, utilizando el azul corporativo (`#3f81da`) y marcando los grados con números romanos (I, ii, iii, IV, etc.).
- **Arrastrar y Soltar**: Re-cableado fluido de la acción de arrastrar un grado de un pad hacia uno de los slots de las progresiones en el paginador.
## Verificación Manual Requerida
Por favor, abre `src/main.lua` dentro del IDE de Reaper (ReaScript) y ejecútalo. 

1. **Diseño Visual**: Comprueba que los colores corresponden al SVG (fondo `#0d0d0d`, acentos `#3f81da`).
2. **Navegación**: Usa la rueda del ratón sobre el área del paginador abajo a la derecha y verifica que cambia la página (y los índices de los contenedores).
3. **Prueba de Foco**: Abre un VST y toca notas QWERTY. Luego, haz clic fuera del plugin, sobre la vista Arrange de Reaper, y presiona la barra espaciadora. Debería funcionar la reproducción normal de Reaper sin que el script intercepte y asuma que estás tocando una nota.

> [!TIP]
> Dado que dividimos el proyecto en módulos, recuerda que para distribuir el script a tus usuarios, Reaper permite "empaquetar" todo usando extensiones, o simplemente distribuís la carpeta `src` entera vía ReaPack en un único commit.
