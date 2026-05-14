# Distribution Packaging Specification

## Purpose

Define the ReaPack distribution metadata, CI pipeline, and versioning constants so the project can be published via the ReaPack community package manager with automated index generation.

## Requirements

### Requirement: ReaPack Header Metadata

The `src/main.lua` header MUST include `@author`, `@donation`, and `@links` tags after the `@changelog` line.

| Tag | Value |
|-----|-------|
| `@author` | `Andrik Sanz Cordoví` |
| `@donation` | `https://ko-fi.com/groveworldmusic` |
| `@links` | `https://github.com/{owner}/GROVE-FL-MIDI` |

#### Scenario: Header contains required tags

- GIVEN a user inspects `src/main.lua`
- WHEN they grep for `@donation` and `@links`
- THEN both tags MUST appear in the header block
- AND no duplicate or conflicting `@author` line SHALL exist

#### Scenario: Donation URL matches config

- GIVEN the `@donation` tag is present
- WHEN extracted
- THEN the URL MUST equal `config.DONATION_URL`
- AND resolve to `https://ko-fi.com/groveworldmusic`

### Requirement: Version and Donation Constants

`src/config.lua` MUST export `APP_VERSION` and `DONATION_URL` as top-level fields.

#### Scenario: Version constant is accessible

- GIVEN a `require("config")` call
- WHEN reading `config.APP_VERSION`
- THEN it MUST equal `"1.0.0"`

#### Scenario: Donation URL constant is accessible

- GIVEN the config module is loaded
- WHEN reading `config.DONATION_URL`
- THEN it MUST equal `"https://ko-fi.com/groveworldmusic"`

### Requirement: ReaPack Index Configuration

A `.reapack-index.yaml` file MUST exist at the project root.

#### Scenario: Config file is present and valid

- GIVEN the project root directory
- WHEN listing files
- THEN `.reapack-index.yaml` MUST be present
- AND it MUST be valid YAML parseable by `reapack-index`

### Requirement: CI Workflow

The repository MUST include `.github/workflows/reapack-index.yml` that regenerates `index.xml` on push to main and on a weekly schedule.

#### Scenario: Workflow triggers on push to main

- GIVEN a push to the `main` branch
- WHEN the workflow runs
- THEN it SHALL check out the repository
- AND run `npx reapack-index` to regenerate `index.xml`
- AND commit the updated `index.xml` if changed

#### Scenario: Workflow has scheduled trigger

- GIVEN the workflow file
- WHEN inspected for `schedule` events
- THEN a weekly cron trigger SHOULD be present (e.g. `0 6 * * 1`)

### Requirement: Valid index.xml Output

The CI pipeline MUST produce a ReaPack-compatible `index.xml` in the repository root.

#### Scenario: index.xml is well-formed

- GIVEN the CI workflow completed successfully
- WHEN the resulting `index.xml` is parsed
- THEN it MUST be well-formed XML
- AND contain a `<reapack>` root element
- AND include a `<category name="MIDI">` entry for `Scale Runner`

#### Scenario: index.xml does not exist for local installs

- GIVEN a user downloads the script manually (not via ReaPack)
- WHEN they inspect the repository root
- THEN `index.xml` MAY be absent — it is CI-generated, not committed manually
