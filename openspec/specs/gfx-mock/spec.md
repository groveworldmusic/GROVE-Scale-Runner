# gfx-mock Specification

## Purpose

Minimal mock for `gfx.*` globals — no-op methods + mutable state fields. Allows modules that read gfx state (mouse, dimensions) to function in tests.

## Requirements

### G1: All 17 gfx methods stubbed as no-ops

The mock MUST export all 17 gfx methods as functions that accept any args and return nothing.

#### Scenario: No-op calls succeed
- GIVEN `gfx = require("tests.mock.gfx")`
- WHEN calling `gfx.circle(100, 100, 50)` or any other method
- THEN no error is raised

### G2: Mutable state fields with defaults

The mock MUST expose mutable fields: `x=0, y=0, w=720, h=500, mouse_x=0, mouse_y=0, mouse_cap=0, mouse_wheel=0, hwnd=nil`.

#### Scenario: Default values on load
- GIVEN a freshly loaded gfx mock
- THEN `gfx.w == 720`, `gfx.h == 500`, `gfx.hwnd == nil`, all others 0

#### Scenario: Mutable fields
- GIVEN the gfx mock
- WHEN `gfx.mouse_x = 300; gfx.mouse_y = 200`
- THEN reading back returns 300 and 200

### G3: Installable via _G

The mock MUST be assignable as `_G.gfx = require("tests.mock.gfx")`.

#### Scenario: Global assignment
- GIVEN the mock module
- WHEN assigned to `_G.gfx`
- THEN no error and all methods/fields accessible
