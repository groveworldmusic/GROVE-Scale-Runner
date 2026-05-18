# preset-browser Specification (Delta)

## ADDED Requirements

### Requirement: Module Structure (Barrel)

The `src/ui/preset-browser.lua` module SHALL act as a thin barrel re-exporting the public APIs of `src/ui/preset-browser/io.lua`, `src/ui/preset-browser/folder.lua`, and `src/ui/preset-browser/preset-list.lua`. All existing logic and API surface MUST be moved to these sub-modules.

#### Scenario: API preservation via barrel

- GIVEN the new barrel structure
- WHEN a consumer calls a public API on `require("ui.preset-browser")` (e.g., `ScanDirectory`)
- THEN it MUST call the corresponding function in the appropriate sub-module (e.g., `io.ScanDirectory`)
- AND return the same result as before
