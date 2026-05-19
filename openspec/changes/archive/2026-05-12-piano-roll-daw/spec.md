# Delta Spec: DAW-Style Piano Roll (piano-roll-daw)

Covers 4 phases modifying the `piano-roll` capability. Single delta across 5 domains.

## Domain: Piano Roll Grid

### ADDED Requirements

#### Grid Hierarchy (4 tiers)

The piano roll SHALL render beat grid with 4 distinct alpha tiers via helper colors from theme:

| Tier | Condition | Alpha | Line style |
|------|-----------|-------|------------|
| Measure | `beat % 4 == 0` | 0.60 | Bold (double `gfx.line`) |
| Beat | `beat == floor(beat)` | 0.35 | Normal 1px |
| 1/8 | `s % 2 == 0` when subdivision ≥ 4 | 0.15 | Normal 1px |
| 1/16 | All other subdivision positions | 0.08 | Normal 1px |

When subdivision mode < 4 (e.g., 1/8), all sub-beats render at the 1/8 tier (alpha 0.15).

##### Scenario: All 4 tiers visible at 1/16
- GIVEN subdivision = 4 (1/16), scroll showing beats 0-4
- WHEN grid renders
- THEN beat 0 and 4 render at alpha 0.60, beats 1-3 at 0.35, half-beats at 0.15, quarter-beats at 0.08

### MODIFIED Requirements

#### Grid Rendering

The piano roll SHALL render a 2D grid where the Y-axis represents pitch (rows, low-to-top) and the X-axis represents time (columns, left-to-right). Grid cells MUST be drawn using `gfx.rect` for lines and `DrawRoundedRect` for note blocks. Beat grid lines MUST use 4 opacity tiers as specified above.

(Previously: 3 levels — strong, weak, subdivision — all with fixed alpha.)

*Scenarios: unchanged from existing spec (Empty grid renders correctly, Note block at correct position).*

#### Virtual Scrolling

The piano roll MUST render only visible rows (pitch range currently on screen) plus a 2-octave buffer above and below. The keyboard strip SHALL scroll in sync with the grid using the same visible range. Scroll position is controlled by the island store's `ScrollX` value.

(Previously: no mention of keyboard strip).

*Scenarios: unchanged.*

### REMOVED Requirements

#### Note Text Labels

(Reason: Replaced by vertical keyboard strip — pitch labels now render as part of piano key shapes on the keyboard strip, not as separate text on the left.)

## Domain: Note Rendering

### ADDED Requirements

#### Vertical Gradient Strips

Each note block SHALL render 3-4 vertical strips inside the rounded rect. Top strip is lightest; each subsequent strip darkens by multiplying RGB by `(1 - t * 0.3)` where t = strip_index / total_strips. Strip count MUST be `max(1, floor(PITCH_ROW_H / 4))`.

##### Scenario: 3 strips at 12px row height
- GIVEN PITCH_ROW_H = 12, NOTE_WHITE = {0.55, 0.72, 0.88, 0.92}
- WHEN DrawNoteBlock renders
- THEN 3 strips appear: strip 0 at ~{0.55, 0.72, 0.88}, strip 1 at ~{0.49, 0.65, 0.79}, strip 2 at ~{0.44, 0.58, 0.70}
- AND velocity alpha applies uniformly to all strips

#### Velocity → Opacity Mapping

Note block opacity MUST be `alpha = 0.35 + (velocity / 127) * 0.65`. Muted notes MUST render at full alpha 1.0 using NOTE_MUTED color, ignoring the velocity→alpha mapping.

##### Scenario: velocity 64 → ~0.68 alpha
- GIVEN note velocity 64
- WHEN rendered
- THEN all gradient strips render at alpha = 0.35 + (64/127)*0.65 ≈ 0.68

##### Scenario: Muted note at full opacity
- GIVEN muted note, velocity 20
- WHEN rendered
- THEN NOTE_MUTED color at alpha 1.0, no gradient

### MODIFIED Requirements

*No existing requirement directly specifies gradient rendering — this is an architectural addition to `DrawNoteBlock`.*

## Domain: Vertical Piano Keyboard

### ADDED Requirements

#### Keyboard Strip Rendering

The `.PITCH_LABEL_W` strip SHALL render real piano key shapes instead of flat colored rects. Uses `piano.lua`'s `PIANO_LAYOUT` for pitch-class-to-white/black mapping, rotated 90° (rows = pitches).

| Key type | Width | Height | Fill | Border | Label |
|----------|-------|--------|------|--------|-------|
| White | 100% LABEL_W | 100% PITCH_ROW_H | `theme.colors.piano_white` | 1px `{0.2,0.2,0.2,0.6}` | OctaveLabel centered |
| Black | 70% LABEL_W | 60% PITCH_ROW_H | `theme.colors.piano_black` | 1px `{0.3,0.3,0.3,0.8}` | None |

Black keys MUST be right-aligned to the grid edge and vertically centered in the row. White key labels use `theme.colors.text_dark`; black key labels omitted.

##### Scenario: White key C4
- GIVEN pitch 60 (C4), white key
- WHEN keyboard strip renders
- THEN a filled rect PITCH_ROW_H × PITCH_LABEL_W with piano_white fill appears
- AND "C4" centered

