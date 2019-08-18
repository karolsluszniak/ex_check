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

  ### Tool order

  Tools are run in parallel, but their output is presented one by one in order to avoid mixing it
  up. You can control the order in which the output is presented for tools that have started at the
  same time via the `:order` tool option. You'll probably want to put tools that run quicker and
  fail more often before the others in order to get useful feedback as soon as possible. Curated
  tools are ordered in such a way out of the box.

  ### Tool processes and ANSI formatting

  Tools are run in separate processes. This has following benefits:

  - allows to run tools in parallel & stream their output
  - catches exit statuses in order to detect failures
  - enables running Mix tasks in multiple envs
  - enables including non-Elixir scripts and tools in the check

  The downside is that tools will be run outside of TTY which will usually result in disabling ANSI
  formatting. This issue is fixed in different ways depending on Elixir version:

  - **Elixir 1.9 and newer**: patches all Elixir commands and Mix tasks with `--erl-config` option
    to load the Erlang configuration provided by `ex_check` that sets the `ansi_enabled` flag

  - **older versions**: patches Mix tasks with `--eval` option to run `Application.put_env/3` that
    sets the `ansi_enabled` flag

  You may keep your Elixir commands unaffected via the `:enable_ansi` tool option. It's ignored for
  non-Elixir tools for which you'll have to enforce ANSI on your own.

  ### Cross-tool dependencies

  Even though tools are run in parallel, it's possible to make sure that specific tool will be run
  only after other(s) are completed via the `:run_after` tool option. This enables defining complex
  workflows in which tools may reuse artifacts from ones executed earlier or they may be forced not
  to run at the same time without giving up on entire parallel execution.

  Note that tools will be run regardless of the exit status of their `:run_after` dependencies, but
  they'll be skipped if their dependencies won't be run at all e.g. due to using `--except` command
  line option or a missing/circular dependency.

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

  Each tool is a `{:tool_name, opts}` tuple where `opts` is a keyword list with following options:

  - `:enabled` - enables/disables already defined tools (default: `true`)
  - `:command` - command as string or list of strings (executable + arguments)
  - `:cd` - directory (relative to cwd) to change to before running the command
  - `:env` - environment variables as map with string keys & values
  - `:order` - integer that controls the order in which tool output is presented (default: `0`)
  - `:run_after` - list of tool names (atoms) as deps that must finish running before tool start
  - `:enable_ansi` - toggles extending Elixir/Mix commands to have ANSI enabled (default: `true`)
  - `:require_deps` - list of package names (atoms) that must be present or tool will be skipped
  - `:require_files` - list of filenames (strings) that must be present or tool will be skipped

  You may also use one of the shorthand tool tuple forms:

  - `{:tool_name, enabled}` where `enabled` is a boolean that translates into the `:enabled` option
  - `{:tool_name, command}` where `command` is a binary that translates into the `:command` option

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
