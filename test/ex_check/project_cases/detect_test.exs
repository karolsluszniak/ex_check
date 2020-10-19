defmodule ExCheck.ProjectCases.DetectTest do
  use ExCheck.ProjectCase, async: true

  @config """
  [
    tools: [
      {:dialyzer, detect: [{:package, :dialyxir, else: :disable}]},
      {:version_detect, ["my", "command"], detect: [{:elixir, "<= 1.0.0"}]},
      {:bad_dir, ["my", "command"], cd: "bad_directory"}
    ]
  ]
  """

  test "detect", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, @config)

    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_dir)

    assert output =~ "credo skipped due to missing package credo"
    assert output =~ "bad_dir skipped due to missing directory bad_directory"
    assert output =~ "version_detect skipped due to Elixir version = "
    refute output =~ "dialyzer skipped"
  end
end
