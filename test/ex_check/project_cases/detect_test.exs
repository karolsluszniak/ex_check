defmodule ExCheck.ProjectCases.DetectTest do
  use ExCheck.ProjectCase, async: true

  @config """
  [
    tools: [
      {:dialyzer, detect: [{:package, :dialyxir, disable: true}]}
    ]
  ]
  """

  test "detect", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, @config)

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert String.contains?(output, "credo skipped due to missing package credo")
    refute String.contains?(output, "dialyzer skipped")
  end
end
