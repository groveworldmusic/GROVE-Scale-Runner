# Delta for piano-roll

## Overview

Two behavior changes: clip boundary for notes and ghost notes aligns to grid edge `x` instead of `x - PITCH_LABEL_W` (Bugs 5, C); rounded rect rendering removes +1 overshoot and velocity dim overlay uses rounded rect path (Bug 4).

## MODIFIED Requirements

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

## ADDED Requirements

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

## Acceptance Criteria (Delta)

- [ ] Notes clip at `x` (grid edge) not `x - PITCH_LABEL_W` at keyboard strip boundary
- [ ] Ghost notes also clip at `x` (same boundary)
- [ ] No bunching of notes at the left edge during scroll
- [ ] No +1 bleeding artifacts in rounded rect corners
- [ ] No square-corner cut into the velocity dim overlay of note blocks
