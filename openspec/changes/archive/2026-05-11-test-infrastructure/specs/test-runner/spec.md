# test-runner Specification

## Purpose

Unified entry point (`run.lua`) and assertion helpers (`helpers.lua`) that enable executing all project tests from a single invocation with aggregated pass/fail reporting.

## Requirements

| ID | Requirement | Scenarios |
|----|------------|-----------|
| P1 | `run.lua` MUST derive `src/` path from own location via `debug.getinfo(1,'S')`, normalize backslashes to forward slashes, prepend to `package.path` | GIVEN run.lua at tests/ WHEN deriving path THEN require("config") resolves from src/. GIVEN Windows path with backslashes WHEN normalized THEN package.path uses forward slashes |
| D1 | `run.lua` MUST discover all `test_*.lua` files and run each via `pcall` | GIVEN 3 test files WHEN all pass THEN os.exit(0). GIVEN one file fails WHEN aggregated THEN os.exit(1) |
| D2 | `run.lua` MUST own `os.exit(0/1)`; test files MUST NOT call it | GIVEN a test file with os.exit WHEN wrapped via pcall THEN exit is suppressed, control returns to runner |
| D3 | `pcall` MUST catch runtime errors without halting other files | GIVEN a test file throws WHEN wrapped THEN error counted as failure, remaining files execute |
| H1 | `helpers.lua` MUST provide `check(c, msg)`, `assert_eq(a,b,msg)`, `summary()` with global counters | GIVEN check(true) THEN passed++. GIVEN check(false) THEN failed++. GIVEN assert_eq(1,1) THEN passed++. GIVEN failures at summary() THEN os.exit(1) |

## Edge Cases

- Empty tests directory: `run.lua` exits 0 (no failures)
- `check` with non-boolean condition: treated as truthy/falsy per Lua rules
- `summary()` called with zero failures: `os.exit(0)`, not called at all
