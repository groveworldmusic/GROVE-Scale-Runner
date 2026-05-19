# Spec: JS_VKeys_GetState Hoisting

## Description
`reaper.JS_VKeys_GetState(0)` was called 28 times per frame inside a `pairs()` loop over `midi_store.GetKeyStates()`. Hoist to one call before the loop.

## Requirements
1. `reaper.JS_VKeys_GetState(0)` is called exactly once per `HandleKeyboard()` invocation, before the key iteration loop
2. The cached `vk_state` value is used within the loop for all 28 key checks
3. Nil guard on `vk_state` remains at loop level (no behavioral change)
4. API guards (`HAS_VKEYS_GET_STATE`, `HAS_VKEYS_INTERCEPT`) remain at module level

## Scenarios
- **Happy path**: 28 keys checked against a single VKeys state snapshot
- **Edge case**: If `reaper.JS_VKeys_GetState` returns nil, the function returns early before the loop (guard preserved)

## Files Affected
- `src/core/keyboard.lua`: ~4 lines changed (hoist call, add local variable)

## Estimated LOC
~4 lines changed
