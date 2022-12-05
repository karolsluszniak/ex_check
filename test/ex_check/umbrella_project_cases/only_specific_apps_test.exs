defmodule ExCheck.UmbrellaProjectCases.OnlySpecificAppsTest do
  use ExCheck.UmbrellaProjectCase, async: true

  @config """
  [
    tools: [
      {:ex_unit, umbrella: [apps: [:child_a]]},
    ]
  ]
  """

  test "only specific apps", %{project_dirs: [project_root_dir, child_a_dir, child_b_dir]} do
    config_path = Path.join(project_root_dir, ".check.exs")
    File.write!(config_path, @config)

    assert {_, 0} = System.cmd("mix", ~w[compile], cd: project_root_dir)
    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_root_dir)

    refute output =~ "ex_unit success"
    assert output =~ "ex_unit in child_a success"
    refute output =~ "ex_unit in child_b success"

    assert {output, 0} = System.cmd("mix", ~w[check], cd: child_a_dir)

    assert output =~ "ex_unit success"

    assert {output, 0} = System.cmd("mix", ~w[check], cd: child_b_dir)

    refute output =~ "ex_unit"
  end
end
