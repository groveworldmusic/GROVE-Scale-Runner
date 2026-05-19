# Delta for Preset Browser — Barrel Pattern Adoption

## Context

`src/ui/preset-browser.lua` (881 LOC) currently re-exports from 4 submodules (`io.lua`, `folder.lua`,
`preset-list.lua`, `main.lua`) via a barrel block at the top of the file, but the 17 inline
function definitions that previously lived in the monolith remain interleaved below the re-export
block. Both the barrel re-export AND the inline definitions are loaded at runtime, creating a
duplicate-export situation that increases LOC and creates maintenance risk without providing any
additional capability.

This change eliminates the 17 inline definitions, making the barrel block the single source of
truth. `DrawPresetBrowser` continues to be the public entry point but becomes a thin passthrough
to `main_mod.DrawPresetBrowser()`. The I/O submodule (`io.lua`) adopts the superior `safe_loader`
and `path_utils` paths — `safe.LoadSandboxed` instead of bare `dofile()`, and
`path_utils.PathJoin` instead of path string concatenation — as already implemented in those
submodules. Zero caller-facing behavior changes.

## ADDED Requirements

### Requirement: Public API Unchanged

The public interface of `require("ui.preset-browser")` SHALL NOT change. All externally callable
functions MUST remain accessible under the same name at the same require path.

#### Scenario: All public functions still reachable after refactor

- GIVEN `local browser = require("ui.preset-browser")`
- WHEN any external caller invokes `browser.SavePreset()`, `browser.LoadPreset()`,
  `browser.ScanDirectory()`, `browser.DrawPresetBrowser()`, `browser.RenamePreset()`,
  `browser.DeletePreset()`, `browser.LoadFavorites()`, `browser.SaveFavorites()`,
  `browser.IsFavorite()`, `browser.GetPresetFilePath()`, `browser.HasLFS()`,
  `browser.Init()`, or `browser.RefreshPresets()`
- THEN the call succeeds with identical behaviour to the pre-refactor path

### Requirement: Monolith Functions Eradicated

The 17 inline function definitions that remain in `preset-browser.lua` below the barrel block
SHALL be removed. The barrel re-export block becomes the only source of truth.

#### Scenario: File LOC reduced to barrel + comments only

- GIVEN `preset-browser.lua` being measured after refactor
- WHEN the file is `wc -l`'d
- THEN the count SHALL be ≤ 80 LOC (barrel re-exports + license + file doc header)

#### Scenario: Fresh require does not load inline functions

- GIVEN `package.loaded["ui.preset-browser"]` is nil
- WHEN `require("ui.preset-browser")` is called
- THEN only the barrel block is executed
- AND no inline function body is evaluated for any removed function

### Requirement: DrawPresetBrowser Thin Passthrough

The orchestrator function that formerly coordinated folder-tree + preset-list + action-buttles
inside the monolith SHALL move entirely to `preset-browser/main.lua`. The barrel entry SHALL be
a single passthrough: `browser.DrawPresetBrowser = main_mod.DrawPresetBrowser`.

#### Scenario: Browser orchestrator delegates to main_mod

- GIVEN the preset browser needs to render
- WHEN `browser.DrawPresetBrowser(...)` is called with arguments `x, y, w, h`
- THEN `main_mod.DrawPresetBrowser(x, y, w, h)` executes with the same arguments
- AND the return value (nil) is propagated unchanged

### Requirement: Superior I/O Paths Enforced

`preset-browser/io.lua` already uses `safe.LoadSandboxed` instead of bare `dofile()`, and
`path_utils.PathJoin` instead of string concatenation. These paths are the only ones used; the
legacy inline functions (now removed) are unavailable.

#### Scenario: Sandboxed loader used for all safe require calls

- GIVEN `browser.LoadPreset("my-song.grove")` is called
- WHEN the I/O submodule reads the file
- THEN `safe.LoadSandboxed(filepath)` is called, not bare `dofile()`
- AND any load error is caught by `LoadSandboxed`'s xpcall and surfaced via `island_store.SetBrowserError()`

#### Scenario: Path join utility used for all path construction

- GIVEN a preset file path is being constructed for a preset named "my-song" in the current directory
- WHEN the full file path is assembled
- THEN `path_utils.PathJoin(current_dir, "my-song.grove")` is the construction method
- AND `..` direct concatenation does not appear in any remaining call site

### Requirement: Barrel Pattern Consistency

`preset-browser.lua` SHALL follow the same barrel conventions as `piano-roll.lua` (83 LOC) and
`compact.lua` (25 LOC): license header, `require` of each submodule, re-export block, return table.

#### Scenario: Barrel structure matches reference barrels

- GIVEN a side-by-side comparison of `preset-browser.lua`, `piano-roll.lua`, and `compact.lua`
- THEN all three reserve a single re-export block after the submodule requires
- AND all three lack inline function definitions below the re-export block

## MODIFIED Requirements

No requirements in `openspec/specs/preset-browser/spec.md` are modified. The Directory Navigation,
Preset List Display, Save Preset, Load Preset, Larger PRESETS Title Font, Rename Preset, Panel
Dividing Line, and Action Button Styling requirements SHALL not change — submodule implementation
is an internal concern invisible to those requirements' scenarios.

Previously: `preset-browser.lua` kept inline monolith functions alongside the barrel re-exports,
causing dual-source maintenance without any caller-facing justification.

## Non-Goals

- The folder tree navigation logic in `folder.lua` is not touched.
- The preset list enumeration in `preset-list.lua` is not changed.
- External call sites using `require("ui.preset-browser").FunctionName` SHALL NOT change.
- No new user-facing features are introduced.

## Dependencies

- Architecture debt sweep view-offset-persist — independent, no prerequisite

## Relevant Files

- `src/ui/preset-browser.lua` — barrel file (663 → ~80 LOC target post-refactor)
- `src/ui/preset-browser/io.lua` — I/O submodule (safe.LoadSandboxed + path_utils already in use)
- `src/ui/preset-browser/folder.lua` — folder tree submodule
- `src/ui/preset-browser/preset-list.lua` — preset list submodule
- `src/ui/preset-browser/main.lua` — orchestrator submodule
