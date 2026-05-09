# Plan de Implementación: Réplica Exacta de UI (GROVE SCALE RUNNER)

Vamos a rediseñar completamente `DrawFullView` para que coincida píxel por píxel (en proporción) con el archivo `GROVE_Scale_Runner.svg`.

## User Review Required

1.  **Iconos del Header**: Reaper GFX no soporta SVG directamente. Voy a dibujar versiones simplificadas con vectores nativos (círculos y líneas) para el icono de ajustes (rueda dentada) y el icono de "Minimal View". ¿Te parece bien o prefieres un caracter de texto (como `*` o `v`)?
2.  **Dimensiones de la Ventana**: Para acomodar este diseño de "islas" con el header, propongo una ventana de `900x550`. ¿Es un tamaño que te resulte cómodo en Reaper?

## Proposed Changes

### `src/ui/views.lua`
- **[NEW] `views.DrawHeader()`**: Dibuja el título "GROVE SCALE RUNNER v1.0.0", el copyright y los iconos de herramientas en la parte superior.
- **[MODIFY] `views.DrawFullView()`**:
    - **Header**: Llama a `DrawHeader()`.
    - **Fila de Islas (Row 1)**:
        - **Isla 1**: Teclado Piano + Dropdown MODO + Visor NOTE.
        - **Isla 2**: Título OCTAVA + Dropdown C0-C8 + Botones rápidos [C5, C4, C3].
        - **Isla 3**: Título CHORD + Dropdown Tipo + Botones rápidos [9na, 7ma, Triada, Note].
        - **Isla 4**: Botón VEL + Botones apilados [Clear, Export, Play].
    - **Fila de Performance (Row 2)**:
        - Pads de performance y slots de progresión ocupando todo el ancho inferior.

### `src/ui/components.lua`
- **[NEW] `components.DrawToolIcon(type, x, y)`**: Dibuja iconos minimalistas para Ajustes y Vista.
- **[MODIFY] `components.DrawDropdown(...)`**: Ajuste estético para que coincida con el estilo de "Isla" (fondo `#0d0d0d` dentro de contenedor `#333`).

## Verification Plan
1. Ejecutar el script y validar que el Header aparezca con el título correcto.
2. Comprobar que los botones rápidos de Octava (C3, C4, C5) cambian el estado sin abrir el menú.
3. Verificar que la disposición de las 4 islas sea horizontal y balanceada.
4. Asegurar que los pads y la progresión se mantengan debajo de las islas.
