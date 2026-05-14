# Delta for Preset Browser

## ADDED Requirements

### Requirement: Panel Dividing Line

A vertical dividing line SHALL separate the folder tree (left) from the preset list (right), rendered at the browser's horizontal midpoint. The line MUST use the theme's border color and span the full content height.

#### Scenario: Line at midpoint

- GIVEN browser at 400px width
- WHEN rendered
- THEN a vertical line appears at x=200px

### Requirement: Action Button Styling

SAVE, RENAME, and LOAD buttons SHALL use rounded borders via `DrawButton` helper, matching the style of other UI rounded buttons (e.g., compact panel).

#### Scenario: Rounded buttons render

- GIVEN the preset browser rendering action buttons
- WHEN each button is drawn
- THEN it has rounded corners and responds visually on hover
