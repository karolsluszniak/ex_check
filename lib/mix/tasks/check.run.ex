defmodule Mix.Tasks.Check.Run do
  # Mix tasks executed by `mix check` are not run in a TTY and will not print ANSI characters in
  # their output - which means no colors, no bold etc. This makes the tool output (e.g. assertion
  # diffs from ex_unit) less useful.
  #
  # This task solves the problem by running arbitrary Mix task in environment preconfigured for
  # always using ANSI characters even when not running in a TTY.

  @moduledoc false

  use Mix.Task

  @impl Mix.Task
  def run([task_name | task_args]) do
    Application.put_env(:elixir, :ansi_enabled, true, persistent: true)
    Mix.Task.run(task_name, task_args)
  end
end
