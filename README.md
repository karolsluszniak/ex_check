# ![ex_check](https://raw.githubusercontent.com/karolsluszniak/ex_check/master/logo.svg) ex_check

[![License](https://img.shields.io/github/license/karolsluszniak/ex_check.svg)](https://github.com/karolsluszniak/ex_check/blob/master/LICENSE.md)
[![Build status (GitHub Actions)](https://img.shields.io/github/workflow/status/karolsluszniak/ex_check/check/master?logo=github)](https://github.com/karolsluszniak/ex_check/actions)
[![Build status (Travis CI)](https://img.shields.io/travis/karolsluszniak/ex_check/master.svg?logo=travis)](https://travis-ci.org/karolsluszniak/ex_check)
[![Hex version](https://img.shields.io/hexpm/v/ex_check.svg)](https://hex.pm/packages/ex_check)
[![Downloads](https://img.shields.io/hexpm/dt/ex_check.svg)](https://hex.pm/packages/ex_check)

![Demo](https://raw.githubusercontent.com/karolsluszniak/ex_check/master/demo-67x16.svg)

**Run all code checking tools with a single convenient `mix check` command.**

---

Takes seconds to setup, saves hours in the long term.
- Comes out of the box with a [predefined set of curated tools](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-tools), including NPM integration for Phoenix assets
- Delivers results faster by [running tools in parallel and identifying all project issues in one go](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-workflow)
- Checks the project consistently on every developer's local machine & [on the CI](https://github.com/karolsluszniak/ex_check#continuous-integration)
- Allows to re-run checks that have [failed in the last run](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-manifest-file)

Sports powerful features to enable ultimate flexibility.
- Add custom mix tasks, shell scripts and commands via [configuration file](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-configuration-file)
- Report status of each check to CI by using [manifest file](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-manifest-file)
- Empower umbrella projects with [parallel recursion over child apps](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-umbrella-projects)
- Design complex parallel workflows with [cross-tool dependencies](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-cross-tool-dependencies)

Takes care of the little details, so you don't have to.
- Compiles the project and collects compilation warnings in one go
- Ensures that output from tools is still [ANSI formatted & colorized](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html#module-tool-processes-and-ansi-formatting)

Read more in the introductory ["One task to rule all Elixir analysis & testing
tools"](http://cloudless.studio/articles/49-one-task-to-rule-all-elixir-analysis-testing-tools)
article.

## Getting started

Add `ex_check` dependency in `mix.exs`:

```elixir
def deps do
  [
    {:ex_check, "~> 0.13.0", only: [:dev], runtime: false}
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

### Configuring tools

If you want to take advantage of curated tools, add following dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:credo, ">= 0.0.0", only: [:dev], runtime: false},
    {:dialyxir, ">= 0.0.0", only: [:dev], runtime: false},
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

### Avoiding duplicate builds

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
      sobelow: :test
    ]
  ]
end

def deps do
  [
    {:credo, ">= 0.0.0", only: [:test], runtime: false},
    {:dialyxir, ">= 0.0.0", only: [:test], runtime: false},
    {:ex_check, "~> 0.13.0", only: [:test], runtime: false},
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

### Avoiding false negatives of `unused_deps` check

You may encounter an issue with the `unused_deps` check failing on the CI while passing locally, caused by fetching only dependencies for specific instead of all deps. If that happens, remove the `--only test` (or similar) from your `mix deps.get` invocation on the CI to fix the issue.

## Documentation

Learn more about the tools included in the check as well as its workflow, configuration and options
[on HexDocs](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html) or by running `mix help check`.

Want to write your own code check? Get yourself started by reading the ["Writing your first Elixir
code check"](http://cloudless.studio/articles/50-writing-your-first-elixir-code-check) article.

## Continuous Integration

With `mix check` you can consistently run the same set of checks locally and on the CI. CI
configuration also becomes trivial and comes out of the box with parallelism and error output from
all checks at once regardless of which ones have failed.

Like on a local machine, all you have to do in order to use `ex_check` on CI is run `mix check` instead of `mix test`. This repo features working CI configs for following providers:

- GitHub Actions - [.github/workflows/check.yml](https://github.com/karolsluszniak/ex_check/blob/master/.github/workflows/check.yml)
- Travis CI - [.travis.yml](https://github.com/karolsluszniak/ex_check/blob/master/.travis.yml)

Yes, `ex_check` uses itself on the CI. Yay for recursion!

## Changelog

See [CHANGELOG.md](https://github.com/karolsluszniak/ex_check/blob/master/CHANGELOG.md).

## License

See [LICENSE.md](https://github.com/karolsluszniak/ex_check/blob/master/LICENSE.md).
