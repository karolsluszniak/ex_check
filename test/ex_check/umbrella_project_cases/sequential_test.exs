defmodule ExCheck.UmbrellaProjectCases.SequentialTest do
  use ExCheck.UmbrellaProjectCase, async: true

  test "sequential", %{project_dirs: [project_root_dir, child_a_dir, child_b_dir]} do
    script_path = Path.join(project_root_dir, "a_out")

    a_script = """
    IO.inspect({:a1, DateTime.utc_now()})
    Process.sleep(1_000)
    File.write!("#{script_path}", "a_out")
    IO.inspect({:a2, DateTime.utc_now()})
    """

    b_script = """
    IO.inspect({:b1, DateTime.utc_now()})
    Process.sleep(1_000)
    IO.puts(File.read!("#{script_path}"))
    IO.inspect({:b2, DateTime.utc_now()})
    """

    config = """
    [
      tools: [
        {:seq, "elixir script.exs", umbrella: [parallel: false]},
      ]
    ]
    """

    config_path = Path.join(project_root_dir, ".check.exs")
    File.write!(config_path, config)

    child_a_script_path = Path.join(child_a_dir, "script.exs")
    File.write!(child_a_script_path, a_script)

    child_b_script_path = Path.join(child_b_dir, "script.exs")
    File.write!(child_b_script_path, b_script)

    System.cmd("mix", ~w[compile], cd: project_root_dir) |> cmd_exit(0)
    output = System.cmd("mix", ~w[check], cd: project_root_dir) |> cmd_exit(0)

    assert output =~ "seq in child_a success"
    assert output =~ "seq in child_b success"
    assert output =~ "a_out"
  end
end
