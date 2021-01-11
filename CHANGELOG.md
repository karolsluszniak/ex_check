# Changelog

## v0.14.0-dev

- **Added** `--fix` command line option that runs tools in fix mode in order to resolve issues automatically along with `:fix` tool option
- **Added** capability to run tool command to retry after failure e.g. in order to run only failed tests or checks along with `:retry` tool option
- **Added** `:doctor` tool

## v0.13.0

- **Added** `:unused_deps` tool
- **Added** `--config` opt to point to arbitrary configuration file path
- **Added** `--failed` opt to only run checks that have failed in the last run
- **Added** `--manifest` opt to specify path to file that holds last run results

## v0.12.0

- **Added** `:deps` tool option with support for depending on specific exit status
- **Removed** `:run_after` tool option (please use `:deps` tool option instead)
- **Fixed** merging tool umbrella opts with those set in ancestor config
- **Updated** default dialyxir config to no longer include `--halt-exit-status` deprecated in
  [1.0.0-rc.7](https://github.com/jeremyjh/dialyxir/blob/master/CHANGELOG.md#100-rc7---2019-09-21)
- **Improved** test suite detection to only check for `test` directory instead of `test_helper.exs`

## v0.11.0

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

## v0.10.0

- **Added** `:run_after` tool coonfiguration option (introducing powerful tool dependency system)

## v0.9.0

- **Added** automatic ANSI enabling for arbitrary Elixir commands (and not just Mix tasks)
- **Added** support for shorthand tool configuration (`{:tool_name, true/false/"command"}`)
- **Fixed** starting of app in Mix tasks that should have it started (e.g. `mix test`)

## v0.8.0

- **Changed** emit exit code via `System.at_exit/1` instead of `System.halt/1`
- **Fixed** accidental starting of app in Mix tasks
- **Removed** `--no-exit-status` command line option
- **Removed** `:exit_status` configuration option

## v0.7.0

- **Changed** automatic ANSI enabling for Mix tasks to use `mix run` instead of `mix check.run`
- **Removed** `mix check.run` task

## v0.6.0

- **Added** `:order` tool coonfiguration option
- **Changed** check summary to sort the items by status and name
- **Fixed** re-enabling tools after disable in ancestor config
- **Fixed** merging env vars with those set in ancestor config
- **Fixed** detection of Mix env for `mix check.run` wrapper

## v0.5.0

- **Added** automatic ANSI enabling for Mix tasks by auto-prepending `mix check.run`
- **Added** `:cd` tool coonfiguration option
- **Added** `:env` tool coonfiguration option
- **Added** support for invoking shell scripts as tools

## v0.3.0

- **Added** ANSI enabling for Mix tasks by prepending `mix check.run` in tool command

## v0.2.0

- **Added** `sobelow` tool
- **Added** loading of ancestor config (home + umbrella root)
- **Changed** Elixir version requirement from `1.9` to `1.7`
