## Exploration: Icon Consistency — MIDI Island Style

### Current State

There are **three separate icon rendering approaches** in the codebase, and a fourth in dead code:

#### 1. Reference Style — MIDI Island Header (`src/ui/midi-island/header.lua`)
- PAINT uses Unicode glyph `✎` (U+270E), KNIFE uses `✂` (U+2702)
- Rendered via `gfx.setfont(1, "Calibri", layout.US(1500))` + `gfx.drawstr()`
- Each button has a **rounded rect background** via `components.DrawRoundedRect(tx, header_y, tool_btn_w, b_h, 10, true)`
- Color states: `btn_active` (active) / `btn_hover` (hover) / `island_bg` (default) for bg; `text` / `text_dim` for glyph
- Glyph centered via `gfx.measurestr()` positioning
- **This is what the user wants everywhere**

#### 2. Procedural GFX — `buttons.DrawToolIcon()` (`src/ui/buttons.lua`, lines 15-132)
- Used by: app header (help ✚ settings ✚ view), CLEAR, EXPORT
- Draws icons procedurally with `gfx.circle()`, `gfx.line()`, `gfx.rect()` — NO Unicode glyphs
- **NO rounded rect background** — icons float directly on whatever bg is underneath
- 9 icon types defined: `"settings"`, `"view"`, `"help"`, `"scroll"`, `"clear"`, `"export"`, `"vel"`, `"mod"`, `"sust"`
- Of these, only **5 are actually called**: `"help"`, `"settings"`, `"view"` (from `views/header.lua`), `"clear"`, `"export"` (from `views/islands.lua`)
- The other 4 (`"scroll"`, `"vel"`, `"mod"`, `"sust"`) are **dead paths inside DrawToolIcon** — never called from anywhere
- `components.DrawToolIcon` is a barrel alias to `buttons.DrawToolIcon` (components.lua line 189)

#### 3. Hybrid (mostly dead) — `icons.lua` (`src/ui/icons.lua`)
- Contains `DrawIcon(type, x, y, size, active, color)` — a separate function from `DrawToolIcon`
- Has BOTH procedural GFX (settings, view, help, scroll, clear, export — identical code to buttons.lua) AND Unicode (prev ◀, next ▶, up ⬆)
- Has an extra `color` parameter that `DrawToolIcon` lacks
- **NEVER required anywhere in the project** — zero `require("ui.icons")` calls → **dead code** that should be removed or revived

#### 4. Inline text/Unicode (other UI areas)
- Performance area: plain `<` and `>` for prev/next page (`views/performance.lua`)
- Preset browser: `▶`/`▼` for folders, `★`/`☆` for favorites, `..` for up navigation (`preset-browser.lua`)
- Docked transport bar: `◄` for undock, `CLR` text for clear (`views/docked.lua`)
- Command islands (VEL, SUS, MOD, PLAY, MIDI): inline `gfx.drawstr("VEL")` etc. (`views/islands.lua`) — these are text labels, not icons

### Affected Areas

- `src/ui/buttons.lua` — **Primary target**: `DrawToolIcon()` lines 15-132 needs full rewrite to Unicode + rounded rect
- `src/ui/icons.lua` — Dead code; evaluate whether to revive as unified source or delete
- `src/ui/components.lua` — Line 189 barrel alias; may need to re-route to new implementation
- `src/ui/views/header.lua` — Lines 107, 110, 162: calls `DrawToolIcon("help")`, `DrawToolIcon("settings")`, `DrawToolIcon("view")` — will automatically benefit from changes to `DrawToolIcon`
- `src/ui/views/islands.lua` — Lines 332, 346: calls `DrawToolIcon("clear")`, `DrawToolIcon("export")` — will automatically benefit
- `src/ui/views/docked.lua` — Line 120: Unicode `◄` for undock; line 114: `CLR` text — could be unified
- `src/ui/views/performance.lua` — Lines 99, 119: plain `<` `>` for prev/next — could use Unicode style
- `src/ui/midi-island/header.lua` — Reference implementation, no changes needed

### Icon Inventory

