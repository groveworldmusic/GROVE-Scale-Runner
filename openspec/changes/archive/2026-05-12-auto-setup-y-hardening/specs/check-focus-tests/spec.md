# Delta for check-focus-tests

## MODIFIED Requirements

### Focus Transitions

Gain focus → `InterceptMappedKeys(true)`. Lose focus → `InterceptMappedKeys(false)` + `AllNotesOff()` + `sequencer.Stop()`.
(Previously: lose focus without `sequencer.Stop()`)

#### Scenario: Gain focus
- GIVEN not intercepting and `gfx.hwnd` matches focused window
- WHEN CheckFocus runs
- THEN `InterceptMappedKeys(true)` called

#### Scenario: Lose focus
- GIVEN intercepting and `gfx.hwnd` does NOT match focused window
- WHEN CheckFocus runs
- THEN `InterceptMappedKeys(false)`, `AllNotesOff()`, AND `sequencer.Stop()` called

#### Scenario: Already intercepting and focused — no-op
- GIVEN intercepting and `gfx.hwnd` matches focus
- WHEN CheckFocus runs
- THEN no calls to any function

#### Scenario: Already not intercepting and unfocused — no-op
- GIVEN NOT intercepting and `gfx.hwnd` does NOT match focus
- WHEN CheckFocus runs
- THEN no calls to any function
