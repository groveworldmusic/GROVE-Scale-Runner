# Piano Roll Specification

## Purpose

Horizontal note grid with pitch×time layout. Renders note blocks from island store data, supports scroll and zoom, and displays beat grid lines. No MIDI recording — Phase 1 renders static notes from the progression only.

## Requirements

### Requirement: Grid Rendering

The piano roll SHALL render a 2D grid where the Y-axis represents pitch (rows, low-to-top) and the X-axis represents time (columns, left-to-right). Grid cells MUST be drawn using `gfx.rect` for lines and `DrawRoundedRect` (from `src/ui/helpers.lua`) for note blocks. Beat grid lines MUST alternate between strong (measure start) and weak (inner beats) visual weight.

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

### Requirement: Virtual Scrolling

The piano roll MUST render only visible rows (pitch range currently on screen) plus a 2-octave buffer above and below. Scroll position is controlled by the island store's `ScrollX` value. The visible window MUST be computed each frame from `gfx.h`, `gfx.w`, the current `Zoom`, and the beat-to-pixel ratio.

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

Mouse wheel delta (`gfx.mouse_wheel`, captured and zeroed per the project pattern) SHALL control horizontal scroll when the cursor is over the piano roll region. Positive delta scrolls right; negative scrolls left. The scroll speed MUST be proportional to current zoom level.

#### Scenario: Wheel scrolls piano roll

- GIVEN the piano roll rendering at zoom 1.0
- WHEN `gfx.mouse_wheel` = 3 and cursor is within piano roll bounds
- THEN `island_store.ScrollX` increases by 3 beats (or equivalent at current zoom)
- AND `gfx.mouse_wheel` is zeroed to 0 after consumption

#### Scenario: Wheel outside piano roll ignored

- GIVEN the piano roll rendering
- WHEN `gfx.mouse_wheel` = 3 but cursor is over the velocity editor region
- THEN the piano roll's scroll position MUST NOT change

## Acceptance Criteria

- [ ] Grid renders with beat lines at correct positions for all zoom levels
- [ ] Note blocks from island store render at correct pitch/time positions
- [ ] Scrolling via mouse wheel updates visible region and note blocks
- [ ] Virtual scroll only renders visible rows + 2-octave buffer (verify via gfx draw count)
- [ ] Zoom preserves beat-based scroll offset
- [ ] No crash with empty notes array, 200+ notes, or zero-duration notes
