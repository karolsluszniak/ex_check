# ex_check usage rules

ex_check provides the `mix check` task: it runs all of a project's code analysis &
testing tools (compiler, formatter, credo, dialyzer, tests, security scanners, ...) in
parallel with one command, and reports every failure in a single run.

## Running

```
mix check
```

Runs every detected tool. Tools whose package or required files are absent are skipped
automatically — you do not need to configure them. Exit status is non-zero if any tool
fails.

For machine-readable output (preferred when an agent parses results):

```
mix check --format agent              # JSON status header + raw failure blocks
mix check --format json --output check.json
```

Both formats include a `diagnostics` list for failed `compiler`/`credo`/`ex_unit` checks —
each entry has `file`, `line` and `message`, so you can jump straight to a finding instead
of parsing the raw output blocks.

## Useful flags

- `--only NAME` / `-o NAME` — run only the named tool(s); repeatable. e.g. `mix check -o credo -o ex_unit`
- `--except NAME` / `-x NAME` — skip the named tool(s); repeatable.
- `--fix` / `-f` — auto-fix what can be fixed (e.g. `mix format`, unlock unused deps).
- `--retry` / `-r` — run only tools that failed in the previous run.
- `--no-parallel` — run tools sequentially.
- `--config PATH` / `-c PATH` — use a specific config file.
- `--format pretty|agent|json|github|junit` — output format (default `pretty`). `github` emits
  GitHub Actions log groups + a `$GITHUB_STEP_SUMMARY` table; `junit` emits a JUnit XML report.
- `--output PATH` — write the report to a file (only with `--format agent`, `json` or `junit`).

Combine `--fix --retry` to fix only the tools that just failed.

## Configuration: `.check.exs`

Generate a commented starter config:

```
mix check.gen.config
```

`.check.exs` returns a keyword list. Root keys:

- `:tools` — list of tool tuples (overrides/extends the curated set).
- `:fix` — `true` to always run fix mode (default `false`).
- `:parallel` — `false` to disable parallelism (default `true`).
- `:retry` — `false` to disable auto-retry (default: on when a manifest exists).
- `:skipped` — `false` to hide skipped tools in the summary.

Tool tuple forms:

```elixir
{:credo, false}                              # disable a curated tool
{:credo, "mix credo --strict"}               # override the command
{:my_task, "mix my_task"}                    # add a custom mix task
{:my_tool, ["my_tool", "arg with spaces"]}   # add an arbitrary command
{:npm_test, command: "npm test", cd: "assets", env: %{"CI" => "true"}}
```

Example `.check.exs`:

```elixir
[
  tools: [
    {:dialyzer, false},
    {:credo, "mix credo --strict"},
    {:my_audit, "mix my_audit"}
  ]
]
```

Local-only overrides go in `~/.check.exs` (e.g. `[fix: true]`). Umbrella projects run
tools recursively per child app by default; tune via each tool's `:umbrella` option.

## Curated tools

`mix check` runs these when detected:

- `compiler` — `mix compile --warnings-as-errors`
- `formatter` — `mix format --check-formatted` (fix: `mix format`)
- `unused_deps` — `mix deps.unlock --check-unused` (fix: `--unused`)
- `credo` — `mix credo`
- `dialyzer` — `mix dialyzer` (needs `:dialyxir`)
- `doctor` — `mix doctor` (needs `:doctor`)
- `ex_doc` — `mix docs` (needs `:ex_doc`)
- `sobelow` — `mix sobelow --exit` (needs `:sobelow`)
- `mix_audit` — `mix deps.audit` (needs `:mix_audit`)
- `gettext` — `mix gettext.extract --check-up-to-date` (needs `:gettext`)
- `ex_unit` — `mix test` (retry: `mix test --failed`)
- `npm_test` — `npm test` in `assets/` (needs `package.json`)

## Agent guidance

- Run `mix check` before considering an Elixir change complete — it surfaces compile
  warnings, format drift, credo/dialyzer/test failures in one pass.
- Prefer `mix check --format agent` for parseable output.
- Use `mix check --fix` to resolve formatting and unused-dep issues automatically.
- Do not add tools that aren't installed; ex_check auto-skips missing ones.
- To narrow a slow run while iterating, use `-o`/`--only`.
