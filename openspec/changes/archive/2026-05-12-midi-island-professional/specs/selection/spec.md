# Delta for Selection — Shift-Additive + Select All

## Overview

Current selection is single-click only (click deselects previous, click same deselects self). Lasso provides multi-selection via pixel rect. This delta adds shift-click additive selection and Ctrl+A select-all to bring selection behavior to professional DAW standards.

## ADDED Requirements

### Requirement: Shift-Click Additive Selection

When Shift is held, clicking a note SHALL add it to the current selection without deselecting others. Clicking an already-selected note while holding Shift SHALL deselect it (toggle). When Shift is NOT held, existing behavior applies (click = select only, clearing previous).

#### Scenario: Shift-click adds to selection

- GIVEN note A is the only selection (`selected_indices = {[1]=true}`)
- WHEN user Shift-clicks note B
- THEN both notes remain selected (`selected_indices = {[1]=true, [3]=true}`)
- AND lasso is NOT activated (Shift+click over note = additive select, not lasso)

#### Scenario: Shift-click toggles selected note

- GIVEN notes A and B both selected
- WHEN user Shift-clicks note B (already selected)
- THEN note B is REMOVED from selection (`selected_indices = {[1]=true}`)

#### Scenario: Click without Shift clears selection

- GIVEN notes A and B selected
- WHEN user clicks note C WITHOUT Shift
- THEN only note C is selected (previous selection cleared)

#### Scenario: Shift on empty space deselects all

- GIVEN 2 notes selected
- WHEN user Shift-clicks on empty grid space
- THEN all notes are deselected (shift+empty = clear)

### Requirement: Ctrl+A Select All

Ctrl+A SHALL select all notes in the current notes array. If all notes are already selected, Ctrl+A SHALL deselect all (toggle). Empty notes array SHALL be a no-op.

#### Scenario: Ctrl+A selects all

- GIVEN 5 notes in the island, none selected
- WHEN user presses Ctrl+A
- THEN all 5 notes appear in `selected_indices`

#### Scenario: Ctrl+A toggles when all selected

- GIVEN 5 notes, all selected
- WHEN user presses Ctrl+A
- THEN all notes are deselected (`selected_indices = {}`)

#### Scenario: Ctrl+A on empty array

- GIVEN zero notes in the island
- WHEN user presses Ctrl+A
- THEN nothing happens (no crash, no error)

## Acceptance Criteria

- [ ] Shift-click adds note to selection without clearing
- [ ] Shift-click on already-selected note toggles it off
- [ ] Click without Shift clears previous selection (existing behavior preserved)
- [ ] Ctrl+A selects all notes; toggles off if all already selected
- [ ] Empty notes array: Ctrl+A is no-op
- [ ] Works in all tool modes (pointer, pencil, eraser)
