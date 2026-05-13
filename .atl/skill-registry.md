# Skill Registry

This registry tracks the available AI agent skills for this project.

## Project-Level Skills
None.

## User-Level Skills
| Skill | Description | Trigger |
|-------|-------------|---------|
| `branch-pr` | PR creation workflow for Agent Teams Lite following the issue-first enforcement system. | When creating a pull request, opening a PR, or preparing changes for review. |
| `go-testing` | Go testing patterns for Gentleman.Dots, including Bubbletea TUI testing. | When writing Go tests, using teatest, or adding test coverage. |
| `issue-creation` | Issue creation workflow for Agent Teams Lite following the issue-first enforcement system. | When creating a GitHub issue, reporting a bug, or requesting a feature. |
| `judgment-day` | Parallel adversarial review protocol that launches two independent blind judge sub-agents simultaneously to review the same target, synthesizes their findings, applies fixes, and re-judges until both pass or escalates after 2 iterations. | When user says "judgment day", "judgment-day", "review adversarial", "dual review", "doble review", "juzgar", "que lo juzguen". |
| `skill-creator` | Creates new AI agent skills following the Agent Skills spec. | When user asks to create a new skill, add agent instructions, or document patterns for AI. |

## Local SDD Skills
| Skill | Description | Trigger |
|-------|-------------|---------|
| `sdd-init` | Initialize SDD context, testing capabilities, registry, and persistence. | sdd init, iniciar sdd, openspec init |
| `sdd-explore` | Explore SDD ideas before committing to a change. | Orchestrator launches exploration or requirement clarification |
| `sdd-propose` | Create an SDD change proposal with intent, scope, and approach. | Orchestrator launches proposal work for a change |
| `sdd-spec` | Write SDD delta specs with requirements and scenarios. | Orchestrator launches spec work for a change |
| `sdd-design` | Create the SDD technical design and architecture approach. | Orchestrator launches design for a change |
| `sdd-tasks` | Break an SDD change into implementation tasks. | Orchestrator launches task planning for a change |
| `sdd-apply` | Implement SDD tasks from specs and design. | Orchestrator launches apply for one or more change tasks |
| `sdd-verify` | Execute tests and prove implementation matches specs, design, and tasks. | SDD verification phase, verify change |
| `sdd-archive` | Archive a completed SDD change by syncing delta specs. | Orchestrator launches archive after implementation and verification |
| `sdd-onboard` | Walk users through the SDD workflow on the real codebase. | Orchestrator launches onboarding for the full SDD cycle |

## Project Standards (auto-resolved)
- **Lua 5.x**: Use `local m = {}` + `return m` module pattern. No ES modules.
- **Reaper GFX API**: Use `gfx.init`, `gfx.rect`, `gfx.circle`, etc. Code organized into ui/* modules (components, views, compact, layout, helpers, format, colors, theme).
- **GFX Dual-Context Pattern**: `main.lua` and `compact.lua` each have their own GFX context. Each must independently read `gfx.mouse_wheel` AND zero it (`gfx.mouse_wheel = 0`) after reading. Missing zeroing causes scroll to repeat every frame.
- **Delta Lifecycle**: GFX-level zeroing clears `gfx.mouse_wheel` per frame. Widget-level zeroing clears `config.state.mouse_wheel_delta` per widget. Both layers are required for scroll features.
- **Scroll Direction Convention**: `mouse_wheel_delta > 0` maps to -1 (decrement index) for navigation widgets (pagination, dropdowns). Maps to +value for non-index controls (volume). Established by pagination at `views.lua:389`.
- **MIDI via Reaper**: `reaper.StuffMIDIMessage` for note on/off; no external MIDI libraries.
- **Package path**: `package.path` extended at runtime via `debug.getinfo(1, 'S')` for relative requires.
- **Module naming**: PascalCase filenames under `src/` (e.g., `core/midi.lua`, `ui/components.lua`).
- **Function naming**: snake_case function names (e.g., `GetMidiNote`, `SendMidi`, `ToggleDock`).
- **State management**: Global `config.state` object holds all mutable state (view mode, root/scale/octave/chord indices, sequencer state, flash timers, active notes, key states, scroll/mouse state). No external state libraries.
- **State initialization**: `config.state` table defined in `src/config.lua` with default values for all fields. State is nil-safe (field is always defined, no lazy init).
- **Active notes pattern**: ref-counted table `config.state.active_notes[note] = count` for managing concurrent note-on/off, not a simple toggle.
- **Circular dependency warning**: `core/sequencer.lua` does NOT require `core/midi.lua` to avoid circular dep. `midi.lua` explicitly documents this constraint.
- **Testing**: Custom mock-based tests in `tests/test_midi.lua` (standalone, no REAPER dep). No `lua` CLI available on dev machine — tests verified via static analysis only. SDD verification uses manual + static review. No CI/CD, no automation.
- **Validation approach**: Hand-rolled assert-pass/fail counters in test scripts. `os.exit(1)` on failure.
- **Config entry**: `-- @description Scale Runner — QWERTY to MIDI Controller for REAPER` header in `main.lua`.
- **Module requires**: Uses `require("config")`, `require("core.midi")`, `require("ui.components")` — package.path extended at runtime from script location.