| Icon Type | Used At | Current Method | Matches MIDI Island Style? |
|-----------|---------|----------------|---------------------------|
| **paint** | midi-island/header.lua:117 | Unicode ✎ (U+270E) + rounded rect bg | ✅ Yes (reference) |
| **knife** | midi-island/header.lua:117 | Unicode ✂ (U+2702) + rounded rect bg | ✅ Yes (reference) |
| **help** | views/header.lua:107 | Procedural: circle + "?" text, NO bg | ❌ No |
| **settings** | views/header.lua:110 | Procedural: gear via 8 circles+lines, NO bg | ❌ No |
| **view** | views/header.lua:162 | Procedural: rect with divider line, NO bg | ❌ No |
| **clear** | views/islands.lua:332 | Procedural: trash can via lines+rects, NO bg | ❌ No |
| **export** | views/islands.lua:346 | Procedural: arrow from tray via lines, NO bg | ❌ No |
| scroll | _defined in buttons.lua, NEVER called_ | Procedural: up/down arrows | 🟡 Dead code |
| vel | _defined in buttons.lua, NEVER called_ | Procedural: bar + dot | 🟡 Dead code |
| mod | _defined in buttons.lua, NEVER called_ | Procedural: sine wave | 🟡 Dead code |
| sust | _defined in buttons.lua, NEVER called_ | Procedural: bracket shape | 🟡 Dead code |
| prev | performance.lua:99 | Plain `<` char, NO bg | ❌ No |
| next | performance.lua:119 | Plain `>` char, NO bg | ❌ No |
| undock | docked.lua:120 | Unicode ◄ (U+25C4) via DrawTransportButton | ❌ No (no rounded rect bg) |
| **clear (docked)** | docked.lua:114 | Text "CLR" via DrawTransportButton | ❌ No |
| VEL | islands.lua:241 | Text "VEL" inline, rounded rect bg | ⚠️ Text, not icon |
| SUS | islands.lua:258 | Text "SUS" inline, rounded rect bg | ⚠️ Text, not icon |
| MOD | islands.lua:284 | Text "MOD" inline, rounded rect bg | ⚠️ Text, not icon |
| folder icon | preset-browser.lua:525 | Unicode ▶/▼ (U+25B6/U+25BC) | ⚠️ Different context |
| star fav | preset-browser.lua:611 | Unicode ★/☆ (U+2605/U+2606) | ⚠️ Different context |

### Available Unicode Replacements

Evaluated for **Calibri font** (the project standard) on Windows:

| Icon | Current | Proposed | Codepoint | Calibri Support | Notes |
|------|---------|----------|-----------|-----------------|-------|
| **help** | circle + "?" | `?` | U+003F | ✅ Always available | Same glyph, in rounded rect |
| **settings** | procedural gear | `⚙` | U+2699 | ✅ Yes | Perfect match — literally a gear |
| **view** | procedural rect+divider | `⊞` | U+229E | ✅ Yes | Squared Plus = expand |
| **view** (alt) | — | `⊟` | U+229F | ✅ Yes | Squared Minus = collapse (for toggle states) |
| **clear** | procedural trash can | `✕` | U+2715 | ✅ Yes | Same glyph family as ✎, ✂ (Dingbats) |
| **clear** (alt) | — | `⌫` | U+232B | ✅ Yes | Erase to the left — intuitive for clear |
| **export** | procedural arrow+tray | `↗` | U+2197 | ✅ Yes | North East Arrow — export/upward motion |
| **export** (alt) | — | `⬆` | U+2B06 | ✅ Yes | Upwards Black Arrow |
| **export** (alt2) | — | `⇧` | U+21E7 | ✅ Yes | Upwards White Arrow |
| scroll | procedural arrows | `⇅` | U+21C5 | ✅ Yes | Up Down Double Arrow |
| scroll (alt) | — | `↕` | U+2195 | ✅ Yes | Up Down Arrow |
| mod | procedural sine wave | `∿` | U+223F | ✅ Yes | Sine Wave — same meaning |
| sust | procedural brackets | `𝄐` | U+1D110 | ⚠️ Unlikely | Not in Calibri; better use text "SUS" |
| vel | procedural bar+dot | `𝘃` | U+1D603 | ⚠️ Unlikely | Not a great match; better use text "VEL" |
| **prev** | plain `<` | `◀` | U+25C0 | ✅ Yes | Already used in `icons.lua` |
| **next** | plain `>` | `▶` | U+25B6 | ✅ Yes | Already used in `icons.lua` |
| undock | `◄` (docked) | `◁` or keep ◄ | U+25C1 | ✅ Yes | Already working |

**Key finding**: The ✎ (U+270E) and ✂ (U+2702) used in the MIDI island are from the **Dingbats** Unicode block (U+2700–U+27BF). The ✕ (U+2715) is from the same block, making it the most visually consistent choice for CLEAR.

### The `icons.lua` Situation

`icons.lua` (109 lines) is **entirely dead code**:
- Zero `require("ui.icons")` calls exist anywhere in the project
- Its `DrawIcon()` function duplicates the procedural GFX from `buttons.DrawToolIcon()` for 6 types (settings, view, help, scroll, clear, export)
- It adds Unicode support for 3 types not in `DrawToolIcon` (prev, next, up)
- It has a `color` parameter that `DrawToolIcon` lacks

**Recommendation**: Either revive `icons.lua` as the single source of truth or delete it. Keeping dead code creates confusion about which icon system is "current."

### Approaches

#### 1. Unicode Conversion — Rewrite `DrawToolIcon` (Recommended)
Replace ALL procedural GFX in `buttons.DrawToolIcon()` with Unicode glyphs + rounded rect backgrounds, matching the MIDI island header style exactly.

