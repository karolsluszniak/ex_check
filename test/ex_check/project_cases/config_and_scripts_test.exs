defmodule ExCheck.ProjectCases.ConfigAndScriptsTest do
  use ExCheck.ProjectCase, async: true

  @config """
  [
    parallel: false,
    skipped: false,

    tools: [
      {:compiler, false},
      {:formatter, false},
      {:ex_unit, order: 2, command: ~w[mix test --cover]},
      {:my_mix_task, order: 1, command: "mix my_task a", env: %{"MIX_ENV" => "prod"}},
      {:my_elixir_script, command: "elixir priv/scripts/script.exs a"},
      {:my_shell_script, command: ["script.sh", "a b"], cd: "scripts", env: %{"SOME" => "xyz"}}
    ]
  ]
  """

  @mix_task ~S"""
  defmodule Mix.Tasks.MyTask do
    def run(args) do
      IO.puts(IO.ANSI.format([:yellow, "my mix task #{Enum.join(args)} #{Mix.env}"]))
    end
  end
  """

  @elixir_script ~S"""
  IO.puts(IO.ANSI.format([:blue, "my elixir script #{Enum.join(System.argv())}"]))
  """

  @shell_script """
  #!/bin/sh
  echo my shell script $1 $SOME
  """

  test "config and scripts", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, @config)

    mix_task_path = Path.join([project_dir, "lib", "mix", "tasks", "my_task.ex"])
    File.mkdir_p!(Path.dirname(mix_task_path))
    File.write!(mix_task_path, @mix_task)

    elixir_script_path = Path.join([project_dir, "priv", "scripts", "script.exs"])
    File.mkdir_p!(Path.dirname(elixir_script_path))
    File.write!(elixir_script_path, @elixir_script)

    shell_script_path = Path.join([project_dir, "scripts", "script.sh"])
    File.mkdir_p!(Path.dirname(shell_script_path))
    File.write!(shell_script_path, @shell_script)
    File.chmod!(shell_script_path, 0o755)

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir, stderr_to_stdout: true)

    assert String.contains?(output, "compiler success")
    refute String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit success")
    refute String.contains?(output, "credo skipped due to missing dependency credo")
    assert String.contains?(output, "my_mix_task success")
    assert String.contains?(output, "my_elixir_script success")
    assert String.contains?(output, "my_shell_script success")

    assert String.contains?(output, "Generated HTML coverage results")
    assert String.contains?(output, IO.ANSI.yellow() <> IO.ANSI.faint() <> "my mix task a prod")
    assert String.contains?(output, IO.ANSI.blue() <> IO.ANSI.faint() <> "my elixir script a")
    assert String.contains?(output, "my shell script a b xyz")

    assert String.match?(output, ~r/running my_shell_script.*running my_mix_task.*running ex_unit/s)
  end
end
