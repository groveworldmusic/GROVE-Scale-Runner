# Piano Roll Specification

## Purpose

Horizontal note grid with pitch×time layout. Renders note blocks from island store data, supports scroll and zoom, displays beat grid lines, and handles mouse interaction. No MIDI recording — Phase 1 renders static notes from the progression only.

New requirements added in this version: shift+click additive selection, cache invalidation on vertical zoom, scrollbar thumb bounds, lasso pitch clamp, and pencil snap behavior.

## Requirements

### Requirement: Grid Rendering

The piano roll SHALL render a 2D grid where the Y-axis represents pitch (rows, low-to-top) and the X-axis represents time (columns, left-to-right). Grid cells MUST be drawn using `gfx.rect` for lines and `DrawRoundedRect` (from `src/ui/helpers.lua`) for note blocks. Beat grid lines MUST use 4 opacity tiers (measure, beat, 1/8, 1/16) with alpha values specified in the Grid Hierarchy requirement. Vertical grid lines at beat positions SHALL be highlighted when they correspond to a pitch in the current scale — see Scale Snap Highlight requirement.

#### Scenario: Empty grid renders correctly

- GIVEN island mode active with an empty notes array
- WHEN the piano roll renders its first frame
- THEN the grid background, beat lines, and pitch axis labels render without errors
- AND zero note blocks are drawn

#### Scenario: Note block at correct position

- GIVEN a note `{pitch=60, start_beat=2.0, duration=1.5, velocity=100, muted=false}`
- WHEN the piano roll renders
- THEN a rectangle MUST appear with left edge at x-coordinate corresponding to beat 2.0
- AND width proportional to 1.5 beats at current zoom
- AND vertical position matching MIDI note 60 (middle C)

#### Scenario: Scale-snap vertical highlight on beat lines

- GIVEN a scale root=0 (C) and scale index=1 (Major, intervals {0,2,4,5,7,9,11})
- AND scale snap highlight is enabled in preferences
- WHEN the piano roll renders beat lines
- THEN vertical grid lines at pitches C, D, E, F, G, A, B `pitch % 12 ∈ {0,2,4,5,7,9,11}` SHALL render with a brighter grid color (e.g., `{0.5, 0.7, 0.5, 0.4}`)
- AND non-scale pitch rows SHALL render at the normal `grid_beat` alpha (0.35)

### Requirement: Grid Hierarchy (4 tiers)

The piano roll SHALL render beat grid with 4 distinct alpha tiers via helper colors from theme:

| Tier | Condition | Alpha | Line style |
|------|-----------|-------|------------|
| Measure | `beat % 4 == 0` | 0.60 | Bold (double `gfx.line`) |
| Beat | `beat == floor(beat)` | 0.35 | Normal 1px |
| 1/8 | `s % 2 == 0` when subdivision ≥ 4 | 0.15 | Normal 1px |
| 1/16 | All other subdivision positions | 0.08 | Normal 1px |

When subdivision mode < 4 (e.g., 1/8), all sub-beats render at the 1/8 tier (alpha 0.15).

#### Scenario: All 4 tiers visible at 1/16

- GIVEN subdivision = 4 (1/16), scroll showing beats 0-4
- WHEN grid renders
- THEN beat 0 and 4 render at alpha 0.60, beats 1-3 at 0.35, half-beats at 0.15, quarter-beats at 0.08

### Requirement: Virtual Scrolling

The piano roll MUST render only visible rows (pitch range currently on screen) plus a 2-octave buffer above and below. The keyboard strip SHALL scroll in sync with the grid using the same visible range. Scroll position is controlled by the island store's `ScrollX` value. The visible window MUST be computed each frame from `gfx.h`, `gfx.w`, the current `Zoom`, and the beat-to-pixel ratio. Scroll and visible-range logic lives in `interaction.lua`, which owns mouse wheel and scrollbar drag dispatch.

#### Scenario: Scroll changes visible region

- GIVEN the piano roll at zoom 1.0 showing beats 0-16
- WHEN `island_store.SetScrollX(128)` (scroll by 8 beats at 16px/beat)
- THEN the first visible beat column changes from 0 to ~8
- AND note blocks outside the visible region are not drawn

#### Scenario: Buffer protects against pop-in

- GIVEN the piano roll virtual scrolling active
- WHEN the visible region ends at octave 4
- THEN rows for octaves 3 and 5 MUST also be pre-rendered (2-octave buffer)

### Requirement: Zoom

The SHALL expose zoom levels from 0.25x (compressed) to 4.0x (expanded) via `island_store.GetZoom()`. Zoom modifies the beat-to-pixel ratio: higher zoom = wider note blocks and beat spacing. Zoom MUST NOT change the scroll position's beat offset (only the visual scale).

#### Scenario: Zoom preserves scroll beat offset

