defmodule ExCheck.ProjectCases.CustomConfigTest do
  use ExCheck.ProjectCase, async: true

  test "custom config", %{project_dir: project_dir} do
    config = """
    [
      skipped: false,
      exit_status: false,
      parallel: false,

      tools: [
        {:compiler, false},
        {:formatter, false},
        {:credo, command: "mix credo --format oneline"},
        {:ex_unit, order: -1},
        {:release, command: "mix release", env: %{"MIX_ENV" => "prod"}},
        {:my_script, command: ["script.sh", "a b"], cd: "scripts", env: %{"SOME" => "xyz"}}
      ]
    ]
    """

    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, config)

    scripts_path = Path.join(project_dir, "scripts")
    File.mkdir_p!(scripts_path)

    script = """
    #!/bin/bash
    echo $1 $SOME
    """

    script_path = Path.join(scripts_path, "script.sh")
    File.write!(script_path, script)
    File.chmod!(script_path, 0o755)

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert String.contains?(output, "compiler success")
    refute String.contains?(output, "formatter success")
    assert String.contains?(output, "ex_unit success")
    refute String.contains?(output, "credo skipped due to missing dependency credo")
    assert String.contains?(output, "release success")
    assert String.contains?(output, "my_script success")

    assert String.contains?(output, "Release created at _build/prod/rel/test_project")
    assert String.contains?(output, "a b xyz")
  end
end
