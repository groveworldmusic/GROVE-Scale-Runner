# Decisiones Técnicas (ADRs)

## ADR-001: Barrel Pattern en components.lua

**Contexto**: components.lua tenía 853 líneas con funciones de todos los dominios.
**Decisión**: Extraer a módulos dedicados y re-exportar via barrel pattern.
**Consecuencias**: Consumers (`views.lua`) siguen importando `components.*` — cero cambios de imports. El barrel oculta la complejidad interna.

## ADR-002: Stores con getters/setters explícitos (sin metatables)

**Contexto**: 375 referencias a `config.state.*` en 13 archivos, sin boundaries de dominio.
**Decisión**: 5 stores con tabla local + getters/setters + Init(). Sin metatables.
**Consecuencias**: Código explícito, fácil de debuggear, cada store encapsula su dominio. Las stores se inicializan desde `main.lua` con `Init(config.state)`.

## ADR-003: Lazy require para DrawRoundedRect

**Contexto**: Los widgets extraídos necesitan `DrawRoundedRect` que vive en `components.lua` (el barrel).
**Decisión**: `require("ui.components")` dentro del cuerpo de la función (no al cargar módulo).
**Consecuencias**: Evita dependencia circular. La función se resuelve en runtime cuando todos los módulos están cargados.

## ADR-004: DEGREE_KEY_LABELS en pads.lua

**Contexto**: La tabla `DEGREE_KEY_LABELS` era usada solo por `DrawScalePad`. El diseño original la ponía en `piano.lua`.
**Decisión**: Mover a `pads.lua` (único consumer) para evitar dependencia cruzada innecesaria.
**Consecuencias**: pads.lua se vuelve autónomo, piano.lua no exporta constantes que nadie más usa.

## ADR-005: LICE wrappers sin require("config")

**Contexto**: lice.lua necesitaba bitmap/font de config.state.compact. Había riesgo de dependencia circular.
**Decisión**: lice.lua NO hace `require("config")`. Recibe parámetros o usa `compact_store` directamente.
**Consecuencias**: lice.lua es seguro de importar desde cualquier lado. Más explícito, menos acoplamiento.

## ADR-006: stores con tabla mutable compartida

**Contexto**: `progression[]`, `key_states{}`, `active_notes{}` se mutan in-place (table.insert, table.remove, ref-counting).
**Decisión**: Las stores devuelven la referencia a la tabla original, no una copia.
**Consecuencias**: Los callers mutan directamente el estado compartido. Es más eficiente pero requiere disciplina para no romper encapsulamiento. Se compensa con getters/setters específicos para las operaciones comunes.

## ADR-007: Data model separado para Island (flat note list)

**Contexto**: El piano roll del modo ISLAND necesita notas MIDI absolutas con `{pitch, start_beat, duration, velocity, muted}`. Las progression entries existentes almacenan `{degree, root_index, scale_index, octave, chord_mode_index}` con patrones de acorde.
**Decisión**: Crear un data model separado en `state/island.lua` con notas planas (flat note list) en vez de enriquecer las progression entries.
**Consecuencias**: Cero acoplamiento entre island y sequencer state. Las notas se convierten desde progression via `ProgressionToNotes()` al entrar al modo ISLAND. Modificaciones en el piano roll no afectan la progression original. El costo es la duplicación de datos y la necesidad de sincronización manual.

## ADR-008: Dual-API para multi-selection (breaking + compat)

**Contexto**: Phase 4 del piano roll necesita multi-selection por lasso. El store actual tiene `selected_note_index` (single `number|nil`) usado por velocity.lua y la info bar.
**Decisión**: Reemplazar `selected_note_index` con `selected_indices{}` (`{[idx]=true}`). Agregar `GetPrimarySelectedIndex()` retornando la primera key. Mantener `GetSelectedNoteIndex()`/`SetSelectedNoteIndex()` como compat shims que usan el nuevo API.
**Consecuencias**: Cero regresión en velocity.lua y views.lua (info bar). El nuevo API permite multi-selection, toggle, count, y bulk operations. `SetNotes()` ahora llama `ClearSelection()` automáticamente porque los índices viejos son inválidos.

## ADR-009: Tool routing en views.lua (no en piano-roll.lua)

**Contexto**: 3 tool modes (pointer/pencil/eraser) necesitan dispatch de clicks diferente. `piano-roll.lua` ya tiene `HandleMouseClick()` y `NoteBlockHitTest()`.
**Decisión**: El dispatch por tool mode se hace en `views.lua` (DrawMIDIIsland mouse handling). `piano-roll.lua` expone `HandlePencilClick()` y `HandleEraserClick()` como funciones separadas. `views.lua` decide cuál llamar según `island_store.GetToolMode()`.
**Consecuencias**: views.lua mantiene el control del event loop (mouse state, click_consumed). piano-roll.lua se mantiene como API pura de dibujo/interacción del grid. Coincide con el flujo existente donde views.lua ya maneja timeline ruler y velocity editor routing.

## ADR-010: Bulk velocity con delta relativo

**Contexto**: Cuando múltiples notas están seleccionadas, el drag en velocity editor debe modificar TODAS las notas seleccionadas. Diferentes notas pueden tener diferentes velocidades base.
**Decisión**: Aplicar delta relativo desde el click inicial. `drag_initial_vel` se captura en mousedown. Cada frame computa `delta = new_vel - drag_initial_vel` y aplica a todas las notas seleccionadas.
**Consecuencias**: Preserva diferencias relativas entre notas (nota suave sigue siendo más suave que nota fuerte). Si solo una nota está seleccionada, aplica el valor absoluto directo (comportamiento legacy).

## ADR-011: Branding normalization — real name consistency over pseudonym

**Contexto**: El proyecto usaba `@author GROVE WORLD MUSIC`, SPDX `Andrik on the beat`, y README credit mixto para distribución ReaPack. La preparación para publicación requería branding unificado.
**Decisión**: Unificar todo a `Andrik Sanz Cordoví` — `@author`, SPDX copyright, y README credit. Separar rol de autor (persona real) vs nombre del producto (`APP_NAME = "GROVE Scale Runner"`).
**Consecuencias**: Consistencia total en headers y documentación. 49 source files restantes con SPDX `Andrik on the beat` quedan como follow-up scope separado. No afecta paths de código.

## ADR-012: Features catalog as single source of truth

**Contexto**: `docs/features.md` estaba desactualizado — la sección 7 (Preset Browser) solo cubría features base sin mencionar v3 metadata, multi-select, batch ops, preview audio, thumbnails, badges, versioning, packs, ni stats.
**Decisión**: Reescribir Section 7 completa documentando todas las features de presets, actualizar Section 13.2 con los nuevos campos de preset-store, agregar el set-based multi-select pattern a Section 15, resolver B14 en Section 16, y marcar F04 como implementada.
**Consecuencias**: El catálogo es ahora representativo del estado real del proyecto (~656 líneas). Sirve como referencia única tanto para desarrolladores como para LLMs. Se actualiza automáticamente con cada feature nueva.
