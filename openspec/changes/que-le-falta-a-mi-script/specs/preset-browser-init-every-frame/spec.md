# Delta for preset_browser.Init() Every Frame

Performance fix: prevent I/O-heavy `preset_browser.Init()` from executing every rendering frame when `preset_root` is empty.

## ADDED Requirements

### Requirement: Guard Init() with one-shot flag

The system MUST guard `preset_browser.Init()` with a module-level boolean flag (`_preset_init_attempted`) that prevents re-execution after the first attempt, regardless of whether the attempt succeeded or failed.

The guard MUST be implemented in `midi-island.lua` (the caller), not in `preset-browser.lua` itself — the browser module's `Init()` should remain a standalone function.

The guard MUST be reset when the user explicitly triggers a rescan or when `preset_root` changes.

#### Scenario: Preset root is valid — Init runs once

- GIVEN `island_store.GetPresetRoot()` returns a valid path
- WHEN `DrawPresetPanel()` is called for the first time
- THEN `preset_browser.Init()` MUST execute once
- AND on subsequent frames, `Init()` MUST NOT execute (saves file I/O)

#### Scenario: Preset root is empty — no repeated I/O

- GIVEN `reaper.GetResourcePath()` failed on first call, leaving `preset_root == ""`
- WHEN `DrawPresetPanel()` runs every frame (60 fps)
- THEN `preset_browser.Init()` MUST be called exactly ONCE (the first frame)
- AND on all subsequent frames, the guard flag prevents re-call
- AND ~60 file-stat calls per second are eliminated

## MODIFIED Requirements

None — no existing spec for this domain.

## REMOVED Requirements

None.
