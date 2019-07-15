# ExCheck

**Runs all checks configured in an Elixir project.**

There are following benefits from using this task:

- **check consistency** is achieved by running the same, established set of checks for the project
  by all developers - be it locally or on the CI server, as a Pull Request or deployment check

- **reasonable defaults** with a set of curated checks for effortlessly ensuring top code quality
  and taking the best out of the rich set of tools that the Elixir ecosystem has to offer

- **shorter feedback loop** thanks to compiling the project once and then running all the
  remaining checks in parallel while the output is streamed live during the check run

- **reduced fixing iterations** thanks to executing all the checks regardless of the failures of
  others and reprinting the errors from all of them at the end of the check run

## Getting started

Add `ex_check` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_check, "~> 0.1.0", only: :dev, runtime: false}
  ]
end
```

Run the check:

```
mix check
```

Learn more about the task workflow, checks, configuration and command line options:

```
mix help check
```

(or read docs at [https://hexdocs.pm/ex_check](https://hexdocs.pm/ex_check))
