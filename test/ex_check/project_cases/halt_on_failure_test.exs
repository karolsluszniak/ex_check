defmodule ExCheck.ProjectCases.HaltOnFailureTest do
  use ExCheck.ProjectCase, async: true

  @config """
  [
    retry: false,
    tools: [
      {:a, command: "echo a_out"},
      {:b, command: ["elixir", "-e", "raise(\\"some error\\")"]},
      {:c, command: "echo c_out"}
    ]
  ]
  """

  test "halt on failure", %{project_dir: project_dir} do
    config_path = Path.join(project_dir, ".check.exs")
    File.write!(config_path, @config)

    args = ~w[check --no-parallel --only a --only b --only c]

    output =
      System.cmd("mix", args ++ ["--halt-on-failure"], cd: project_dir) |> cmd_exit(1)

    assert output =~ "a success"
    assert output =~ "b error code 1"
    assert output =~ "c skipped due to halted after failure of b"
    refute output =~ "c_out"

    output = System.cmd("mix", args, cd: project_dir) |> cmd_exit(1)

    assert output =~ "c success"
    assert output =~ "c_out"
  end
end
