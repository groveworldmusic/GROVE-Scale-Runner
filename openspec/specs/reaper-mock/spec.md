# reaper-mock Specification

## Purpose

Mock table for `reaper.*` globals that enables runtime function tests without an active REAPER instance. Each stub records calls for assertion.

## Requirements

### R1: All 38 reaper functions stubbed

The mock MUST export a table with entries for ALL 38 reaper functions, each created via `make_mock_fn(name)`.

#### Scenario: Stub returns safe default
- GIVEN `reaper = require("tests.mock.reaper")`
- WHEN calling any stubbed reaper function
- THEN a compatible default is returned (nil, 0, "", false)

#### Scenario: Stub records calls
- GIVEN `reaper.StuffMIDIMessage = make_mock_fn("StuffMIDIMessage")`
- WHEN `reaper.StuffMIDIMessage(1, 0x90, 60, 100)`
- THEN `reaper.StuffMIDIMessage.mock.call_count == 1`
- AND `reaper.StuffMIDIMessage.mock.calls[1] == {1, 0x90, 60, 100}`

### R2: reset_all_calls()

The mock MUST expose `reset_all_calls()` that zeroes call_count and empties calls[] on every tracked mock fn.

#### Scenario: Counters cleared between sections
- GIVEN two mocked calls made then `reset_all_calls()` invoked
- WHEN checking any mock fn
- THEN call_count == 0 AND calls == {}

### R3: Installable via _G

The mock MUST be assignable as `_G.reaper = require("tests.mock.reaper")` without errors.

#### Scenario: Global assignment
- GIVEN the mock module
- WHEN assigned to `_G.reaper`
- THEN no error is raised and all stubs are callable
