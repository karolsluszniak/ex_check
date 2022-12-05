defmodule ExCheck.UmbrellaProjectCases.SequentialTest do
  use ExCheck.UmbrellaProjectCase, async: true

  @a_script """
  Process.sleep(1_000)
  File.write!(Path.join("..", "a_out"), "a_out")
  """

  @b_script """
  IO.puts(File.read!(Path.join("..", "a_out")))
  """

  @config """
  [
    tools: [
      {:seq, "elixir script.exs", umbrella: [parallel: false]},
    ]
  ]
  """

  test "sequential", %{project_dirs: [project_root_dir, child_a_dir, child_b_dir]} do
    config_path = Path.join(project_root_dir, ".check.exs")
    File.write!(config_path, @config)

    child_a_script_path = Path.join(child_a_dir, "script.exs")
    File.write!(child_a_script_path, @a_script)

    child_b_script_path = Path.join(child_b_dir, "script.exs")
    File.write!(child_b_script_path, @b_script)

    assert {_, 0} = System.cmd("mix", ~w[compile], cd: project_root_dir)
    assert {output, 0} = System.cmd("mix", ~w[check], cd: project_root_dir)

    assert output =~ "seq in child_a success"
    assert output =~ "seq in child_b success"
    assert output =~ "a_out"
  end
end
