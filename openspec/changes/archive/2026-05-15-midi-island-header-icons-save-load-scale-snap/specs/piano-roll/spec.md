# Delta for Piano Roll

## MODIFIED Requirements

### Requirement: Grid Rendering

The piano roll SHALL render a 2D grid where the Y-axis represents pitch (rows, low-to-top) and the X-axis represents time (columns, left-to-right). Grid cells MUST be drawn using `gfx.rect` for lines and `DrawRoundedRect` (from `src/ui/helpers.lua`) for note blocks. Beat grid lines MUST use 4 opacity tiers (measure, beat, 1/8, 1/16) with alpha values specified in the Grid Hierarchy requirement. Vertical grid lines at beat positions SHALL be highlighted when they correspond to a pitch in the current scale — see Scale Snap Highlight requirement.
(Previously: no scale snap highlight on vertical grid lines)

#### Scenario: Scale-snap vertical highlight on beat lines

- GIVEN a scale root=0 (C) and scale index=1 (Major, intervals {0,2,4,5,7,9,11})
- AND scale snap highlight is enabled in preferences
- WHEN the piano roll renders beat lines
- THEN vertical grid lines at pitches C, D, E, F, G, A, B `pitch % 12 ∈ {0,2,4,5,7,9,11}` SHALL render with a brighter grid color (e.g., `{0.5, 0.7, 0.5, 0.4}`)
- AND non-scale pitch rows SHALL render at the normal `grid_beat` alpha (0.35)

### ADDED Requirements

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

The piano roll grid area SHALL clip note rendering so that note blocks do not visually extend into the keyboard strip (LABEL_W zone on the left). On the right side, the grid SHALL render with correct Z-order: scrollbar thumb SHALL draw above the grid background but note content SHALL stop at the scrollbar track edge.

#### Scenario: Notes clip at keyboard strip boundary

- GIVEN a note starting near the left edge of the grid
- WHEN the user scrolls left past beat 0
- THEN note blocks MUST NOT render past `x - LABEL_W = 0` (the keyboard strip boundary)
- AND no visual artifacts appear at the left edge of the grid where keyboard strip meets beat grid

#### Scenario: Right side scrollbar does not overlap notes

- GIVEN the piano roll grid with scrollbar visible
- WHEN notes extend to the rightmost visible beat
- THEN note blocks SHALL NOT overlap the vertical scrollbar track
- AND the scrollbar thumb SHALL render with correct Z-order above the grid background

## Acceptance Criteria

- [ ] Scale snap highlight toggle exists in preferences_store
- [ ] Vertical grid lines at scale pitches use a distinct brighter color when toggle is ON
- [ ] Highlight updates immediately when scale changes
- [ ] Notes clip cleanly at keyboard strip boundary (no overlap into LABEL_W)
- [ ] No right-side rendering artifact at scrollbar boundary
