defmodule ExCheck.UmbrellaProjectCases.NonRecursiveTest do
  use ExCheck.UmbrellaProjectCase, async: true

  @config """
  [
    tools: [
      {:ex_unit, umbrella: [recursive: false], detect: []},
    ]
  ]
  """

  test "non-recursive", %{project_dirs: [project_root_dir | _]} do
    config_path = Path.join(project_root_dir, ".check.exs")
    File.write!(config_path, @config)

    assert {_, 0} = System.cmd("mix", ~w[compile], cd: project_root_dir)
    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_root_dir)

    assert output =~ "ex_unit success"
    refute output =~ "ex_unit in child_a success"
    refute output =~ "ex_unit in child_b success"
  end
end
