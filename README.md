# ex_check

[![license](https://img.shields.io/github/license/karolsluszniak/ex_check.svg)](https://github.com/karolsluszniak/ex_check/blob/master/LICENSE.md)
[![build status](https://img.shields.io/travis/karolsluszniak/ex_check/master.svg)](https://travis-ci.org/karolsluszniak/ex_check)
[![Hex version](https://img.shields.io/hexpm/v/ex_check.svg)](https://hex.pm/packages/ex_check)

**One task to efficiently run all code analysis & testing tools in an Elixir project.**

- Runs all tools with a single convenient `mix check` command
- Comes out of the box with a predefined set of curated tools
- Checks the project consistently for all developers & on the CI
- Facilitates custom mix tasks and scripts acting as project checks
- Delivers results faster by running & streaming tools in parallel
- Identifies all project issues in one go by always running all tools
- Takes care of the little details (compile once, enable ANSI etc)

Read more and see demo on [Cloudless Studio blog](http://cloudless.studio/articles/49-one-task-to-rule-all-elixir-analysis-testing-tools).

## Getting started

Add `ex_check` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_check, ">= 0.0.0", only: :dev, runtime: false}
  ]
end
```

Optionally add curated tools to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:credo, ">= 0.0.0", only: :dev, runtime: false},
    {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
    {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
    {:sobelow, ">= 0.0.0", only: :dev, runtime: false}
  ]
end
```

Run the check:

```
mix check
```

Optionally generate config to adjust the check:

```
mix check.gen.config
```

## Continuous Integration

With `mix check` you can consistently run the same set of checks locally and on the CI. CI
configuration also becomes trivial and comes out of the box with parallelism and error output from
all checks at once regardless if previous one failed.

Here's the minimal `.travis.yml` to get you started on [Travis CI](https://travis-ci.org):

```yaml
language: elixir

script: mix check
```

If you use the `dialyzer` tool, you'll also want to cover PLT build timeouts and caching:

```yaml
# ...

before_script:
  - travis_wait mix dialyzer --plt

cache:
  directories:
    - _build
    - deps
```

## Documentation

Learn more about the task workflow, included tools, configuration and options:

```
mix help check
```

Read docs for `mix check` on HexDocs: [latest version](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html).
