# keyboard-interaction-tests Specification

## Purpose

Verify keyboard module interaction with REAPER APIs (JS_VKeys_Intercept, JS_VKeys_GetState) and correct note trigger behavior.

## Requirements

### K1: InterceptMappedKeys(true)

InterceptMappedKeys(true) MUST call JS_VKeys_Intercept for each VKEY_MAP entry with action=1.

#### Scenario: All keys intercepted
- GIVEN VKEY_MAP with N entries
- WHEN `keyboard.InterceptMappedKeys(true)`
- THEN reaper.JS_VKeys_Intercept called N times, each with action=1

### K2: InterceptMappedKeys(false)

InterceptMappedKeys(false) MUST call JS_VKeys_Intercept with action=-1.

#### Scenario: All keys released
- GIVEN previously intercepted
- WHEN `keyboard.InterceptMappedKeys(false)`
- THEN each VKEY_MAP entry called with action=-1

### K3: Cleanup idempotent

Cleanup MUST only call InterceptMappedKeys if is_intercepting is true. Second call is no-op.

#### Scenario: Double cleanup safe
- GIVEN intercept active
- WHEN `Cleanup()` called twice
- THEN InterceptMappedKeys(false) called only once

### K4: HandleKeyboard

HandleKeyboard MUST read key state, trigger note-on for pressed keys, note-off for released.

#### Scenario: Key-down triggers note-on
- GIVEN VKEY byte string with first key pressed AND velocity humanization off
- WHEN `keyboard.HandleKeyboard(vkey_string)`
- THEN TriggerChord called with velocity=100

#### Scenario: Key-up sends note-off
- GIVEN VKEY byte string with first key released (was held)
- WHEN HandleKeyboard
- THEN SendMidi note-off for that note

#### Scenario: Unmapped keys ignored
- GIVEN VKEY byte string with unmapped key pressed
- WHEN HandleKeyboard
- THEN no reaper calls made
