# Delta for test-runner

## ADDED Requirements

### Requirement: P0 — Globals installed before module loading

The runner MUST assign `_G.reaper` and `_G.gfx` to their mock tables BEFORE extending package.path. Any require of src/ modules must have globals in place.

#### Scenario: Mock globals present at require time
- GIVEN run.lua loads `_G.reaper = require("tests.mock.reaper")` and `_G.gfx = require("tests.mock.gfx")`
- WHEN extend package.path THEN require("core.midi") THEN require a test file
- THEN no "attempt to index a nil value (global 'reaper')" error occurs

#### Scenario: Counters reset between test files
- GIVEN test file A made calls to reaper mock
- WHEN run.lua transitions to test file B
- THEN `reset_all_calls()` was invoked, all mock call counts are zero

## MODIFIED Requirements

### Requirement: P1 — Path derivation

The runner MUST derive `src/` path from own location, normalize backslashes, prepend to `package.path`. This MUST happen AFTER global installation.
(Previously: runner derived path and extended package.path without global pre-installation)

#### Scenario: Path correctly derived
- GIVEN run.lua at `D:\project\tests\run.lua`
- WHEN ready to extend package.path (after globals installed)
- THEN `package.path` starts with `D:/project/src/?.lua;`

## REMOVED Requirements

None.
