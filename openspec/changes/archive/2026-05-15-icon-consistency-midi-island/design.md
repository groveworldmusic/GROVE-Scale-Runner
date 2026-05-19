# Design: Icon Consistency — MIDI Island Style

## Technical Approach

Rewrite `buttons.DrawToolIcon()` (lines 15-132) to replace 5 procedural GFX paths (help, settings, view, clear, export) with Unicode glyphs + `components.DrawRoundedRect()` backgrounds, mirroring `midi-island/header.lua:DrawToolModeRow` pattern exactly. Remove 4 dead code paths (scroll, vel, mod, sust). Delete dead `icons.lua`. No call-site changes needed — all 5 invocations via `components.DrawToolIcon` barrel benefit transparently.

No `config.state` changes. Single GFX context (main window). No circular dependency impact.

## Architecture Decisions

### Decision: Unicode glyphs over procedural GFX

| Option | Tradeoff |
|--------|----------|
| Procedural (current) | ~50 LOC per icon, inconsistent look, harder to maintain |
| Unicode glyphs (chosen) | 1 `gfx.drawstr()` call per icon, proven in MIDI island header, 0 custom math |
| Bundled icon font | Overkill for 5 icons, adds asset dependency |

### Decision: Self-drawn rounded rect inside DrawToolIcon

`DrawToolIcon` now owns its background. Islands.lua's outer `DrawRoundedRect` for clear/export becomes redundant but harmless (opaque overdraw). In a follow-up, islands.lua lines 327-329 and 341-343 can be removed for cleanliness.

## Data Flow

```
Call site (header/islands)
  → components.DrawToolIcon(type, x, y, size, active?)   [barrel]
    → buttons.DrawToolIcon(type, x, y, size, active?)
      1. Set bg color from state (active/hover/default)
      2. gfx.setfont("Calibri", size*0.75)
      3. components.DrawRoundedRect(x, y, size, size, r=size/4, fill=true)
      4. Set glyph color (active→text, else→text_dim)
      5. gw,gh = gfx.measurestr(glyph)
      6. gfx.x = x+(size-gw)/2, gfx.y = y+(size-gh)/2
      7. gfx.drawstr(glyph)
      8. Return ui_store.GetMouseClick() and hover
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/ui/buttons.lua` | Modify | Rewrite `DrawToolIcon`: Unicode glyphs + rounded rect bg; remove scroll/vel/mod/sust (~40 LOC saved, net) |
| `src/ui/icons.lua` | Delete | 109 lines, zero `require("ui.icons")` calls confirmed by grep |
| `src/ui/components.lua` | Nop | Barrel at line 189 already points to `buttons.DrawToolIcon`. Remove icons.lua re-export if present — confirmed absent. |
| `src/ui/views/islands.lua` | Optional cleanup | Lines 327-329, 341-343 outer `DrawRoundedRect` now redundant |

## Icon Mapping

| Type | Glyph | Codepoint | Notes |
|------|-------|-----------|-------|
| help | `?` | U+003F | Same as current, now inside rounded rect |
| settings | `⚙` | U+2699 | Gear — literal semantic match |
| view | `⊞` | U+229E | Squared Plus = expand (compact toggle) |
| clear | `✕` | U+2715 | Dingbats block, same family as ✎/✂ |
| export | `↗` | U+2197 | NE arrow = export motion |

## Color/State Logic (exact mirror of header.lua lines 113-116)

| State | Background | Glyph |
|-------|-----------|-------|
| `active=true` | `btn_active` (#3f81da blue) | `text` (#e6e6e6 white) |
| Hover (not active) | `btn_hover` (#444444) | `text_dim` (#858585) |
| Default | `island_bg` (#333333) | `text_dim` (#858585) |

Font: `gfx.setfont(1, "Calibri", math.floor(size * 0.75))` — scaled proportionally to icon size, matching MIDI island header convention.

## Dead Code Removal

4 type branches removed from `DrawToolIcon`:
- **scroll** (lines 42-51): up/down arrows — unused in codebase
- **vel** (lines 94-100): velocity bar + dot — unused
- **mod** (lines 102-116): sine wave — unused
- **sust** (lines 118-128): bracket shape — unused

Total: ~40 LOC removed, reducing `DrawToolIcon` from 117 to ~70 lines.

## icons.lua Deletion

File `src/ui/icons.lua` (109 lines) contains:
- `DrawIcon()` function — duplicate of `DrawToolIcon` with same procedural icons
- Icon types (prev/next/up) already handled elsewhere

Grep confirmed zero `require("ui.icons")` calls across all `src/` files. Safe to delete entirely.

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Visual | All 5 icons render as Unicode + rounded rect | Launch script in REAPER, inspect header (help, settings, view) and islands (clear, export) |
| Visual | Color states match MIDI island | Hover each icon, verify `btn_hover` bg. Activate view toggle, verify `btn_active` |
| Visual | Clear/export still functional | Click clear → slots empty. Click export → MIDI item created |
| Regression | No missing require warnings | REAPER console: confirm no "module not found: ui.icons" |
| Visual | Font leak check | Other text (dropdowns, labels) unaffected — verify no rendering artifacts |
| Static | Dead types removed | Grep for "scroll"/"vel"/"mod"/"sust" in buttons.lua after change — 0 matches |

Since there's no test runner (see `openspec/config.yaml`: `tdd: false`), verification is manual REAPER inspection.

## Migration

No migration required. Pure visual change — no state, no data, no config.

## Open Questions

- None. Proposal is precise, code reading confirmed all assumptions.
