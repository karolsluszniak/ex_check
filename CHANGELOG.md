# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- **Added** `--format github` reporter emitting GitHub Actions `::group::` log blocks for each tool (raw failure output wrapped in a `::stop-commands::` injection guard) plus a Markdown run summary appended to `$GITHUB_STEP_SUMMARY`
- **Added** `--format junit` reporter emitting a JUnit XML report (`testsuite`/`testcase`) for CI systems such as GitLab CI and Jenkins, pairing with `--output report.xml`
- **Added** structured diagnostics parsed from `compiler`, `credo` and `ex_unit` failure output (`ExCheck.Diagnostics`), exposed as a `diagnostics` list (`file`, `line`, `column`, `message`, `severity`) in the `json` and `agent` reporters so agents can jump straight to findings
- **Added** inline `::error`/`::warning file=…,line=…` annotations to the `github` reporter (from the structured diagnostics) so findings surface directly in the GitHub PR diff
- **Changed** our own CI to dogfood the new format via `mix check --format github`

## [1.0.0-rc.1] - 2026-06-29

- **Documented** the minimum Elixir bump (1.12 → 1.17) as a **breaking** change in the changelog, with an upgrade path for projects on Elixir 1.12–1.16
- **Added** README "Usage rules for coding agents" section recommending [`usage_rules`](https://hex.pm/packages/usage_rules) so projects sync the shipped rules into `AGENTS.md` and agents drive `mix check --format agent`

## [1.0.0-rc.0] - 2026-06-26

First release of `ex_check_ng`, a community-maintained fork of
[`ex_check`](https://github.com/karolsluszniak/ex_check), dormant since 2024. The module namespace
(`ExCheck`) and the `mix check` task are unchanged, so it stays a drop-in replacement.

- **BREAKING — Changed** minimum supported Elixir version from Elixir 1.12 to Elixir 1.17 (bundled tooling — `usage_rules` and `mix_audit`'s `yaml_elixir` — requires it). Projects on Elixir 1.12–1.16 must stay on `ex_check` `0.16.0` or upgrade Elixir.
- **Added** pluggable `ExCheck.Reporter` behaviour, replacing inline result rendering in `ExCheck.Check`
- **Added** `--format json` reporter emitting the full run as a JSON document for machine consumption
- **Added** `--format agent` reporter with a compact one-line-per-tool summary and failing output only, optimised for LLM/agent consumption
- **Added** `--output <path>` option to write reporter output to a file instead of stdout
- **Added** `usage-rules.md` and a `verify-with-check` agent skill (shipped in the Hex package) so LLM coding agents get accurate guidance on driving `mix check`
- **Improved** toolchain and CI matrix to Elixir 1.20 / OTP 28

## [0.16.0] - 2024-03-01

- **Changed** minimum supported Elixir version from Elixir 1.7 to Elixir 1.12
- **Added** `gettext` tool
- **Fixed** incorrect relative path handling in Elixir 1.16

## [0.15.0] - 2022-12-05

- **Added** `mix_audit` tool
- **Fixed** retry mode info to properly split tool names
- **Improved** docs with numerous fixes & refinements

## [0.14.0] - 2021-01-26

- **Added** `--fix` command line option to resolve issues automatically for tools that provide the fix command via the `:fix` tool option
- **Added** automatic toggling of retry mode when previous run resulted in failures (pass `--no-retry` to override)
- **Added** `:doctor` tool
- **Improved** retry mode with capability to run only failed tests or checks for tools that provide the retry command via the `:retry` tool option
- **Improved** default tool ordering to persist when custom config is applied to default tools
- **Renamed** `--failed` command line option to `--retry`

## [0.13.0] - 2020-12-23

- **Added** `:unused_deps` tool
- **Added** `--config` command line option to point to arbitrary configuration file path
- **Added** `--failed` command line option to only run checks that have failed in the last run
- **Added** `--manifest` command line option to specify path to file that holds last run results

## [0.12.0] - 2020-07-06

- **Added** `:deps` tool option with support for depending on specific exit status
- **Removed** `:run_after` tool option (please use `:deps` tool option instead)
- **Fixed** merging tool umbrella opts with those set in ancestor config
- **Updated** default dialyxir config to no longer include `--halt-exit-status` deprecated in
  [1.0.0-rc.7](https://github.com/jeremyjh/dialyxir/blob/master/CHANGELOG.md#100-rc7---2019-09-21)
- **Improved** test suite detection to only check for `test` directory instead of `test_helper.exs`

## [0.11.0] - 2019-09-07

- **Added** support for parallel & sequential recursive tool execution in umbrella projects
- **Added** support for tool to target only specific umbrella child app(s)
- **Added** `:npm_test` tool for seamless integration of testing assets in Phoenix projects
- **Added** tool skipping if `cd` tool option points to non-existing directory
- **Added** `{:tool_name, command, opts}` shorthand tool tuples
- **Added** umbrella recursive flag to tool `sobelow` (fixing it for umbrella projects)
- **Changed** tool autodetection to support detection order and disabling instead of skipping
- **Fixed** `{:tool_name, command}` tool tuples to support lists of strings for commands
- **Removed** `:require_files` and `:require_deps` tool configuration options
- **Removed** `--skip` option from default configuration for tool `sobelow`

## [0.10.0] - 2019-08-18

- **Added** `:run_after` tool coonfiguration option (introducing powerful tool dependency system)

## [0.9.0] - 2019-08-01

- **Added** automatic ANSI enabling for arbitrary Elixir commands (and not just Mix tasks)
- **Added** support for shorthand tool configuration (`{:tool_name, true/false/"command"}`)
- **Fixed** starting of app in Mix tasks that should have it started (e.g. `mix test`)

## [0.8.0] - 2019-07-31

- **Changed** emit exit code via `System.at_exit/1` instead of `System.halt/1`
- **Fixed** accidental starting of app in Mix tasks
- **Removed** `--no-exit-status` command line option
- **Removed** `:exit_status` configuration option

## [0.7.0] - 2019-07-29

- **Changed** automatic ANSI enabling for Mix tasks to use `mix run` instead of `mix check.run`
- **Removed** `mix check.run` task

## [0.6.0] - 2019-07-26

- **Added** `:order` tool coonfiguration option
- **Changed** check summary to sort the items by status and name
- **Fixed** re-enabling tools after disable in ancestor config
- **Fixed** merging env vars with those set in ancestor config
- **Fixed** detection of Mix env for `mix check.run` wrapper

## [0.5.0] - 2019-07-24

- **Added** automatic ANSI enabling for Mix tasks by auto-prepending `mix check.run`
- **Added** `:cd` tool coonfiguration option
- **Added** `:env` tool coonfiguration option
- **Added** support for invoking shell scripts as tools

## [0.4.0] - 2019-07-23

No user-facing changes.

## [0.3.0] - 2019-07-22

- **Added** ANSI enabling for Mix tasks by prepending `mix check.run` in tool command

## [0.2.0] - 2019-07-19

- **Added** `sobelow` tool
- **Added** loading of ancestor config (home + umbrella root)
- **Changed** Elixir version requirement from `1.9` to `1.7`

## [0.1.0] - 2019-07-15

Initial release.

[Unreleased]: https://github.com/karolsluszniak/ex_check/compare/v0.14.0...HEAD
[0.14.0]: https://github.com/karolsluszniak/ex_check/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/karolsluszniak/ex_check/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/karolsluszniak/ex_check/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/karolsluszniak/ex_check/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/karolsluszniak/ex_check/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/karolsluszniak/ex_check/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/karolsluszniak/ex_check/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/karolsluszniak/ex_check/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/karolsluszniak/ex_check/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/karolsluszniak/ex_check/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/karolsluszniak/ex_check/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/karolsluszniak/ex_check/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/karolsluszniak/ex_check/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/karolsluszniak/ex_check/releases/tag/v0.1.0
