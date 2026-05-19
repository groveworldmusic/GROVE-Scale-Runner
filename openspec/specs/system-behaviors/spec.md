# Delta: Production-Readiness Polish — System Behaviors

Covers behavioral changes in deliverables 2–4. Deliverable 1 (DrawMIDIIsland split) is a pure refactor with no spec-level behavioral change.

## Scope

| Deliverable | Type | Behavior Change |
|-------------|------|-----------------|
| 1. Split DrawMIDIIsland | Pure refactor | None — identical behavior, extracted helpers |
| 2. Persist preferences | Behavioral | Preferences survive REAPER restart |
| 3. Unify ExtState namespace | Behavioral | Single namespace `GROVE_Scale_Runner`; migrate from legacy `GROVE_FL_MIDI` |
| 4. pcall GFX + error display | Behavioral | GFX calls wrapped; errors shown not crashed |

---

## ADDED Requirements

### Requirement: Persist User Preferences via ExtState

The system MUST persist the following user preferences across REAPER restarts using `reaper.SetExtState`/`reaper.GetExtState`: `root_index`, `scale_index`, `octave`, `chord_mode_index`, `inversion_index`, `volume`, `color_mode`.

#### Scenario: Preferences survive REAPER restart

- GIVEN the user has set `root_index` to 3, `octave` to 5, and `volume` to 80 in a previous session
- WHEN the script initializes in a new REAPER session
- THEN `config.state.root_index` MUST be 3, `config.state.octave` MUST be 5, and `sequencer_store.volume` MUST be 80

#### Scenario: First launch with no saved preferences

- GIVEN no ExtState keys exist for `GROVE_Scale_Runner` (fresh install)
- WHEN the script initializes
- THEN all preference values MUST fall back to their hardcoded defaults (root_index=1, octave=4, volume=100, etc.)

#### Scenario: Persist on value change, not on read

- GIVEN a preference value changes (e.g., user selects a new scale)
- WHEN the setter is called
- THEN the new value MUST be written to ExtState immediately
- AND reading the value MUST NOT trigger a write

### Requirement: Unify ExtState Namespace Under `GROVE_Scale_Runner`

All ExtState operations MUST use the `GROVE_Scale_Runner` namespace (the canonical one). On initialization, the system MUST transparently migrate any existing keys from the legacy `GROVE_FL_MIDI` namespace.

#### Scenario: Clean migration from legacy namespace

- GIVEN ExtState `GROVE_FL_MIDI` contains `root_index=3` and no `GROVE_Scale_Runner` keys exist
- WHEN the script initializes
- THEN `GROVE_Scale_Runner.root_index` MUST be 3
- AND `GROVE_FL_MIDI.root_index` MUST still exist (legacy keys are NOT deleted)

#### Scenario: Canonical namespace takes precedence

- GIVEN ExtState `GROVE_Scale_Runner.root_index=2` AND legacy `GROVE_FL_MIDI.root_index=3` both exist
- WHEN the script initializes
- THEN `config.state.root_index` MUST be 2 (canonical namespace wins)
- AND no migration from legacy occurs

### Requirement: Safe GFX Initialization and Shutdown

`gfx.init()` and `gfx.quit()` MUST be wrapped in `pcall`. On failure, the error MUST be displayed via `reaper.ShowConsoleMsg()` without crashing REAPER.

#### Scenario: gfx.init fails during REAPER shutdown

- GIVEN REAPER is shutting down and GFX context is unavailable
- WHEN `SafeGfxInit()` is called
- THEN `pcall` catches the error
- AND the error message is printed via `reaper.ShowConsoleMsg()`
- AND the script continues without crashing

#### Scenario: Error message is visible to the user

- GIVEN a GFX call has failed
- WHEN `pcall` returns an error
- THEN the system MUST call a `ShowError()` function that displays the error in `reaper.ShowConsoleMsg()`
- AND the function name and error string MUST be included in the message

---

## UNCHANGED Behaviors (Deliverable 1 — Pure Refactor)

The following behaviors are explicitly UNCHANGED by this change:

- `DrawMIDIIsland()` renders the identical visual output before and after the split
- All keyboard shortcut overlays, tool mode rows, snap controls, and preset panels appear at the same coordinates with the same styling
- Mouse click handlers in DrawMIDIIsland map to the same logic — just relocated into named helpers
- All 382 existing tests pass without modification