- GIVEN scroll at beat 4.0 and zoom 1.0
- WHEN zoom changes to 2.0
- THEN `GetScrollX()` (beat-based) remains the same
- BUT the pixel position of beat 4.0 moves rightward

### Requirement: Mouse Wheel Scroll

Mouse wheel delta (`gfx.mouse_wheel`, captured and zeroed per the project pattern) SHALL control horizontal scroll when the cursor is over the piano roll region. Positive delta scrolls right; negative scrolls left. The scroll speed MUST be proportional to current zoom level. The wheel handler lives in `interaction.lua`; the existing zeroing pattern (`gfx.mouse_wheel` consumed per frame) MUST be preserved.

#### Scenario: Wheel scrolls piano roll

- GIVEN the piano roll rendering at zoom 1.0
- WHEN `gfx.mouse_wheel` = 3 and cursor is within piano roll bounds
- THEN `island_store.ScrollX` increases by 3 beats (or equivalent at current zoom)
- AND `gfx.mouse_wheel` is zeroed to 0 after consumption

#### Scenario: Wheel outside piano roll ignored

- GIVEN the piano roll rendering
- WHEN `gfx.mouse_wheel` = 3 but cursor is over the velocity editor region
- THEN the piano roll's scroll position MUST NOT change

### Requirement: Horizontal Scrollbar Interaction

The scrollbar thumb SHALL be draggable via click-and-drag. Thumb width MUST be proportional to the visible fraction of the total timeline. Drag MUST update `island_store.ScrollX` proportionally. Click on track outside thumb SHALL page-scroll by one viewport width.

#### Scenario: Drag thumb scrolls

- GIVEN scrollbar at ScrollX=0
- WHEN user drags thumb right by 30px
- THEN ScrollX increases proportionally

#### Scenario: Click track pages

- GIVEN scrollbar at leftmost position
- WHEN user clicks track right of thumb
- THEN ScrollX increases by one viewport width

<!-- Requirement removed: Note Text Labels — replaced by Vertical Piano Keyboard strip (see Keyboard Strip Rendering) -->

### Requirement: Vertical Gradient Strips

Each note block SHALL render 3-4 vertical strips inside the rounded rect. Top strip is lightest; each subsequent strip darkens by multiplying RGB by `(1 - t * 0.3)` where t = strip_index / total_strips. Strip count MUST be `max(1, floor(PITCH_ROW_H / 4))`.

#### Scenario: 3 strips at 12px row height

- GIVEN PITCH_ROW_H = 12, NOTE_WHITE = {0.55, 0.72, 0.88, 0.92}
- WHEN DrawNoteBlock renders
- THEN 3 strips appear: strip 0 at ~{0.55, 0.72, 0.88}, strip 1 at ~{0.49, 0.65, 0.79}, strip 2 at ~{0.44, 0.58, 0.70}
- AND velocity alpha applies uniformly to all strips

### Requirement: Velocity → Opacity Mapping

Note block opacity MUST be `alpha = 0.35 + (velocity / 127) * 0.65`. Muted notes MUST render at full alpha 1.0 using NOTE_MUTED color, ignoring the velocity→alpha mapping.

#### Scenario: velocity 64 → ~0.68 alpha

- GIVEN note velocity 64
- WHEN rendered
- THEN all gradient strips render at alpha = 0.35 + (64/127)*0.65 ≈ 0.68

#### Scenario: Muted note at full opacity

- GIVEN muted note, velocity 20
- WHEN rendered
- THEN NOTE_MUTED color at alpha 1.0, no gradient

### Requirement: Keyboard Strip Rendering

The `.PITCH_LABEL_W` strip SHALL render real piano key shapes instead of flat colored rects. Uses `piano.lua`'s `PIANO_LAYOUT` for pitch-class-to-white/black mapping, rotated 90° (rows = pitches).

| Key type | Width | Height | Fill | Border | Label |
|----------|-------|--------|------|--------|-------|
| White | 100% LABEL_W | 100% PITCH_ROW_H | `theme.colors.piano_white` | 1px `{0.2,0.2,0.2,0.6}` | OctaveLabel centered |
| Black | 70% LABEL_W | 60% PITCH_ROW_H | `theme.colors.piano_black` | 1px `{0.3,0.3,0.3,0.8}` | None |

Black keys MUST be right-aligned to the grid edge and vertically centered in the row. White key labels use `theme.colors.text_dark`; black key labels omitted.

#### Scenario: White key C4

- GIVEN pitch 60 (C4), white key
- WHEN keyboard strip renders
- THEN a filled rect PITCH_ROW_H × PITCH_LABEL_W with piano_white fill appears
- AND "C4" centered

#### Scenario: Black key C#4

