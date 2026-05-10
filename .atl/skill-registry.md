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
- **Reaper GFX API**: Use `gfx.init`, `gfx.rect`, `gfx.circle`, etc. Avoid direct API calls outside modules.
- **MIDI via Reaper**: `reaper.StuffMIDIMessage` for note on/off; no external MIDI libraries.
- **Package path**: `package.path` extended at runtime via `debug.getinfo(1, 'S')` for relative requires.
- **State management**: Global `config.state` object; no external state libraries.
- **Testing**: Custom mock-based tests in `tests/test_midi.lua` (standalone, no REAPER dep). No `lua` CLI available — tests verified via static analysis only. SDD verification uses manual + static review.