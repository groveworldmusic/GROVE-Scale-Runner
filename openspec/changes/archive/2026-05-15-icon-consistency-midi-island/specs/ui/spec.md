# Delta for UI — Icon Consistency: MIDI Island Style

## ADDED Requirements

### Requirement: Visual Uniformity — Unicode Glyph in Rounded Rect

Each of the 5 tool icon types (help, settings, view, clear, export) MUST render as a Unicode glyph centered inside a `components.DrawRoundedRect` background, matching the MIDI island header style (Paint ✎, Knife ✂).

#### Scenario: Help icon renders as "?" glyph on rounded rect

- GIVEN `DrawToolIcon("help", x, y, size, false)` is called
- WHEN `gfx.drawstr` renders the icon
- THEN the glyph `?` (U+003F) appears centered inside a rounded rect
- AND `gfx.setfont` is called before each draw to prevent font state leak

#### Scenario: Settings icon renders as gear glyph

- GIVEN `DrawToolIcon("settings", x, y, size, false)` is called
- WHEN the icon renders
- THEN the glyph `⚙` (U+2699) appears centered inside a rounded rect

#### Scenario: View icon renders as squared plus glyph

- GIVEN `DrawToolIcon("view", x, y, size, false)` is called
- WHEN the icon renders
- THEN the glyph `⊞` (U+229E) appears centered inside a rounded rect

#### Scenario: Clear icon renders as multiplication sign glyph

- GIVEN `DrawToolIcon("clear", x, y, size, false)` is called
- WHEN the icon renders
- THEN the glyph `✕` (U+2715) appears centered inside a rounded rect
- AND the glyph belongs to the same Dingbats block as ✎ (U+270E) and ✂ (U+2702), maintaining visual consistency

#### Scenario: Export icon renders as north-east arrow glyph

- GIVEN `DrawToolIcon("export", x, y, size, false)` is called
- WHEN the icon renders
- THEN the glyph `↗` (U+2197) appears centered inside a rounded rect

### Requirement: Color State Mapping

Background and glyph colors MUST follow the same state logic as MIDI island header buttons.

| State | Background | Glyph |
|-------|-----------|-------|
| Active (`active=true`) | `theme.colors.btn_active` | `theme.colors.text` |
| Hover (mouse inside, not active) | `theme.colors.btn_hover` | `theme.colors.text` |
| Default (no active, no hover) | `theme.colors.island_bg` | `theme.colors.text_dim` |

#### Scenario: Active icon shows btn_active background with text color

- GIVEN `DrawToolIcon("clear", x, y, size, true)` is called
- WHEN the icon renders
- THEN the background uses `theme.colors.btn_active`
- AND the glyph uses `theme.colors.text`

#### Scenario: Hovered icon shows btn_hover background with text color

- GIVEN `DrawToolIcon("help", x, y, size, false)` is called
- AND the mouse cursor is within the icon bounds
- WHEN the icon renders
- THEN the background uses `theme.colors.btn_hover`
- AND the glyph uses `theme.colors.text`

#### Scenario: Default icon shows island_bg background with text_dim color

- GIVEN `DrawToolIcon("help", x, y, size, false)` is called
- AND the mouse cursor is outside the icon bounds
- WHEN the icon renders
- THEN the background uses `theme.colors.island_bg`
- AND the glyph uses `theme.colors.text_dim`

### Requirement: Glyph Centering via gfx.measurestr

Each glyph MUST be centered within the rounded rect using `gfx.measurestr` to calculate the exact width and height, then positioning via `gfx.x`/`gfx.y`.

#### Scenario: Glyph centering is calculated per-frame

- GIVEN any icon type renders via `DrawToolIcon`
- WHEN the icon is drawn
- THEN `gfx.measurestr(glyph)` is called to obtain glyph dimensions
- AND `gfx.x`/`gfx.y` are set to `x + (size - glyph_w) / 2` / `y + (size - glyph_h) / 2`

### Requirement: Font State Isolation

`gfx.setfont()` MUST be called before every `gfx.measurestr()`/`gfx.drawstr()` call inside `DrawToolIcon` to prevent font state leaking from previous frames.

#### Scenario: Font is set before each draw call

- GIVEN `DrawToolIcon` is rendering an icon
- WHEN `gfx.measurestr` is called
- THEN `gfx.setfont(1, "Calibri", <size>)` has been called earlier in the same invocation

## MODIFIED Requirements

None — this is a pure visual refactor with no existing requirements in `openspec/specs/ui/`.

## REMOVED Requirements

### Requirement: Dead Type Removal

`DrawToolIcon` SHALL remove support for the following unused types, saving approximately 40 LOC: `scroll`, `vel`, `mod`, `sust`.

#### Scenario: Removed types return no rendering

- GIVEN `DrawToolIcon("scroll", x, y, size)` is called
- WHEN the function executes
- THEN the call produces no `gfx.*` draw calls
- AND the function returns the normal click-detection boolean

### Requirement: Delete src/ui/icons.lua

The file `src/ui/icons.lua` SHALL be deleted — zero `require("ui.icons")` calls exist in the codebase (confirmed via grep).

#### Scenario: No breakage from file deletion

- GIVEN `src/ui/icons.lua` has been deleted
- WHEN the application runs through Init
- THEN no error occurs from a missing `require("ui.icons")` module
- AND `components.lua` has no reference to `icons.lua` in its barrel re-exports

## NON-REQUIREMENTS (explicitly out of scope)

The following icons SHALL NOT be changed:
- Performance area prev/next (`◀`/`▶`) — different component lifecycle
- Docked transport bar icons (CLR, `◄`) — pixel-measured context
- Preset browser icons (`▶`/`▼`/`★`/`☆`) — already Unicode, different context
- MIDI island header (Paint ✎, Knife ✂) — reference implementation, no changes required

## Functional Invariants (SHALL NOT change)

| Invariant | Description |
|-----------|-------------|
| Click detection | `DrawToolIcon(...)` MUST return `true`/`false` (same boolean contract as current) |
| `active` param | `active` flag MUST still toggle the visual state between active/default colors |
| Barrel alias | `components.DrawToolIcon = buttons.DrawToolIcon` MUST remain unchanged |
| Call sites | All 5 call sites (`header.lua:107,110,162`, `islands.lua:332,346`) MUST work without code changes |

