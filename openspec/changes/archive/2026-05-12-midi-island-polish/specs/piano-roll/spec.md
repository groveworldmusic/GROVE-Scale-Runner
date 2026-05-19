# Delta for Piano Roll

## ADDED Requirements

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

### Requirement: Note Text Labels

Each note block SHALL display its MIDI note name (e.g., "C4") centered inside the block using `gfx.setfont(1)` at 1-2pt larger than default. If block width is too narrow (< ~20px), label SHALL be omitted.

#### Scenario: Label renders at zoom 2.0

- GIVEN note block pitch 60 (C4) at zoom 2.0
- WHEN rendered
- THEN block contains centered "C4"

#### Scenario: Label hidden at low zoom

- GIVEN note block at zoom 0.25x, width < 20px
- WHEN rendered
- THEN no text inside block
