defmodule Mix.Tasks.Check do
  @moduledoc """
  One task to efficiently run all code analysis & testing tools in an Elixir project.

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

  You can disable or adjust curated tools as well as add custom ones via the configuration file.

  ## Workflow

  1. `:compiler` tool is run before others in order to compile the project just once and to avoid
     reprinting the compilation error multiple times.

  2. If the compilation succeded (even if with warnings), further tools are run in parallel while
     their output is streamed live one by one for instant insight.

  3. Output from tools that have failed gets reprinted for sake of easily reading into them all at
     once and identifying all project issues in one go.

  4. Summary is presented with a list of all tools that have failed, succeeded or were skipped due
     to missing files or project dependencies.

  5. If any of the tools have failed, the Erlang system gets requested to emit exit status 1 upon
     shutdown in order to make the CI build fail.

  ## Tool execution

  Tools are run in separate processes. This has following benefits:

  - allows to run tools in parallel & stream their output
  - catches exit statuses in order to detect failures
  - enables running Mix tasks in multiple envs
  - enables including non-Elixir scripts and tools in the check

  The downside is that tools will be run without TTY which will usually result in tools disabling
  ANSI formatting. This issue is fixed for mix tasks (which often depend on `IO.ANSI.format/1` for
  output formatting) by wrapping them in `mix do` that explicitly enables ANSI.

  ## Configuration file

  Check configuration may be adjusted with the optional `.check.exs` file. Task will load the
  configuration in following order:

  1. Default stock configuration.
  2. `.check.exs` in user home directory.
  3. `.check.exs` in umbrella root directory when called from sub-project.
  4. `.check.exs` in current project directory.

  Configuration file should evaluate to keyword list with following options:

  - `:parallel` - toggles running tools in parallel (default: `true`)
  - `:skipped` - toggles printing skipped tools in summary (default: `true`)
  - `:tools` - a list of tools to run (default: curated tools)

  Each tool is a`{:tool_name, opts}` tuple where `opts` is a keyword list with following options:

  - `:command` - command as string or list of strings (executable + arguments)
  - `:cd` - directory (relative to cwd) to change to before running the command
  - `:env` - environment variables as map with string keys & values
  - `:enable_ansi` - toggles wrapping mix tasks to have ANSI enabled (default: `true`)
  - `:enabled` - toggles including already defined tools in the check (default: `true`)
  - `:order` - integer that controls the order in which tool output is presented (default: `0`)
  - `:require_deps` - list of package atoms that must be present or tool will be skipped
  - `:require_files` - list of file name strings that must be present or tool will be skipped

  Use the `mix check.gen.config` task to generate sample configuration that comes with well-commented examples to help you get started.

  ## Command line options

  - `--only dialyzer --only credo ...` - run only specified check(s)
  - `--except dialyzer --except credo ...` - don't run specified check(s)
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
