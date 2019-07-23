# ex_check

[![license](https://img.shields.io/github/license/karolsluszniak/ex_check.svg)](https://github.com/karolsluszniak/ex_check/blob/master/LICENSE.md)
[![build status](https://img.shields.io/travis/karolsluszniak/ex_check/master.svg)](https://travis-ci.org/karolsluszniak/ex_check)
[![Hex version](https://img.shields.io/hexpm/v/ex_check.svg)](https://hex.pm/packages/ex_check)

**One task to efficiently run all code analysis & testing tools in an Elixir project.**

There are following benefits from using this task:

- **check consistency** is achieved by running the same, established set of tools for the project
  by all developers - be it locally or on the CI server, as a Pull Request or deployment check

- **reasonable defaults** with a set of curated tools for effortlessly ensuring top code quality
  and taking the best out of the rich set of tools that the Elixir ecosystem has to offer

- **shorter feedback loop** thanks to compiling the project once and then running all the
  remaining tools in parallel while the output is streamed live during the check run

- **reduced fixing iterations** thanks to executing all the tools regardless of the failures of
  others and reprinting the errors from all of them at the end of the check run

Read more and see demo on [Cloudless Studio blog](http://cloudless.studio/articles/49-one-task-to-rule-all-elixir-analysis-testing-tools).

## Getting started

Add `ex_check` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_check, ">= 0.0.0", only: [:dev, :test], runtime: false}
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
