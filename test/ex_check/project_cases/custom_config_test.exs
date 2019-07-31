defmodule ExCheck.ProjectCases.CustomConfigTest do
  use ExCheck.ProjectCase, async: true

  @config """
  [
    parallel: false,
    skipped: false,

    tools: [
      {:compiler, false},
      {:formatter, false},
      {:ex_unit, order: 2, command: ~w[mix test --cover]},
      {:my_task, order: 1, command: "mix my_task", env: %{"MIX_ENV" => "prod"}},
      {:my_script, command: ["script.sh", "a b"], cd: "scripts", env: %{"SOME" => "xyz"}}
    ]
  ]
  """

  @task ~S"""
  defmodule Mix.Tasks.MyTask do
    use Mix.Task

    def run(_) do
      IO.puts("my task #{Mix.env}")
    end
  end
  """

  @script """
  #!/bin/bash
  echo $1 $SOME
  """

  test "custom config", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, @config)

    task_path = Path.join([project_dir, "lib", "mix", "tasks", "my_task.ex"])
    File.mkdir_p!(Path.dirname(task_path))
    File.write!(task_path, @task)

    script_path = Path.join([project_dir, "scripts", "script.sh"])
    File.mkdir_p!(Path.dirname(script_path))
    File.write!(script_path, @script)
    File.chmod!(script_path, 0o755)

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir, stderr_to_stdout: true)

    assert String.contains?(output, "compiler success")
    refute String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit success")
    refute String.contains?(output, "credo skipped due to missing dependency credo")
    assert String.contains?(output, "my_task success")
    assert String.contains?(output, "my_script success")

    assert String.contains?(output, "Generated HTML coverage results")
    assert String.contains?(output, "my task prod")
    assert String.contains?(output, "a b xyz")

    assert String.match?(output, ~r/running my_script.*running my_task.*running ex_unit/s)
  end
end
