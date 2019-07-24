defmodule Mix.Tasks.Check do
  @moduledoc """
  One task to efficiently run all code analysis & testing tools in an Elixir project.

  ## How it works

  First it runs the compiler and aborts upon compilation errors (but not warnings). Further tools
  are run in parallel (unless `--no-parallel` option is passed) and their output is streamed one by one for instant insight.

  After all tools are completed, output from those that have failed gets reprinted for sake of
  easily reading into them all at once.

  Finally, a summary is presented with a list of all tools that have succeeded, failed or were
  skipped due to missing files or project dependencies (unless `--no-skipped` option is passed).

  ## Tools

  Following curated tools are configured by default:

  - [`:compiler`] - produces compilation warnings that allow to early detect bugs & typos in the
    code eg. an attempt to call non-existing or deprecated function

  - [`:formatter`] - ensures that all the code follows the same basic formatting rules such as
    maximum number of chars in a line or function indentation

  - [`:ex_unit`] - starts the application in test mode and runs all runtime tests against it
    (defined as test modules or embedded in docs as doctests)

  - [`:credo`] - ensures that all the code follows a further established set of software design,
    consistency, readability & misc rules and conventions (still statical)

  - [`:sobelow`] - performs security-focused static analysis mainly focused on the Phoenix
    framework, but also detecting vulnerable dependencies in arbitrary Mix projects

  - [`:dialyzer`] - performs static code analysis around type mismatches and other issues that are
    commonly detected by static language compilers

  - [`:ex_doc`] - compiles the project documentation in order to ensure that there are no issues
    that would make it impossible for docs to get collected and assembled

  You can disable or adjust curated tools as well as add custom ones via the config file.

  ## Configuration file

  Check configuration may be adjusted with the optional `.check.exs` file. Task will load the
  configuration in following order:

  1. Default stock configuration.
  2. `.check.exs` in user home directory.
  3. `.check.exs` in umbrella root directory when called from sub-project.
  4. `.check.exs` in current project directory.

  Configuration file should evaluate to keyword list with following options:

  - `:exit_status` - toggles halting EVM to return non-zero exit status (default: true)
  - `:parallel` - toggles running tools in parallel (default: true)
  - `:skipped` - toggles printing skipped tools in summary (default: true)
  - `:tools` - a list of tools to run

  Each tool is a `{:tool_name, false}` tuple to disable specific tool or `{:tool_name, opts}` tuple
  where `opts` is a keyword list with following options:

  - `:command` - command as string or list of strings (executable + arguments)
  - `:cd` - directory (relative to cwd) to change to before running the command
  - `:env` - environment variables as map with string keys & values
  - `:order` - integer that controls the order in which tool output is presented (default: 0)

  Use the `mix check.gen.config` task to generate sample configuration that comes with well-commented examples to help you get started.

  ## Command line options

  - `--only dialyzer --only credo ...` - run only specified check(s)
  - `--except dialyzer --except credo ...` - don't run specified check(s)
  - `--no-exit-status` - don't halt EVM to return non-zero exit status
  - `--no-parallel` - don't run tools in parallel
  - `--no-skipped` - don't print skipped tools in summary

  [`:compiler`]: https://hexdocs.pm/mix/Mix.Tasks.Compile.html
  [`:formatter`]: https://hexdocs.pm/mix/Mix.Tasks.Format.html
  [`:ex_unit`]: https://hexdocs.pm/ex_unit
  [`:credo`]: https://hexdocs.pm/credo
  [`:sobelow`]: https://hexdocs.pm/sobelow
  [`:dialyzer`]: https://hexdocs.pm/dialyxir
  [`:ex_doc`]: https://hexdocs.pm/ex_doc
  """

  use Mix.Task
  alias ExCheck.Check

  @shortdoc "Runs all code analysis & testing tools in an Elixir project"

  @switches [
    only: :keep,
    except: :keep,
    skipped: :boolean,
    exit_status: :boolean,
    parallel: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    opts
    |> process_opts()
    |> Check.run()
  end

  defp process_opts(opts) do
    Enum.map(opts, fn
      {:only, name} -> {:only, String.to_atom(name)}
      {:except, name} -> {:except, String.to_atom(name)}
      opt -> opt
    end)
  end
end