- GIVEN pitch 61 (C#4), black key
- WHEN keyboard strip renders
- THEN a filled rect 60% PITCH_ROW_H × 70% PITCH_LABEL_W appears, right-aligned, vertically centered
- AND no text label

#### Scenario: Keyboard scrolls with grid

- GIVEN scroll offset = 12 (scrolled down 12 rows)
- WHEN rendering
- THEN visible keyboard keys match the visible pitch rows from ComputeVisibleRanges

### Requirement: Grid Hierarchy Colors (Theme)

theme.colors SHALL add:

| Key | Value | Purpose |
|-----|-------|---------|
| `grid_measure` | `{0.5, 0.5, 0.5, 0.60}` | Measure lines (bold) |
| `grid_beat` | `{0.4, 0.4, 0.4, 0.35}` | Beat lines (medium) |
| `grid_sub_1_8` | `{0.25, 0.25, 0.25, 0.15}` | 1/8 subdivision faint |
| `grid_sub_1_16` | `{0.20, 0.20, 0.20, 0.08}` | 1/16 subdivision very faint |
| `lasso_fill` | `{0.25, 0.50, 1.0, 0.15}` | Lasso rect fill (semi-transparent blue) |
| `lasso_border` | `{0.25, 0.50, 1.0, 0.50}` | Lasso rect border |

### Requirement: Modular Split into 4 Sub-Modules

The `src/ui/piano-roll.lua` monolith (1022 LOC) SHALL be split into 4 sub-modules within `src/ui/piano-roll/`:
- `grid.lua` — grid lines, beat hierarchy rendering, scrollbar, keyboard strip
- `note.lua` — note drawing, gradient strips, velocity→opacity mapping, muted rendering
- `interaction.lua` — hit-testing, mouse dispatch, drag/select state machine, wheel scroll
- `view.lua` — rendering coordinator: visible ranges → grid → notes → scrollbar → lasso

A barrel module `src/ui/piano-roll.lua` SHALL re-export all public functions. Existing consumers (views.lua, velocity-editor, etc.) MUST NOT require refactoring.

#### Scenario: Barrel preserves consumer API

- GIVEN `local piano_roll = require("ui.piano-roll")`
- WHEN any consumer calls `piano_roll.Draw()` or other exported functions
- THEN behavior is identical to pre-split AND no require paths changed

#### Scenario: Hit-testing centralized

- GIVEN a mouse click at (x, y) over the piano roll region
- WHEN interaction.lua's hit-test dispatch runs
- THEN it returns correct target (note block, resize edge, scrollbar, keyboard strip, or empty)
- AND all mouse routing passes through this single function

#### Scenario: Grid rendering behavior unchanged

- GIVEN the modular split
- WHEN grid.lua draws beat lines
- THEN the 4-tier alpha hierarchy from the existing spec is identical
- AND `grid_measure`, `grid_beat`, `grid_sub_1_8`, `grid_sub_1_16` colors match

### Requirement: Shift+click additive selection

`HandleMouseClick` MUST receive `shift_held` from the caller.

#### Scenario: Shift toggles selection

- GIVEN a note is NOT selected
- WHEN shift+clicked
- THEN the note SHALL toggle into the selection

### Requirement: Cache key includes PITCH_ROW_H

`ComputeVisibleRanges` cache MUST include `PITCH_ROW_H` in its key.

#### Scenario: Grid correct after vertical zoom

- GIVEN the grid is visible
- WHEN the user zooms vertically (Alt+wheel)
- THEN visible rows SHALL recompute and note positions SHALL be correct

### Requirement: Scrollbar thumb within track

Scrollbar thumbs MUST compute position as `ratio * (track - thumb_size)`.

#### Scenario: Thumb stays inside at max scroll

- GIVEN scroll is at maximum
- THEN the thumb SHALL NOT extend past the track

### Requirement: Lasso pitch_high clamped

`GetNotesInRect` MUST clamp `pitch_high = math.min(MAX_PITCH, …)`.

#### Scenario: Lasso above grid

- GIVEN the mouse starts above the grid
- WHEN a lasso drag is performed
- THEN out-of-rect notes SHALL NOT be selected

### Requirement: No snap when snap is off

When `snap_res <= 0`, `HandlePencilClick` MUST NOT quantize the beat.

#### Scenario: Free placement

- GIVEN snap is disabled
- WHEN a note is placed with the pencil
- THEN the note SHALL be at the exact clicked beat

### Requirement: Scale Snap Highlight Toggle

`preferences_store` SHALL add a new boolean field `scale_snap_highlight` (default `false`). When enabled, vertical grid lines at the piano roll zone (not the keyboard strip) SHALL render with a tinted color for the 7 pitches in the current scale. The highlight SHALL apply to the full height of the grid area.

#### Scenario: Toggle on shows highlights

- GIVEN `scale_snap_highlight = false`
- WHEN the user toggles it to `true` via preferences
- THEN vertical grid lines at scale pitches SHALL use highlight color
- AND non-scale pitch lines SHALL remain at normal alpha

#### Scenario: Highlight changes when scale changes

- GIVEN `scale_snap_highlight = true` with C Major
- WHEN user changes scale to A Minor (intervals {0,2,3,5,7,8,10})
- THEN the highlighted grid lines SHALL shift to pitches A, B, C, D, E, F, G (`pitch % 12 ∈ {9,11,0,2,4,5,7}`)

### Requirement: Horizontal Scroll Clip Boundary

The piano roll grid area SHALL clip note rendering so that note blocks do not visually extend into the keyboard strip (LABEL_W zone on the left). The clip boundary MUST align with the grid edge (`x`), not the keyboard strip interior. Ghost notes MUST use the same clip boundary (`x`). On the right side, the grid SHALL render with correct Z-order: scrollbar thumb SHALL draw above the grid background but note content SHALL stop at the scrollbar track edge.

(Previously: clip boundary used `x - PITCH_LABEL_W`, causing notes to visually bunch at keyboard strip)

#### Scenario: Notes clip at grid edge boundary (not keyboard strip)

- GIVEN a note starting near the left edge of the grid
- WHEN the user scrolls left past beat 0
- THEN note blocks MUST NOT render past `x` (the grid clipping boundary)
- AND ghost notes MUST also clip at `x` (not `x - PITCH_LABEL_W`)
- AND no visual bunching appears at the left edge of the note grid

#### Scenario: Right side scrollbar does not overlap notes

- GIVEN the piano roll grid with scrollbar visible
- WHEN notes extend to the rightmost visible beat
- THEN note blocks SHALL NOT overlap the vertical scrollbar track
- AND the scrollbar thumb SHALL render with correct Z-order above the grid background

### Requirement: Note Rendering Correctness

Rounded rect rendering SHALL use exact dimensions without +1 overshoot. The velocity dimming overlay over note blocks SHALL use a rounded rect path to preserve corner shape. REAPER GFX note: `gfx.rect` draws axis-aligned rectangles with sharp corners — it MUST NOT replace `DrawRoundedRect` where rounded corners are required.

#### Scenario: No +1 overshoot in rounded rect fills

- GIVEN `DrawRoundedRect` or `DrawRoundedRectEx` called with `(x, y, w, h)`
- WHEN the opaque fill path renders
- THEN width and height MUST NOT add +1 to the passed dimensions
- AND no bleeding artifacts appear at the bottom-right corner of rounded rects

#### Scenario: Velocity dim overlay preserves rounded corners

- GIVEN a note block drawn with `DrawNoteWithGradient`
- WHEN the velocity dimming overlay applies
- THEN the overlay SHALL use `DrawRoundedRect` with the same corner radius
- AND `gfx.rect` (square corners) SHALL NOT be used for the overlay
- AND no "bottom valley" artifact appears where flat overlay clips rounded corners

## Acceptance Criteria

- [ ] Grid renders with beat lines at correct positions for all zoom levels
- [ ] Grid renders 4 distinct opacity levels (measure/beat/1/8/1/16) matching DAW convention
- [ ] Note blocks from island store render with vertical gradient + velocity→alpha (0.35–1.0)
- [ ] Scrolling via mouse wheel updates visible region and note blocks
- [ ] Virtual scroll only renders visible rows + 2-octave buffer (verify via gfx draw count)
- [ ] Zoom preserves beat-based scroll offset
- [ ] No crash with empty notes array, 200+ notes, or zero-duration notes
- [ ] Scrollbar thumb is draggable and updates scroll position proportionally
- [ ] Vertical keyboard shows real black/white key shapes from PIANO_LAYOUT
- [ ] Shift+click toggles note selection (aditive, does not clear)
- [ ] ComputeVisibleRanges cache invalidates on vertical zoom (PITCH_ROW_H in key)
- [ ] Scrollbar thumb stays inside track at max scroll (vertical + horizontal)
- [ ] Lasso GetNotesInRect clamps pitch_high ≤ MAX_PITCH
- [ ] Pencil places note at exact beat when snap is off (snap_res ≤ 0)
- [ ] Scale snap highlight toggle exists in preferences_store
- [ ] Vertical grid lines at scale pitches use a distinct brighter color when toggle is ON
- [ ] Highlight updates immediately when scale changes
- [ ] Notes clip at `x` (grid edge) not `x - PITCH_LABEL_W` at keyboard strip boundary
- [ ] Ghost notes also clip at `x` (same boundary)
- [ ] No bunching of notes at the left edge during scroll
- [ ] No +1 bleeding artifacts in rounded rect corners
- [ ] No square-corner cut into the velocity dim overlay of note blocks
- [ ] No right-side rendering artifact at scrollbar boundary
