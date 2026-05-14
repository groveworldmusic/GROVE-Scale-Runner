# Delta for JS_VKeys_GetState Hoisting

Performance fix: reduce `reaper.JS_VKeys_GetState(0)` from 28 calls/frame to 1 call/frame.

## ADDED Requirements

### Requirement: Hoist API call outside key loop

The system MUST call `reaper.JS_VKeys_GetState(0)` EXACTLY ONCE per frame, BEFORE iterating over tracked virtual keys, and cache the result in a local variable. Each key inside the loop MUST read from the cached local instead of calling the API.

The existing guard (`if not vk_state then return end`) MUST remain at loop level — if the API returns nil, the entire loop is skipped.

#### Scenario: Normal operation — 28 keys processed with 1 API call

- GIVEN `keyboard.HandleKeyboard()` is called with `is_intercepting == true` and the API is available
- WHEN execution enters the key iteration loop
- THEN `JS_VKeys_GetState(0)` MUST have been called exactly once BEFORE the loop begins
- AND each of the 28 keys reads from the same cached local variable

#### Scenario: API returns nil — early exit

- GIVEN `reaper.JS_VKeys_GetState(0)` returns `nil` (API temporarily unavailable)
- WHEN the hoisted call returns nil
- THEN the function MUST return immediately without iterating any keys
- AND no note-on/off processing occurs for this frame

## MODIFIED Requirements

None — no existing spec for this domain.

## REMOVED Requirements

None.