##### Scenario: Black key C#4
- GIVEN pitch 61 (C#4), black key
- WHEN keyboard strip renders
- THEN a filled rect 60% PITCH_ROW_H × 70% PITCH_LABEL_W appears, right-aligned, vertically centered
- AND no text label

##### Scenario: Keyboard scrolls with grid
- GIVEN scroll offset = 12 (scrolled down 12 rows)
- WHEN rendering
- THEN visible keyboard keys match the visible pitch rows from ComputeVisibleRanges

## Domain: Island Store

### ADDED Requirements

#### Tool Mode State

The store SHALL expose `GetToolMode() -> string` and `SetToolMode(string)`. Valid: `"pointer"`, `"pencil"`, `"eraser"`. Default: `"pointer"`.

#### Lasso State

The store SHALL expose: `GetLassoActive() -> boolean`, `SetLassoActive(bool)`, `GetLassoStart() -> {x, y}`, `SetLassoStart(t)`, `GetLassoEnd() -> {x, y}`, `SetLassoEnd(t)`. All default to nil/false after Init.

#### Multi-Selection (breaking change)

`selected_note_index (number | nil)` SHALL be replaced by `selected_indices (table {[idx]=true})`. Backward compat SHALL be provided via `GetPrimarySelectedNoteIndex() -> number | nil` returning the last selected index from the set. Existing consumers (velocity editor, info bar) MUST use this compat getter.

##### Scenario: Multi-select
- GIVEN selected_indices = {[2]=true, [5]=true}
- WHEN `GetPrimarySelectedNoteIndex()` called
- THEN returns 5 (last entry)

##### Scenario: Empty selection
- GIVEN selected_indices = {}
- WHEN `GetPrimarySelectedNoteIndex()` called
- THEN returns nil

#### Note CRUD

The store SHALL expose `AddNote({pitch, start_beat, duration, velocity, muted})` appending to notes[] and `RemoveNoteAtIndex(idx)` removing the entry at that index and shifting subsequent entries. Both SHALL update note_count. `AddNote` SHALL set `origin = "manual"` automatically.

#### Bulk Operations

Right-click on any selected note SHALL toggle mute on ALL selected_indices. Delete key SHALL remove all selected_indices from notes[]. See `Domain: Velocity Editor` for velocity bulk edit.

### MODIFIED Requirements

#### Store API Surface

The store MUST expose getter/setter pairs for: `ScrollX(number)`, `Zoom(number 0.25-4.0)`, `Notes(table[])`, `PrimarySelectedNoteIndex(number|nil)`, `SelectedPreset(string|nil)`, `ToolMode(string)`, `LassoActive(boolean)`, `LassoStart/End({x,y})`. Notes MUST be returned by REFERENCE.

(Previously: ActiveNoteIndex replaced by PrimarySelectedNoteIndex compat; ToolMode/Lasso fields added.)

#### Edit Buffer

This requirement is REMOVED — velocity editing now operates on selected_indices set. Compatibility handled via `GetPrimarySelectedNoteIndex()`.

## Domain: Velocity Editor

### MODIFIED Requirements

#### Click-to-Edit Velocity

The user SHALL click and drag vertically on a velocity bar to change velocity. When `selected_indices` contains multiple entries, drag SHALL apply the SAME relative change to ALL selected notes. The `GetPrimarySelectedNoteIndex()` SHALL identify the bar the user initially clicked (for display/feedback).

##### Scenario: Drag changes all selected velocities
- GIVEN selected_indices = {[2]=true, [5]=true}, both velocity 64
- WHEN user clicks bar at index 2, drags upward
- THEN notes[2].velocity and notes[5].velocity both increase by the same delta

#### Mute Toggle

Right-click on any selected note's velocity bar or on the piano roll SHALL toggle mute on ALL selected_indices.

## Domain: Theme

### ADDED Requirements

#### Grid Hierarchy Colors

theme.colors SHALL add:

| Key | Value | Purpose |
|-----|-------|---------|
| `grid_measure` | `{0.5, 0.5, 0.5, 0.60}` | Measure lines (bold) |
| `grid_beat` | `{0.4, 0.4, 0.4, 0.35}` | Beat lines (medium) |
| `grid_sub_1_8` | `{0.25, 0.25, 0.25, 0.15}` | 1/8 subdivision faint |
| `grid_sub_1_16` | `{0.20, 0.20, 0.20, 0.08}` | 1/16 subdivision very faint |
| `lasso_fill` | `{0.25, 0.50, 1.0, 0.15}` | Lasso rect fill (semi-transparent blue) |
| `lasso_border` | `{0.25, 0.50, 1.0, 0.50}` | Lasso rect border |

## Domain: Timeline Ruler

### MODIFIED Requirements

#### Beat Marker Rendering

The timeline ruler SHALL render tick marks matching the piano roll's 4-tier grid hierarchy. Measure ticks SHALL be tallest (16px) at alpha 0.60, beat ticks medium (8px) at alpha 0.35, subdivision ticks (4px) at alpha 0.15/0.08. Color values MUST match the new grid hierarchy colors.

(Previously: 2 tiers — measure (alpha 0.7), beat (alpha 0.4) — using separate constants from piano roll.)

## Acceptance Criteria

- [ ] Grid renders 4 distinct opacity levels matching DAW convention
- [ ] Note blocks show vertical gradient with velocity→alpha (min 0.35)
- [ ] Vertical keyboard shows real black/white key shapes from PIANO_LAYOUT
- [ ] 3 tool modes cycle via header buttons
- [ ] Pencil creates notes; eraser removes on click
- [ ] Lasso draws visible rect during drag; notes inside become selected
- [ ] Bulk operations (mute, delete, velocity) apply to all selected_indices
- [ ] `GetPrimarySelectedNoteIndex()` returns correct value for backward compat
- [ ] Timeline ruler mirrors grid hierarchy colors
