# Proposal: Separar estado global en stores (Phase 3d)

## Intent

375 refs a `config.state.*` en 13 archivos, todo tabla plana sin boundaries de dominio. Extraer 5 stores con getters/setters para encapsular estado por subsistema.

## Scope

- **In**: 5 stores (compact, sequencer, drag, midi, ui) en PR chain, 375 refs redirigidas, `config.state` reducido
- **Out**: `root_index/scale_index/octave/chord_mode_index` + `view_offset_x/y` (~67 refs) se quedan en `config.state`
- **Out**: `use_scroll` (5 refs) se queda — no justifica store propio

## Capabilities

None — pure refactor. No new behavior, no consumer API changes.

## Approach

PR chain (menor a mayor riesgo). Cada store encapsula su dominio con getters/setters; cada archivo importa el store que necesita.

| # | Store | Claves | Refs | LOC | Riesgo |
|---|-------|--------|------|-----|--------|
| 1 | `state/compact.lua` | compact.*, compact_overlay_active, last_gfx_state | ~23 | ~60-80 | Bajo |
| 2 | `state/sequencer.lua` | sequencer.*, progression[], current_page, page_override_timer, slot_flash | ~53 | ~120-160 | Bajo-Medio |
| 3 | `state/drag.lua` | drag.* (9 sub-keys) | ~62 | ~150-200 | Medio |
| 4 | `state/midi.lua` | use_velocity, last_note_played, active_note_draw_timer, key_states, active_notes, mouse_pad_state | ~38 | ~100-150 | Medio-Alto |
| 5 | `state/ui.lua` | view_mode, mouse_*, color_mode, slider_dragging, pad_flash, docked_mode, auto_start_* | ~110 | ~250-350 | Alto |

## Affected Areas

| Archivo | Impacto |
|---------|---------|
| `src/state/compact.lua` | Nuevo (~20 LOC) |
| `src/state/sequencer.lua` | Nuevo (~50 LOC) |
| `src/state/drag.lua` | Nuevo (~40 LOC) |
| `src/state/midi.lua` | Nuevo (~35 LOC) |
| `src/state/ui.lua` | Nuevo (~60 LOC) |
| `src/config.lua` | Reduce state table |
| 13 files `src/*/*.lua` | Import updates |

## Risks

| Riesgo | Prob. | Mitigación |
|--------|-------|------------|
| `mouse_click` como event bus (24 refs, 2 GFX contexts) | Alta | PR#5 dedicado, test manual widget por widget |
| `mouse_wheel_delta` zeroing pattern | Media | Documentar en spec, mantener patrón exacto |
| `sequencer.volume` UI→core dep (views escribe, midi lee) | Media | midi store importa sequencer store — cross-store dep explícita |
| Budget ~700-950 LOC > 400-line guard | Alta | PR chain obligatorio, cada PR < 400 LOC |
| `progression[]` array compartido (4 archivos) | Media | PR#2 unifica progression + sequencer en mismo store |

## Rollback Plan

`git revert <sha>` por PR individual. Cada store es autónomo en runtime — la chain no requiere merge estricto.

## Dependencies

Ninguna externa. Asume Phase 3a/3b/3c completadas (estructura de módulos descompuesta).

## Success Criteria

- [ ] 0 refs a `config.state.*` para claves extraídas
- [ ] `config.state` reducido a 6 claves root (~67 refs)
- [ ] 5 `src/state/*.lua` creados, 13 archivos modificados
- [ ] Comportamiento idéntico en main y compact GFX contexts
