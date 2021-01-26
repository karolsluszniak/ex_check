# ![ex_check](./logo-with-name.svg)

[![Hex version](https://img.shields.io/hexpm/v/ex_check.svg?color=hsl(265,40%,60%))](https://hex.pm/packages/ex_check)
[![Build status (GitHub)](https://img.shields.io/github/workflow/status/karolsluszniak/ex_check/check/master?logo=github)](https://github.com/karolsluszniak/ex_check/actions)
[![Build status (Travis)](https://img.shields.io/travis/karolsluszniak/ex_check/master.svg?logo=travis)](https://travis-ci.org/karolsluszniak/ex_check)
[![Downloads](https://img.shields.io/hexpm/dt/ex_check.svg)](https://hex.pm/packages/ex_check)
[![License](https://img.shields.io/github/license/karolsluszniak/ex_check.svg)](https://github.com/karolsluszniak/ex_check/blob/master/LICENSE.md)

![Demo](https://raw.githubusercontent.com/karolsluszniak/ex_check/master/demo-67x16.svg)

**Run all code checking tools with a single convenient `mix check` command.**

---

Takes seconds to setup, saves hours in the long term.
- Comes out of the box with a [predefined set of curated tools](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-tools)
- Delivers results faster by [running tools in parallel and catching all issues in one go](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-workflow)
- Checks the project consistently on every developer's local machine & [on the CI](https://github.com/karolsluszniak/ex_check#continuous-integration)
- Runs only the tools & tests that have [failed in the last run](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-retrying-failed-tools)
- Fixes issues automatically in [the fix mode](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-fix-mode)

Sports powerful features to enable ultimate flexibility.
- Add custom mix tasks, shell scripts and commands via [configuration file](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-configuration-file)
- Enhance you CI workflow to [report status](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-manifest-file), [retry random failures](#random-failures) or [autofix issues](#autofixing)
- Empower umbrella projects with [parallel recursion over child apps](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-umbrella-projects)
- Design complex parallel workflows with [cross-tool deps](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-cross-tool-dependencies)

Takes care of the little details, so you don't have to.
- Compiles the project and collects compilation warnings in one go
- Ensures that output from tools is [ANSI formatted & colorized](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-tool-processes-and-ansi-formatting)
- Retries ExUnit with the `--failed` flag

Read more in the introductory ["One task to rule all Elixir analysis & testing tools"](http://cloudless.studio/articles/49-one-task-to-rule-all-elixir-analysis-testing-tools) article.

## Getting started

Add `ex_check` dependency in `mix.exs`:

```elixir
def deps do
  [
    {:ex_check, "~> 0.14.0", only: [:dev], runtime: false}
  ]
end
```

Fetch the dependency:

```
mix deps.get
```

Run the check:

```
mix check
```

That's it - `mix check` will detect and run all the available tools.

### Community tools

If you want to take advantage of community curated tools, add following dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:credo, ">= 0.0.0", only: [:dev], runtime: false},
    {:dialyxir, ">= 0.0.0", only: [:dev], runtime: false},
    {:doctor, ">= 0.0.0", only: [:dev], runtime: false},
    {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false},
    {:sobelow, ">= 0.0.0", only: [:dev], runtime: false}
  ]
end
```

You may also generate `.check.exs` to adjust the check:

```
mix check.gen.config
```

Among others, this allows to permamently disable specific tools and avoid the skipped notices.

```elixir
[
  tools: [
    {:dialyzer, false},
    {:sobelow, false}
  ]
]
```

### Local-only fix mode

You should keep local and CI configuration as consistent as possible by putting together the project-specific `.check.exs`. Still, you may introduce local-only config by creating the `~/.check.exs` file. This may be useful to enforce global flags on all local runs. For example, the following config will enable the fix mode in local (writeable) envirnoment:

```elixir
[
  fix: true
]
```

> You may also [enable the fix mode on the CI](#autofixing).

## Documentation

Learn more about the tools included in the check as well as its workflow, configuration and options [on HexDocs](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html) or by running `mix help check`.

Want to write your own code check? Get yourself started by reading the ["Writing your first Elixir code check"](http://cloudless.studio/articles/50-writing-your-first-elixir-code-check) article.

## Continuous Integration

With `mix check` you can consistently run the same set of checks locally and on the CI. CI configuration also becomes trivial and comes out of the box with parallelism and error output from all checks at once regardless of which ones have failed.

Like on a local machine, all you have to do in order to use `ex_check` on CI is run `mix check` nstead of `mix test`. This repo features working CI configs for following providers:

- GitHub - [.github/workflows/check.yml](https://github.com/karolsluszniak/ex_check/blob/master/.github/workflows/check.yml)
- Travis - [.travis.yml](https://github.com/karolsluszniak/ex_check/blob/master/.travis.yml)

Yes, `ex_check` uses itself on the CI. Yay for recursion!

### Autofixing

You may automatically fix and commit back trivial issues by triggering the fix mode on the CI as well. In order to do so, you'll need a CI script or workflow similar to the example below:

```bash
mix check --fix && \
  git diff-index --quiet HEAD -- && \
  git config --global user.name 'Autofix' && \
  git config --global user.email 'autofix@example.com' && \
  git add --all && \
  git commit --message "Autofix" && \
  git push
```

First, we perform the check in the fix mode. Then, if no unfixable issues have occurred and if fixes were actually made, we proceed to commit and push these fixes.

Of course your CI will need to have write permissions to the source repository.

### Random failures

You may take advantage of the automatic retry feature to efficiently re-run failed tools & tests multiple times. For instance, following shell command runs check up to three times: `mix check || mix check || mix check`. And here goes an alternative without the logical operators:

```bash
mix check
mix check --retry
mix check --retry
```

This will work as expected because the `--retry` flag will ensure that only failed tools are executed, resulting in no-op if previous run has succeeded.

## Troubleshooting

### Duplicate builds

If, as suggested above, you've added `ex_check` and curated tools to `only: [:dev]`, you're keeping the test environment reserved for `ex_unit`. While a clean setup, it comes at the expense of Mix having to compile your app twice - in order to prepare `:test` build just for `ex_unit` and `:dev` build for other tools. This costs precious time both on local machine and on the CI. It may also cause issues if you set `MIX_ENV=test`, which is a common practice on the CI.

You may avoid this issue by running `mix check` and all the tools it depends on in the test environment. In such case you may want to have the following config in `mix.exs`:

```elixir
def project do
  [
    # ...
    preferred_cli_env: [
      check: :test,
      credo: :test,
      dialyzer: :test,
      doctor: :test,
      sobelow: :test
    ]
  ]
end

def deps do
  [
    {:credo, ">= 0.0.0", only: [:test], runtime: false},
    {:dialyxir, ">= 0.0.0", only: [:test], runtime: false},
    {:doctor, ">= 0.0.0", only: [:test], runtime: false},
    {:ex_check, "~> 0.14.0", only: [:test], runtime: false},
    {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
    {:sobelow, ">= 0.0.0", only: [:test], runtime: false}
  ]
end
```

And the following in `.check.exs`:

```elixir
[
  tools: [
    {:compiler, env: %{"MIX_ENV" => "test"}},
    {:formatter, env: %{"MIX_ENV" => "test"}},
    {:ex_doc, env: %{"MIX_ENV" => "test"}}
  ]
]
```

Above setup will consistently check the project using just the test build, both locally and on the CI.

### `unused_deps` false negatives

You may encounter an issue with the `unused_deps` check failing on the CI while passing locally, caused by fetching only dependencies for specific env. If that happens, remove the `--only test` (or similar) from your `mix deps.get` invocation on the CI to fix the issue.

## Changelog

See [CHANGELOG.md](https://github.com/karolsluszniak/ex_check/blob/master/CHANGELOG.md).

## License

See [LICENSE.md](https://github.com/karolsluszniak/ex_check/blob/master/LICENSE.md).
