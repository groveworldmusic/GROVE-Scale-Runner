# Proposal: Icon Consistency — MIDI Island Style

## Intent

Procedural GFX icons (help, settings, view, clear, export) look mismatched vs MIDI island header icons (PAINT ✎, KNIFE ✂). Goal: make ALL procedural icons use the same Unicode glyph + rounded rect background style proven in `midi-island/header.lua`.

## Scope

### In Scope
- Convert `buttons.DrawToolIcon()` for: help, settings, view, clear, export → Unicode glyph + `DrawRoundedRect` bg
- Add rounded rect background matching `midi-island/header.lua` color/state logic (btn_active/hover/island_bg)
- Remove 4 dead code paths: scroll, vel, mod, sust
- Delete `src/ui/icons.lua` (entirely dead — zero require calls)
- Update barrel re-exports in `components.lua` as needed

### Out of Scope
- Performance area prev/next (`<` `>`) — different component, no user complaint
- Docked transport (CLR, ◄) — pixel-measured context; unmatched if changed now
- Preset browser icons (▶/▼/★/☆) — already Unicode, different context
- MIDI island header — reference, no changes needed

## Capabilities

None — pure UI refactor. No spec-level behavior changes.

## Approach

Replace all procedural GFX in `buttons.DrawToolIcon()` with Unicode glyphs + `components.DrawRoundedRect()` bg, matching `midi-island/header.lua` exactly:

| Icon | Current | Unicode | Codepoint | Notes |
|------|---------|---------|-----------|-------|
| help | circle + `?` | `?` | U+003F | Same glyph, now in rounded rect |
| settings | 8-circle gear | `⚙` | U+2699 | Literally a gear — perfect match |
| view | rect + divider | `⊞` / `⊟` | U+229E/F | Squared Plus/Minus = expand/collapse toggle |
| clear | procedural trash | `✕` | U+2715 | Same Dingbats block as ✎, ✂ |
| export | arrow + tray | `↗` | U+2197 | NE arrow = export motion |

- Add `components.DrawRoundedRect()` + color state at top (bg params: `btn_active` / `btn_hover` / `island_bg`)
- Glyph centered via `gfx.measurestr()` (established pattern)
- Remove dead types (scroll, vel, mod, sust) — saving ~40 LOC
- Delete `icons.lua` — confirmed zero `require("ui.icons")` calls
- All call sites (`views/header.lua:107,110,162`, `views/islands.lua:332,346`) benefit automatically

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/buttons.lua` | Modified | `DrawToolIcon()` rewrite: Unicode + rounded rect bg; remove 4 dead paths |
| `src/ui/icons.lua` | Removed | Dead file deleted (109 lines, zero requires) |
| `src/ui/components.lua` | Modified | Remove icons.lua barrel re-export if present; verify no breakage |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Unicode tofu on non-Calibri systems | Low | All glyphs well-supported on Windows (Basic Latin, Dingbats, Arrows). |
| Glyph width breaks centering | Low | `gfx.measurestr()` used — same pattern as MIDI island. |
| Font state leak across frames | Low | `gfx.setfont()` called before each draw in new `DrawToolIcon`. |
| `icons.lua` referenced elsewhere | None | Grep confirmed zero require calls. |

## Rollback Plan

1. `git checkout src/ui/buttons.lua` — restores old `DrawToolIcon`
2. `git checkout src/ui/icons.lua` — restores dead file (or `git restore`)
3. `git checkout src/ui/components.lua` — restores barrel re-exports
4. Verify all 5 call sites render original procedural icons
5. Single-change scope = trivial revert

## Dependencies

None.

## Success Criteria

- [ ] All 5 icon types render as Unicode glyphs in rounded rect backgrounds
- [ ] Color states match MIDI island header exactly (bg: btn_active/hover/island_bg; glyph: text/text_dim)
- [ ] Click detection unchanged — all call sites return correct boolean
- [ ] Dead types (scroll, vel, mod, sust) removed from `DrawToolIcon`
- [ ] `icons.lua` deleted — zero `require("ui.icons")` calls confirmed via grep
- [ ] Visual consistency confirmed: help/settings/view/clear/export match PAINT/KNIFE style
