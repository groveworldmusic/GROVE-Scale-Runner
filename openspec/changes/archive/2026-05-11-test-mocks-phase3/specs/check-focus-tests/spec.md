# CheckFocus Tests — Specification

## Purpose
Focus detection with 0.2s throttle, enabling/disabling keyboard intercept based on GFX window focus.

## Requirements

### Requirement: Throttle
Second call within 0.2s MUST be no-op; call after 0.2s MUST execute.

#### Scenario: Blocks rapid calls
- GIVEN `time_precise` returns 0.0 then 0.1
- WHEN CheckFocus runs at 0.1
- THEN no `InterceptMappedKeys` or `AllNotesOff` call occurs

#### Scenario: Releases after boundary
- GIVEN `time_precise` returns 0.0 then 0.25
- WHEN CheckFocus runs at 0.25
- THEN focus check executes normally

### Requirement: Focus Transitions
Gain focus → `InterceptMappedKeys(true)`. Lose focus → `InterceptMappedKeys(false)` + `AllNotesOff()`.

#### Scenario: Gain focus
- GIVEN not intercepting and `gfx.hwnd` matches focused window
- WHEN CheckFocus runs
- THEN `InterceptMappedKeys(true)` is called

#### Scenario: Lose focus
- GIVEN intercepting and `gfx.hwnd` does NOT match focused window
- WHEN CheckFocus runs
- THEN `InterceptMappedKeys(false)` and `AllNotesOff()` are called

### Requirement: Stable No-ops
Focus state unchanged MUST produce no side effects.

#### Scenario: Already intercepting and focused — no-op
- GIVEN intercepting and `gfx.hwnd` matches focus
- WHEN CheckFocus runs
- THEN no calls to `InterceptMappedKeys` or `AllNotesOff`

#### Scenario: Already not intercepting and unfocused — no-op
- GIVEN NOT intercepting and `gfx.hwnd` does NOT match focus
- WHEN CheckFocus runs
- THEN no calls to `InterceptMappedKeys` or `AllNotesOff`
