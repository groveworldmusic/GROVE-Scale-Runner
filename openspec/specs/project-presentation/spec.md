# Project Presentation Specification

## Purpose

Define the README content, branding conventions, and metadata consistency rules so the project presents a unified professional identity on GitHub and in ReaPack listings.

## Requirements

### Requirement: README.md is Present and Complete

A `README.md` MUST exist at the project root covering description, features, installation, usage, and links.

#### Scenario: All required sections are present

- GIVEN a visitor reads `README.md`
- WHEN they scan section headings
- THEN the file MUST contain: project description, feature list, installation steps, usage guide, and a links section
- AND the links section SHALL include the Ko-fi donation URL

#### Scenario: Installation steps are actionable

- GIVEN a user follows the README installation instructions
- WHEN they complete the steps
- THEN the script SHALL appear in the REAPER Actions list under "Scale Runner"

#### Scenario: README is valid Markdown

- GIVEN the `README.md` file
- WHEN rendered on GitHub
- THEN all relative links MUST resolve to existing files
- AND no broken image references SHALL exist

### Requirement: Branding Consistency

All project metadata MUST use the resolved branding identities without contradictions.

| Context | Identity |
|---------|----------|
| `@author` header | `Andrik Sanz Cordoví` |
| `APP_NAME` | `GROVE Scale Runner` |
| SPDX copyright holder | `Andrik Sanz Cordoví` |
| `@description` | `Scale Runner — QWERTY to MIDI Controller for REAPER` |

#### Scenario: Author is consistent across all headers

- GIVEN the `main.lua` header
- WHEN comparing `@author`, the SPDX copyright line, and any other attribution
- THEN all MUST resolve to `Andrik Sanz Cordoví`
- AND there MUST be no contradictory author strings (e.g. `GROVE WORLD MUSIC` SHALL NOT appear)

#### Scenario: Product name is consistent

- GIVEN any UI title, config constant, or documentation reference
- WHEN referring to the application
- THEN it MUST use `GROVE Scale Runner`
- AND SHALL NOT use inconsistent variants (`Grove FL MIDI`, `scale-runner`, etc.)

#### Scenario: SPDX-License-Identifier is present

- GIVEN the first 20 lines of `main.lua`
- WHEN scanned for `SPDX-License-Identifier`
- THEN it MUST be present and set to `MIT`

### Requirement: Donation Link

The Ko-fi donation link MUST appear in both the ReaPack header and the README.

#### Scenario: Donation link is in both locations

- GIVEN the `@donation` tag in `main.lua` and the README links section
- WHEN extracting all donation URLs
- THEN both MUST contain `https://ko-fi.com/groveworldmusic`
- AND the README SHOULD label it clearly (e.g. "Support on Ko-fi" or similar)
