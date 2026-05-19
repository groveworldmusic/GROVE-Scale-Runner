# Color Themes Specification

**Domain**: color-themes
**Change**: expansion-features (P1)
**Type**: New — no existing spec

## Purpose

Provide 3 built-in color palettes (Current, Dark, High Contrast) with persistence and UI selector. All ~37 UI consumers continue using `theme.colors.*` with zero behavioral change when `theme_index == 1` (Current).

## Requirements

### Requirement: Theme Index Persistence

`preferences_store` MUST add a `theme_index` field (int, range 1–3, default 1) with getter `GetThemeIndex()` and setter `SetThemeIndex(idx)`. The setter MUST mark `save_pending = true` for debounced ExtState persistence via `TickSaveDebounce`.

#### Scenario: Theme index survives reload

- GIVEN the user selects "Dark" theme (index 2)
- WHEN the script reloads
- THEN `preferences_store.SyncFromState()` restores `theme_index = 2`
- AND the Dark palette is active on first frame

#### Scenario: No prior ExtState defaults to 1

- GIVEN no `theme_index` key exists in ExtState
- WHEN `preferences_store.Init()` runs
- THEN `theme_index` SHALL default to 1 (Current)

### Requirement: Theme Palette Definitions

`src/ui/themes.lua` MUST export a `themes` table with 3 entries, each containing an identical-shape `colors` table with these keys: `bg`, `fg`, `accent`, `island_bg`, `island_header`, `dim`, `midi_note`, `selection`, `grid_line`, `grid_beat`, `grid_sub`, `grid_row_highlight`, `pitch_label_bg`, `pitch_label_fg`, `slot_bg`, `slot_active`, `slot_inactive`, `transport_bg`.

Each theme MUST also define `grade_colors[7]` — ordered array of RGB tuples mapping grade→color (purple, blue, cyan, green, yellow, orange, red).

#### Scenario: All 3 themes produce valid colors

- GIVEN `themes[1]` (Current), `themes[2]` (Dark), and `themes[3]` (HighContrast)
- WHEN accessing `theme.colors.bg` for each
- THEN each SHALL return a non-nil RGB tuple
- AND HighContrast bg SHALL differ from Current bg by minimum perceptual contrast ratio

### Requirement: Transparent Theme Loader

`src/ui/theme.lua` MUST load `themes[preferences_store.GetThemeIndex()]` and assign its `colors` table to `theme.colors`. Switching the index MUST take effect on the next frame — no re-init required.

#### Scenario: Switch theme at runtime

- GIVEN the script is running with `theme.colors.bg == Current`
- WHEN `preferences_store.SetThemeIndex(2)` is called
- THEN on the next GFX frame `theme.colors.bg` SHALL reflect the Dark palette
- AND all UI components using `theme.colors.*` SHALL render with the new palette

### Requirement: Theme Selector UI

The MIDI island header MUST include a dropdown control for theme selection. The dropdown SHALL show the current theme name and list all 3 entries. Selection SHALL call `preferences_store.SetThemeIndex()`.

#### Scenario: Dropdown renders in header

- GIVEN the MIDI island is expanded
- WHEN the header renders
- THEN a theme selector control SHALL be visible between the PRESETS toggle and RELOAD button
- AND the label/text SHALL indicate the currently active theme name

## Non-Goals

- User-created themes (current palette only, no custom palette editor)
- Per-component color overrides
- Theme animation or transition effects
- `colors.lua` (grade→color for pads) — unchanged, uses dedicated `grade_colors` from active theme

## Dependencies

- **Builds on**: `preferences_store` with TickSaveDebounce pattern (existing)
- **P1 → P2 → P3**: P1 is independent — no dependency on P2 or P3. P1 header additions (theme dropdown) share the same header surface as P2 (remap button) and P3 (record toggle), so coordinate layout to avoid overlap.

## Test Requirements

| Assertion | Type |
|-----------|------|
| `theme_index` get/set roundtrip (1–3) | Unit |
| Default index = 1 on Init with no ExtState | Unit |
| `theme.colors.bg` changes after `SetThemeIndex` | Unit |
| All 3 themes produce non-nil, 3-element color tuples for every key | Static |
| HighContrast grade_colors[7] differ from Current by >30% luminosity per channel | Static |
