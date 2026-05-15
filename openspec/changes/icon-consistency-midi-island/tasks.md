# Tasks: Icon Consistency — MIDI Island Style

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~302 (187 buttons.lua + 109 icons.lua + 6 islands.lua) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: feature-branch-chain
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | PR | Notes |
|------|------|----|-------|
| 1 | Rewrite DrawToolIcon + delete icons.lua + islands cleanup | PR 1 | Single PR, ~302 lines, under 400 budget |

## Phase 1: Core Implementation — DrawToolIcon Rewrite

- [x] 1.1 Rewrite buttons.DrawToolIcon: replace procedural GFX for help (`?`), settings (`⚙`), view (`⊞`), clear (`✕`), export (`↗`) with Unicode glyphs + `components.DrawRoundedRect` background, mirroring `midi-island/header.lua:DrawToolModeRow` pattern
- [x] 1.2 Implement color state logic: `active→btn_active+text`, `hover(not active)→btn_hover+text`, `default→island_bg+text_dim` per spec table
- [x] 1.3 Ensure `gfx.setfont(1, "Calibri", math.floor(size*0.75))` before every `gfx.measurestr()`/`gfx.drawstr()` for font state isolation
- [x] 1.4 Center each glyph via `gfx.measurestr` → `gfx.x/y = x+(size-gw)/2, y+(size-gh)/2`
- [x] 1.5 Verify return contract unchanged: `return ui_store.GetMouseClick() and hover` (boolean)
- [x] 1.6 Remove 4 dead type branches: `scroll`, `vel`, `mod`, `sust` (~40 LOC removed)
- [x] 1.7 Verify barrel at `components.lua:189` (`components.DrawToolIcon = buttons.DrawToolIcon`) needs no change

## Phase 2: Dead Code Removal

- [x] 2.1 Delete `src/ui/icons.lua` (109 lines, zero `require("ui.icons")` calls confirmed by grep)
- [x] 2.2 Optional: Remove redundant outer `DrawRoundedRect` calls at `islands.lua:327-329` (clear bg) and `islands.lua:341-343` (export bg) — now harmless overdraw since `DrawToolIcon` owns its background

## Phase 3: Verification in REAPER

- [ ] 3.1 Launch script, visually verify all 5 tool icons (help header, settings header, view header, clear islands, export islands) render as Unicode glyph + rounded rect
- [ ] 3.2 Hover each icon: confirm `btn_hover` bg + glyph color change. Activate view toggle: confirm `btn_active` bg
- [ ] 3.3 Click clear → slots empty. Click export → MIDI item created. No regressions
- [ ] 3.4 REAPER console: confirm no "module not found: ui.icons" warnings
- [ ] 3.5 Font leak check: verify other UI text (dropdowns, labels, tooltips) renders correctly — no glyph artifacts
- [ ] 3.6 Static check: grep for `"scroll"`, `"vel"`, `"mod"`, `"sust"` in buttons.lua — 0 matches after change
