defmodule ExCheck.ProjectCases.DepsTest do
  use ExCheck.ProjectCase, async: true

  @a_eval """
  Process.sleep(1_000)
  File.write!("a_out", "a_out")
  """

  @b_eval """
  Process.sleep(500)
  File.write!("b_out", "b_out")
  """

  @c_eval """
  IO.puts(File.read!("a_out") <> "-" <> File.read!("b_out"))
  """

  @g_eval """
  raise("some error")
  """

  @config """
  [
    tools: [
      {:c, command: ["elixir", "-e", #{inspect(@c_eval)}], deps: [:a, :b]},
      {:a, command: ["elixir", "-e", #{inspect(@a_eval)}], order: 1},
      {:b, command: ["elixir", "-e", #{inspect(@b_eval)}]},
      {:d, command: "dont_matter", deps: [:e]},
      {:e, command: "dont_matter_too", deps: [:d]},
      {:f, command: "dont_matter_too", deps: [:nonexisting]},

      {:g, command: ["elixir", "-e", #{inspect(@g_eval)}]},
      {:g_any, command: "echo", deps: [:g]},
      {:g_success, command: "echo", deps: [{:g, status: :ok}]},
      {:g_success_hide, command: "echo", deps: [{:g, status: :ok, else: :disable}]},
      {:g_failure, command: "echo", deps: [{:g, status: :error}]}
    ]
  ]
  """

  test "deps", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, @config)

    assert {output, 1} = System.cmd("mix", ~w[check], cd: project_dir)

    assert output =~ "a success"
    assert output =~ "b success"
    assert output =~ "c success"
    assert output =~ "d skipped due to unsatisfied dependency e"
    assert output =~ "e skipped due to unsatisfied dependency d"
    assert output =~ "f skipped due to unsatisfied dependency nonexisting"
    assert output =~ "a_out-b_out"
    assert output =~ ~r/running b.*running a.*running c/s

    assert output =~ "g error code 1"
    assert output =~ "g_success skipped due to unsatisfied dependency g"
    refute output =~ "g_success_hide skipped"
    assert output =~ "g_failure success"
  end

  test "deps (no parallel)", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, @config)

    assert {output, 1} = System.cmd("mix", ~w[check --no-parallel], cd: project_dir)

    assert output =~ "a success"
    assert output =~ "b success"
    assert output =~ "c success"
    assert output =~ "d skipped due to unsatisfied dependency e"
    assert output =~ "e skipped due to unsatisfied dependency d"
    assert output =~ "f skipped due to unsatisfied dependency nonexisting"
    assert output =~ "a_out-b_out"
    assert output =~ ~r/running b.*running a.*running c/s

    assert output =~ "g error code 1"
    assert output =~ "g_success skipped due to unsatisfied dependency g"
    refute output =~ "g_success_hide skipped"
    assert output =~ "g_failure success"
  end
end