- **What**: Each icon type gets a Unicode glyph + `components.DrawRoundedRect` bg. Same color/state/hover logic as MIDI island.
- **Icon mapping**:
  - `help` → "?" in rounded rect
  - `settings` → "⚙" in rounded rect
  - `view` → "⊞"/"⊟" in rounded rect (toggle states)
  - `clear` → "✕" in rounded rect
  - `export` → "↗" or "⬆" in rounded rect
  - Remove dead types: scroll, vel, mod, sust
  - Clean up `icons.lua` (delete or revive as the new unified source)
- **Pros**: Direct fix — all call sites (`views/header.lua`, `views/islands.lua`) benefit automatically; matches the exact look the user wants; eliminates dead code paths
- **Cons**: Need to verify every Unicode glyph renders correctly in REAPER GFX on Windows (Calibri); some glyphs may be wider/narrower requiring size adjustments
- **Effort**: Medium (~1-2h code, ~1h testing)

#### 2. Full Unification — Revive `icons.lua` as Single Source
Move all icon rendering into `icons.lua`, make `DrawToolIcon` delegate to `DrawIcon`, update the barrel alias.

- **What**: `icons.lua` becomes the sole icon module. `components.DrawToolIcon` routes to `icons.DrawIcon`. Remove procedural code from `buttons.lua`.
- **Pros**: Single source of truth; `icons.lua` already has the right structure for this (color param, Unicode support for prev/next); cleans up dead code properly
- **Cons**: More indirection; `icons.lua` needs full rewrite anyway (it currently has procedural GFX for most types); the barrel alias means callers still use `components.DrawToolIcon`
- **Effort**: Medium-High (~2-3h)

#### 3. Minimal Change — Add Rounded Rect Bg to Current `DrawToolIcon`
Keep existing procedural GFX but add a rounded rect background behind each icon + polish the drawing.

- **What**: Add `components.DrawRoundedRect(x, y, size, size, 10, true)` before drawing each icon type in `DrawToolIcon`. Keep procedural GFX.
- **Pros**: Minimal code change; no Unicode compatibility risk
- **Cons**: Procedural GFX will NEVER look as clean as professionally-designed font glyphs; the mismatch the user reports is fundamental (lines vs. smooth glyphs), not just missing bg
- **Effort**: Low-Medium (~1h)
- **Verdict**: ❌ Doesn't fully address the user's complaint

### Recommendation

**Approach 1 — Unicode Conversion of `DrawToolIcon`** with cleanup of dead code.

Why:
1. It matches the user's request exactly — all icons look like MIDI island PAINT/CUT
2. The approach is proven — ✎ and ✂ already work beautifully in the same codebase
3. All call sites benefit automatically — no changes needed in `views/header.lua` or `views/islands.lua`
4. It eliminates 4 dead code paths (scroll, vel, mod, sust) within `DrawToolIcon`
5. It allows cleaning up `icons.lua` (delete or repurpose as the unified module)

**Implementation sketch**:
1. In `buttons.lua`, replace all procedural GFX in `DrawToolIcon()` with Unicode glyphs
2. Add `components.DrawRoundedRect()` call at the top of `DrawToolIcon()` for the background
3. Match the color/state logic from MIDI island header exactly
4. Keep the `active` parameter for toggle state coloring (like settings menu)
5. Remove dead paths (scroll, vel, mod, sust)
6. Either delete `icons.lua` or port its Unicode types (prev ◀, next ▶, up ⬆) into the new `DrawToolIcon`
7. Validate every glyph renders correctly in REAPER

### Risks

- **Unicode glyph rendering**: Some glyphs may render as tofu (□) on systems without Calibri or with older versions. `⚙` (U+2699) is well-supported but should be tested. `∿` (U+223F) is less common.
- **Glyph width variance**: Unicode glyphs have different advance widths — centering logic must account for this via `gfx.measurestr()` (already done in MIDI island)
- **Font size scaling**: MIDI island uses `layout.US(1500)` for its glyphs, the app header uses a different sizing — need to normalize sizes for visual consistency
- **REAPER GFX quirk**: `gfx.setfont()` persists across frames. Any icon rendering must ensure font is set correctly before drawing (not assumed from previous draw calls)
- **`icons.lua` cleanup**: If we keep `icons.lua` around as dead code, it will continue to confuse. Must either delete or actively revive.
- **Docked transport bar icons**: The docked bar uses pixel measurements (not layout.US) — Unicode glyphs at small pixel sizes (~12px) may look different than the scaled layout versions

### Ready for Proposal

Yes — proceed to SDD proposal with Approach 1 (Unicode Conversion). The user should know:
- PAINT ✎ and KNIFE ✂ are the reference — the change makes ALL procedural icons look like them
- CLEAR will use ✕, EXPORT will use ↗ or ⬆, SETTINGS will use ⚙, VIEW will use ⊞/⊟
- HELP will keep `?` but in a rounded rect with proper MIDI island styling
- Dead types and `icons.lua` will be cleaned up
- Risk of Unicode tofu needs testing but all proposed glyphs are well-supported on Windows/Calibri
