# Delta for Island Store

## ADDED Requirements

### Requirement: Velocity Panel Collapse State

The store MUST expose `GetVelocityPanelExpanded() -> boolean` and `SetVelocityPanelExpanded(boolean)`. Default after Init MUST be `true`. When `false`, the velocity panel collapses upward and freed space allocates to the piano roll.

#### Scenario: Default expanded

- GIVEN fresh Init
- WHEN `GetVelocityPanelExpanded()` called
- THEN returns `true`

#### Scenario: Collapse via setter

- GIVEN expanded panel
- WHEN `SetVelocityPanelExpanded(false)`
- THEN getter returns `false`
